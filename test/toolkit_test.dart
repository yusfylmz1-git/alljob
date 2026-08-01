import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/features/toolkit/application/toolkit_calculators.dart';
import 'package:sepette_hizmet/features/toolkit/application/toolkit_cost.dart';
import 'package:sepette_hizmet/features/toolkit/application/toolkit_models.dart';
import 'package:sepette_hizmet/features/toolkit/presentation/toolkit_hub_screen.dart';

/// Usta Çantası (PRD-007 Faz A) testleri:
/// - Hub ekranı misafir için (provider/backend olmadan) exception'sız açılır.
/// - Zorunlu "tahmini" uyarısı görünür.
/// - Çekirdek model matematiği (net alan sıkışması, seans toplamı).
void main() {
  group('ToolkitHubScreen', () {
    Future<void> pumpHub(WidgetTester tester, {required bool dark}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // Hub'ın Riverpod veya Firebase bağımlılığı yok — ProviderScope gereksiz.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const ToolkitHubScreen(),
      ));
      await tester.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'koyu' : 'açık'} temada açılır ve uyarı gösterir',
          (tester) async {
        await pumpHub(tester, dark: dark);

        expect(find.text('Usta Çantası'), findsWidgets);
        // Zorunlu "tahmini" uyarısı (PRD kritik ilke).
        expect(
          find.textContaining('Tahmini ölçüm'),
          findsOneWidget,
        );
        // Üstteki araç kartları görünür (alttakiler ListView'de kaydırma ister).
        expect(find.text('Ölç & Hesapla'), findsOneWidget);
        expect(find.text('Alan Hesapla'), findsOneWidget);
        // Alttaki bir kart kaydırınca erişilebilir (liste doğru kuruluyor).
        await tester.scrollUntilVisible(
          find.text('Teklif Oluştur'),
          200,
        );
        expect(find.text('Teklif Oluştur'), findsOneWidget);
      });
    }
  });

  group('Yuzey', () {
    test('dikdörtgen brüt/net alan hesaplar', () {
      final y = Yuzey.dikdortgen(enM: 4, boyM: 3);
      expect(y.brutAlanM2, 12);
      expect(y.netAlanM2, 12);
    });

    test('düşüm net alandan çıkar', () {
      final y = Yuzey.dikdortgen(enM: 4, boyM: 3, dususmM2: 2);
      expect(y.netAlanM2, 10);
    });

    test('düşüm alanı aşarsa net alan negatife düşmez', () {
      final y = Yuzey.dikdortgen(enM: 1, boyM: 1, dususmM2: 5);
      expect(y.netAlanM2, 0);
    });

    test('doğrudan alan girişi desteklenir', () {
      final y = Yuzey.alan(alanM2: 25, dususmM2: 5);
      expect(y.brutAlanM2, 25);
      expect(y.netAlanM2, 20);
    });
  });

  group('OlcumSeansi', () {
    test('boş seansın toplamı sıfırdır', () {
      expect(OlcumSeansi().toplamNetAlanM2, 0);
    });

    test('yüzey ekleme immutable yeni seans üretir ve toplar', () {
      final s0 = OlcumSeansi();
      final s1 = s0
          .yuzeyEkle(Yuzey.dikdortgen(enM: 2, boyM: 3)) // 6
          .yuzeyEkle(Yuzey.alan(alanM2: 4)); // 4
      expect(s0.toplamNetAlanM2, 0, reason: 'orijinal seans değişmemeli');
      expect(s1.toplamNetAlanM2, 10);
      expect(s1.yuzeyler.length, 2);
    });
  });

  group('FireOrani / OlcuKaynagi', () {
    test('fire oranları beklenen çarpanlara sahip', () {
      expect(FireOrani.yok.oran, 0.0);
      expect(FireOrani.on.oran, 0.10);
      expect(FireOrani.onbes.oran, 0.15);
    });

    test('kaynak rozet etiketleri', () {
      expect(OlcuKaynagi.manuel.etiket, 'Manuel');
      expect(OlcuKaynagi.ar.etiket, 'AR');
    });
  });

  group('trSayi (TR biçim)', () {
    test('binlik ve ondalık ayracı doğru', () {
      expect(trSayi(1234.5), '1.234,5');
      expect(trSayi(1000000), '1.000.000');
      expect(trSayi(12), '12');
      expect(trSayi(0), '0');
    });

    test('gereksiz sondaki sıfırlar atılır', () {
      expect(trSayi(10.50), '10,5');
      expect(trSayi(10.00), '10');
    });
  });

  group('alanHesapla (Faz B)', () {
    test('fire yok: net = brüt - düşüm, fireli = net', () {
      final seans = OlcumSeansi(yuzeyler: [
        Yuzey.dikdortgen(enM: 4, boyM: 3, dususmM2: 2), // brüt 12, net 10
      ]);
      final r = alanHesapla(seans);
      expect(r.brutM2, 12);
      expect(r.dususmM2, 2);
      expect(r.netM2, 10);
      expect(r.fireliM2, 10);
      expect(r.tahmini, isTrue);
    });

    test('%10 fire net alanı büyütür', () {
      final seans =
          OlcumSeansi(yuzeyler: [Yuzey.dikdortgen(enM: 5, boyM: 2)]); // 10
      final r = alanHesapla(seans, fire: FireOrani.on);
      expect(r.netM2, 10);
      expect(r.fireliM2, closeTo(11, 1e-9));
    });

    test('özel fire oranı uygulanır', () {
      final seans =
          OlcumSeansi(yuzeyler: [Yuzey.dikdortgen(enM: 10, boyM: 10)]); // 100
      final r = alanHesapla(seans,
          fire: FireOrani.ozel, ozelFireOrani: 0.08);
      expect(r.fireliM2, closeTo(108, 1e-9));
    });
  });

  group('boyaHesapla (Faz B)', () {
    test('litre = alan × kat / verim', () {
      final r = boyaHesapla(alanM2: 60, katSayisi: 2, verimM2PerLitre: 12);
      expect(r.litre, closeTo(10, 1e-9)); // 120 / 12
      expect(r.ozet, contains('tahmini'));
    });

    test('verim 0/negatif → güvenli 10', () {
      final r = boyaHesapla(alanM2: 100, verimM2PerLitre: 0);
      expect(r.verimM2PerLitre, 10);
      expect(r.litre, closeTo(10, 1e-9));
    });

    test('kat < 1 → en az 1 kat', () {
      final r = boyaHesapla(alanM2: 10, katSayisi: 0, verimM2PerLitre: 10);
      expect(r.katSayisi, 1);
      expect(r.litre, closeTo(1, 1e-9));
    });
  });

  group('fayansHesapla (Faz B)', () {
    test('derzsiz, fire yok: adet yukarı yuvarlanır', () {
      // 10 m² alan, 50×50 cm fayans = 0.25 m²/adet → 40 adet.
      final r = fayansHesapla(
        alanM2: 10,
        fayansEnCm: 50,
        fayansBoyCm: 50,
        fire: FireOrani.yok,
      );
      expect(r.tekFayansM2, closeTo(0.25, 1e-9));
      expect(r.adet, 40);
    });

    test('fire adet sayısını artırır ve yukarı yuvarlar', () {
      // 40 adet × 1.10 = 44.
      final r = fayansHesapla(
        alanM2: 10,
        fayansEnCm: 50,
        fayansBoyCm: 50,
        fire: FireOrani.on,
      );
      expect(r.adet, 44);
    });

    test('derz efektif alanı büyütür → daha az adet', () {
      final derzsiz = fayansHesapla(
          alanM2: 10, fayansEnCm: 50, fayansBoyCm: 50, fire: FireOrani.yok);
      final derzli = fayansHesapla(
          alanM2: 10,
          fayansEnCm: 50,
          fayansBoyCm: 50,
          derzMm: 5,
          fire: FireOrani.yok);
      expect(derzli.adet, lessThanOrEqualTo(derzsiz.adet));
    });

    test('geçersiz ebat → 0 adet (çökme yok)', () {
      final r = fayansHesapla(alanM2: 10, fayansEnCm: 0, fayansBoyCm: 0);
      expect(r.adet, 0);
    });
  });

  group('parkeHesapla', () {
    test('paket adedi fire dâhil yukarı yuvarlanır', () {
      // 20 m² zemin, 2 m²/paket, %10 fire → 22 m² / 2 = 11 paket.
      final r = parkeHesapla(alanM2: 20, paketM2: 2, fire: FireOrani.on);
      expect(r.fireliM2, closeTo(22, 0.001));
      expect(r.paketAdedi, 11);
    });

    test('küsurat yukarı yuvarlanır', () {
      // 15 m², 2.5 m²/paket, fire yok → 6 paket (15/2.5 = 6.0 → tam),
      // 16 m² → 6.4 → 7 paket.
      expect(parkeHesapla(alanM2: 15, paketM2: 2.5, fire: FireOrani.yok)
          .paketAdedi, 6);
      expect(parkeHesapla(alanM2: 16, paketM2: 2.5, fire: FireOrani.yok)
          .paketAdedi, 7);
    });

    test('paket alanı 0/negatif → güvenli 2.0', () {
      final r = parkeHesapla(alanM2: 10, paketM2: 0, fire: FireOrani.yok);
      expect(r.paketM2, 2.0);
      expect(r.paketAdedi, 5);
    });

    test('geçersiz alan → 0 paket (çökme yok)', () {
      expect(parkeHesapla(alanM2: 0).paketAdedi, 0);
    });
  });

  group('uzunlukM (Faz D — AR)', () {
    test('eksen boyunca mesafe', () {
      expect(uzunlukM([0, 0, 0], [3, 0, 0]), closeTo(3, 1e-9));
      expect(uzunlukM([0, 0, 0], [0, 0, 4]), closeTo(4, 1e-9));
    });

    test('3B çapraz mesafe (3-4-5)', () {
      expect(uzunlukM([0, 0, 0], [3, 0, 4]), closeTo(5, 1e-9));
    });

    test('eksik koordinat → 0 (çökme yok)', () {
      expect(uzunlukM([0, 0], [1, 1, 1]), 0);
    });

    test('ArUzunlukSonucu tahmini ve özet', () {
      const s = ArUzunlukSonucu(metre: 2.5);
      expect(s.tahmini, isTrue);
      expect(s.ozet, contains('2,5 m'));
    });
  });

  group('maliyetHesapla (Faz C)', () {
    test('bileşenler toplanır', () {
      final r = maliyetHesapla(
          malzeme: 1000, iscilik: 500, yol: 100, diger: 50);
      expect(r.toplam, 1650);
    });

    test('negatif bileşen 0 sayılır', () {
      final r = maliyetHesapla(malzeme: -100, iscilik: 200);
      expect(r.malzeme, 0);
      expect(r.toplam, 200);
    });
  });

  group('karHesapla (Faz C)', () {
    test('yüzde kâr satışa eklenir', () {
      final r = karHesapla(
          maliyet: 1000, yontem: KarYontemi.yuzde, deger: 25);
      expect(r.karTutari, closeTo(250, 1e-9));
      expect(r.satis, closeTo(1250, 1e-9));
      expect(r.efektifYuzde, closeTo(20, 1e-9)); // 250/1250
    });

    test('sabit kâr doğrudan eklenir', () {
      final r =
          karHesapla(maliyet: 1000, yontem: KarYontemi.sabit, deger: 300);
      expect(r.satis, closeTo(1300, 1e-9));
    });
  });

  group('teklifHesapla (Faz C)', () {
    test('ara toplam + KDV %20 + genel toplam', () {
      final r = teklifHesapla(kalemler: [
        const TeklifKalemi(aciklama: 'Boya', miktar: 2, birimFiyat: 100),
        const TeklifKalemi(aciklama: 'İşçilik', miktar: 1, birimFiyat: 300),
      ]);
      expect(r.araToplam, 500); // 200 + 300
      expect(r.kdvTutari, closeTo(100, 1e-9));
      expect(r.genelToplam, closeTo(600, 1e-9));
      expect(r.ozet, contains('GENEL TOPLAM'));
    });

    test('KDV kapalı → genel toplam = ara toplam', () {
      final r = teklifHesapla(
        kalemler: [
          const TeklifKalemi(aciklama: 'x', miktar: 1, birimFiyat: 100),
        ],
        kdvOrani: 0,
      );
      expect(r.genelToplam, 100);
    });
  });

  group('birimCevir (Faz C)', () {
    test('cm → m', () {
      final cm = kBirimTablosu[BirimGrubu.uzunluk]!
          .firstWhere((b) => b.ad == 'cm');
      final m =
          kBirimTablosu[BirimGrubu.uzunluk]!.firstWhere((b) => b.ad == 'm');
      expect(birimCevir(250, cm, m), closeTo(2.5, 1e-9));
    });

    test('inç → cm', () {
      final inc = kBirimTablosu[BirimGrubu.uzunluk]!
          .firstWhere((b) => b.ad == 'inç');
      final cm = kBirimTablosu[BirimGrubu.uzunluk]!
          .firstWhere((b) => b.ad == 'cm');
      expect(birimCevir(1, inc, cm), closeTo(2.54, 1e-9));
    });
  });

  group('sureHesapla (Faz C)', () {
    test('saat = alan / hız, gün = saat / günlük', () {
      final r = sureHesapla(alanM2: 60, m2PerSaat: 15, gunlukSaat: 8);
      expect(r.saat, closeTo(4, 1e-9));
      expect(r.gun, closeTo(0.5, 1e-9));
    });

    test('hız 0 → güvenli 1 (çökme yok)', () {
      final r = sureHesapla(alanM2: 10, m2PerSaat: 0);
      expect(r.m2PerSaat, 1);
      expect(r.saat, 10);
    });
  });
}

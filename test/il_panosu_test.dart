// Regresyon: il bazlı müsait sayacı ve Pro takvimi (2026-08-23).
//
// Şehir bazlı Pro geçişinin ölçüsü: bir ilde kaç kullanıcı ŞU AN müsait?
// 1.000'e ulaşan il ücretli döneme hazır sayılır ve iki aylık takvim başlar.
//
// Bugüne kadar istatistiklerde İL KIRILIMI yoktu — "Bursa 1.000'e ulaştı mı?"
// sorusu cevaplanamıyordu ve pilot il seçilemiyordu.
//
// Çift test (kural 7): eşik/aşama doğru hesaplanıyor MU + damga bir kez
// yazılıp bir daha DEĞİŞMİYOR MU. İkincisi kritik: sayı düştü diye geri
// sayım geri sararsa kullanıcıya verilen tarih anlamını yitirir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/admin/data/admin_province_stats.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  ProvinceStat stat({
    int sayi = 0,
    DateTime? damga,
  }) =>
      ProvinceStat(
        province: 'Bursa',
        availableCount: sayi,
        thresholdReachedAt: damga,
      );

  group('Eşik hesabı', () {
    test('eşiğin altında kalan sayı doğru', () {
      expect(stat(sayi: 400).remaining, 600);
      expect(stat(sayi: 999).remaining, 1);
    });

    test('damgasız kayıt eşiğe ULAŞMIŞ sayılmaz', () {
      // Sayı eşiği geçse bile TAKVİM damgayla başlar: sunucu sayımı
      // yazana kadar hiçbir aşama işlemez.
      expect(stat(sayi: 1500).reached, isFalse);
      expect(stat(sayi: 1500).phaseAt(DateTime(2026, 9, 1)), isNull,
          reason: 'Takvimi başlatan şey damgadır, sayı değil.');
      // `remaining` ilerlemeyi ölçer, damgayı değil — eşik aşıldıysa 0.
      expect(stat(sayi: 1500).remaining, 0);
    });

    test('damgalı kayıt ulaşmış sayılır ve kalan 0', () {
      final s = stat(sayi: 1000, damga: DateTime(2026, 9, 1));
      expect(s.reached, isTrue);
      expect(s.remaining, 0);
    });

    test('ilerleme 1\'i AŞMIYOR', () {
      // Çubuk taşarsa görsel bozulur.
      expect(stat(sayi: 5000, damga: DateTime(2026, 9, 1)).progress, 1.0);
      expect(stat(sayi: 500).progress, 0.5);
      expect(stat(sayi: 0).progress, 0.0);
    });
  });

  group('Pro takvimi — üç aşama', () {
    final damga = DateTime(2026, 9, 1);

    test('ilk 30 gün: geri sayım (hâlâ ücretsiz)', () {
      expect(stat(damga: damga).phaseAt(DateTime(2026, 9, 1)),
          ProvincePhase.countdown);
      expect(stat(damga: damga).phaseAt(DateTime(2026, 9, 29)),
          ProvincePhase.countdown);
    });

    test('30–60 gün: teklif penceresi', () {
      expect(stat(damga: damga).phaseAt(DateTime(2026, 10, 1)),
          ProvincePhase.offer);
      expect(stat(damga: damga).phaseAt(DateTime(2026, 10, 30)),
          ProvincePhase.offer);
    });

    test('60 günden sonra: ücretli', () {
      expect(stat(damga: damga).phaseAt(DateTime(2026, 11, 5)),
          ProvincePhase.paid);
    });

    test('damga yoksa aşama YOK', () {
      // Eşiğe ulaşmamış ilde takvim hiç başlamaz.
      expect(stat(sayi: 800).phaseAt(DateTime(2026, 9, 1)), isNull);
    });

    test('aşama sınırları BİTİŞİK (boşluk yok)', () {
      // 29/30 ve 59/60 sınırlarında hiçbir gün aşamasız kalmamalı.
      for (var gun = 0; gun < 90; gun++) {
        final an = damga.add(Duration(days: gun));
        expect(stat(damga: damga).phaseAt(an), isNotNull,
            reason: '$gun. günde aşama boş kaldı.');
      }
    });
  });

  group('Fazlasını yapmıyor — damga KİLİTLİ', () {
    test('sunucu damgayı yalnız BİR KEZ yazıyor', () {
      // Sayı düştü diye geri sayım geri sararsa kullanıcıya verilen tarih
      // anlamını yitirir.
      final js = read('functions/index.js');
      expect(js.contains('!damgalar.has(il)'), isTrue,
          reason: 'Damga her sayımda yeniden yazılıyor — takvim kayar.');
    });

    test('boşalan ilde sayaç sıfırlanır ama damga KORUNUR', () {
      final js = read('functions/index.js');
      expect(js.contains('{availableCount: 0, updatedAt: simdi}'), isTrue,
          reason: 'Boşalan il eski sayıyı göstermeye devam etmemeli.');
      // Sıfırlama patch'i thresholdReachedAt taşımamalı.
      expect(js.contains('{availableCount: 0, updatedAt: simdi, '), isFalse);
    });
  });

  group('Sunucu sayımı — tasarım kararları', () {
    late String js;
    setUpAll(() => js = read('functions/index.js'));

    test('GÜNLÜK toplu sayım, artırımlı sayaç DEĞİL', () {
      // "Şu an müsait" sık değişir; her değişimde increment yazmak kayar
      // (CF yeniden denemesi sayacı ikiler). Tam sayım her gün sıfırdan.
      expect(js.contains('exports.rebuildProvinceStats = onSchedule('), isTrue);
      expect(js.contains('schedule: "0 3 * * *"'), isTrue);
    });

    test('sorgular SAYFALI', () {
      // Koleksiyon büyüyecek; limitsiz tarama zaman aşımı üretir.
      final blok = RegExp(
        r'exports\.rebuildProvinceStats = onSchedule\((.*?)\n\);',
        dotAll: true,
      ).firstMatch(js);
      expect(blok, isNotNull);
      final govde = blok!.group(1)!;
      expect(govde.contains('.orderBy(FieldPath.documentId())'), isTrue);
      expect(govde.contains('startAfter('), isTrue);
    });

    test('ölçü users.available (isAvailableAt KOPYALANMIYOR)', () {
      // Haftalık takvimi sunucuda yeniden hesaplamak, istemcideki
      // `isAvailableAt` mantığının ikinci bir kopyası olurdu ve iki taraf
      // zamanla ayrışırdı.
      expect(js.contains('d.available !== true) continue'), isTrue);
      expect(js.contains('weeklySchedule'), isFalse,
          reason: 'Takvim mantığı sunucuya kopyalanmış — ayrışma riski.');
    });

    test('askıya alınmış hesap arzın parçası DEĞİL', () {
      expect(js.contains('d.suspended === true) continue'), isTrue);
    });

    test('mevcut damgalar TEK sorguda okunuyor', () {
      // İl başına ayrı `get()` 81 ayrı okuma demekti.
      final blok = RegExp(
        r'exports\.rebuildProvinceStats = onSchedule\((.*?)\n\);',
        dotAll: true,
      ).firstMatch(js)!.group(1)!;
      expect(blok.contains('const mevcutSnap = await kok.get();'), isTrue);
    });
  });

  group('Eşik iki tarafta AYNI', () {
    test('Dart ve JS eşiği eşleşiyor', () {
      // Ayrışırsa pano "hazır" derken sunucu damgalamaz (ya da tersi).
      final js = read('functions/index.js');
      final m = RegExp(r'const PROVINCE_THRESHOLD = (\d+);').firstMatch(js);
      expect(m, isNotNull, reason: 'Sunucu eşiği tanımlı değil.');
      expect(int.parse(m!.group(1)!), ProvinceStat.threshold);
    });
  });

  group('Pano toplu plan ekranının İÇİNDE', () {
    test('ayrı sekme açılmamış (menü şişmesin)', () {
      final app = read('lib/features/admin/presentation/admin_app.dart');
      expect(app.contains('AdminProvincePanel'), isFalse,
          reason: 'Pano ayrı sekme yapılmış; yönetici il seçmek için iki '
              'ekran arasında gidip gelir.');
    });

    test('toplu plan ekranına bağlı ve il seçiciyi dolduruyor', () {
      final ekran =
          read('lib/features/admin/presentation/admin_bulk_plan_screen.dart');
      expect(ekran.contains('AdminProvincePanel('), isTrue);
      expect(ekran.contains('onSelect:'), isTrue,
          reason: 'Tabloda görülen il elle aranmak zorunda kalmamalı.');
    });
  });
}

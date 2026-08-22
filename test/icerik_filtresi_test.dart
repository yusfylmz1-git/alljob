// Regresyon: argo / müstehcen içerik denetimi (2026-08-23).
//
// Kapalı test geri bildirimi: "mesajlarda argo kelime filtreleme yapmıyoruz.
// müstehcen yazıların denetlemesini nasıl yaparız?"
//
// Tasarım — ENGELLEME DEĞİL, KADEMELİ MÜDAHALE:
//   * mild  → istemci sorar, kullanıcı ısrar ederse gönderilir.
//   * severe→ mesaj yine gider ama sunucuda moderasyon kuyruğuna düşer.
//
// Çift test (kural 7): küfür yakalanıyor MU + masum mesaj ELENMİYOR MU.
// İkincisi burada BİRİNCİDEN ÖNEMLİ: yanlış pozitif, kullanıcının meşru
// mesajını engeller ve filtreye olan güveni bitirir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/utils/content_filter.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  ContentSeverity sev(String s) => ContentFilter.inspect(s).severity;

  group('Küfür yakalanıyor', () {
    test('düz yazım', () {
      expect(sev('siktir git buradan'), ContentSeverity.severe);
      expect(sev('amk'), ContentSeverity.severe);
    });

    test('kaba dil UYARI eşiğinde', () {
      expect(sev('salak herif'), ContentSeverity.mild);
      expect(sev('serefsiz adam'), ContentSeverity.mild);
    });

    test('ağır içerik kaba dili EZER (öncelik)', () {
      // Aynı mesajda ikisi de varsa sonuç severe olmalı; mild'e düşerse
      // sunucu kuyruğa hiç düşmez.
      expect(sev('salak herif siktir'), ContentSeverity.severe);
    });
  });

  group('Kaçış denemeleri normalize ediliyor', () {
    test('boşlukla ayırma: "S İ K T İ R"', () {
      expect(normalizeForFilter('S İ K T İ R'), 'siktir');
      expect(sev('S İ K T İ R'), ContentSeverity.severe);
    });

    test('noktalama: "a.m.k"', () {
      expect(sev('a.m.k'), ContentSeverity.severe);
    });

    test('leetspeak: "s1kt1r"', () {
      expect(sev('s1kt1r'), ContentSeverity.severe);
    });

    test('harf tekrarı: "siktirrrr"', () {
      expect(sev('siktirrrr'), ContentSeverity.severe);
    });

    test('büyük/küçük harf ve Türkçe karakter', () {
      expect(sev('OROSPU'), ContentSeverity.severe);
    });
  });

  group('Fazlasını yapmıyor — masum mesajlar TEMİZ', () {
    test('normal usta mesajları', () {
      const mesajlar = [
        'Merhaba, kombi tamiri için yarın gelebilirim.',
        'Fiyat 2500 TL, malzeme dahil.',
        'Adresinizi paylaşır mısınız?',
        'İşi bitirdim, kolay gelsin.',
        'Boya işi için Salı günü uygunum.',
      ];
      for (final m in mesajlar) {
        expect(ContentFilter.inspect(m).isClean, isTrue,
            reason: 'Masum mesaj yakalandı: "$m"');
      }
    });

    test('yasak kelimeyi İÇEREN masum kelimeler', () {
      // Kelime sınırı + kalkan listesi olmasa hepsi yanlışlıkla yakalanırdı.
      const masum = [
        'malzeme listesi hazır',
        'maliyet hesabı çıkardım',
        'analiz raporu ektedir',
        'anahtar teslim iş',
        'sikke koleksiyonu için vitrin',
        'Malatya\'dan geliyorum',
        'bokser marka ürün',
      ];
      for (final m in masum) {
        expect(ContentFilter.inspect(m).isClean, isTrue,
            reason: 'Yanlış pozitif: "$m"');
      }
    });

    test('günlük dolgu sözcükleri uyarı ÜRETMİYOR', () {
      // "lan"/"bok" bilinçli olarak listede DEĞİL: her mesajda uyarı çıkarsa
      // kullanıcı öğrenip geçer ve uyarı gerçek hakarette de anlamsızlaşır.
      expect(ContentFilter.inspect('lan unuttum').isClean, isTrue);
      expect(ContentFilter.inspect('hava bok gibi').isClean, isTrue);
    });

    test('boş / null metin çökmüyor', () {
      expect(ContentFilter.inspect(null).isClean, isTrue);
      expect(ContentFilter.inspect('').isClean, isTrue);
      expect(ContentFilter.inspect('   ').isClean, isTrue);
      expect(ContentFilter.inspect('!!! ??? ...').isClean, isTrue);
    });
  });

  group('Sözlükler normalize biçimde TUTULUYOR', () {
    // Bu testin varlık sebebi gerçek bir hata: liste ilk yazıldığında
    // 'yarrak' ve 'namussuz' ham hâldeydi. Normalize edilmiş metinde çift
    // harf teke indiği için ('yarak', 'namusuz') bu maddeler HİÇ eşleşmiyor,
    // filtre sessizce delik veriyordu.
    test('her sözlük maddesi kendi normalizasyonuna eşit', () {
      final kaynak = read('lib/core/utils/content_filter.dart');
      final listeler = RegExp(
        r'static const List<String> _\w+ = \[(.*?)\];',
        dotAll: true,
      ).allMatches(kaynak);

      expect(listeler.length, 3,
          reason: 'Üç liste bekleniyor: _severe, _mild, _allowList.');

      for (final l in listeler) {
        final govde = l
            .group(1)!
            .split('\n')
            .where((x) => !x.trimLeft().startsWith('//'))
            .join('\n');
        final kelimeler =
            RegExp(r"'([^']+)'").allMatches(govde).map((m) => m.group(1)!);
        for (final k in kelimeler) {
          expect(normalizeForFilter(k), k,
              reason: '"$k" normalize edilince "${normalizeForFilter(k)}" '
                  'oluyor — bu maddeyi HİÇBİR mesaj tetikleyemez.');
        }
      }
    });
  });

  group('Sunucu aynası istemciyle AYNI', () {
    late String dart;
    late String js;
    setUpAll(() {
      dart = read('lib/core/utils/content_filter.dart');
      js = read('functions/index.js');
    });

    test('ağır kelime listeleri birebir aynı', () {
      // Ayrışırsa: istemci uyarır ama sunucu kuyruğa düşürmez (ya da tersi).
      List<String> cikar(String kaynak, RegExp desen) {
        final blok = desen.firstMatch(kaynak);
        expect(blok, isNotNull, reason: 'Liste bulunamadı.');
        // Yorum satırları elenir: içlerindeki tırnaklı metin listeye
        // karışırsa test kaynağın biçimine takılır, içeriğine değil.
        final govde = blok!
            .group(1)!
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        return RegExp("['\"]([^'\"]+)['\"]")
            .allMatches(govde)
            .map((m) => m.group(1)!)
            .toList();
      }

      final dartListe = cikar(
        dart,
        RegExp(r'static const List<String> _severe = \[(.*?)\];', dotAll: true),
      );
      final jsListe = cikar(
        js,
        RegExp(r'const SEVERE_WORDS = \[(.*?)\];', dotAll: true),
      );

      expect(jsListe, dartListe,
          reason: 'İstemci ve sunucu sözlükleri ayrışmış — biri yakalarken '
              'diğeri kaçırır. İkisi BİRLİKTE değişmeli.');
    });

    test('kalkan listeleri birebir aynı', () {
      List<String> cikar(String kaynak, RegExp desen) {
        final govde = desen
            .firstMatch(kaynak)!
            .group(1)!
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        return RegExp("['\"]([^'\"]+)['\"]")
            .allMatches(govde)
            .map((m) => m.group(1)!)
            .toList();
      }

      expect(
        cikar(js, RegExp(r'const FILTER_ALLOW = \[(.*?)\];', dotAll: true)),
        cikar(
          dart,
          RegExp(r'static const List<String> _allowList = \[(.*?)\];',
              dotAll: true),
        ),
        reason: 'Kalkan ayrışırsa bir taraf masum mesajı yakalar.',
      );
    });
  });

  group('Sunucu: ağır içerik moderasyon kuyruğuna düşer', () {
    late String js;
    setUpAll(() => js = read('functions/index.js'));

    test('onMessageCreated filtreyi çağırıyor', () {
      expect(js.contains('severeMatches(msg.text)'), isTrue);
      expect(js.contains('flagMessageForReview('), isTrue);
    });

    test('mesaj SİLİNMİYOR / engellenmiyor', () {
      // Filtre bir kapı değil: karar moderatörün. Mesaj silen bir çağrı
      // eklenirse yanlış pozitif kullanıcının mesajını yok eder.
      final blok = RegExp(
        r'exports\.onMessageCreated = onDocumentCreated\((.*?)\n\);',
        dotAll: true,
      ).firstMatch(js);
      expect(blok, isNotNull);
      expect(blok!.group(1)!.contains('.delete()'), isFalse,
          reason: 'Filtre mesajı silmemeli — karar moderatörün.');
    });

    test('filtre hatası bildirimi DÜŞÜRMÜYOR', () {
      expect(js.contains('içerik filtresi hatası'), isTrue,
          reason: 'Sözlük hatası tüm mesajlaşmayı bozmamalı.');
    });

    test('kuyruk kaydı deterministik kimlikli (tekrar şişirmiyor)', () {
      expect(js.contains('__autofilter'), isTrue,
          reason: 'CF yeniden denemesi kuyruğa ikinci kayıt atmamalı.');
    });

    test('kanıt metni kısaltılıyor', () {
      expect(js.contains('.slice(0, 500)'), isTrue,
          reason: 'Rapor dökümanı sohbetin tamamını taşımamalı.');
    });
  });

  group('İstemci: gönderim öncesi uyarı', () {
    late String chat;
    setUpAll(() =>
        chat = read('lib/features/chat/presentation/chat_screen.dart'));

    test('gönderim denetimden geçiyor', () {
      expect(chat.contains('if (!await _icerikOnayi(text)) return;'), isTrue);
    });

    test('temiz mesajda diyalog AÇILMIYOR', () {
      expect(chat.contains('if (verdict.isClean) return true;'), isTrue,
          reason: 'Sıcak yolda gereksiz diyalog kullanıcıyı yorar.');
    });

    test('kullanıcı ısrar edebiliyor (kapı değil)', () {
      expect(chat.contains('Yine de gönder'), isTrue,
          reason: 'Yanlış pozitif meşru mesajı engellememeli.');
    });

    test('yakalanan KELİME kullanıcıya gösterilmiyor', () {
      // Söylemek filtreyi atlatmayı öğretir.
      expect(chat.contains('verdict.matches'), isFalse,
          reason: 'Eşleşen kelimeyi göstermek kaçış öğretir.');
    });
  });

  group('Moderatör otomatik kaydı ayırt edebiliyor', () {
    test('admin ekranı "system" uid\'ini çeviriyor', () {
      final ekran =
          read('lib/features/admin/presentation/admin_reports_screen.dart');
      expect(ekran.contains('Otomatik içerik filtresi'), isTrue,
          reason: 'Ham "system" gösterilirse moderatör olmayan bir '
              'kullanıcıyı arar.');
    });
  });
}

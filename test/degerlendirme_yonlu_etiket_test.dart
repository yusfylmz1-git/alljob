import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/review.dart';

/// Madde 9 — müşteri ve usta değerlendirme kriterleri AYNI kartlardı.
///
/// Usta bir müşteriyi "Temiz işçilik" ya da "Uygun fiyat" diye puanlayamaz:
/// o etiketler hizmeti VERENİ tarif eder. Müşteri tarafında ölçülen şey iş
/// ilişkisidir — iletişim, ödeme, randevuya sadakat, erişim.
void main() {
  group('Etiket setleri yöne göre ayrı', () {
    test('usta seti işçilik/fiyat odaklı kalır', () {
      final u = ReviewTags.positiveFor(ReviewDirection.customerToArtisan);
      expect(u, contains('Temiz işçilik'));
      expect(u, contains('Uygun fiyat'));
    });

    test('müşteri seti işçilik/fiyat etiketi İÇERMEZ', () {
      final m = ReviewTags.positiveFor(ReviewDirection.artisanToCustomer);
      expect(m, isNot(contains('Temiz işçilik')),
          reason: 'Müşteri işçilik yapmaz.');
      expect(m, isNot(contains('Uygun fiyat')),
          reason: 'Fiyatı usta belirler.');
      expect(m, isNot(contains('Kaliteli işçilik')));
    });

    test('müşteri seti iş ilişkisini ölçer', () {
      final m = ReviewTags.positiveFor(ReviewDirection.artisanToCustomer);
      expect(m, contains('Ödemeyi zamanında yaptı'));
      expect(m, contains('Net anlattı'));
      final n = ReviewTags.negativeFor(ReviewDirection.artisanToCustomer);
      expect(n, contains('Ödeme sorunlu'));
      expect(n, contains('Beklenti belirsizdi'));
    });

    test('iki yön de olumlu/olumsuz DENGELİ (8+8)', () {
      for (final d in ReviewDirection.values) {
        expect(ReviewTags.positiveFor(d).length, 8, reason: '$d olumlu');
        expect(ReviewTags.negativeFor(d).length, 8, reason: '$d olumsuz');
      }
    });

    test('bir set içinde etiket tekrarı yok', () {
      for (final d in ReviewDirection.values) {
        final hepsi = [...ReviewTags.positiveFor(d), ...ReviewTags.negativeFor(d)];
        expect(hepsi.toSet().length, hepsi.length,
            reason: '$d içinde aynı etiket iki kez geçiyor.');
      }
    });
  });

  group('isNegative — ESKİ kayıtlar da doğru renklenir', () {
    // Yön ayrımından önceki değerlendirmeler karşı setin etiketlerini
    // taşıyor. Rozet/renk hesabı (`review_cta`, usta profili) onlarda da
    // çalışmalı, yoksa olumsuz etiket YEŞİL görünürdü.
    test('usta setinin olumsuzları', () {
      expect(ReviewTags.isNegative('Kötü işçilik'), isTrue);
      expect(ReviewTags.isNegative('Pahalı'), isTrue);
    });

    test('müşteri setinin olumsuzları', () {
      expect(ReviewTags.isNegative('Ödeme sorunlu'), isTrue);
      expect(ReviewTags.isNegative('Saygısız davrandı'), isTrue);
      expect(ReviewTags.isNegative('Ulaşılamıyordu'), isTrue);
    });

    test('olumlular olumsuz SAYILMAZ (fazlasını yapma)', () {
      expect(ReviewTags.isNegative('Temiz işçilik'), isFalse);
      expect(ReviewTags.isNegative('Ödemeyi zamanında yaptı'), isFalse);
      expect(ReviewTags.isNegative('Tekrar çalışırım'), isFalse);
    });

    test('iki sette ORTAK olan etiketler olumsuz kalır', () {
      // "Randevuya gelmedi" ve "Tavsiye etmiyorum" her iki tarafta da
      // anlamlı; kesişim zararsızdır ama olumsuzluğu bozulmamalı.
      expect(ReviewTags.isNegative('Randevuya gelmedi'), isTrue);
      expect(ReviewTags.isNegative('Tavsiye etmiyorum'), isTrue);
    });
  });

  group('Ekran yönü doğru kaynaktan alıyor', () {
    late String scr;
    setUpAll(() => scr =
        File('lib/features/review/presentation/review_screen.dart')
            .readAsStringSync());

    test('etiketler sabit değil, yöne göre seçiliyor', () {
      expect(scr.contains('ReviewTags.positiveFor(yon)'), isTrue);
      expect(scr.contains('ReviewTags.negativeFor(yon)'), isTrue);
      // Eski sabit kullanım kalmamalı.
      expect(scr.contains('tags: ReviewTags.positive,'), isFalse);
      expect(scr.contains('tags: ReviewTags.negative,'), isFalse);
    });

    test('gösterim ve GÖNDERİM aynı kaynağa bakıyor', () {
      // İkisi ayrışırsa kullanıcı bir set görüp başka set kaydederdi.
      expect('artisanDetailProvider'.allMatches(scr).length >= 2, isTrue);
    });

    test('kayıttaki yabancı etiket kaldırılabiliyor', () {
      // Görünmeyen ama seçili kalan etiket, kullanıcının kaldıramadığı bir
      // veri olurdu.
      expect(scr.contains('_gosterilecek'), isTrue);
    });
  });
}

// Regresyon: admin listelerinde Pro / müsaitlik / il görünür (2026-08-23).
//
// Denetim bulgusu: "admin panelinde illerin durumu, Pro üyeler vs. detaylı
// filtreleme yapacağım bir yer yok."
//
// Panel veriyi TUTUYOR ama SUNMUYORDU: `isPremium`, `available`,
// `serviceAreas` hepsi okunuyordu, hiçbiri listede görünmüyordu. Yönetici
// "bu kişi Pro mu, müsait mi" sorusunu ancak profilini açıp
// cevaplayabiliyordu — 30 kişilik listede 30 tıklama.
//
// Çift test (kural 7): rozetler geldi Mİ + maliyet artmadı MI.
// İkincisi kritik: liste başına ekstra doküman okuması eklemek 30 satırlık
// sayfada 30 okuma demek.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  late String kullanicilar;
  late String ustalar;

  setUpAll(() {
    kullanicilar =
        read('lib/features/admin/presentation/admin_users_screen.dart');
    ustalar =
        read('lib/features/admin/presentation/admin_artisans_screen.dart');
  });

  group('Kullanıcı listesi — rol ayrımı', () {
    test('mağaza sahibi ARTIK müşteri görünmüyor', () {
      // Önce yalnız "Usta / Müşteri" vardı; mağaza sahibi müşteri
      // sayılıyordu. Pro modelinde ölçü müsaitlik ve mağaza sahibi de
      // müsait olur — yönetici ayırt edebilmeli.
      expect(kullanicilar.contains("if (user.hasShopProfile)"), isTrue);
      expect(kullanicilar.contains("label: 'Mağaza'"), isTrue);
    });

    test('müşteri rozeti YALNIZ ikisi de yokken', () {
      expect(
        kullanicilar
            .contains('if (!user.hasArtisanProfile && !user.hasShopProfile)'),
        isTrue,
        reason: 'Usta + mağaza olan kişi hem "Usta" hem "Müşteri" '
            'görünürse liste yanıltır.',
      );
    });
  });

  group('Müsaitlik — Pro modelinin ölçüsü', () {
    test('kullanıcı listesinde müsaitlik rozeti var', () {
      expect(kullanicilar.contains("user.available ? 'Müsait' : 'Kapalı'"),
          isTrue);
    });

    test('müsaitlik YALNIZ usta/mağazada gösteriliyor', () {
      // Müşteride "Kapalı" yazmak anlamsız — o zaten hiç müsait olmaz.
      expect(
        kullanicilar
            .contains('if (user.hasArtisanProfile || user.hasShopProfile)'),
        isTrue,
      );
    });

    test('usta listesinde müsaitlik + premium YAN YANA', () {
      // İkisi birlikte okunur: müsait ama premium yoksa, o kişi geçişte
      // kapanacak demektir. Ayrı yerlerde olsa bağlantı kurulamaz.
      expect(ustalar.contains("'Duraklattı'"), isTrue);
      expect(ustalar.contains("_premiumLabel(p)"), isTrue);
    });

    test('usta listesi takvimli müsaitliği AYIRT ediyor', () {
      // `alwaysAvailable` false ise haftalık takvim devrede — "Kapalı"
      // demek yanlış olurdu.
      expect(ustalar.contains("'Takvimli'"), isTrue);
    });
  });

  group('İl bilgisi', () {
    test('usta listesinde il rozeti var', () {
      expect(ustalar.contains('p.serviceAreas.first.province'), isTrue);
    });

    test('kullanıcı listesinde il mağaza bölgesinden okunuyor', () {
      expect(kullanicilar.contains('user.shopServiceAreas'), isTrue);
    });
  });

  group('Fazlasını yapmıyor — MALİYET artmadı', () {
    test('kullanıcı kartı EK doküman okumuyor', () {
      // `artisanProfiles`'tan premium okumak liste başına 30 ekstra okuma
      // demekti. Bilinçli olarak yapılmadı; usta listesinde zaten var.
      expect(kullanicilar.contains("collection('artisanProfiles')"), isFalse,
          reason: 'Kullanıcı listesi ekstra doküman okuyor — 30 satırlık '
              'sayfada 30 fazladan okuma.');
      expect(kullanicilar.contains('artisanDetailProvider'), isFalse);
    });

    test('rozetler MEVCUT alanlardan geliyor', () {
      // Hiçbiri yeni sorgu gerektirmiyor: available, hasShopProfile,
      // shopServiceAreas hepsi `users` dokümanında.
      for (final alan in [
        'user.available',
        'user.hasShopProfile',
        'user.shopServiceAreas',
      ]) {
        expect(kullanicilar.contains(alan), isTrue, reason: '$alan yok.');
      }
    });

    test('il eksikliği SESSİZ değil — kodda açıklanmış', () {
      // Yalnız usta olan kullanıcıda il görünmüyor (o veri ayrı
      // dokümanda). Bu bilinçli bir ödün; sonradan bakan biri hata
      // sanmasın diye gerekçesi yazılı.
      expect(kullanicilar.contains('maliyetsiz'), isTrue,
          reason: 'Eksikliğin gerekçesi kodda anlatılmamış.');
    });
  });
}

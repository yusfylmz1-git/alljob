// Regresyon: dört kullanıcı durumunun gördüğü içerik (2026-08-20).
//
// Uygulamada dört durum var:
//   1. müşteri            2. müşteri + usta
//   3. müşteri + mağaza   4. müşteri + usta + mağaza
//
// Ana sayfa gövdesi HERKESTE AYNIDIR (2026-08-08 kararı: tek ürün, tek ana
// sayfa) ve müşteri gözüyle kuruludur: "usta bul", "ilan ver", "talep
// oluştur". Bu düzende 2, 3 ve 4 numaralı durumlar ana sayfada kendilerine
// iş getiren HİÇBİR ŞEY görmüyordu — işlerini bulmak için Keşfet'e geçip
// sekme değiştirmeleri gerekiyordu.
//
// Çözüm: `HomeForYou` role duyarlı bir şerit ekler. Müşteride kendini gizler,
// yani 1 numaralı durumun ana sayfası DEĞİŞMEMİŞTİR.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  late String forYou;
  late String homeScreen;
  late String profile;

  setUpAll(() {
    forYou = read('lib/features/home/presentation/widgets/home_for_you.dart');
    homeScreen = read('lib/features/home/presentation/home_screen.dart');
    profile = read('lib/features/profile/presentation/profile_screen.dart');
  });

  group('Ana sayfa role duyarlı', () {
    test('HomeForYou ana sayfaya bağlı', () {
      expect(homeScreen.contains('HomeForYou()'), isTrue,
          reason: 'Role duyarlı bölüm ana sayfadan çıkarılmış — usta/satıcı '
              'yine ana sayfada kendine iş bulamaz.');
    });

    test('rolü OLMAYAN müşteride bölüm gizlenir', () {
      // İki erken çıkış: oturum yok, ve ne usta ne mağaza.
      expect(forYou.contains('if (!ustaMi && !magazaVar)'), isTrue,
          reason: 'Müşteriye boş/alakasız bölüm gösteriliyor.');
      expect(forYou.contains('return const SizedBox.shrink()'), isTrue);
    });

    test('usta ilanları, satıcı talepleri görür', () {
      expect(forYou.contains('user.hasArtisanProfile'), isTrue);
      expect(forYou.contains('user.hasShopProfile'), isTrue);
      expect(forYou.contains('nearbyJobsProvider'), isTrue,
          reason: 'İlan şeridi süzülmüş kaynaktan beslenmiyor — il/meslek '
              'eşleşmesi kaybolur.');
      expect(forYou.contains('productRequestsProvider'), isTrue);
    });

    test('ilan şeridi il+meslek SÜZÜLMÜŞ kaynaktan gelir', () {
      // Ham `openJobsProvider` kullanılsaydı usta başka ilin ilanını görürdü
      // (2026-08-20 feed bulgusunun aynısı burada tekrarlanmasın).
      expect(forYou.contains('openJobsProvider'), isFalse,
          reason: 'Ham akış kullanılmış — il/meslek elemesi atlanır.');
    });

    test('yenileme şeridi de tazeler', () {
      expect(homeScreen.contains('ref.invalidate(nearbyJobsProvider)'), isTrue,
          reason: 'Aşağı çekmek "Sana Uygun İlanlar" bölümünü tazelemiyor.');
    });

    test('misafire gösterilmez (oturum şartı)', () {
      expect(homeScreen.contains('if (!isGuest) const HomeForYou()'), isTrue);
      expect(forYou.contains('if (user == null)'), isTrue);
    });
  });

  group('Profil davet kartları: fayda + şart', () {
    test('usta daveti faydaları SAYIYOR', () {
      expect(profile.contains('_RolDavetKarti'), isTrue,
          reason: 'Zengin davet kartı kaldırılmış, kuru metne dönülmüş.');
      expect(profile.contains('faydalar:'), isTrue);
    });

    test('her iki davet de MÜSAİTLİK şartını söylüyor', () {
      // Sonradan "ürünlerim neden görünmüyor" sorusunu doğuran şey buydu:
      // müsaitlik anahtarı açılmadan vitrin ve mesaj kapalı kalıyor.
      final sartSayisi = 'sartMetni:'.allMatches(profile).length;
      expect(sartSayisi, 2,
          reason: 'Usta ve mağaza davetlerinin İKİSİNDE de müsaitlik uyarısı '
              'olmalı; biri eksikse kullanıcı sonradan şaşırır.');
      expect(profile.contains('Müsait'), isTrue);
    });

    test('faydalar KODUN gerçek davranışına dayanıyor', () {
      // Vaat edilen üç şeyin karşılığı gerçekten var mı?
      final kesfet = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      final magaza = read(
          'lib/features/products/presentation/widgets/magaza_sekmesi.dart');
      final urunler = read('lib/features/products/data/product_providers.dart');

      // "İlanlar sekmesi açılır" → kapı hasArtisanProfile
      expect(kesfet.contains('!user.hasArtisanProfile'), isTrue);
      // "Taleplerin tamamını görürsünüz" → mağaza + müsaitlik
      expect(magaza.contains('magazaVar && musait'), isTrue);
      // "Vitrininiz listelenir" → müsaitliğe bağlı
      expect(urunler.contains('availableDiscoverProductsProvider'), isTrue);
    });
  });

  group('Mağaza kurgusu korundu (fazlasını yapmadı)', () {
    // Kullanıcı teyidi 2026-08-20: "mağaza sahipleri zaten talepleri
    // görebiliyor, sıkıntı yok". Bu grup o davranışın kazara bozulmasını
    // yakalar.
    test('mağaza + müsait → taleplerin TAMAMI', () {
      final magaza = read(
          'lib/features/products/presentation/widgets/magaza_sekmesi.dart');
      expect(magaza.contains('final kilitli = !(magazaVar && musait)'), isTrue);
      expect(magaza.contains('kSinirliTalepSayisi'), isTrue,
          reason: 'Kilitli durumda örnek gösterimi kalkmış — kullanıcı '
              'değeri hiç göremez.');
    });

    test('Talepler sekmesi Keşfet > Mağaza altında duruyor', () {
      final magaza = read(
          'lib/features/products/presentation/widgets/magaza_sekmesi.dart');
      expect(magaza.contains("Tab(text: 'Talepler')"), isTrue);
    });
  });
}

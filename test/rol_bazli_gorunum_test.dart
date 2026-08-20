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

  group('Keşfet > İlanlar kapısı: önizleme + davet', () {
    // 2026-08-20: kapı BOŞ bir uyarı ekranıydı ("usta profili açın").
    // Kullanıcı ne kaçırdığını göremediği için profil açmak soyut bir
    // talimattı. Mağaza > Talepler'de çalışan desen buraya da taşındı.
    late String kesfet;
    setUpAll(() {
      kesfet = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
    });

    test('boş uyarı ekranı YERİNE önizleme gösteriliyor', () {
      expect(kesfet.contains('_IlanKapisiOnizleme'), isTrue,
          reason: 'Önizleme kaldırılmış, boş kapı ekranına dönülmüş.');
      // Eski hâl: usta kapısı `notice(...)` ile boş uyarı ekranı döndürüyor,
      // tek eylemi "Profile git" düğmesiydi. Metnin kendisi aranamaz —
      // yukarıdaki açıklama yorumunda da geçiyor.
      expect(kesfet.contains("Text('Profile git')"), isFalse,
          reason: 'Boş uyarı ekranına geri dönülmüş.');
    });

    test('gerçek ilan gösteriyor, süzülmüş kaynaktan', () {
      expect(kesfet.contains('visibleJobFeedProvider'), isTrue,
          reason: 'Ham akış kullanılırsa ürün talepleri de örnek olarak '
              'gösterilir.');
      expect(kesfet.contains('NearbyJobCard'), isTrue);
    });

    test('davet kartı + gizli sayı var', () {
      expect(kesfet.contains('_UstaProfiliDaveti'), isTrue);
      expect(kesfet.contains('gizliSayi > 0'), isTrue,
          reason: 'Sayı 0 iken de sayı yazılıyor olabilir — yanlış vaat.');
    });

    test('"ilan vermek usta olmayı gerektirmez" bilgisi korundu', () {
      // Eski metindeki bu bilgi kaybolursa müşteri "ilan veremiyorum" sanır.
      expect(kesfet.contains('usta olmanız gerekmez'), isTrue);
    });

    test('MİSAFİR de önizleme görür', () {
      // Misafir aynı ilanları ana sayfa şeridinde ve "Hemen Lazım"
      // listesinde ZATEN görebiliyor; Keşfet'te boş duvar göstermek bir şey
      // korumuyor, yalnız tutarsızlık üretiyordu.
      expect(kesfet.contains('_IlanKapisiOnizleme(misafir: true)'), isTrue,
          reason: 'Misafir yine boş kapı ekranına düşüyor.');
    });

    test('misafir daveti GİRİŞE, üye daveti PROFİLE götürür', () {
      // İki adımlı çağrı: misafire "meslek ve bölge ekleyin" demek, henüz
      // hesabı yokken anlamsız bir talimat olurdu.
      expect(kesfet.contains("Text(misafir ? 'Giriş yap' : 'Usta profili aç')"),
          isTrue,
          reason: 'Davet düğmesi duruma göre değişmiyor.');
      expect(kesfet.contains('misafir ? RoutePaths.login : RoutePaths.profile'),
          isTrue,
          reason: 'Misafir profil ekranına yönlendiriliyor — giriş yapmadan '
              'orada yapabileceği bir şey yok.');
    });

    test('iki kapı AYNI sayıda önizleme gösterir', () {
      // Tutarlılık: iki ekran tek sabitten yönetilmeli.
      final sabitler = read('lib/core/constants/app_constants.dart');
      final magaza = read(
          'lib/features/products/presentation/widgets/magaza_sekmesi.dart');

      expect(sabitler.contains('kapiOnizlemeSayisi'), isTrue);
      expect(kesfet.contains('AppConstants.kapiOnizlemeSayisi'), isTrue);
      expect(magaza.contains('AppConstants.kapiOnizlemeSayisi'), isTrue,
          reason: 'Mağaza kapısı ayrı bir sayıya bağlanmış — iki ekran '
              'farklı davranır.');
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

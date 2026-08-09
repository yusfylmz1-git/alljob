import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/data/models/product.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';

/// Mağaza modülü — Aşama 1 mimari uyum (2026-08-10).
///
/// Ürün modülü 2026-08-08'de kaldırılmış (`4476326`), 2026-08-10'da Mağaza
/// olarak geri getirilmiştir. Aradaki iki haftada ürünün yarısı değişti; bu
/// dosya, geri gelen kodun BUGÜNKÜ mimariye uyduğunu çiviler.
///
/// Plan: `vault/06-Test/PLAN-Magaza.md`
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('1.1 — Ürün sohbeti tek kutuya düşer', () {
    // En kritik madde. Oturum 84'te sohbet kimliği role bağlı olmaktan
    // çıkıp ALFABETİK sıralamaya geçti. Ürün detayı `startChat` çağırıyor;
    // ürün yolundan açılan sohbet, aynı kişiyle olan MEVCUT kutuya düşmeli.
    // Düşmezse oturum 84'te kapatılan "aynı çift iki kutu" hatası geri gelir.

    test('ürün yolundan açılan sohbet, ilan yolundakiyle AYNI kimliktir', () {
      const alici = 'uid_alici';
      const satici = 'uid_satici';

      // Ürün detayı: "ben müşteriyim, ürün sahibi karşı taraf".
      final urunden = MockChatRepository.chatIdFor(alici, satici);
      // İlan detayı: aynı çift, roller TERS (ilanı veren müşteri sayılır).
      final ilandan = MockChatRepository.chatIdFor(satici, alici);

      expect(urunden, ilandan,
          reason: 'Kimlik alfabetik sıralanmalı; giriş noktası kimliği '
              'değiştirmemeli. Aksi halde aynı çift iki kutu açar.');
    });

    test('startChat aynı çift için ikinci kutu YARATMAZ', () async {
      final repo = MockChatRepository();
      final ilk = await repo.startChat(
        customerUid: 'uid_alici',
        customerName: 'Alıcı',
        artisanUid: 'uid_satici',
        artisanName: 'Satıcı',
      );
      // Ters yönden gir (ürün detayı ↔ ilan detayı farkı).
      final ikinci = await repo.startChat(
        customerUid: 'uid_satici',
        customerName: 'Satıcı',
        artisanUid: 'uid_alici',
        artisanName: 'Alıcı',
      );

      expect(ikinci, ilk, reason: 'Tek kutu olmalı.');

      final threads = await repo.watchThreads('uid_alici').first;
      expect(threads.length, 1,
          reason: 'Ters yönden girmek ikinci sohbet doğurmamalı.');
    });

    test('roller İLK açılışta donar, ters giriş yeniden yazmaz', () async {
      final repo = MockChatRepository();
      await repo.startChat(
        customerUid: 'uid_alici',
        customerName: 'Alıcı',
        artisanUid: 'uid_satici',
        artisanName: 'Satıcı',
      );
      await repo.startChat(
        customerUid: 'uid_satici',
        customerName: 'Satıcı',
        artisanUid: 'uid_alici',
        artisanName: 'Alıcı',
      );

      final t = (await repo.watchThreads('uid_alici').first).single;
      expect(t.customerUid, 'uid_alici',
          reason: 'İlk açılıştaki rol korunmalı (putIfAbsent).');
      expect(t.artisanUid, 'uid_satici');
    });

    test('ürün detayı startChat kullanır, kendi kimliğini ÜRETMEZ', () {
      final ekran =
          read('lib/features/products/presentation/product_detail_screen.dart');
      expect(ekran.contains('chatRepo.startChat('), isTrue,
          reason: 'Sohbet açılışı ortak yoldan geçmeli.');
      expect(ekran.contains("'chat_"), isFalse,
          reason: 'Ekran kendi sohbet kimliğini kurmamalı — kimlik mantığı '
              'tek yerde (chatIdFor) durur.');
    });
  });

  group('1.2 — Vitrin doluluğu kapısı kalktı (herkes satabilir)', () {
    // Eski kod yayın öncesi "vitrin dolu mu" kontrolü yapıyordu
    // (PRD-006 §K9): `canMatchJobs` = meslek + hizmet bölgesi seçili mi.
    // O şart USTA kavramıydı; usta olmayan biri meslek seçmediği için ürün
    // yayınlayamıyordu. Kullanıcı kararı "herkes satabilir" olduğu için
    // kapı kaldırıldı.
    //
    // NOT: `shop_completion.dart` SİLİNMEDİ — usta vitrini için hâlâ
    // kullanılıyor, yalnızca `application/` → `data/` klasörüne taşınmış.
    // Ürün tarafının ona bağlanmaması gerekiyor, varlığı sorun değil.

    test('ürün kodu vitrin doluluğuna bakmaz', () {
      final dir = Directory('lib/features/products');
      final hits = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('shopCompletion') ||
              f.readAsStringSync().contains('shop_completion'))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty,
          reason: 'Herkes satabildiği için vitrin şartı aranmaz. '
              'Bulunan: $hits');
    });

    test('ürün oluşturma usta modu ŞARTI aramaz', () {
      final dir = Directory('lib/features/products');
      final hits = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('isArtisan'))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty,
          reason: 'Usta olmak ürün koymanın şartı DEĞİL. Bulunan: $hits');
    });

    test('yayın kapısı yalnız içerik + hesap durumuna bakar', () {
      // Kapının imzası daralmalı: usta vitrini parametreleri kalkmalı.
      expect(canPublishProduct(userSuspended: false, fieldsComplete: true),
          isTrue,
          reason: 'Meslek/bölge seçmemiş biri de ürün yayınlayabilmeli.');
      expect(canPublishProduct(userSuspended: true, fieldsComplete: true),
          isFalse, reason: 'Askıdaki hesap yayın yapamaz.');
      expect(canPublishProduct(userSuspended: false, fieldsComplete: false),
          isFalse, reason: 'Eksik ürün yayınlanamaz.');
    });

    test('Keşfet paneli misafire de ürünleri gösterir', () {
      final panel = read(
          'lib/features/products/presentation/widgets/products_explore_panel.dart');
      expect(panel.contains('canSell'), isTrue,
          reason: 'Satış girişi oturuma bağlı olmalı, usta moduna değil.');
      expect(panel.contains('Ustaların vitrin ürünleri'), isFalse,
          reason: 'Metin artık ustaya özel değil.');
    });
  });

  group('1.5 — Dükkân bölümü İKİ profil ekranında da var', () {
    // "Herkes satabilir" olduğu için vitrin yalnız usta profiline ait
    // değil. Eski kod `_ShopSection`'ı sadece usta profiline koyuyordu;
    // usta olmayan bir satıcının ürünleri hiçbir profilde görünmezdi.

    test('usta profili dükkânı gösterir', () {
      final s = read(
          'lib/features/customer/presentation/artisan_profile_screen.dart');
      expect(s.contains('DukkanBolumu'), isTrue);
    });

    test('genel kullanıcı profili de dükkânı gösterir', () {
      final s =
          read('lib/features/customer/presentation/public_user_screen.dart');
      expect(s.contains('DukkanBolumu'), isTrue,
          reason: 'Usta olmayan satıcının vitrini de görünmeli.');
      expect(s.contains('Usta olmayan profilde gösterilecek vitrin yok'),
          isFalse,
          reason: 'Eski varsayım metni kalmamalı.');
    });

    test('dükkân YALNIZ yayındaki ürünleri gösterir (gizlilik)', () {
      // `myProductsProvider` taslak/satılmış/duraklatılmış dâhil HER şeyi
      // verir; başkasının profilinde onu kullanmak sızıntı olurdu.
      final w = read(
          'lib/features/products/presentation/widgets/dukkan_bolumu.dart');
      expect(w.contains('publicProductsProvider'), isTrue,
          reason: 'Vitrin publicProductsProvider kullanmalı.');
      expect(w.contains('myProductsProvider'), isFalse,
          reason: 'myProductsProvider taslakları sızdırır.');
    });

    test('vitrin ölçütü Keşfet feed’iyle aynı kuralı kullanır', () {
      // İkisi ayrışırsa profilde görünüp Keşfet'te görünmeyen ürün doğar.
      final p = read('lib/features/products/data/product_providers.dart');
      expect(p.contains('isLiveInDiscover'), isTrue);
    });
  });

  group('Aşama 2 — sunucu tarafı geri geldi', () {
    late String cf;
    late String rules;
    setUpAll(() {
      cf = read('functions/index.js');
      rules = read('firestore.rules');
    });

    test('altı ürün fonksiyonu tanımlı', () {
      for (final f in [
        'onProductWritten',
        'publishProduct',
        'updateProductContent',
        'adminModerateProduct',
        'onProductReportWritten',
        'purgeRemovedProducts',
      ]) {
        expect(cf.contains('exports.$f'), isTrue, reason: '$f eksik.');
      }
    });

    test('cascade ÇAĞRILIYOR — tanımı olup çağrısı olmayan hâl tekrarlanmasın',
        () {
      // b6940ec'de cascadeProductsHideBits tanımı silinmiş ama üç çağrı
      // yerinde kalmıştı; deploy edilseydi askıya alma ÇALIŞMA ZAMANINDA
      // patlayacaktı. Şimdi tersi tehlike: tanım var, çağrı unutulmuş.
      expect(cf.contains('async function cascadeProductsHideBits'), isTrue);
      final calls = RegExp(r'await cascadeProductsHideBits\(')
          .allMatches(cf)
          .length;
      expect(calls, greaterThanOrEqualTo(2),
          reason: 'Askıya alma ve profil gizleme cascade çağırmalı; '
              'bulunan: $calls');
    });

    test('yayın kapısı sunucuda — istemci status ile active yapamaz', () {
      expect(rules.contains('ownerNeverPublishesViaStatus'), isTrue,
          reason: 'İstemci status yazarak yayına geçebilseydi '
              'publishProduct kapısı (rate limit, iletişim deseni, '
              'aktif ürün tavanı) tamamen atlanırdı.');
    });

    test('ürün kuralı USTA şartı aramaz', () {
      // Kural bloğunu izole et — başka blokların isArtisan'ı sayılmasın.
      final basla = rules.indexOf('match /products/{productId}');
      expect(basla, greaterThan(0));
      final blok = rules.substring(basla, rules.indexOf('match /reports/'));
      expect(blok.contains('isArtisan'), isFalse,
          reason: 'Herkes satabilir; kural usta şartı koymamalı.');
      expect(blok.contains('isEmailVerified()'), isTrue,
          reason: 'E-posta doğrulaması şartı DURMALI (spam kapısı).');
    });

    test('products yetkileri tanımlı, purge varsayılan moderatörde DEĞİL', () {
      expect(cf.contains('"products.read"'), isTrue);
      expect(cf.contains('"products.moderate"'), isTrue);
      expect(cf.contains('"products.purge"'), isTrue);

      final varsayilanBasla = cf.indexOf('DEFAULT_MODERATOR_CAPABILITIES');
      final varsayilan =
          cf.substring(varsayilanBasla, cf.indexOf('ALL_CAPABILITIES'));
      expect(varsayilan.contains('"products.purge"'), isFalse,
          reason: 'hard_purge geri dönüşsüz — varsayılan moderatörde olmamalı.');
    });

    test('hesap silme ürünleri ve storage klasörünü kapsıyor', () {
      expect(cf.contains('collection("products").where("ownerUid"'), isTrue,
          reason: 'Silinen hesabın ürünleri kalmamalı (KVKK).');
      expect(cf.contains('"product"'), isTrue,
          reason: 'STORAGE_FOLDERS product klasörünü içermeli.');
    });
  });

  group('Aşama 3 — ürün talebi + günlük özet bildirim', () {
    late String cf;
    setUpAll(() => cf = read('functions/index.js'));

    test('ürün talebi USTA feed’ine düşmez', () {
      // Alıcı kitlesi satıcılar. Bu eşleşme sessizce de tutmazdı
      // ('product_request' bir meslek kodu değil) ama açık kapı şart:
      // biri kategoriyi meslek listesine eklerse talep usta feed'ine sızar.
      final job = Job(
        jobId: 'j1',
        customerId: 'c1',
        customerName: 'Müşteri',
        title: 'Çimento lazım',
        description: 'On torba çimento arıyorum.',
        category: kProductRequestCategory,
        province: 'Bursa',
        district: 'Nilüfer',
        photos: const [],
        priceType: JobPriceType.fixed,
        status: JobStatus.open,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      expect(
        job.matchesArtisan(
          professionCodes: const ['product_request', 'plumber'],
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
        ),
        isFalse,
        reason: 'Meslek kodu uydurulsa bile ustaya düşmemeli.',
      );
      expect(job.isProductRequest, isTrue);
    });

    test('normal ilan hâlâ eşleşiyor (talep kapısı fazla kesmedi)', () {
      final job = Job(
        jobId: 'j2',
        customerId: 'c1',
        customerName: 'Müşteri',
        title: 'Musluk tamiri',
        description: 'Mutfak musluğu damlatıyor.',
        category: 'plumber',
        province: 'Bursa',
        district: 'Nilüfer',
        photos: const [],
        priceType: JobPriceType.fixed,
        status: JobStatus.open,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      );
      expect(
        job.matchesArtisan(
          professionCodes: const ['plumber'],
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Osmangazi'),
          ],
        ),
        isTrue,
        reason: 'İl eşleşmesi yeter — ilçe elemez (2026-08-10 kararı).',
      );
    });

    test('anlık fan-out talebi ATLAR', () {
      expect(cf.contains('PRODUCT_REQUEST_CATEGORY'), isTrue);
      final fanout = cf.substring(
        cf.indexOf('exports.onJobCreated'),
        cf.indexOf('exports.onJobWritten'),
      );
      expect(fanout.contains('=== PRODUCT_REQUEST_CATEGORY'), isTrue,
          reason: 'onJobCreated ürün talebinde erken dönmeli — yoksa '
              'talepler ustalara ANLIK push olarak giderdi.');
    });

    test('özet CF günde bir kez çalışır', () {
      expect(cf.contains('exports.sendProductRequestDigest'), isTrue);
      final ozet = cf.substring(cf.indexOf('exports.sendProductRequestDigest'));
      expect(ozet.contains('"0 19 * * *"'), isTrue,
          reason: 'Günlük tek çalışma — spam tavanı buna dayanıyor.');
      expect(ozet.contains('istanbulDayKey()'), isTrue,
          reason: 'Bildirim kimliği güne çakılı olmalı; aynı gün ikinci '
              'çalışma üzerine yazsın, bildirim çoğalmasın.');
    });

    test('özet kendi talebini açana geri gitmez', () {
      final ozet = cf.substring(cf.indexOf('exports.sendProductRequestDigest'));
      expect(ozet.contains('alicilar.delete(j.customerId)'), isTrue);
    });

    test('özet AYRI tercihe bağlı — üç katman da tanımalı', () {
      // Biri eksik kalırsa anahtar sessizce çalışmaz: parser'da yoksa
      // undefined döner ve bildirim hiç gitmez.
      expect(cf.contains('productDigest: p.productDigest !== false'), isTrue,
          reason: 'prefsFromPushSnap alanı okumalı.');
      expect(
          cf.contains('category === "productDigest"'), isTrue,
          reason: 'isPushCategoryAllowed kategoriyi tanımalı.');
      expect(cf.contains('data.kind === "productDigest"'), isTrue,
          reason: 'pushCategoryFromData eşlemeli.');

      final prefs =
          read('lib/features/notifications/data/notification_prefs.dart');
      expect(prefs.contains('productDigest'), isTrue,
          reason: 'İstemci modeli paritesi (kural 1).');
      final ekran = read(
          'lib/features/notifications/presentation/notification_prefs_screen.dart');
      expect(ekran.contains('productDigest'), isTrue,
          reason: 'Kullanıcı kapatabilmeli.');
    });
  });

  group('Aşama 4 — modül kullanıcıya AÇILDI', () {
    late String router;
    late String kesfet;
    setUpAll(() {
      router = read('lib/core/router/app_router.dart');
      kesfet = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
    });

    test('Keşfet üç sekme: Ustalar | İlanlar | Mağaza', () {
      expect(kesfet.contains('TabController(length: 3'), isTrue,
          reason: 'Sekme sayısı 3 olmalı; 2 kalırsa Mağaza sekmesi '
              'oluşturulur ama TabBarView ile eşleşmez ve çöker.');
      expect(kesfet.contains("Tab(text: 'Mağaza'"), isTrue);
      expect(kesfet.contains('MagazaSekmesi()'), isTrue);
    });

    test('Mağaza sekmesinde erişim kapısı YOK', () {
      final s = read(
          'lib/features/products/presentation/widgets/magaza_sekmesi.dart');
      expect(s.contains('isArtisan'), isFalse,
          reason: 'Usta modu şartı olmamalı.');
      expect(s.contains('RoutePaths.login'), isFalse,
          reason: 'Misafir de Mağaza sekmesini görebilmeli — İlanlar '
              'sekmesindeki giriş kapısı buraya TAŞINMAMALI.');
    });

    test('ürün rotaları /products/:id ÖNCESİNDE tanımlı', () {
      // Sıra bozulursa "new" ve "mine" birer ürün kimliği sanılır ve
      // kullanıcı ürün ekleme ekranı yerine "bulunamadı" görür.
      final yeni = router.indexOf('RoutePaths.productNew');
      final benim = router.indexOf('RoutePaths.myProducts');
      final detay = router.indexOf("path: '/products/:productId'");
      expect(yeni, greaterThan(0));
      expect(benim, greaterThan(0));
      expect(detay, greaterThan(0));
      expect(yeni, lessThan(detay), reason: '/products/new önce gelmeli.');
      expect(benim, lessThan(detay), reason: '/products/mine önce gelmeli.');
    });

    test('ürün YAZMA yolları oturum ister, okuma istemez', () {
      expect(router.contains('loc == RoutePaths.productNew'), isTrue);
      expect(router.contains('loc == RoutePaths.myProducts'), isTrue);
      expect(router.contains("loc.endsWith('/edit')"), isTrue);
      // Detay yolu needsLogin listesinde OLMAMALI (misafire açık).
      expect(router.contains("loc.startsWith('/products/') &&\n"), isFalse);
    });

    test('talep formu ?kind=product ile açılır ve süresi SABİT 7 gün', () {
      expect(router.contains("'product' => kProductRequestCategory"), isTrue);
      final form = read('lib/features/jobs/presentation/create_job_screen.dart');
      expect(
          form.contains('kProductRequestCategory => JobDuration.day7'), isTrue,
          reason: 'Süre sunucuda değil formda zorlanıyor; kullanıcı '
              'kategoriyi sonradan değiştirse bile 7 gün olmalı.');
      expect(form.contains('kProductRequestCategory: '), isTrue,
          reason: 'Kategori seçicide görünmeli.');
    });

    test('talep listesi ayrı sorgu açmaz', () {
      final p = read('lib/features/jobs/data/job_providers.dart');
      expect(p.contains('productRequestsProvider'), isTrue);
      final blok = p.substring(p.indexOf('productRequestsProvider'));
      expect(blok.contains('openJobsProvider'), isTrue,
          reason: 'quickSupportJobsProvider ile aynı desen — açık ilanlar '
              'üzerinden süzülmeli, yeni indeks gerektirmemeli.');
    });
  });

  group('Aşama 0 — geri getirme bağları yerinde', () {
    test('mock veritabanında ürün koleksiyonu var (mock paritesi)', () {
      expect(MockDatabase().products, isEmpty,
          reason: 'MockDatabase.products alanı bulunmalı (kural 1).');
    });

    test('ürün rotaları tanımlı', () {
      final p = read('lib/core/router/route_paths.dart');
      for (final r in ['productsBase', 'productNew', 'myProducts',
        'productDetail', 'productEdit']) {
        expect(p.contains(r), isTrue, reason: '$r rotası eksik.');
      }
    });

    test('rota sırası uyarısı korunuyor', () {
      // /products/new ve /products/mine, /products/:id ÖNCESİNDE
      // tanımlanmazsa "new" bir ürün kimliği sanılır.
      final p = read('lib/core/router/route_paths.dart');
      expect(p.contains('ÖNCESİNDE'), isTrue,
          reason: 'Router sırası tuzağı belgeli kalmalı.');
    });
  });
}

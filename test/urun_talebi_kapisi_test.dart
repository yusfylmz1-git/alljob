import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/features/products/presentation/widgets/magaza_sekmesi.dart'
    show kSinirliTalepSayisi;

/// Ürün talepleri kapısı (2026-08-14 ürün kararı).
///
/// KARAR: Mağazası olmayan veya "müsait değil" durumundaki kullanıcı
/// Keşfet'teki ürün taleplerini SINIRLI görür. Tamamı için mağaza açıp
/// müsaitliği açması gerekir.
///
/// GEREKÇE: talebe cevap vermek mağaza ister; mağazasız kullanıcı zaten
/// mesaj atamıyor (`availability_gate.dart`). Listenin tamamını göstermek
/// boş bir vaat olur ve talep sahibinin ihtiyacını rakip taramasına açar.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String sekme;
  setUpAll(() => sekme = read(
      'lib/features/products/presentation/widgets/magaza_sekmesi.dart'));

  group('Sınırlama uygulanıyor', () {
    test('sınır sıfırdan büyük (kullanıcı ne kaçırdığını görmeli)', () {
      // 0 göstermek "burada bir şey yok" izlenimi verirdi; kullanıcı mağaza
      // açmanın neden değerli olduğunu anlayamazdı.
      expect(kSinirliTalepSayisi, greaterThan(0));
      expect(kSinirliTalepSayisi, lessThan(10));
    });

    test('kapı İKİ koşula birden bakıyor: mağaza VE müsaitlik', () {
      expect(sekme.contains('hasShopProfile'), isTrue);
      expect(sekme.contains('available'), isTrue);
      expect(sekme.contains('!(magazaVar && musait)'), isTrue,
          reason: 'Tek koşula bakılıyor — mağazası olup müsait olmayan '
              'kullanıcı tüm talepleri görür ama mesaj atamaz.');
    });

    test('kilitliyken liste kırpılıyor', () {
      expect(sekme.contains('talepler.take(kSinirliTalepSayisi)'), isTrue,
          reason: 'Liste kırpılmıyor — sınırlama etkisiz.');
    });
  });

  group('Kapı kartı kullanıcıyı çıkmaza sokmuyor', () {
    test('eksik olana göre farklı yönlendirme', () {
      // Mağaza yok → mağaza açma; mağaza var ama kapalı → müsaitlik.
      // Tek mesaj gösterilirse kullanıcı ne yapacağını bilemez.
      expect(sekme.contains('RoutePaths.shopSetup'), isTrue);
      expect(sekme.contains('RoutePaths.profile'), isTrue);
      expect(sekme.contains('Mağaza aç'), isTrue);
      expect(sekme.contains('Müsaitliği aç'), isTrue);
    });

    test('gizli sayı 0 iken sayı yazılmıyor (yanlış vaat yok)', () {
      expect(sekme.contains('gizliSayi > 0'), isTrue);
    });
  });

  group('Asıl koruma yerinde duruyor', () {
    // Görsel sınırlama tek başına yeterli değil: talep detayına doğrudan
    // rota ile ulaşılabilir. Mesaj atmayı engelleyen kapı korunmalı.
    test('detay ekranlarında müsaitlik kapısı var', () {
      for (final yol in [
        'lib/features/jobs/presentation/job_detail_screen.dart',
        'lib/features/products/presentation/product_detail_screen.dart',
      ]) {
        expect(read(yol).contains('artisanAvailabilityAllowsNewChat('), isTrue,
            reason: '$yol içinde mesaj kapısı yok — sınırlama atlatılabilir.');
      }
    });
  });

  group('Müsait olmayan satıcının ürünleri gizleniyor', () {
    // KARAR (2026-08-14): müsait olmayan satıcı ürün taleplerine mesaj
    // atamıyor ve mağaza vitrini profilinde gizleniyor. Ürünleri Keşfet'te
    // durmaya devam ederse müşteri, yazamayacağı bir satıcıya düşer.
    test('Keşfet için süzülmüş provider var', () {
      final p = read('lib/features/products/data/product_providers.dart');
      expect(p.contains('availableDiscoverProductsProvider'), isTrue);
      expect(p.contains('satici.available'), isTrue,
          reason: 'Müsaitlik kontrolü yok — filtre etkisiz.');
    });

    test('Keşfet paneli süzülmüş listeyi kullanıyor', () {
      final e = read(
          'lib/features/products/presentation/widgets/products_explore_panel.dart');
      expect(e.contains('availableDiscoverProductsProvider'), isTrue,
          reason: 'Panel ham listeyi kullanıyor — müsait olmayan satıcının '
              'ürünleri Keşfet\'te görünmeye devam eder.');
    });

    test('sahibi KENDİ ürününü görmeye devam ediyor', () {
      // Kendi ürünü kaybolursa satıcı "ürünüm silindi" sanır.
      final p = read('lib/features/products/data/product_providers.dart');
      expect(p.contains('p.ownerUid == me'), isTrue);
    });

    test('satıcı yüklenmeden ürün gizlenmiyor (titreme yok)', () {
      // Yükleme sırasında listeyi boşaltıp doldurmak göz yorucu olurdu.
      final p = read('lib/features/products/data/product_providers.dart');
      expect(p.contains('satici == null || satici.available'), isTrue);
    });

    // BELİRTİ: "müsaitliği açtım ama ürünlerim başka telefonda görünmedi".
    //
    // SEBEP: `publicUserProvider` tek seferlik `.get()` yapan bir
    // FutureProvider'dı ve sonucu önbelleğe alıyordu. Satıcı müsaitliğini
    // değiştirdiğinde DİĞER cihazlar eski değeri okumaya devam ediyor,
    // Keşfet filtresi değişimi hiç öğrenmiyordu.
    test('satıcı müsaitliği CANLI okunuyor (önbellek değil)', () {
      final c = read('lib/features/auth/application/auth_controller.dart');
      expect(c.contains('StreamProvider.autoDispose.family<AppUser?, String>'),
          isTrue,
          reason: 'publicUserProvider hâlâ FutureProvider — müsaitlik '
              'değişimi diğer cihazlara yansımaz.');
      expect(c.contains('watchPublicUser'), isTrue);
    });

    test('watchPublicUser her iki repoda da var (kural 1)', () {
      expect(
        read('lib/features/auth/data/firebase_auth_repository.dart')
            .contains('Stream<AppUser?> watchPublicUser'),
        isTrue,
      );
      expect(
        read('lib/features/auth/data/mock_auth_repository.dart')
            .contains('Stream<AppUser?> watchPublicUser'),
        isTrue,
        reason: 'Mock paritesi yok — mock testleri gerçek davranışı '
            'taklit etmez.',
      );
    });

    test('canlı akış çıkışta sahte çökme üretmiyor', () {
      final f = read('lib/features/auth/data/firebase_auth_repository.dart');
      final i = f.indexOf('Stream<AppUser?> watchPublicUser');
      final govde = f.substring(i, i + 600);
      expect(govde.contains('signOutSafe'), isTrue,
          reason: 'uid kapsamlı yeni dinleyici korumasız — çıkışta '
              'permission-denied ile hata ekranı açılır.');
    });

    // ÖLÇEK: her müsaitlik değişimi Firestore yazması + o satıcıyı izleyen
    // her istemciye okuma üretir. Çok sayıda satıcı sık aç/kapa yaparsa
    // koruma olmadan gereksiz fatura ve ağ yükü oluşur.
    test('anahtar işlem sürerken kilitleniyor (yazma fırtınası yok)', () {
      final p = read('lib/features/profile/presentation/profile_screen.dart');
      final i = p.indexOf('class _AvailabilitySwitchState');
      final govde = p.substring(i);
      expect(govde.contains('_busy'), isTrue,
          reason: 'Çift dokunuş koruması yok — hızlı aç-kapa yazmayı katlar.');
      expect(govde.contains('onChanged: _busy ? null :'), isTrue,
          reason: 'Anahtar meşgulken devre dışı bırakılmıyor.');
    });

    test('müsaitlik users dokümanına TEK yazımda gidiyor', () {
      // Eskiden save() + ayrı updateUserProfile(available:) idi — aynı
      // dokümana ardışık iki yazma.
      final c =
          read('lib/features/artisan/application/my_profile_controller.dart');
      final i = c.indexOf('Future<bool> setAvailable');
      final govde = c.substring(i, i + 700);
      expect(govde.contains('save(available: active)'), isTrue,
          reason: 'Müsaitlik ayrı bir yazımla gönderiliyor — mükerrer yazma.');
      // Ayrı çağrı kalmamalı.
      expect(govde.contains('updateUserProfile(available:'), isFalse);
    });

    test('canlı dinleyici autoDispose (sızıntı yok)', () {
      // Ekran kapanınca dinleyici kapanmazsa açık dinleyici sayısı büyür.
      final a = read('lib/features/auth/application/auth_controller.dart');
      expect(a.contains('StreamProvider.autoDispose.family'), isTrue,
          reason: 'publicUserProvider autoDispose değil — dinleyici sızar.');
    });

    test('mağaza vitrini de müsaitliğe bakıyor', () {
      final d = read(
          'lib/features/products/presentation/widgets/dukkan_bolumu.dart');
      expect(d.contains('!satici.available'), isTrue);
      // Sahibi kendi vitrinini görmeli.
      expect(d.contains('isOwner'), isTrue);
    });
  });

  group('Profil metni düzeltmesi', () {
    test('"Yeni ürün paylaşın" (fotoğraf değil)', () {
      // Düğme ürün EKLEME formunu açıyor; eski metin yalnız fotoğraf
      // paylaşılacağı izlenimi veriyordu.
      final p = read('lib/features/profile/presentation/profile_screen.dart');
      expect(p.contains('Yeni ürün paylaşın'), isTrue);
      expect(p.contains('Ürün fotoğrafı paylaşın'), isFalse);
    });
  });
}

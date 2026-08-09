import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
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

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/data/models/product.dart';
import 'package:sepette_hizmet/data/models/product_category.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';

/// Mağaza ekran görüntüsü demo seti (`vault/06-Test/Demo-Veri-Seti.md`).
///
/// Çift test mantığı: demo verinin ÜRETİLDİĞİNİ doğrulayan testler kadar,
/// varsayılan kurucunun ona HİÇ DOKUNMADIĞINI doğrulayan testler de var.
/// İkincisi olmazsa demo seti sessizce normal mock davranışını kirletir ve
/// tohum sayısına bağlı testler (artisan_search, magaza_mimari_uyum) kırılır.
void main() {
  group('Varsayılan MockDatabase — demo verisi İÇERMEZ', () {
    test('ürün, favori ve demo kullanıcı haritaları boş kalır', () {
      final db = MockDatabase();

      expect(db.products, isEmpty,
          reason: 'magaza_mimari_uyum_test ürünlerin boş olmasını bekliyor.');
      expect(db.favorites, isEmpty);
      expect(db.demoUsers, isEmpty);
    });

    test('demo_ önekli usta tohumlanmaz', () {
      final db = MockDatabase();

      expect(db.artisans.keys.any((k) => k.startsWith('demo_')), isFalse,
          reason: 'Demo personalar arama sonuçlarını kaydırırdı.');
    });

    test('demo ilanları tohumlanmaz', () {
      final db = MockDatabase();

      expect(db.jobs.keys.any((k) => k.startsWith('job_demo_')), isFalse);
      expect(db.jobs.containsKey('job_seed_1'), isTrue,
          reason: 'Mevcut örnek ilanlar korunmalı.');
    });
  });

  group('withDemoPersonas: true — ekran görüntüsü seti', () {
    test('9 usta personası + yalnız müşteri olan Zeynep üretilir', () {
      final db = MockDatabase(withDemoPersonas: true);

      final demoArtisans =
          db.artisans.keys.where((k) => k.startsWith('demo_')).toList();
      expect(demoArtisans, hasLength(9));

      // Zeynep usta DEĞİL → artisans'a girmez ama kullanıcı olarak bilinir.
      expect(db.artisans.containsKey('demo_zeynep'), isFalse);
      expect(db.demoUsers['demo_zeynep'], isNotNull);
      expect(db.demoUsers['demo_zeynep']!.hasArtisanProfile, isFalse);
      expect(db.demoUsers, hasLength(10));
    });

    test('her personanın adı, fotoğraf handle\'ı ve hakkında metni dolu', () {
      final db = MockDatabase(withDemoPersonas: true);

      for (final rec in db.artisans.values) {
        if (!rec.uid.startsWith('demo_')) continue;

        expect(rec.displayName, isNotEmpty);
        expect(rec.displayName, isNot('Kullanıcı'));
        expect(rec.profilePhotoUrl, startsWith('local://demo/avatar/'),
            reason: 'AppImage yalnız local:// ve http handle tanır.');
        expect(rec.profile.aboutText.length, greaterThan(40),
            reason: 'Şablon metin değil, elle yazılmış tanıtım bekleniyor.');
        // Arama `professionCodes` getter'ına bakar: çoklu liste boşsa tek
        // `profession` alanına düşer. Boş kalırsa usta listede HİÇ görünmez.
        expect(rec.profile.professionCodes, isNotEmpty,
            reason: 'Meslek kodu yoksa usta arama listesinde HİÇ görünmez.');
      }
    });

    test('8 ürün üretilir ve hepsi Keşfet\'te görünür', () {
      final db = MockDatabase(withDemoPersonas: true);

      expect(db.products, hasLength(8));
      expect(db.products.values.every((p) => p.isLiveInDiscover), isTrue,
          reason: 'status active + moderationHidden false olmayan ürün '
              'vitrinde görünmez, ekran görüntüsüne yaramaz.');
      expect(db.products.values.every((p) => p.photos.isNotEmpty), isTrue);
      expect(db.products.values.where((p) => p.featured), hasLength(2),
          reason: 'Vitrinin başında duracak ürünler.');
    });

    test('ürün sahipleri gerçek personalar ve adları çözülmüş', () {
      final db = MockDatabase(withDemoPersonas: true);

      for (final p in db.products.values) {
        expect(db.demoUsers.containsKey(p.ownerUid), isTrue,
            reason: '${p.ownerUid} tanımsız bir satıcı.');
        expect(p.ownerName, isNotEmpty);
      }
    });

    test('mağaza sahibi personalarda hasShopProfile ve kategoriler dolu', () {
      final db = MockDatabase(withDemoPersonas: true);

      final sellers =
          db.products.values.map((p) => p.ownerUid).toSet();
      for (final uid in sellers) {
        final user = db.demoUsers[uid]!;
        expect(user.hasShopProfile, isTrue,
            reason: '$uid ürün satıyor ama mağaza profili kapalı.');
        expect(user.shopCategories, isNotEmpty);
      }
    });

    test('4 demo ilan üretilir, hepsi açık ve süresi dolmamış', () {
      final db = MockDatabase(withDemoPersonas: true);

      final demoJobs = db.jobs.values
          .where((j) => j.jobId.startsWith('job_demo_'))
          .toList();
      expect(demoJobs, hasLength(4));

      final now = DateTime.now();
      for (final j in demoJobs) {
        expect(j.status.name, 'open');
        expect(j.expiresAt.isAfter(now), isTrue,
            reason: '${j.jobId} "Süresi doldu" görünürdü.');
        expect(db.demoUsers.containsKey(j.customerId), isTrue,
            reason: 'İlan sahibi tanımsız bir kullanıcı.');
      }
    });

    test('3 favori üretilir ve takip edilenler gerçek usta', () {
      final db = MockDatabase(withDemoPersonas: true);

      expect(db.favorites, hasLength(3));
      for (final f in db.favorites.values) {
        expect(f.customerUid, 'demo_zeynep');
        expect(db.artisans.containsKey(f.artisanUid), isTrue);
        expect(f.artisanName, isNotEmpty);
        expect(f.professionNameTR, isNotEmpty,
            reason: 'Takip listesinde meslek satırı boş çizilirdi.');
      }
    });

    test('mevcut tohum demo setiyle birlikte de korunur', () {
      final plain = MockDatabase();
      final demo = MockDatabase(withDemoPersonas: true);

      // Demo seti mevcut ustaların ÜZERİNE yazmaz, yanına ekler.
      final plainArtisans =
          plain.artisans.keys.where((k) => !k.startsWith('demo_')).length;
      final demoArtisans =
          demo.artisans.keys.where((k) => !k.startsWith('demo_')).length;
      expect(demoArtisans, plainArtisans);

      expect(demo.jobs.containsKey('job_seed_1'), isTrue);
    });

    test('publicUser demo personayı çözer, tanımsız uid için null döner', () {
      final db = MockDatabase(withDemoPersonas: true);

      expect(db.publicUser('demo_kerem')!.displayName, 'Kerem Alptekin');
      expect(db.publicUser('demo_zeynep')!.displayName, 'Zeynep Uçar');
      expect(db.publicUser('boyle_bir_uid_yok'), isNull);
    });

    test('publicUser tohumlanmış normal ustayı da çözer', () {
      final db = MockDatabase(withDemoPersonas: true);

      final someArtisan =
          db.artisans.keys.firstWhere((k) => !k.startsWith('demo_'));
      final resolved = db.publicUser(someArtisan);

      expect(resolved, isNotNull);
      expect(resolved!.hasArtisanProfile, isTrue);
    });
  });

  group('MockAuthRepository.fetchPublicUser — kullanıcı rehberi paritesi', () {
    test('rehber verilince başka uid\'ler ÇÖZÜLÜR', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final auth = MockAuthRepository(publicUserResolver: db.publicUser);
      addTearDown(auth.dispose);

      final kerem = await auth.fetchPublicUser('demo_kerem');
      expect(kerem, isNotNull);
      expect(kerem!.displayName, 'Kerem Alptekin');
      expect(kerem.displayName, isNot('Kullanıcı'),
          reason: 'Sohbet başlığında ve ürün kartında ad görünmeliydi.');
      expect(kerem.hasArtisanProfile, isTrue);

      final zeynep = await auth.fetchPublicUser('demo_zeynep');
      expect(zeynep!.displayName, 'Zeynep Uçar');
      expect(zeynep.hasArtisanProfile, isFalse);
    });

    test('rehberin tanımadığı uid iskelete düşer (ekran boş kalmaz)', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final auth = MockAuthRepository(publicUserResolver: db.publicUser);
      addTearDown(auth.dispose);

      final u = await auth.fetchPublicUser('bilinmeyen_uid');
      expect(u, isNotNull);
      expect(u!.displayName, 'Kullanıcı');
    });

    test('rehber YOKSA eski davranış birebir korunur (geri uyum)', () async {
      final auth = MockAuthRepository();
      addTearDown(auth.dispose);

      final u = await auth.fetchPublicUser('demo_kerem');
      expect(u!.displayName, 'Kullanıcı',
          reason: 'Rehbersiz kurucu mevcut testlerin gördüğü davranıştır.');
    });

    test('boş uid null döner', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final auth = MockAuthRepository(publicUserResolver: db.publicUser);
      addTearDown(auth.dispose);

      expect(await auth.fetchPublicUser('  '), isNull);
    });
  });

  group('Demo sohbetleri', () {
    test('seed çağrılmadan sohbet YOKTUR', () {
      final repo = MockChatRepository();
      addTearDown(repo.dispose);

      expect(repo.getThread('herhangi'), isNull);
    });

    test('4 sohbet üretilir ve her iki taraf da görür', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final zeynep = await repo.watchThreads('demo_zeynep').first;
      expect(zeynep, hasLength(3),
          reason: 'Zeynep: Elif, Kerem ve Ayşe Nur ile yazışıyor.');

      final tolga = await repo.watchThreads('demo_tolga').first;
      expect(tolga, hasLength(1));
    });

    test('sohbet kimliği alfabetiktir — rol sırası değiştirmez', () {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      expect(
        MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif'),
        MockChatRepository.chatIdFor('demo_elif', 'demo_zeynep'),
      );
      expect(
        repo.hasChatBetween(
            customerUid: 'demo_zeynep', artisanUid: 'demo_elif'),
        isTrue,
      );
    });

    test('mesajlar zamana yayılmış ve sıralı', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final id = MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif');
      final msgs = await repo.watchMessages(id).first;

      expect(msgs.length, greaterThan(5));
      for (var i = 1; i < msgs.length; i++) {
        expect(msgs[i].createdAt.isAfter(msgs[i - 1].createdAt), isTrue,
            reason: 'Mesajlar eskiden yeniye sıralı olmalı, aksi hâlde '
                'ekran görüntüsünde saatler karışık görünür.');
      }
    });

    test('sistem mesajı şeridi üretilir', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final id = MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif');
      final msgs = await repo.watchMessages(id).first;

      final sys = msgs.where((m) => m.isSystem).toList();
      expect(sys, hasLength(1));
      expect(sys.first.senderUid, 'system');
      expect(sys.first.text, isNotEmpty);
    });

    test('fotoğraflı mesajlar local:// handle taşır', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final id = MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif');
      final msgs = await repo.watchMessages(id).first;

      final withImage = msgs.where((m) => m.imageHandle != null).toList();
      expect(withImage, isNotEmpty);
      expect(withImage.every((m) => m.imageHandle!.startsWith('local://')),
          isTrue);
    });

    test('Kerem sohbeti Zeynep tarafında OKUNMAMIŞ (liste rozeti için)', () {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final keremId = MockChatRepository.chatIdFor('demo_zeynep', 'demo_kerem');
      expect(repo.unreadCount(chatId: keremId, uid: 'demo_zeynep'),
          greaterThan(0));

      final elifId = MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif');
      expect(repo.unreadCount(chatId: elifId, uid: 'demo_zeynep'), 0,
          reason: 'Elif sohbeti okunmuş bırakıldı.');
    });

    test('sohbet başlıklarında ad ve avatar dolu', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final threads = await repo.watchThreads('demo_zeynep').first;
      for (final t in threads) {
        expect(t.customerName, isNotEmpty);
        expect(t.artisanName, isNotEmpty);
        expect(t.artisanPhotoUrl, startsWith('local://demo/avatar/'));
        expect(t.lastMessage, isNotNull);
      }
    });

    test('sabitlenmiş sohbet üretilir', () async {
      final repo = MockChatRepository()..seedDemoThreads();
      addTearDown(repo.dispose);

      final id = MockChatRepository.chatIdFor('demo_zeynep', 'demo_elif');
      expect(repo.getThread(id)!.pinnedBy, contains('demo_zeynep'));
    });
  });

  group('Ürün alanları — ekranda ham kod görünmemeli', () {
    test('kategori kodları ProductCategory içinde tanımlı', () {
      final db = MockDatabase(withDemoPersonas: true);

      for (final p in db.products.values) {
        expect(ProductCategory.sirali, contains(p.categoryCode),
            reason: '${p.categoryCode} bilinmeyen kategori → kart etiketi boş '
                'ya da ham kod görünür.');
      }
    });

    test('pazarlıklı olmayan ürünlerde fiyat dolu', () {
      final db = MockDatabase(withDemoPersonas: true);

      for (final p in db.products.values) {
        if (p.priceType == ProductPriceType.negotiable) continue;
        expect(p.priceAmount, isNotNull, reason: '${p.id} fiyatsız görünürdü.');
        expect(p.priceAmount, greaterThan(0));
      }
    });
  });
}

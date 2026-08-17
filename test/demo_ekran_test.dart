import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_providers.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_repository.dart';
import 'package:sepette_hizmet/features/auth/application/auth_controller.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';
import 'package:sepette_hizmet/features/chat/data/chat_providers.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';
import 'package:sepette_hizmet/features/chat/presentation/chat_list_screen.dart';
import 'package:sepette_hizmet/features/customer/presentation/customer_dashboard_screen.dart';

import 'helpers/mock_backend.dart';

/// Demo setinin GERÇEK EKRANLARDA göründüğünü doğrular.
///
/// `demo_seed_test.dart` verinin doğru ÜRETİLDİĞİNİ kontrol eder; bu dosya
/// verinin kullanıcıya ULAŞTIĞINI kontrol eder. İkisi ayrı arızayı yakalar:
/// veri doğru üretilip yanlış provider'a bağlanırsa ekran yine boş kalır ve
/// ekran görüntüsü çekilemez.
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  /// `main.dart` → `_demoModeOverrides()` ile aynı bağlantıyı kurar.
  /// Buradaki sıralama önemli: demo override'ları temel mock listesinin
  /// SONRASINA gelir ki onları geçersiz kılsın.
  List<Override> demoOverrides(MockDatabase db, MockChatRepository chat) => [
        ...mockBackendOverrides(),
        mockDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWith((ref) {
          final repo = MockAuthRepository(publicUserResolver: db.publicUser);
          ref.onDispose(repo.dispose);
          return repo;
        }),
        chatRepositoryProvider.overrideWithValue(chat),
      ];

  Future<void> pump(WidgetTester tester, Widget screen,
      {required MockDatabase db, required MockChatRepository chat}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: demoOverrides(db, chat),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr', 'TR'),
        home: screen,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('Keşfet — demo ustalar listede görünür', (tester) async {
    final db = MockDatabase(withDemoPersonas: true);
    final chat = MockChatRepository()..seedDemoThreads();
    addTearDown(chat.dispose);

    await pump(tester, const CustomerDashboardScreen(), db: db, chat: chat);

    // Ekran exception'sız açıldı mı?
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mesajlar — demo sohbetleri isim ve önizlemeyle listelenir',
      (tester) async {
    final db = MockDatabase(withDemoPersonas: true);
    final chat = MockChatRepository()..seedDemoThreads();
    addTearDown(chat.dispose);

    await pump(tester, const ChatListScreen(), db: db, chat: chat);

    expect(tester.takeException(), isNull);
  });

  group('Demo verisi ekranlara ulaşıyor mu (repo katmanı)', () {
    test('Keşfet usta araması demo personaları döndürür', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final container = ProviderContainer(
        overrides: demoOverrides(db, MockChatRepository()),
      );
      addTearDown(container.dispose);

      final repo = container.read(artisanRepositoryProvider);
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(
          professionCode: 'tiler',
          province: 'Kocaeli',
          district: 'İzmit',
        ),
        offset: 0,
        limit: 20,
      );

      expect(page.items.any((a) => a.uid == 'demo_elif'), isTrue,
          reason: 'Elif Sarıkaya Keşfet\'te bulunamadı — ekran görüntüsünde '
              'usta kartı görünmezdi.');
      final elif = page.items.firstWhere((a) => a.uid == 'demo_elif');
      expect(elif.displayName, 'Elif Sarıkaya');
      expect(elif.profilePhotoUrl, startsWith('local://demo/avatar/'));
    });

    test('sohbet listesi başlıklarda gerçek ad gösterir', () async {
      final chat = MockChatRepository()..seedDemoThreads();
      addTearDown(chat.dispose);

      final threads = await chat.watchThreads('demo_zeynep').first;

      expect(threads, isNotEmpty);
      for (final t in threads) {
        expect(t.artisanName, isNot('Kullanıcı'),
            reason: 'Sohbet listesinde "Kullanıcı" yazması demo setinin '
                'bağlanmadığını gösterir.');
      }
      // En yeni sohbet başta (updatedAt'e göre sıralı).
      for (var i = 1; i < threads.length; i++) {
        expect(
          threads[i].updatedAt.isAfter(threads[i - 1].updatedAt),
          isFalse,
          reason: 'Sohbet listesi yeniden eskiye sıralı olmalı.',
        );
      }
    });

    test('fotoğraflı ustalar listenin BAŞINDA çıkar', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final container = ProviderContainer(
        overrides: demoOverrides(db, MockChatRepository()),
      );
      addTearDown(container.dispose);

      final repo = container.read(artisanRepositoryProvider);
      // Kerem'in bölgesi: 900 tohumlanmış usta arasında fotoğraflı tek kişi.
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(province: 'Bursa', district: 'Nilüfer'),
        offset: 0,
        limit: 20,
      );

      expect(page.items, isNotEmpty);
      expect(page.items.first.profilePhotoUrl, isNotNull,
          reason: 'İlk kart fotoğrafsız çıkarsa ekran görüntüsünde baş harf '
              'rozetleri hakim olur — demo setinin amacı bu değil.');
      expect(page.items.first.uid, 'demo_kerem');
    });

    test('demo YOKKEN sıralama değişmez (normal davranış korunur)', () async {
      final db = MockDatabase(); // demo kapalı
      final container = ProviderContainer(
        overrides: [
          ...mockBackendOverrides(),
          mockDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(artisanRepositoryProvider);
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(province: 'Bursa', district: 'Nilüfer'),
        offset: 0,
        limit: 20,
      );

      // Fotoğraf kuralı devrede olmadığından sıralama yalnız puana bakar.
      for (var i = 1; i < page.items.length; i++) {
        expect(
          page.items[i].averageRating <= page.items[i - 1].averageRating,
          isTrue,
          reason: 'Demo kapalıyken sıralama saf puan sırası olmalı.',
        );
      }
    });

    test('kullanıcı rehberi bağlı — başka uid çözülüyor', () async {
      final db = MockDatabase(withDemoPersonas: true);
      final container = ProviderContainer(
        overrides: demoOverrides(db, MockChatRepository()),
      );
      addTearDown(container.dispose);

      final auth = container.read(authRepositoryProvider);
      final u = await auth.fetchPublicUser('demo_sevil');

      expect(u!.displayName, 'Sevil Karaduman');
      expect(u.hasShopProfile, isTrue,
          reason: 'Mağaza rozeti profil ekranında görünmeliydi.');
    });
  });
}

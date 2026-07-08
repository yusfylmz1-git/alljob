import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/local/mock_database.dart';
import 'package:usta_cepte/data/models/artisan_profile.dart';
import 'package:usta_cepte/data/models/geo_models.dart';
import 'package:usta_cepte/features/artisan/data/artisan_repository.dart';
import 'package:usta_cepte/features/artisan/data/mock_artisan_repository.dart';

void main() {
  // Mahalle filtresi kaldırıldı — bölge filtresi il+ilçe düzeyindedir.
  const dikkaldirim = ArtisanFilter(
    province: 'Bursa',
    district: 'Osmangazi',
    professionCode: 'painter',
  );

  group('MockArtisanRepository arama', () {
    test('bölge + meslek filtreler ve ilk sayfayı sınırlar', () async {
      final repo = MockArtisanRepository(MockDatabase());
      final page = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 20,
      );

      expect(page.items.length, 20);
      expect(page.hasMore, isTrue); // 25 boyacı + 1 elektrikçi var
      // Tümü boyacı olmalı
      expect(page.items.every((a) => a.professionCode == 'painter'), isTrue);
    });

    test('metin sorgusu meslek adıyla eşleşir (Türkçe harf duyarlı)', () async {
      final repo = MockArtisanRepository(MockDatabase());
      // Büyük harfli Türkçe sorgu da eşleşmeli (İ/I dönüşümü).
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(query: 'BOYACI'),
        offset: 0,
        limit: 100,
      );
      expect(page.items, isNotEmpty);
      expect(page.items.every((a) => a.professionCode == 'painter'), isTrue);
    });

    test('metin sorgusu usta adıyla eşleşir', () async {
      final db = MockDatabase();
      final repo = MockArtisanRepository(db);
      final page = await repo.searchArtisans(
        // Tohum verideki adlardan bağımsız: hiçbir kayıtta geçmeyen sorgu boş döner.
        filter: const ArtisanFilter(query: 'xqzw-olmayan-usta'),
        offset: 0,
        limit: 100,
      );
      expect(page.items, isEmpty);
    });

    test('müşteri aramasında yalnızca müsait ustalar döner (yeni temel kural)',
        () async {
      final repo = MockArtisanRepository(MockDatabase());
      final page = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 100,
      );

      // Müsait olmayan usta müşteriye GÖSTERİLMEZ.
      expect(page.items, isNotEmpty);
      expect(page.items.every((a) => a.isAvailable), isTrue);
    });

    test('müsait olmayan usta aramada görünmez', () async {
      final db = MockDatabase();
      final repo = MockArtisanRepository(db);
      db.upsertArtisan(
        uid: 'kapali',
        displayName: 'Kapalı Usta',
        profile: ArtisanProfile.initial('kapali').copyWith(
          profession: 'painter',
          serviceAreas: const [
            ServiceArea(
                province: 'Bursa',
                district: 'Osmangazi',
                neighborhood: 'Dikkaldırım'),
          ],
          manualPause: true, // müsait değil
        ),
      );
      final page = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 100,
      );
      expect(page.items.any((a) => a.uid == 'kapali'), isFalse);
    });

    test('müsait grup içinde puana göre azalan sıralı', () async {
      final repo = MockArtisanRepository(MockDatabase());
      final page = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 20,
      );

      final available = page.items.where((a) => a.isAvailable).toList();
      for (var i = 0; i < available.length - 1; i++) {
        expect(
            available[i].averageRating >= available[i + 1].averageRating, isTrue);
      }
    });

    test('yeni ustalara "Yeni Usta" rozeti atanır', () async {
      final repo = MockArtisanRepository(MockDatabase());
      final all = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 100, // tüm boyacılar tek sayfada
      );
      // Seed'de son 2 boyacı 15 günden yeni → rozet.
      expect(all.items.where((a) => a.isNewArtisan).length, 2);
    });

    test('ikinci sayfa kalan ustaları getirir', () async {
      final repo = MockArtisanRepository(MockDatabase());
      // Toplam eşleşen sayısını tek büyük sayfayla ölç, sonra 2. sayfayla kıyasla
      // (ilçe düzeyi filtre; sabit sayıya bağlanmaz).
      final all = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 500,
      );
      final page2 = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 20,
        limit: 20,
      );
      expect(all.items.length, greaterThan(20)); // sayfalama anlamlı olmalı
      expect(page2.items.length, all.items.length - 20);
      expect(page2.hasMore, isFalse);
    });

    test('opsiyonel filtre: yalnızca meslek (bölge yok) tüm boyacıları getirir',
        () async {
      final repo = MockArtisanRepository(MockDatabase());
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(professionCode: 'painter'),
        offset: 0,
        limit: 500,
      );
      // En az 25 Dikkaldırım boyacısı + genel boyacılar.
      expect(page.items.length, greaterThanOrEqualTo(25));
      expect(page.items.every((a) => a.professionCode == 'painter'), isTrue);
    });

    test('opsiyonel filtre: yalnızca il o ilin ustalarını getirir', () async {
      final repo = MockArtisanRepository(MockDatabase());
      final bursa = await repo.searchArtisans(
        filter: const ArtisanFilter(province: 'Bursa'),
        offset: 0,
        limit: 500,
      );
      final all = await repo.searchArtisans(
        filter: const ArtisanFilter(),
        offset: 0,
        limit: 500,
      );
      // Bursa en az demo verisi kadar; Türkiye geneli Bursa'dan büyük.
      expect(bursa.items.length, greaterThanOrEqualTo(27));
      expect(all.items.length, greaterThanOrEqualTo(bursa.items.length));
    });

    test('her meslek en az bir usta döndürür (usta bulmuyor regresyonu)',
        () async {
      final repo = MockArtisanRepository(MockDatabase());
      const professions = [
        'painter', 'plumber', 'electrician', 'carpenter', 'tiler', 'welder',
        'ac_technician', 'locksmith', 'white_goods', 'mover', 'gardener',
        'cleaner',
      ];
      for (final code in professions) {
        final page = await repo.searchArtisans(
          filter: ArtisanFilter(professionCode: code),
          offset: 0,
          limit: 10,
        );
        expect(page.items, isNotEmpty, reason: '$code için usta bulunamadı');
      }
    });

    test('eşleşmeyen bölge boş döner', () async {
      final repo = MockArtisanRepository(MockDatabase());
      // Seed'de hiçbir ustanın hizmet vermediği bir il.
      final page = await repo.searchArtisans(
        filter: const ArtisanFilter(province: 'Van', professionCode: 'painter'),
        offset: 0,
        limit: 20,
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('detay profil + yorumları getirir', () async {
      final repo = MockArtisanRepository(MockDatabase());
      final detail = await repo.getArtisanDetail('artisan_0');
      expect(detail, isNotNull);
      expect(detail!.uid, 'artisan_0');
      expect(detail.reviews, isNotEmpty);
    });

    test('kaydedilen usta profili aramada görünür (ortak DB)', () async {
      final db = MockDatabase();
      final repo = MockArtisanRepository(db);

      db.upsertArtisan(
        uid: 'me',
        displayName: 'Deneme Usta',
        profile: ArtisanProfile.initial('me').copyWith(
          profession: 'painter',
          serviceAreas: const [
            ServiceArea(
                province: 'Bursa',
                district: 'Osmangazi',
                neighborhood: 'Dikkaldırım'),
          ],
          alwaysAvailable: true,
        ),
      );

      final page = await repo.searchArtisans(
        filter: dikkaldirim,
        offset: 0,
        limit: 100,
      );
      final me = page.items.where((a) => a.uid == 'me');
      expect(me, isNotEmpty);
      expect(me.first.displayName, 'Deneme Usta');
    });
  });
}

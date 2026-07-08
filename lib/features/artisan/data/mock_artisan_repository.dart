import 'dart:math';

import '../../../data/local/mock_database.dart';
import 'artisan_repository.dart';

/// Bellek içi usta araması. Ortak [MockDatabase]'i okur; böylece ustaların
/// kendi kaydettiği profiller de müşteri aramasında görünür.
class MockArtisanRepository implements ArtisanRepository {
  MockArtisanRepository(this._db);

  final MockDatabase _db;

  @override
  Future<ArtisanSearchPage> searchArtisans({
    required ArtisanFilter filter,
    required int offset,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    // Opsiyonel filtre (PRD §3): verilen alanlar AND; boş alan tümünü kabul eder.
    // Meslek seçilmemiş kayıtlar (yeni ustalar) listelenmez.
    final matches = _db.all.where((r) {
      if (r.profile.profession.isEmpty) return false;
      if (filter.professionCode != null &&
          r.profile.profession != filter.professionCode) {
        return false;
      }
      // Temel kural: müsait olmayan usta müşteri aramasında GÖSTERİLMEZ.
      // (Müsaitlik Premium gerektirir → görünenler fiilen Premium ustalardır.)
      if (!r.profile.isAvailableAt(now)) return false;
      if (!filter.matchesQuery(
        displayName: r.displayName,
        professionNameTR: kProfessionNames[r.profile.profession] ?? '',
      )) {
        return false;
      }
      if (!filter.hasGeo) return true;
      return r.profile.serviceAreas.any(filter.matchesArea);
    }).toList();

    // Sıralama (PRD §3): ilk yıl modelinde önce müsait ustalar (puana göre),
    // sonra müsait olmayanlar; 1. yıldan sonra tümü zaten müsait → puana göre.
    matches.sort((a, b) {
      final aAvail = a.profile.isAvailableAt(now);
      final bAvail = b.profile.isAvailableAt(now);
      if (aAvail != bAvail) return aAvail ? -1 : 1;
      return b.profile.averageRating.compareTo(a.profile.averageRating);
    });

    final pageEnd = min(offset + limit, matches.length);
    final pageItems = (offset >= matches.length)
        ? <ArtisanRecord>[]
        : matches.sublist(offset, pageEnd);

    return ArtisanSearchPage(
      items: pageItems.map(_toSummary).toList(),
      hasMore: pageEnd < matches.length,
    );
  }

  @override
  Future<ArtisanDetail?> getArtisanDetail(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final record = _db.artisans[uid];
    if (record == null) return null;
    return ArtisanDetail(
      uid: record.uid,
      displayName: record.displayName,
      professionNameTR: kProfessionNames[record.profile.profession] ?? '',
      profile: record.profile,
      reviews: record.reviews,
      profilePhotoUrl: record.profilePhotoUrl,
    );
  }

  ArtisanSummary _toSummary(ArtisanRecord r) => ArtisanSummary(
        uid: r.uid,
        displayName: r.displayName,
        professionCode: r.profile.profession,
        professionNameTR: kProfessionNames[r.profile.profession] ?? '',
        experienceYears: r.profile.experienceYears,
        averageRating: r.profile.averageRating,
        totalReviews: r.profile.totalReviews,
        isVerified: r.profile.isVerified,
        isPremium: r.profile.isPremium,
        isAvailable: r.profile.isAvailable,
        isNewArtisan: r.profile.isNewArtisan,
        profilePhotoUrl: r.profilePhotoUrl,
      );
}

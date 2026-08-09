import 'dart:math';

import '../../../data/local/mock_database.dart';
import '../../../data/models/artisan_profile.dart';
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
    bool? premiumFreeDuringBeta,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final now = DateTime.now();

    // Premium kapısı — mock, güvenlik kuralı/istemci davranışını taklit eder.
    bool musait(ArtisanProfile p) =>
        p.isAvailableAt(now, premiumFreeDuringBeta: premiumFreeDuringBeta);

    // Opsiyonel filtre (PRD §3): verilen alanlar AND; boş alan tümünü kabul eder.
    // Meslek seçilmemiş kayıtlar (yeni ustalar) listelenmez.
    final matches = _db.all.where((r) {
      if (r.profile.professionCodes.isEmpty) return false;
      if (filter.professionCode != null &&
          !r.profile.professionCodes.contains(filter.professionCode)) {
        return false;
      }
      // Temel kural: müsait olmayan usta müşteri aramasında GÖSTERİLMEZ.
      // (Müsaitlik Premium gerektirir → görünenler fiilen Premium ustalardır.)
      if (!musait(r.profile)) return false;
      if (!filter.matchesQuery(
        displayName: r.displayName,
        professionNameTR:
            r.profile.professionLabelsTR(kProfessionNames),
      )) {
        return false;
      }
      if (!filter.hasGeo) return true;
      return r.profile.serviceAreas.any(filter.matchesArea);
    }).toList();

    // Sıralama (PRD §3): ilk yıl modelinde önce müsait ustalar (puana göre),
    // sonra müsait olmayanlar; 1. yıldan sonra tümü zaten müsait → puana göre.
    matches.sort((a, b) {
      final aAvail = musait(a.profile);
      final bAvail = musait(b.profile);
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
      professionNameTR:
          record.profile.professionLabelsTR(kProfessionNames),
      profile: record.profile,
      reviews: record.reviews,
      profilePhotoUrl: record.profilePhotoUrl,
    );
  }

  ArtisanSummary _toSummary(ArtisanRecord r) => ArtisanSummary(
        uid: r.uid,
        displayName: r.displayName,
        professionCode: r.profile.profession,
        professionNameTR:
            r.profile.professionLabelsTR(kProfessionNames),
        experienceYears: r.profile.experienceYears,
        averageRating: r.profile.averageRating,
        totalReviews: r.profile.totalReviews,
        topTags: r.profile.topTags,
        isVerified: r.profile.showVerifiedBadge,
        isEmailVerified: r.profile.emailVerified,
        isPremium: r.profile.isPremium,
        isAvailable: r.profile.isAvailable,
        isNewArtisan: r.profile.isNewArtisan,
        profilePhotoUrl: r.profilePhotoUrl,
        areaLabel: r.profile.serviceAreas.isNotEmpty
            ? r.profile.serviceAreas.first.labelTR
            : null,
      );
}

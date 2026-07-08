import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/artisan_profile.dart';
import 'artisan_providers.dart';
import 'firebase_my_profile_repository.dart';

/// Ustanın KENDİ profilini okuyup yazdığı soyutlama (PRD Ekran D).
/// Listeleme tarafındaki `ArtisanRepository`'den ayrıdır ama AYNI veritabanını
/// kullanır — böylece kaydedilen profil müşteri aramasında da görünür.
abstract interface class MyProfileRepository {
  /// Ustanın profilini getirir; yoksa boş başlangıç profili döner.
  Future<ArtisanProfile> getMyProfile(String uid);

  /// Profili kaydeder (puanlama alanları korunur, onlar Cloud Functions'a ait).
  Future<void> saveMyProfile({
    required String uid,
    required String displayName,
    String? profilePhotoUrl,
    required ArtisanProfile profile,
  });

  /// Telefon doğrulaması sonrası ustanın "mavi tik"ini (isVerified) açar.
  /// Yalnızca profil dökümanı zaten varsa yazar (müşteri için no-op).
  Future<void> markVerified(String uid);
}

/// Ortak [MockDatabase] üzerinden çalışan uygulama.
class MockMyProfileRepository implements MyProfileRepository {
  MockMyProfileRepository(this._ref);

  final Ref _ref;

  @override
  Future<ArtisanProfile> getMyProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final db = _ref.read(mockDatabaseProvider);
    return db.artisans[uid]?.profile ?? ArtisanProfile.initial(uid);
  }

  @override
  Future<void> saveMyProfile({
    required String uid,
    required String displayName,
    String? profilePhotoUrl,
    required ArtisanProfile profile,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _ref.read(mockDatabaseProvider).upsertArtisan(
          uid: uid,
          displayName: displayName,
          profilePhotoUrl: profilePhotoUrl,
          profile: profile,
        );
  }

  @override
  Future<void> markVerified(String uid) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final db = _ref.read(mockDatabaseProvider);
    final existing = db.artisans[uid];
    if (existing == null) return; // müşteri → mavi tik yok
    db.upsertArtisan(
      uid: uid,
      displayName: existing.displayName,
      profilePhotoUrl: existing.profilePhotoUrl,
      profile: existing.profile.copyWith(isVerified: true),
    );
  }
}

final myProfileRepositoryProvider = Provider<MyProfileRepository>((ref) {
  if (useFirebaseBackend) return FirebaseMyProfileRepository();
  return MockMyProfileRepository(ref);
});

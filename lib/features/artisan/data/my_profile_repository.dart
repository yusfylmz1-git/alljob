import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/artisan_profile.dart';
import '../../auth/application/auth_controller.dart' show authRepositoryProvider;
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

  /// Ustanın "mavi tik"ini (isVerified) açar.
  ///
  /// SMS doğrulaması kaldırıldığından (2026-08-18) istemci bu metodu ARTIK
  /// ÇAĞIRMAZ ve Firestore kuralı `isVerified` yazımını istemciye kapatır;
  /// rozet yalnız admin/CF tarafından verilir (`adminVerified`). Metot,
  /// arayüz bütünlüğü için duruyor.
  Future<void> markVerified(String uid);

  /// Vitrinde telefon görünürlüğü (rıza). Profil yoksa no-op.
  Future<void> setPhoneVisibility({
    required String uid,
    required bool showOnProfile,
    String? publicPhone,
  });
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
    final db = _ref.read(mockDatabaseProvider);
    // Kural paritesi: isPremium/premiumExpiresAt istemci kaydıyla DEĞİŞEMEZ
    // (Firebase tarafında kural + merge korur) — mevcut değer korunur,
    // ilk kayıtta premium verilmez.
    final existing = db.artisans[uid]?.profile;
    db.upsertArtisan(
      uid: uid,
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      profile: profile.copyWith(
        isPremium: existing?.isPremium ?? false,
        premiumExpiresAt: existing?.premiumExpiresAt,
      ),
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

  @override
  Future<void> setPhoneVisibility({
    required String uid,
    required bool showOnProfile,
    String? publicPhone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    // FIREBASE PARİTESİ (kural 1): gerçek uygulama numarayı İKİ yere yazar —
    // `users/{uid}.publicPhone` (profil başlığının OKUDUĞU yer) ve
    // `artisanProfiles/{uid}` (usta vitrini). Mock'ta `users` karşılığı
    // auth deposudur; oraya yazılmazsa profil başlığı numarayı göstermez ve
    // 2026-08-14'te canlıda çıkan hata mock testlerinde görünmez.
    //
    // YAYIN ≠ KAYIT (2026-08-23): kapatmak YALNIZ yayını düşürür. Burada
    // `updateUserProfile(publicPhone: '')` ÇAĞRILAMAZ — o metot kalıcı
    // kaydı (`savedPhone`) da temizler ve numara tamamen kaybolurdu; hatanın
    // ta kendisi buydu. Bunun yerine kullanıcı doğrudan güncellenir:
    // `clearPublicPhone` yayını siler, `savedPhone` yerinde kalır.
    await _ref.read(authRepositoryProvider).setPublicPhoneVisibility(
          show: showOnProfile,
          publicPhone: publicPhone,
        );

    final db = _ref.read(mockDatabaseProvider);
    final existing = db.artisans[uid];
    // Mağaza sahibinin usta profili olmayabilir: `users` yazımı yukarıda
    // KOŞULSUZ yapıldı, burada yalnız vitrin alanları güncellenir.
    if (existing == null) return;
    db.upsertArtisan(
      uid: uid,
      displayName: existing.displayName,
      profilePhotoUrl: existing.profilePhotoUrl,
      profile: existing.profile.copyWith(
        showPhoneOnProfile: showOnProfile,
        publicPhone: showOnProfile ? publicPhone : null,
        clearPublicPhone: !showOnProfile,
      ),
    );
  }
}

final myProfileRepositoryProvider = Provider<MyProfileRepository>((ref) {
  if (useFirebaseBackend) return FirebaseMyProfileRepository();
  return MockMyProfileRepository(ref);
});

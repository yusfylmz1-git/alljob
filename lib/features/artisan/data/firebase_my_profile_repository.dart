import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/validators.dart';
import '../../../data/models/artisan_profile.dart';
import 'my_profile_repository.dart';

/// Firestore `artisanProfiles/{uid}` ile çalışan [MyProfileRepository].
///
/// displayName ve profil fotoğrafı, listeleme sırasında ekstra okuma yapmamak
/// için profil dökümanına DENORMALIZE edilir (users ile birlikte tutulur).
/// Puanlama alanları (averageRating/totalReviews) burada YAZILMAZ — onlar
/// Cloud Functions'a aittir (PRD §5); kayıt sırasında merge ile korunur.
class FirebaseMyProfileRepository implements MyProfileRepository {
  FirebaseMyProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('artisanProfiles').doc(uid);

  @override
  Future<ArtisanProfile> getMyProfile(String uid) async {
    try {
      final snap = await _profileDoc(uid)
          .get()
          .timeout(const Duration(seconds: 12));
      if (snap.exists && snap.data() != null) {
        final raw = snap.data()!;
        final profile = ArtisanProfile.fromMap(uid, raw);
        // H3 heal arka planda — İşler açılışını bloklamasın (ANR).
        unawaited(_healMatchFields(uid, raw, profile));
        return profile;
      }
    } catch (_) {
      // Zaman aşımı / ağ: boş profille devam (UI kilitlenmesin).
      return ArtisanProfile.initial(uid);
    }
    return ArtisanProfile.initial(uid);
  }

  /// Eski/eksik H3 alanlarını senkron yazar (rules paritesi).
  Future<void> _healMatchFields(
    String uid,
    Map<String, dynamic> raw,
    ArtisanProfile profile,
  ) async {
    final expectedKeys =
        profile.serviceAreas.map((e) => e.key).where((k) => k != '|').toList();
    final rawKeys = (raw['serviceAreaKeys'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final keysMissingOrStale = expectedKeys.isNotEmpty &&
        (rawKeys.isEmpty ||
            expectedKeys.length != rawKeys.length ||
            !expectedKeys.every(rawKeys.contains));
    final needProf = profile.professionCodes.isNotEmpty &&
        (raw['professions'] is! List ||
            (raw['professions'] as List).isEmpty);
    if (!keysMissingOrStale && !needProf) return;
    final patch = <String, dynamic>{};
    if (keysMissingOrStale) patch['serviceAreaKeys'] = expectedKeys;
    if (needProf) patch['professions'] = profile.professionCodes;
    try {
      await _profileDoc(uid).set(patch, SetOptions(merge: true));
    } catch (_) {/* best-effort; create teklif yine denenecek */}
  }

  @override
  Future<void> saveMyProfile({
    required String uid,
    required String displayName,
    String? profilePhotoUrl,
    required ArtisanProfile profile,
  }) async {
    // Profil alanları + denormalize edilmiş ad/foto. Puanlama ve premium
    // alanları BURADAN YAZILMAZ (kural da reddeder): rating/sayaç alanları
    // Cloud Functions'a, isPremium/premiumExpiresAt ileride satın alma
    // doğrulamasına aittir. toMap'ten çıkarılıp merge ile korunur.
    // Deneyim / hakkımda istemci ve rules tavanıyla hizalanır.
    final safeProfile = profile.copyWith(
      experienceYears:
          Validators.clampExperienceYears(profile.experienceYears),
      aboutText: Validators.sanitizeFreeText(profile.aboutText),
    );
    final safeName = Validators.normalizeDisplayName(displayName);
    final data = Map<String, dynamic>.from(safeProfile.toMap())
      ..remove('averageRating')
      ..remove('totalReviews')
      ..remove('totalRatingSum')
      ..remove('completedJobs')
      ..remove('isPremium')
      ..remove('premiumExpiresAt')
      ..['displayName'] = safeName
      ..['profilePhotoURL'] = profilePhotoUrl;

    await _profileDoc(uid).set(data, SetOptions(merge: true));

    // users dökümanındaki görünen ad/foto da güncel kalsın.
    await _db.collection('users').doc(uid).set({
      'displayName': safeName,
      'profilePhotoURL': profilePhotoUrl,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> markVerified(String uid) async {
    // Yalnızca profil dökümanı VARSA yaz — merge, olmayan dökümanı yaratıp
    // müşteriye yarım bir usta profili oluşturmasın. Kural, `isVerified=true`
    // yazımına yalnızca jetonda doğrulanmış telefon varsa izin verir.
    final snap = await _profileDoc(uid).get();
    if (!snap.exists) return;
    await _profileDoc(uid).set({'isVerified': true}, SetOptions(merge: true));
  }
}

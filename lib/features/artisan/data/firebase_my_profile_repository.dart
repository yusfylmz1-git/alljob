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
    // Hemen Lazım il düzeyi eşleşmesi için (rules string ayıramaz).
    final expectedProvinces = profile.serviceAreas
        .map((e) => e.province)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    final rawProvinces = (raw['serviceProvinces'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final provincesMissingOrStale = expectedProvinces.isNotEmpty &&
        (rawProvinces.isEmpty ||
            expectedProvinces.length != rawProvinces.length ||
            !expectedProvinces.every(rawProvinces.contains));
    if (!keysMissingOrStale && !needProf && !provincesMissingOrStale) return;
    final patch = <String, dynamic>{};
    if (keysMissingOrStale) patch['serviceAreaKeys'] = expectedKeys;
    if (provincesMissingOrStale) patch['serviceProvinces'] = expectedProvinces;
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
      ..remove('topTags') // CF (onReviewWritten) yazar; istemci yazamaz.
      ..remove('completedJobs')
      ..remove('isPremium')
      ..remove('premiumExpiresAt')
      // B-04: DOĞRULAMA AYNALARI da yazımdan çıkar. `verifiedClaimOk` ve
      // `emailVerifiedMirrorOk` (firestore.rules) bu alanların true olmasını
      // Auth token'ındaki `phone_number` / `email_verified` ile karşılaştırır.
      // Profilde true yazılı ama token'da karşılığı yoksa TÜM KAYIT reddedilir
      // ("sunucu reddetti"). İstemcinin bunları yazmasına gerek yok: telefon
      // doğrulama akışı ve CF yazar, merge ile mevcut değer korunur.
      ..remove('isVerified')
      ..remove('emailVerified')
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
    // `isVerified` alanı artık admin/CF moderasyonunda denetlenir.
  }

  @override
  Future<void> setPhoneVisibility({
    required String uid,
    required bool showOnProfile,
    String? publicPhone,
  }) async {
    // İKİ DOKÜMANA DA YAZILIR (2026-08-14 cihaz bulgusu: "göster" işaretlense
    // de numara profilde çıkmıyordu).
    //
    // Sebep: burası yalnız `artisanProfiles/{uid}` yazıyordu, ama profil
    // başlığı numarayı `users/{uid}.publicPhone` alanından okuyor
    // (`ProfileHeader` → `user.publicPhone`). İki alan aynı adı taşıyor ama
    // AYRI dokümanlarda; yazılan yer okunan yer değildi.
    //
    // `users` yazımı ÖNCE ve KOŞULSUZ yapılır: mağaza sahibinin
    // `artisanProfiles` dokümanı hiç olmayabilir — eski kod o durumda
    // `if (!snap.exists) return` ile sessizce çıkıyor ve mağazacının
    // numarası HİÇ yazılmıyordu.
    await _db.collection('users').doc(uid).set({
      // Boş dize DEĞİL null: `users` kuralı publicPhone için string|null
      // kabul eder ve null "alanı temizle" anlamına gelir.
      'publicPhone': showOnProfile ? publicPhone : null,
    }, SetOptions(merge: true));

    // KALICI KAYIT (2026-08-23) — `private/contact.savedPhone`'a DOKUNULMAZ.
    //
    // Bu metot YALNIZ YAYINI değiştirir. Numaranın kendisi
    // `users/{uid}/private/contact.savedPhone` altında durur ve ancak
    // kullanıcı "İletişim Numarası" formundan silerse gider
    // (`updateUserProfile`). Eskiden bu ayrım yoktu: anahtarı kapatmak
    // numarayı SİLİYOR, kullanıcı geri açmak isteyince numara olmadığı için
    // anahtar satırı ekrandan tamamen kayboluyordu (testçi bulgusu:
    // "telefonu göster kapatınca telefon gidiyor").
    //
    // AÇARKEN yayınlanan numarayı kalıcı kayda da yaz: kullanıcı numarasını
    // yalnız `artisanProfiles` tarafında değiştirmiş olabilir.
    if (showOnProfile && publicPhone != null && publicPhone.trim().isNotEmpty) {
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('private')
            .doc('contact')
            .set({'savedPhone': publicPhone.trim()}, SetOptions(merge: true));
      } catch (_) {
        // Yardımcı kayıt: yayın zaten yazıldı, `contactPhone` ona düşer.
      }
    }

    // Usta vitrini için profil dokümanı (varsa) da güncellenir.
    final snap = await _profileDoc(uid).get();
    if (!snap.exists) return;
    await _profileDoc(uid).set({
      'showPhoneOnProfile': showOnProfile,
      'publicPhone': showOnProfile ? publicPhone : null,
    }, SetOptions(merge: true));
  }
}

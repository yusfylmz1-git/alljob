import '../../core/constants/app_constants.dart';
import 'availability.dart';
import 'geo_models.dart';
import 'social_links.dart';

/// `artisanProfiles` koleksiyonundaki usta profili. Döküman ID'si = Auth UID.
class ArtisanProfile {
  const ArtisanProfile({
    required this.uid,
    required this.profession,
    this.professions = const [],
    required this.experienceYears,
    required this.aboutText,
    required this.serviceAreas,
    required this.certificates,
    required this.workPhotos,
    required this.isVerified,
    this.emailVerified = false,
    required this.averageRating,
    required this.totalReviews,
    required this.totalRatingSum,
    this.topTags = const [],
    this.completedJobs = 0,
    required this.isPremium,
    required this.alwaysAvailable,
    required this.manualPause,
    required this.weeklySchedule,
    required this.createdAt,
    this.premiumExpiresAt,
    this.premiumProductId,
    this.certificateStatus = 'none',
    this.certificateNote,
    this.adminVerified = false,
    this.featured = false,
    this.moderationHidden = false,
    this.showPhoneOnProfile = false,
    this.publicPhone,
    this.socialLinks = SocialLinks.empty,
  });

  final String uid;

  /// Birincil meslek kodu (geriye dönük + CF `profession ==` sorguları).
  /// [professionCodes] listesinin ilki ile senkron tutulur.
  final String profession;

  /// Ustanın seçtiği tüm meslek kodları (çoklu meslek). Boşsa [profession].
  final List<String> professions;
  final int experienceYears;
  final String aboutText;
  final List<ServiceArea> serviceAreas;
  final List<String> certificates;
  final List<String> workPhotos;
  final bool isVerified;

  /// Auth e-posta doğrulamasının herkese açık aynası (Keşfet tooltip).
  /// Yazım: token `email_verified` iken istemci/true; rules zorlar.
  final bool emailVerified;

  /// Platform (admin) onayı — CF yazar (K16).
  final bool adminVerified;
  final bool featured;
  final bool moderationHidden;

  /// Yüklenen ustalık/yeterlilik belgelerinin inceleme durumu.
  /// `none` (belge yok) · `pending` (incelemede) · `approved` · `rejected`.
  /// SALT OKUNUR: yalnız CF (adminReviewCertificates) yazar; istemci belge
  /// yükleyince sunucu tarafında `pending`e döner.
  final String certificateStatus;

  /// Reddedildiyse ustaya gösterilen gerekçe (`rejected` dışında null).
  final String? certificateNote;

  /// Belgeleri onaylanmış usta mı? Profilde "Belgeli usta" rozeti çıkar.
  /// Mavi tike (telefon/platform onayı) ETKİ ETMEZ — ayrı bir sinyaldir.
  bool get hasApprovedCertificates =>
      certificateStatus == 'approved' && certificates.isNotEmpty;

  /// Belgeler incelemede mi? (usta profilinde "inceleniyor" bilgisi)
  bool get certificatesPending => certificateStatus == 'pending';

  /// Usta, doğrulanmış telefonunu vitrinde herkese açık göstermeyi seçti mi?
  /// true ise [publicPhone] profilde (avatar altında) görünür ve aramaya açılır.
  final bool showPhoneOnProfile;

  /// Vitrinde gösterilecek E.164 telefon (yalnız [showPhoneOnProfile] true iken).
  /// Private `users/.../contact` kopyası değildir; açık rıza ile yazılır.
  final String? publicPhone;

  /// Vitrinde gösterilen sosyal medya / iş hattı bağlantıları (opsiyonel).
  /// Kullanıcı adları normalize edilmiş biçimde saklanır — bkz. [SocialLinks].
  final SocialLinks socialLinks;

  /// Profilde aranabilir telefon gösterilsin mi?
  bool get hasPublicPhone =>
      showPhoneOnProfile &&
      publicPhone != null &&
      publicPhone!.trim().isNotEmpty;

  /// Mavi tik: telefon yolu VEYA platform onayı (e-posta tek başına yetmez).
  bool get showVerifiedBadge => isVerified || adminVerified;

  /// Keşfet / profil mavi tik tooltip metni.
  String get verifiedBadgeTooltip {
    if (adminVerified && !isVerified) return 'Platform onaylı usta';
    if (isVerified && emailVerified) {
      return 'Telefon ve e-posta doğrulanmış usta';
    }
    if (isVerified) return 'Telefonu doğrulanmış usta';
    if (adminVerified) return 'Platform onaylı usta';
    return 'Doğrulanmış usta';
  }

  /// Etkili meslek listesi (çoklu + legacy tek alan).
  List<String> get professionCodes {
    if (professions.isNotEmpty) {
      return professions.where((c) => c.trim().isNotEmpty).toList();
    }
    if (profession.trim().isNotEmpty) return [profession.trim()];
    return const [];
  }

  /// Görüntüleme: virgülle birleştirilmiş Türkçe adlar (en fazla 3 + …).
  String professionLabelsTR(Map<String, String> names) {
    final codes = professionCodes;
    if (codes.isEmpty) return '';
    final labels = codes
        .map((c) => names[c] ?? c)
        .where((s) => s.isNotEmpty)
        .toList();
    if (labels.length <= 3) return labels.join(', ');
    return '${labels.take(3).join(', ')} +${labels.length - 3}';
  }

  // Puanlama — yalnızca Cloud Functions günceller (PRD §5).
  final double averageRating;
  final int totalReviews;
  final int totalRatingSum;

  /// En sık verilen (olumlu) değerlendirme etiketleri; en çok 3. Yalnızca
  /// Cloud Functions `onReviewWritten` günceller (tagCounts'tan türetilir).
  /// Keşfet / ana sayfa usta kartındaki rozetler bunu gösterir.
  final List<String> topTags;

  /// Tamamlanan iş sayısı — yalnızca Cloud Functions günceller (`onJobWritten`,
  /// iş `completed` durumuna İLK geçtiğinde +1). İstemci yazamaz (kural).
  final int completedJobs;

  // Monetizasyon — gelir modeli yalnızca Premium üyeliğe dayanır (PRD §6).
  final bool isPremium;
  final DateTime? premiumExpiresAt;

  /// Aboneliğin kaynağı: Play ürün kimliği ya da yönetici manuel tanımlaması
  /// (`manual_admin_grant`). SALT OKUNUR — yalnız Cloud Functions yazar,
  /// bu yüzden [toMap]'e dâhil EDİLMEZ (rules istemci yazımını reddeder).
  final String? premiumProductId;

  // Canlı müsaitlik / çalışma takvimi (PRD §3).
  final bool alwaysAvailable;
  final bool manualPause; // "Geçici Olarak Müsait Değilim"
  final WeeklySchedule weeklySchedule;

  /// Ustanın platforma katıldığı an — "Yeni Usta" görünürlük desteği için.
  final DateTime createdAt;

  bool get hasActivePremium => hasActivePremiumAt(DateTime.now());

  /// Verilen ana göre aktif premium. [isAvailableAt] gibi bir "an" alan
  /// hesaplar bunu kullanmalı: aksi hâlde tek çağrı içinde iki farklı zaman
  /// kaynağı olur (verilen `now` + gerçek saat) ve sonuç tutarsızlaşır.
  bool hasActivePremiumAt(DateTime now) =>
      isPremium &&
      premiumExpiresAt != null &&
      premiumExpiresAt!.isAfter(now);

  /// Premium ÖZELLİKLERİNE erişim (müsait olma, iş ilanlarını görme).
  /// [premiumFreeDuringBeta] verilmezse [AppConstants] (yerel fallback).
  /// Tercihen remote `adminConfig/runtime` ile çağırın (M7).
  /// Rozet gösterimi buna DEĞİL [hasActivePremium]'a bakar.
  bool hasPremiumAccess({bool? premiumFreeDuringBeta, DateTime? now}) =>
      (premiumFreeDuringBeta ?? AppConstants.premiumFreeDuringBeta) ||
      hasActivePremiumAt(now ?? DateTime.now());

  /// Canlı müsaitlik: PREMIUM ERİŞİMİ olmayan usta hiç müsait sayılmaz; sonra
  /// manuel duraklatma her şeyi geçersiz kılar; sonra "her zaman müsait";
  /// değilse haftalık plana bakılır (PRD §3, Arama Sonuçları).
  ///
  /// PREMIUM KAPISI (2026-08-09): ücretsiz döneme son verildiğinde
  /// (`premiumFreeDuringBeta = false`) müsaitlik KENDİLİĞİNDEN kapanmıyordu —
  /// anahtarı açık bırakmış usta açık kalmaya devam ediyordu. Kapıyı burada
  /// tutmak toplu yazmadan iyidir: kimsenin verisi değişmez, ücretsiz döneme
  /// dönülürse herkes eski hâline kendiliğinden döner ve ustanın kendi
  /// duraklatma tercihi kaybolmaz.
  ///
  /// [premiumFreeDuringBeta] verilmezse [AppConstants] (yerel fallback);
  /// çağıran taraf remote `adminConfig/runtime` değerini geçmelidir.
  bool isAvailableAt(DateTime now, {bool? premiumFreeDuringBeta}) {
    if (!hasPremiumAccess(
      premiumFreeDuringBeta: premiumFreeDuringBeta,
      now: now,
    )) {
      return false;
    }
    if (manualPause) return false;
    if (alwaysAvailable) return true;
    return weeklySchedule.isOpenAt(now);
  }

  bool get isAvailable => isAvailableAt(DateTime.now());

  /// İlk [AppConstants.newArtisanVisibilityDays] gün boyunca "Yeni Usta" rozeti.
  bool isNewArtisanAt(DateTime now) =>
      now.difference(createdAt).inDays < AppConstants.newArtisanVisibilityDays;

  bool get isNewArtisan => isNewArtisanAt(DateTime.now());

  /// Kullanıcı panelinde gösterilen müsaitlik kipi.
  AvailabilityMode get availabilityMode {
    if (manualPause) return AvailabilityMode.paused;
    if (alwaysAvailable) return AvailabilityMode.always;
    return AvailabilityMode.weekly;
  }

  /// Yeni kayıt olan usta için boş başlangıç profili.
  factory ArtisanProfile.initial(String uid) => ArtisanProfile(
    uid: uid,
    profession: '',
    professions: const [],
    experienceYears: 0,
    aboutText: '',
    serviceAreas: const [],
    certificates: const [],
    workPhotos: const [],
    isVerified: false,
    emailVerified: false,
    averageRating: 0,
    totalReviews: 0,
    totalRatingSum: 0,
    isPremium: false,
    premiumExpiresAt: null,
    alwaysAvailable: false,
    manualPause: false,
    weeklySchedule: WeeklySchedule.empty(),
    createdAt: DateTime.now(),
  );

  ArtisanProfile copyWith({
    String? profession,
    List<String>? professions,
    int? experienceYears,
    String? aboutText,
    List<ServiceArea>? serviceAreas,
    List<String>? certificates,
    List<String>? workPhotos,
    bool? isVerified,
    bool? emailVerified,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    bool? alwaysAvailable,
    bool? manualPause,
    WeeklySchedule? weeklySchedule,
    bool? showPhoneOnProfile,
    String? publicPhone,
    bool clearPublicPhone = false,
    SocialLinks? socialLinks,
  }) {
    final nextList = professions ?? this.professions;
    final nextPrimary =
        profession ?? (nextList.isNotEmpty ? nextList.first : this.profession);
    return ArtisanProfile(
      uid: uid,
      profession: nextPrimary,
      professions: nextList,
      experienceYears: experienceYears ?? this.experienceYears,
      aboutText: aboutText ?? this.aboutText,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      certificates: certificates ?? this.certificates,
      workPhotos: workPhotos ?? this.workPhotos,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalRatingSum: totalRatingSum,
      topTags: topTags,
      completedJobs: completedJobs,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      premiumProductId: premiumProductId,
      certificateStatus: certificateStatus,
      certificateNote: certificateNote,
      alwaysAvailable: alwaysAvailable ?? this.alwaysAvailable,
      manualPause: manualPause ?? this.manualPause,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      createdAt: createdAt,
      adminVerified: adminVerified,
      featured: featured,
      moderationHidden: moderationHidden,
      showPhoneOnProfile: showPhoneOnProfile ?? this.showPhoneOnProfile,
      publicPhone: clearPublicPhone ? null : (publicPhone ?? this.publicPhone),
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }

  /// Yalnızca puanlama/sayaç alanlarını günceller (mock'ta Cloud Functions
  /// yerine). Normal [copyWith] bu alanları kasıtlı olarak korur.
  ArtisanProfile copyWithRating({
    required double averageRating,
    required int totalReviews,
    required int totalRatingSum,
    List<String>? topTags,
    int? completedJobs,
  }) {
    return ArtisanProfile(
      uid: uid,
      profession: profession,
      professions: professions,
      experienceYears: experienceYears,
      aboutText: aboutText,
      serviceAreas: serviceAreas,
      certificates: certificates,
      workPhotos: workPhotos,
      isVerified: isVerified,
      emailVerified: emailVerified,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalRatingSum: totalRatingSum,
      topTags: topTags ?? this.topTags,
      completedJobs: completedJobs ?? this.completedJobs,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      premiumProductId: premiumProductId,
      certificateStatus: certificateStatus,
      certificateNote: certificateNote,
      alwaysAvailable: alwaysAvailable,
      manualPause: manualPause,
      weeklySchedule: weeklySchedule,
      createdAt: createdAt,
      adminVerified: adminVerified,
      featured: featured,
      moderationHidden: moderationHidden,
      showPhoneOnProfile: showPhoneOnProfile,
      publicPhone: publicPhone,
      socialLinks: socialLinks,
    );
  }

  Map<String, dynamic> toMap() {
    final codes = professionCodes;
    final primary = codes.isNotEmpty ? codes.first : profession;
    return {
      'profession': primary,
      // Çoklu meslek (array-contains sorguları + UI).
      'professions': codes,
      'experienceYears': experienceYears,
      'aboutText': aboutText,
      'serviceAreas': serviceAreas.map((e) => e.toMap()).toList(),
      // H3: rules eşleşmesi için "İl|İlçe" anahtarları (serviceAreas ile senkron).
      'serviceAreaKeys': serviceAreas
          .map((e) => e.key)
          .where((k) => k != '|')
          .toList(),
      // Hemen Lazım İL düzeyinde eşleştiğinden rules'un il listesine ihtiyacı
      // var: kurallar string ayıramadığı için "İl|İlçe" anahtarından il
      // çıkarılamaz. serviceAreas ile senkron, tekilleştirilmiş.
      'serviceProvinces': serviceAreas
          .map((e) => e.province)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList(),
      'certificates': certificates,
      'workPhotos': workPhotos,
      'isVerified': isVerified,
      'emailVerified': emailVerified,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalRatingSum': totalRatingSum,
      'topTags': topTags,
      'completedJobs': completedJobs,
      'isPremium': isPremium,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'alwaysAvailable': alwaysAvailable,
      'manualPause': manualPause,
      'weeklySchedule': weeklySchedule.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'showPhoneOnProfile': showPhoneOnProfile,
      'publicPhone': publicPhone,
      'socialLinks': socialLinks.toMap(),
    };
  }

  factory ArtisanProfile.fromMap(String uid, Map<String, dynamic> map) {
    final single = (map['profession'] as String?) ?? '';
    final rawList =
        (map['professions'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final list = rawList.isNotEmpty
        ? rawList
        : (single.isNotEmpty ? [single] : const <String>[]);
    return ArtisanProfile(
      uid: uid,
      profession: list.isNotEmpty ? list.first : single,
      professions: list,
      experienceYears: (() {
        final y = (map['experienceYears'] as num?)?.toInt() ?? 0;
        if (y < 0) return 0;
        if (y > 60) return 60; // AppConstants.maxExperienceYears ile hizalı
        return y;
      })(),
      aboutText: (map['aboutText'] as String?) ?? '',
      serviceAreas: ((map['serviceAreas'] as List?) ?? [])
          .map((e) => ServiceArea.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      certificates: ((map['certificates'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      workPhotos: ((map['workPhotos'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      isVerified: (map['isVerified'] as bool?) ?? false,
      emailVerified: map['emailVerified'] == true,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      totalRatingSum: (map['totalRatingSum'] as num?)?.toInt() ?? 0,
      topTags: ((map['topTags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      completedJobs: (map['completedJobs'] as num?)?.toInt() ?? 0,
      isPremium: (map['isPremium'] as bool?) ?? false,
      premiumExpiresAt: map['premiumExpiresAt'] != null
          ? DateTime.tryParse(map['premiumExpiresAt'].toString())
          : null,
      premiumProductId: map['premiumProductId'] as String?,
      certificateStatus:
          (map['certificateStatus'] as String?)?.trim().isNotEmpty == true
          ? map['certificateStatus'] as String
          : 'none',
      certificateNote: map['certificateNote'] as String?,
      alwaysAvailable: (map['alwaysAvailable'] as bool?) ?? false,
      manualPause: (map['manualPause'] as bool?) ?? false,
      weeklySchedule: WeeklySchedule.fromMap(map['weeklySchedule'] as Map?),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      adminVerified: map['adminVerified'] == true,
      featured: map['featured'] == true,
      moderationHidden: map['moderationHidden'] == true,
      showPhoneOnProfile: map['showPhoneOnProfile'] == true,
      publicPhone: map['publicPhone'] as String?,
      socialLinks: SocialLinks.fromMap(
        (map['socialLinks'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

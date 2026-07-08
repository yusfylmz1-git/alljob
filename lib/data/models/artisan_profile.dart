import '../../core/constants/app_constants.dart';
import 'availability.dart';
import 'geo_models.dart';

/// `artisanProfiles` koleksiyonundaki usta profili. Döküman ID'si = Auth UID.
class ArtisanProfile {
  const ArtisanProfile({
    required this.uid,
    required this.profession,
    required this.experienceYears,
    required this.aboutText,
    required this.serviceAreas,
    required this.certificates,
    required this.workPhotos,
    required this.isVerified,
    required this.averageRating,
    required this.totalReviews,
    required this.totalRatingSum,
    required this.isPremium,
    required this.alwaysAvailable,
    required this.manualPause,
    required this.weeklySchedule,
    required this.createdAt,
    this.premiumExpiresAt,
  });

  final String uid;
  final String profession; // meslek kodu
  final int experienceYears;
  final String aboutText;
  final List<ServiceArea> serviceAreas;
  final List<String> certificates;
  final List<String> workPhotos;
  final bool isVerified;

  // Puanlama — yalnızca Cloud Functions günceller (PRD §5).
  final double averageRating;
  final int totalReviews;
  final int totalRatingSum;

  // Monetizasyon — gelir modeli yalnızca Premium üyeliğe dayanır (PRD §6).
  final bool isPremium;
  final DateTime? premiumExpiresAt;

  // Canlı müsaitlik / çalışma takvimi (PRD §3).
  final bool alwaysAvailable;
  final bool manualPause; // "Geçici Olarak Müsait Değilim"
  final WeeklySchedule weeklySchedule;

  /// Ustanın platforma katıldığı an — "Yeni Usta" görünürlük desteği için.
  final DateTime createdAt;

  bool get hasActivePremium =>
      isPremium &&
      premiumExpiresAt != null &&
      premiumExpiresAt!.isAfter(DateTime.now());

  /// Canlı müsaitlik: manuel duraklatma her şeyi geçersiz kılar; sonra
  /// "her zaman müsait"; değilse haftalık plana bakılır (PRD §3, Arama Sonuçları).
  bool isAvailableAt(DateTime now) {
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
        experienceYears: 0,
        aboutText: '',
        serviceAreas: const [],
        certificates: const [],
        workPhotos: const [],
        isVerified: false,
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
    int? experienceYears,
    String? aboutText,
    List<ServiceArea>? serviceAreas,
    List<String>? certificates,
    List<String>? workPhotos,
    bool? isVerified,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    bool? alwaysAvailable,
    bool? manualPause,
    WeeklySchedule? weeklySchedule,
  }) {
    return ArtisanProfile(
      uid: uid,
      profession: profession ?? this.profession,
      experienceYears: experienceYears ?? this.experienceYears,
      aboutText: aboutText ?? this.aboutText,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      certificates: certificates ?? this.certificates,
      workPhotos: workPhotos ?? this.workPhotos,
      isVerified: isVerified ?? this.isVerified,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalRatingSum: totalRatingSum,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      alwaysAvailable: alwaysAvailable ?? this.alwaysAvailable,
      manualPause: manualPause ?? this.manualPause,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      createdAt: createdAt,
    );
  }

  /// Yalnızca puanlama alanlarını günceller (mock'ta Cloud Functions yerine).
  /// Normal [copyWith] bu alanları kasıtlı olarak korur.
  ArtisanProfile copyWithRating({
    required double averageRating,
    required int totalReviews,
    required int totalRatingSum,
  }) {
    return ArtisanProfile(
      uid: uid,
      profession: profession,
      experienceYears: experienceYears,
      aboutText: aboutText,
      serviceAreas: serviceAreas,
      certificates: certificates,
      workPhotos: workPhotos,
      isVerified: isVerified,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalRatingSum: totalRatingSum,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      alwaysAvailable: alwaysAvailable,
      manualPause: manualPause,
      weeklySchedule: weeklySchedule,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'profession': profession,
        'experienceYears': experienceYears,
        'aboutText': aboutText,
        'serviceAreas': serviceAreas.map((e) => e.toMap()).toList(),
        'certificates': certificates,
        'workPhotos': workPhotos,
        'isVerified': isVerified,
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'totalRatingSum': totalRatingSum,
        'isPremium': isPremium,
        'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
        'alwaysAvailable': alwaysAvailable,
        'manualPause': manualPause,
        'weeklySchedule': weeklySchedule.toMap(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ArtisanProfile.fromMap(String uid, Map<String, dynamic> map) {
    return ArtisanProfile(
      uid: uid,
      profession: (map['profession'] as String?) ?? '',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      aboutText: (map['aboutText'] as String?) ?? '',
      serviceAreas: ((map['serviceAreas'] as List?) ?? [])
          .map((e) => ServiceArea.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      certificates: ((map['certificates'] as List?) ?? []).map((e) => e.toString()).toList(),
      workPhotos: ((map['workPhotos'] as List?) ?? []).map((e) => e.toString()).toList(),
      isVerified: (map['isVerified'] as bool?) ?? false,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      totalRatingSum: (map['totalRatingSum'] as num?)?.toInt() ?? 0,
      isPremium: (map['isPremium'] as bool?) ?? false,
      premiumExpiresAt: map['premiumExpiresAt'] != null
          ? DateTime.tryParse(map['premiumExpiresAt'].toString())
          : null,
      alwaysAvailable: (map['alwaysAvailable'] as bool?) ?? false,
      manualPause: (map['manualPause'] as bool?) ?? false,
      weeklySchedule: WeeklySchedule.fromMap(map['weeklySchedule'] as Map?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

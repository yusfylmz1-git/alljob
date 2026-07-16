import 'job.dart' show JobPriceType;

/// Teklif durumu (#4/#7).
enum OfferStatus {
  pending, // müşteri incelemesini bekliyor
  accepted, // müşteri bu teklifi seçti
  rejected, // başka teklif seçildiği için elendi
  withdrawn; // usta teklifi geri çekti

  String get apiValue => name;

  static OfferStatus fromString(String? v) => OfferStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OfferStatus.pending,
      );

  String get labelTR => switch (this) {
        OfferStatus.pending => 'Beklemede',
        OfferStatus.accepted => 'Kabul Edildi',
        OfferStatus.rejected => 'Seçilmedi',
        OfferStatus.withdrawn => 'Geri Çekildi',
      };
}

/// `offers` koleksiyonundaki teklif. Bir usta bir ilana yalnızca 1 kez teklif
/// verebilir (#1) — bu yüzden döküman ID'si deterministiktir:
/// [Offer.idFor] = `"${jobId}__${artisanId}"`.
class Offer {
  const Offer({
    required this.offerId,
    required this.jobId,
    required this.artisanId,
    required this.customerId,
    required this.artisanName,
    required this.professionNameTR,
    required this.experienceYears,
    required this.rating,
    required this.totalReviews,
    required this.isVerified,
    required this.isPremium,
    required this.priceType,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.artisanPhotoUrl,
    this.price,
    this.jobTitle = '',
  });

  final String offerId;
  final String jobId;
  final String jobTitle; // denormalize — ustanın "İlgilendiğim işler" listesi
  final String artisanId;
  final String customerId; // kural + sohbet için

  // Usta özet snapshot (#5) — müşteri teklifleri incelerken görür.
  final String artisanName;
  final String? artisanPhotoUrl;
  final String professionNameTR;
  final int experienceYears;
  final double rating;
  final int totalReviews;
  final bool isVerified;
  final bool isPremium;

  final JobPriceType priceType;
  final double? price; // inspection ise null (#8)
  final String note;

  final OfferStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String idFor(String jobId, String artisanId) => '${jobId}__$artisanId';

  Offer copyWith({
    JobPriceType? priceType,
    double? price,
    String? note,
    OfferStatus? status,
    DateTime? updatedAt,
    double? rating,
    int? totalReviews,
    bool? isVerified,
    bool? isPremium,
  }) {
    return Offer(
      offerId: offerId,
      jobId: jobId,
      jobTitle: jobTitle,
      artisanId: artisanId,
      customerId: customerId,
      artisanName: artisanName,
      artisanPhotoUrl: artisanPhotoUrl,
      professionNameTR: professionNameTR,
      experienceYears: experienceYears,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      priceType: priceType ?? this.priceType,
      price: price ?? this.price,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'jobTitle': jobTitle,
        'artisanId': artisanId,
        'customerId': customerId,
        'artisanName': artisanName,
        'artisanPhotoURL': artisanPhotoUrl,
        'professionNameTR': professionNameTR,
        'experienceYears': experienceYears,
        'rating': rating,
        'totalReviews': totalReviews,
        'isVerified': isVerified,
        'isPremium': isPremium,
        'priceType': priceType.apiValue,
        'price': price,
        'note': note,
        'status': status.apiValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Offer.fromMap(String offerId, Map<String, dynamic> map) {
    return Offer(
      offerId: offerId,
      jobId: (map['jobId'] as String?) ?? '',
      jobTitle: (map['jobTitle'] as String?) ?? '',
      artisanId: (map['artisanId'] as String?) ?? '',
      customerId: (map['customerId'] as String?) ?? '',
      artisanName: (map['artisanName'] as String?) ?? '',
      artisanPhotoUrl: map['artisanPhotoURL'] as String?,
      professionNameTR: (map['professionNameTR'] as String?) ?? '',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      isVerified: (map['isVerified'] as bool?) ?? false,
      isPremium: (map['isPremium'] as bool?) ?? false,
      priceType: JobPriceType.fromString(map['priceType'] as String?),
      price: (map['price'] as num?)?.toDouble(),
      note: (map['note'] as String?) ?? '',
      status: OfferStatus.fromString(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

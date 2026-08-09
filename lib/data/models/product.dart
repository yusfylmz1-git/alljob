/// Keşfet Ürünler — domain model + lifecycle helpers (PRD-006).
library;

import '../../core/constants/app_constants.dart';
import '../../core/utils/search_fold.dart';

/// Ürün yaşam döngüsü durumu (Firestore string).
enum ProductStatus {
  draft,
  pendingReview,
  active,
  paused,
  outOfStock,
  sold,
  removed;

  String get apiValue => switch (this) {
        ProductStatus.draft => 'draft',
        ProductStatus.pendingReview => 'pending_review',
        ProductStatus.active => 'active',
        ProductStatus.paused => 'paused',
        ProductStatus.outOfStock => 'out_of_stock',
        ProductStatus.sold => 'sold',
        ProductStatus.removed => 'removed',
      };

  static ProductStatus fromString(String? v) {
    switch (v) {
      case 'pending_review':
        return ProductStatus.pendingReview;
      case 'active':
        return ProductStatus.active;
      case 'paused':
        return ProductStatus.paused;
      case 'out_of_stock':
        return ProductStatus.outOfStock;
      case 'sold':
        return ProductStatus.sold;
      case 'removed':
        return ProductStatus.removed;
      case 'draft':
      default:
        return ProductStatus.draft;
    }
  }

  String get labelTR => switch (this) {
        ProductStatus.draft => 'Taslak',
        ProductStatus.pendingReview => 'İncelemede',
        ProductStatus.active => 'Yayında',
        ProductStatus.paused => 'Duraklatıldı',
        ProductStatus.outOfStock => 'Stokta yok',
        ProductStatus.sold => 'Satıldı',
        ProductStatus.removed => 'Kaldırıldı',
      };

  /// Keşfet feed'ine aday mı? (ayrıca moderationHidden==false gerekir)
  bool get isDiscoverEligible => this == ProductStatus.active;
}

enum ProductPriceType {
  fixed,
  negotiable,
  from;

  String get apiValue => name;

  static ProductPriceType fromString(String? v) =>
      ProductPriceType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ProductPriceType.negotiable,
      );

  String get labelTR => switch (this) {
        ProductPriceType.fixed => 'Sabit fiyat',
        ProductPriceType.negotiable => 'Görüşülür',
        ProductPriceType.from => 'Başlangıç',
      };
}

enum ProductCondition {
  brandNew,
  likeNew,
  used,
  handmade;

  String get apiValue => switch (this) {
        ProductCondition.brandNew => 'new',
        ProductCondition.likeNew => 'like_new',
        ProductCondition.used => 'used',
        ProductCondition.handmade => 'handmade',
      };

  static ProductCondition fromString(String? v) {
    switch (v) {
      case 'new':
        return ProductCondition.brandNew;
      case 'like_new':
        return ProductCondition.likeNew;
      case 'used':
        return ProductCondition.used;
      case 'handmade':
      default:
        return ProductCondition.handmade;
    }
  }

  String get labelTR => switch (this) {
        ProductCondition.brandNew => 'Sıfır',
        ProductCondition.likeNew => 'Az kullanılmış',
        ProductCondition.used => 'İkinci el',
        ProductCondition.handmade => 'El yapımı',
      };
}

/// Owner client status geçiş allowlist (PRD §4.2.4) — rules ile parite.
bool canOwnerTransition(ProductStatus from, ProductStatus to) {
  if (from == to) {
    return from != ProductStatus.pendingReview;
  }
  return switch (from) {
    ProductStatus.draft =>
      to == ProductStatus.removed,
    ProductStatus.pendingReview => to == ProductStatus.removed,
    ProductStatus.active =>
      to == ProductStatus.paused ||
          to == ProductStatus.outOfStock ||
          to == ProductStatus.sold ||
          to == ProductStatus.removed,
    ProductStatus.paused =>
      to == ProductStatus.active || to == ProductStatus.removed,
    ProductStatus.outOfStock =>
      to == ProductStatus.active || to == ProductStatus.removed,
    ProductStatus.sold => to == ProductStatus.removed,
    ProductStatus.removed => to == ProductStatus.draft,
  };
}

/// Client asla draft/pending → active yazamaz (publish CF).
bool ownerNeverPublishesViaStatus(ProductStatus from, ProductStatus to) {
  if (to != ProductStatus.active) return true;
  return from != ProductStatus.draft && from != ProductStatus.pendingReview;
}

/// Content keys yalnız draft'ta client yazılabilir.
bool contentWritableForStatus(ProductStatus status) =>
    status == ProductStatus.draft;

/// Yayın eligibility (ShopCompletion ile karıştırma).
/// Ürün yayınlanabilir mi?
///
/// ⚠️ 2026-08-10 — "HERKES SATABİLİR" (kullanıcı kararı, Mağaza modülü).
/// Eskiden kapı `canMatchJobs` (meslek + hizmet bölgesi seçili mi) ve
/// `photoOk` istiyordu; ikisi de USTA vitrini kavramıydı. Usta olmayan biri
/// meslek seçmediği için ürün yayınlayamıyordu — bu, karara aykırı.
///
/// Kalan şartlar içeriğin kendisine ve hesabın durumuna bakar:
/// askıya alınmış kullanıcı yayın yapamaz, eksik ürün yayınlanamaz.
/// Bkz. `vault/06-Test/PLAN-Magaza.md` §Aşama 2.
bool canPublishProduct({
  required bool userSuspended,
  required bool fieldsComplete,
}) =>
    !userSuspended && fieldsComplete;

bool productFieldsComplete({
  required String title,
  required String description,
  required String categoryCode,
  required List<String> photos,
  required ProductPriceType priceType,
  required double? priceAmount,
  required String province,
  required ProductCondition condition,
}) {
  final t = title.trim();
  final d = description.trim();
  if (t.length < AppConstants.productTitleMin ||
      t.length > AppConstants.productTitleMax) {
    return false;
  }
  if (d.length < AppConstants.productDescMin ||
      d.length > AppConstants.productDescMax) {
    return false;
  }
  if (categoryCode.trim().isEmpty) return false;
  if (photos.isEmpty || photos.length > AppConstants.maxProductPhotos) {
    return false;
  }
  if (province.trim().isEmpty) return false;
  if (priceType != ProductPriceType.negotiable) {
    if (priceAmount == null || priceAmount <= 0) return false;
  }
  return true;
}

/// Keşfet ürün kaydı.
class Product {
  const Product({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.categoryCode,
    required this.photos,
    required this.priceType,
    required this.condition,
    required this.province,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ownerPhotoUrl,
    this.tags = const [],
    this.priceAmount,
    this.currency = 'TRY',
    this.quantity = 1,
    this.district,
    this.moderationHidden = false,
    this.hiddenByModeration = false,
    this.hiddenByUserSuspend = false,
    this.hiddenByArtisanHide = false,
    this.featured = false,
    this.publishedAt,
    this.soldAt,
    this.removedAt,
    this.removedBy,
    this.removedReason,
    this.reportCount = 0,
    this.viewCount = 0,
    this.moderationNote,
    this.schemaVersion = 1,
  });

  final String id;
  final String ownerUid;
  final String ownerName;
  final String? ownerPhotoUrl;
  final String title;
  final String description;
  final String categoryCode;
  final List<String> tags;
  final List<String> photos;
  final ProductPriceType priceType;
  final double? priceAmount;
  final String currency;
  final ProductCondition condition;
  final int quantity;
  final String province;
  final String? district;
  final ProductStatus status;
  final bool moderationHidden;
  final bool hiddenByModeration;
  final bool hiddenByUserSuspend;
  final bool hiddenByArtisanHide;
  final bool featured;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? soldAt;
  final DateTime? removedAt;
  final String? removedBy;
  final String? removedReason;
  final int reportCount;
  final int viewCount;
  final String? moderationNote;
  final int schemaVersion;

  bool get isLiveInDiscover =>
      status.isDiscoverEligible && !moderationHidden;

  bool get isOwnerRestorable =>
      status == ProductStatus.removed && removedBy == 'owner';

  String get placeLabel {
    final d = district?.trim();
    if (d != null && d.isNotEmpty) return '$province / $d';
    return province;
  }

  String get priceLabel {
    if (priceType == ProductPriceType.negotiable || priceAmount == null) {
      return 'Fiyat görüşülür';
    }
    final n = priceAmount!.round();
    final s = '$n ₺';
    return priceType == ProductPriceType.from ? '$s\'den' : s;
  }

  String? get coverPhoto => photos.isEmpty ? null : photos.first;

  /// Client create/update payload — moderation/server alanları YOK.
  Map<String, dynamic> toMap({bool includeLifecycle = true}) {
    final map = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'ownerPhotoURL': ownerPhotoUrl,
      'title': title,
      'titleFold': foldTrSearch(title),
      'description': description,
      'categoryCode': categoryCode,
      'tags': tags,
      'tagsFold': tags.map(foldTrSearch).toList(),
      'photos': photos,
      'priceType': priceType.apiValue,
      'priceAmount': priceAmount,
      'currency': currency,
      'condition': condition.apiValue,
      'quantity': quantity,
      'province': province,
      'district': district,
      'status': status.apiValue,
      'moderationHidden': false, // create only; update should not flip via toMap
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (includeLifecycle) {
      if (soldAt != null) map['soldAt'] = soldAt!.toIso8601String();
      if (removedAt != null) map['removedAt'] = removedAt!.toIso8601String();
      if (removedBy != null) map['removedBy'] = removedBy;
      if (removedReason != null) map['removedReason'] = removedReason;
    }
    return map;
  }

  /// Safe+lifecycle client patch (content excluded when off-draft).
  Map<String, dynamic> toClientUpdateMap({
    required ProductStatus previousStatus,
  }) {
    final map = <String, dynamic>{
      'ownerName': ownerName,
      'ownerPhotoURL': ownerPhotoUrl,
      'priceType': priceType.apiValue,
      'priceAmount': priceAmount,
      'currency': currency,
      'quantity': quantity,
      'tags': tags,
      'tagsFold': tags.map(foldTrSearch).toList(),
      'condition': condition.apiValue,
      'province': province,
      'district': district,
      'status': status.apiValue,
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (contentWritableForStatus(previousStatus) &&
        contentWritableForStatus(status)) {
      map['title'] = title;
      map['titleFold'] = foldTrSearch(title);
      map['description'] = description;
      map['categoryCode'] = categoryCode;
      map['photos'] = photos;
    }
    if (status == ProductStatus.sold && soldAt != null) {
      map['soldAt'] = soldAt!.toIso8601String();
    }
    if (status == ProductStatus.removed) {
      map['removedAt'] =
          (removedAt ?? updatedAt).toIso8601String();
      map['removedBy'] = removedBy ?? 'owner';
      if (removedReason != null) map['removedReason'] = removedReason;
    }
    if (status == ProductStatus.draft &&
        previousStatus == ProductStatus.removed) {
      map['removedAt'] = null;
      map['removedBy'] = null;
      map['removedReason'] = null;
    }
    return map;
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      ownerUid: (map['ownerUid'] as String?) ?? '',
      ownerName: (map['ownerName'] as String?) ?? '',
      ownerPhotoUrl: map['ownerPhotoURL'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      categoryCode: (map['categoryCode'] as String?) ?? '',
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      photos: (map['photos'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      priceType: ProductPriceType.fromString(map['priceType'] as String?),
      priceAmount: (map['priceAmount'] as num?)?.toDouble(),
      currency: (map['currency'] as String?) ?? 'TRY',
      condition: ProductCondition.fromString(map['condition'] as String?),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      province: (map['province'] as String?) ?? '',
      district: map['district'] as String?,
      status: ProductStatus.fromString(map['status'] as String?),
      moderationHidden: map['moderationHidden'] == true,
      hiddenByModeration: map['hiddenByModeration'] == true,
      hiddenByUserSuspend: map['hiddenByUserSuspend'] == true,
      hiddenByArtisanHide: map['hiddenByArtisanHide'] == true,
      featured: map['featured'] == true,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      publishedAt: DateTime.tryParse(map['publishedAt']?.toString() ?? ''),
      soldAt: DateTime.tryParse(map['soldAt']?.toString() ?? ''),
      removedAt: DateTime.tryParse(map['removedAt']?.toString() ?? ''),
      removedBy: map['removedBy'] as String?,
      removedReason: map['removedReason'] as String?,
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      moderationNote: map['moderationNote'] as String? ??
          map['adminModerationNote'] as String?,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Product copyWith({
    String? title,
    String? description,
    String? categoryCode,
    List<String>? tags,
    List<String>? photos,
    ProductPriceType? priceType,
    double? priceAmount,
    bool clearPriceAmount = false,
    ProductCondition? condition,
    int? quantity,
    String? province,
    String? district,
    ProductStatus? status,
    DateTime? updatedAt,
    DateTime? soldAt,
    DateTime? removedAt,
    String? removedBy,
    String? removedReason,
    String? ownerName,
    String? ownerPhotoUrl,
  }) {
    return Product(
      id: id,
      ownerUid: ownerUid,
      ownerName: ownerName ?? this.ownerName,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryCode: categoryCode ?? this.categoryCode,
      tags: tags ?? this.tags,
      photos: photos ?? this.photos,
      priceType: priceType ?? this.priceType,
      priceAmount:
          clearPriceAmount ? null : (priceAmount ?? this.priceAmount),
      currency: currency,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      province: province ?? this.province,
      district: district ?? this.district,
      status: status ?? this.status,
      moderationHidden: moderationHidden,
      hiddenByModeration: hiddenByModeration,
      hiddenByUserSuspend: hiddenByUserSuspend,
      hiddenByArtisanHide: hiddenByArtisanHide,
      featured: featured,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt,
      soldAt: soldAt ?? this.soldAt,
      removedAt: removedAt ?? this.removedAt,
      removedBy: removedBy ?? this.removedBy,
      removedReason: removedReason ?? this.removedReason,
      reportCount: reportCount,
      viewCount: viewCount,
      moderationNote: moderationNote,
      schemaVersion: schemaVersion,
    );
  }
}

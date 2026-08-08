/// `favorites` koleksiyonundaki takip kaydı — **herkes herkesi takip eder**
/// (Instagram gibi). Döküman ID'si deterministiktir: [Favorite.idFor] =
/// `"${customerUid}__${artisanUid}"`.
///
/// > ⚠️ **Alan adları tarihsel.** Başlangıçta takip yalnız müşteri → usta
/// > yönlüydü; 2026-08-08'de herkese açıldı. Firestore alan adları
/// > (`customerUid`, `artisanUid`) **bilerek DEĞİŞTİRİLMEDİ** — yeniden
/// > adlandırmak veri göçü olurdu (CLAUDE.md kural 6 mantığı). Yeni anlam:
/// >
/// > | Alan | Yeni anlam |
/// > |---|---|
/// > | `customerUid` | **takip EDEN** ([followerUid]) |
/// > | `artisanUid` | **takip EDİLEN** ([followedUid]) |
///
/// Yeni kod [followerUid] / [followedUid] takma adlarını kullanmalıdır.
///
/// İki yönde de liste hızlı görünsün diye çift taraflı snapshot taşır:
/// takip edilenin bilgisi "Takip Ettiklerim" listesi için, takip edenin
/// bilgisi "Takipçilerim" için. Eski kayıtlar bazı alanları taşımayabilir →
/// okuma tarafı boş adı `users` dökümanından tamamlar.
class Favorite {
  const Favorite({
    required this.customerUid,
    required this.artisanUid,
    required this.artisanName,
    required this.createdAt,
    // Usta-özel alanlar: takip edilen usta DEĞİLSE anlamsızdır, boş kalır.
    // (Herkes herkesi takip edebiliyor — 2026-08-08.) UI `hasArtisanInfo`
    // ile kontrol eder; boşken meslek/puan satırı çizilmez.
    this.professionNameTR = '',
    this.rating = 0,
    this.totalReviews = 0,
    this.photoUrl,
    this.customerName = '',
    this.customerPhotoUrl,
  });

  final String customerUid;
  final String artisanUid;

  /// Takip EDEN kullanıcı. (`customerUid` alanının yeni adı — bkz. sınıf notu.)
  String get followerUid => customerUid;

  /// Takip EDİLEN kullanıcı. (`artisanUid` alanının yeni adı.)
  String get followedUid => artisanUid;

  // Takip edilenin snapshot'ı — "Takip Ettiklerim" listesi hızlı görünsün diye.
  final String artisanName;
  final String professionNameTR;
  final double rating;
  final int totalReviews;
  final String? photoUrl;

  /// Takip edilenin görünen adı. (`artisanName` alanının yeni adı.)
  String get followedName => artisanName;

  /// Takip edilen kişinin usta vitrini var mı? Yoksa meslek/puan satırı
  /// çizilmez (sıradan kullanıcı takibi).
  bool get hasArtisanInfo =>
      professionNameTR.trim().isNotEmpty || totalReviews > 0;

  // Takip edenin snapshot'ı — "Takipçilerim" listesi hızlı görünsün diye.
  final String customerName;
  final String? customerPhotoUrl;

  /// Takip edenin görünen adı. (`customerName` alanının yeni adı.)
  String get followerName => customerName;

  final DateTime createdAt;

  static String idFor(String customerUid, String artisanUid) =>
      '${customerUid}__$artisanUid';

  String get id => idFor(customerUid, artisanUid);

  Favorite copyWith({String? customerName, String? customerPhotoUrl}) =>
      Favorite(
        customerUid: customerUid,
        artisanUid: artisanUid,
        artisanName: artisanName,
        professionNameTR: professionNameTR,
        rating: rating,
        totalReviews: totalReviews,
        photoUrl: photoUrl,
        customerName: customerName ?? this.customerName,
        customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'customerUid': customerUid,
        'artisanUid': artisanUid,
        'artisanName': artisanName,
        'professionNameTR': professionNameTR,
        'rating': rating,
        'totalReviews': totalReviews,
        'photoURL': photoUrl,
        'customerName': customerName,
        'customerPhotoURL': customerPhotoUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Favorite.fromMap(String id, Map<String, dynamic> map) {
    return Favorite(
      customerUid: (map['customerUid'] as String?) ?? '',
      artisanUid: (map['artisanUid'] as String?) ?? '',
      artisanName: (map['artisanName'] as String?) ?? '',
      professionNameTR: (map['professionNameTR'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      photoUrl: map['photoURL'] as String?,
      customerName: (map['customerName'] as String?) ?? '',
      customerPhotoUrl: map['customerPhotoURL'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

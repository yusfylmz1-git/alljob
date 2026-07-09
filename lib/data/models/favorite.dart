/// `favorites` koleksiyonundaki takip kaydı (#14): müşteri → usta yönlü
/// ("Takip Et"). Döküman ID'si deterministiktir: [Favorite.idFor] =
/// `"${customerUid}__${artisanUid}"`.
///
/// İki yönde de liste hızlı görünsün diye çift taraflı snapshot taşır:
/// usta bilgisi müşterinin "Takip Ettiklerim" listesi için, müşteri bilgisi
/// ustanın "Sizi Takip Edenler" bölümü için (bildirim ekranı). Eski kayıtlar
/// müşteri alanlarını taşımayabilir → okuma tarafı boş adı `users`
/// dökümanından tamamlar.
class Favorite {
  const Favorite({
    required this.customerUid,
    required this.artisanUid,
    required this.artisanName,
    required this.professionNameTR,
    required this.rating,
    required this.totalReviews,
    required this.createdAt,
    this.photoUrl,
    this.customerName = '',
    this.customerPhotoUrl,
  });

  final String customerUid;
  final String artisanUid;

  // Usta snapshot'ı — müşterinin listesi hızlı görünsün diye.
  final String artisanName;
  final String professionNameTR;
  final double rating;
  final int totalReviews;
  final String? photoUrl;

  // Müşteri snapshot'ı — ustanın takipçi listesi hızlı görünsün diye.
  final String customerName;
  final String? customerPhotoUrl;

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

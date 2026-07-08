/// `favorites` koleksiyonundaki favori usta kaydı (#14). Döküman ID'si
/// deterministiktir: [Favorite.idFor] = `"${customerUid}__${artisanUid}"`.
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
  });

  final String customerUid;
  final String artisanUid;

  // Liste hızlı görünsün diye snapshot.
  final String artisanName;
  final String professionNameTR;
  final double rating;
  final int totalReviews;
  final String? photoUrl;

  final DateTime createdAt;

  static String idFor(String customerUid, String artisanUid) =>
      '${customerUid}__$artisanUid';

  String get id => idFor(customerUid, artisanUid);

  Map<String, dynamic> toMap() => {
        'customerUid': customerUid,
        'artisanUid': artisanUid,
        'artisanName': artisanName,
        'professionNameTR': professionNameTR,
        'rating': rating,
        'totalReviews': totalReviews,
        'photoURL': photoUrl,
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
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

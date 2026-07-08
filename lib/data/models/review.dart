/// İş sonu değerlendirmesinde seçilebilen hazır etiketler (PRD §3).
/// Serbest metin yorum yoktur; müşteri yalnızca yıldız + bu etiketleri seçer.
class ReviewTags {
  ReviewTags._();

  static const List<String> positive = [
    'Temiz işçilik',
    'Zamanında geldi',
    'Profesyonel',
    'Güler yüzlü',
    'Hızlı çözüm',
    'Kaliteli işçilik',
    'Güvenilir',
    'Uygun fiyat',
  ];

  static const List<String> negative = [
    'Geç geldi',
    'Kötü işçilik',
    'Eksik iş yaptı',
    'İletişimi zayıf',
    'Pahalı',
    'Randevuya gelmedi',
    'Sorun çözülmedi',
    'Tavsiye etmiyorum',
  ];

  static bool isNegative(String tag) => negative.contains(tag);
}

/// `reviews` koleksiyonundaki değerlendirme dökümanı (PRD Ekran H, §3).
/// Yalnızca 1–5 yıldız + hazır olumlu/olumsuz etiketler içerir (serbest metin yok).
class Review {
  const Review({
    required this.id,
    required this.artisanUid,
    required this.customerUid,
    required this.customerDisplayName,
    required this.chatId,
    required this.rating,
    required this.tags,
    required this.createdAt,
  });

  final String id;
  final String artisanUid;
  final String customerUid;
  final String customerDisplayName;
  final String chatId;
  final int rating; // 1..5
  final List<String> tags; // hazır etiketler (ReviewTags)
  final DateTime createdAt;

  /// Gizlilik için maskelenmiş ad: "Ahmet Yılmaz" -> "A***".
  String get maskedName {
    final trimmed = customerDisplayName.trim();
    if (trimmed.isEmpty) return 'A***';
    return '${trimmed.substring(0, 1)}***';
  }

  Map<String, dynamic> toMap() => {
        'artisanUID': artisanUid,
        'customerUID': customerUid,
        'customerDisplayName': customerDisplayName,
        'chatId': chatId,
        'rating': rating,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
        id: id,
        artisanUid: (m['artisanUID'] as String?) ?? '',
        customerUid: (m['customerUID'] as String?) ?? '',
        customerDisplayName: (m['customerDisplayName'] as String?) ?? '',
        chatId: (m['chatId'] as String?) ?? '',
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        tags: ((m['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

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

/// Değerlendirmenin yönü.
///
/// Yön artık yalnızca "kim kimi puanladı" bilgisidir; GÖRÜNÜRLÜK ayrımı
/// yapmaz — 2026-08-08'den beri müşteri profilinde de puan herkese açıktır.
enum ReviewDirection {
  /// Müşteri → usta.
  customerToArtisan,

  /// Usta → müşteri.
  artisanToCustomer;

  String get suffix => switch (this) {
        ReviewDirection.customerToArtisan => 'c2a',
        ReviewDirection.artisanToCustomer => 'a2c',
      };

  String get apiValue => suffix;

  /// Eksik alan = ESKİ kayıt: çift yönlü şemadan önce yalnız müşteri→usta
  /// değerlendirmesi vardı.
  static ReviewDirection fromString(String? v) =>
      v == 'a2c' ? artisanToCustomer : customerToArtisan;

  /// `reviews` doküman kimliği. Eski (yönsüz) kayıtlar düz `chatId` taşır;
  /// onlar [customerToArtisan] sayılır.
  ///
  /// YENİ kayıtlar bunu kullanmaz — bkz. [reviewDocId].
  static String docIdFor(String chatId, ReviewDirection dir) =>
      dir == customerToArtisan ? chatId : '${chatId}__${dir.suffix}';
}

/// Bir değerlendirmenin doküman kimliği — KİŞİ ÇİFTİNE bağlı (2026-08-08).
///
/// `rev_{yazan}__{hedef}`
///
/// Kimlik deterministik olduğu için **bir kişi bir kişiyi yalnızca bir kez**
/// değerlendirebilir: ikinci gönderim aynı dokümanın üzerine yazar, yani
/// otomatik olarak GÜNCELLEME olur. Sunucu tarafında ayrıca bir "daha önce
/// yazmış mı" sorgusu gerekmez; kimliğin kendisi kısıtı taşır.
///
/// Eskiden kimlik `chatId` tabanlıydı ve sohbet ilan bazlı olduğu için aynı
/// çift her iş için ayrı puan verebiliyordu. Sohbet kişi bazlına dönünce
/// (bkz. `FirebaseChatRepository.chatIdFor`) o dayanak kalktı; kimlik artık
/// doğrudan çifti anlatıyor.
///
/// ESKİ `chat_*` kimlikli kayıtlar Firestore'da durmaya devam eder ve
/// okunur — yalnız yeni yazımlar bu biçimi alır.
String reviewDocId({required String authorUid, required String targetUid}) =>
    'rev_${authorUid}__$targetUid';

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
    this.direction = ReviewDirection.customerToArtisan,
  });

  final String id;
  final String artisanUid;
  final String customerUid;
  final String customerDisplayName;
  final String chatId;
  final int rating; // 1..5
  final List<String> tags; // hazır etiketler (ReviewTags)
  final DateTime createdAt;

  /// Kimin kimi puanladığı. Eski kayıtlarda alan yoktur → müşteri→usta.
  final ReviewDirection direction;

  /// Yazanın görünen adı — YÖNDEN BAĞIMSIZ.
  ///
  /// Alan adı (`customerDisplayName`) şemadan miras: a2c kayıtlarında bile
  /// kaydı YAZAN tarafın adını taşır. Yeniden adlandırmak veri göçüdür
  /// (CLAUDE.md kural 6), o yüzden anlamı burada okunur kılınıyor.
  String get authorDisplayName => customerDisplayName;

  /// Puanı ALAN taraf.
  String get targetUid => direction == ReviewDirection.customerToArtisan
      ? artisanUid
      : customerUid;

  /// Puanı VEREN taraf.
  String get authorUid => direction == ReviewDirection.customerToArtisan
      ? customerUid
      : artisanUid;

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
        'direction': direction.apiValue,
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
        direction: ReviewDirection.fromString(m['direction'] as String?),
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Sohbet mesajı (PRD Ekran E). Metin ve/veya fotoğraf içerebilir.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderUid,
    required this.createdAt,
    this.text,
    this.imageHandle,
    this.deleted = false,
  });

  final String id;
  final String chatId;
  final String senderUid;
  final String? text;
  final String? imageHandle;
  final DateTime createdAt;

  /// Gönderen mesajı sildi (yumuşak silme): içerik kaldırılır, yerinde
  /// "Bu mesaj silindi" gösterilir (WhatsApp modeli).
  final bool deleted;

  bool get hasImage => imageHandle != null && !deleted;

  /// Sohbet listesi önizlemesinde silinen mesaj için gösterilen metin.
  static const deletedPreview = 'Bu mesaj silindi';
}

/// İki kullanıcı (müşteri + usta) arasındaki sohbet başlığı/özeti.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.customerUid,
    required this.artisanUid,
    required this.customerName,
    required this.artisanName,
    required this.updatedAt,
    this.createdAt,
    this.lastMessage,
    this.artisanPhotoUrl,
    this.customerPhotoUrl,
  });

  final String id;
  final String customerUid;
  final String artisanUid;
  final String customerName;
  final String artisanName;
  final String? lastMessage;
  final DateTime updatedAt;

  /// Sohbet açılış anı (H6 kilit). Yoksa [updatedAt] kullanılır.
  final DateTime? createdAt;
  final String? artisanPhotoUrl;
  final String? customerPhotoUrl;

  DateTime get openedAt => createdAt ?? updatedAt;

  bool involves(String uid) => uid == customerUid || uid == artisanUid;

  /// Karşı tarafın uid'i — verilen kullanıcıya göre.
  String otherUid(String myUid) => myUid == customerUid ? artisanUid : customerUid;

  /// Karşı tarafın adı — verilen kullanıcıya göre.
  String otherName(String myUid) => myUid == customerUid ? artisanName : customerName;

  String? otherPhoto(String myUid) =>
      myUid == customerUid ? artisanPhotoUrl : customerPhotoUrl;
}

/// Denormalize sohbet okunmamış sayacı (`users/{uid}/private/chatMeta`).
/// Alt bar / menü rozeti tüm thread listesini dinlemeden bu dökümanı izler.
class ChatUnreadMeta {
  const ChatUnreadMeta({
    this.total = 0,
    this.customer = 0,
    this.artisan = 0,
  });

  static const zero = ChatUnreadMeta();

  /// Toplam okunmamış (müşteri + usta tarafı).
  final int total;

  /// Kullanıcının müşteri olduğu sohbetlerdeki okunmamış.
  final int customer;

  /// Kullanıcının usta olduğu sohbetlerdeki okunmamış.
  final int artisan;

  factory ChatUnreadMeta.fromMap(Map<String, dynamic>? map) {
    if (map == null) return zero;
    int i(String k) {
      final v = map[k];
      if (v is int) return v < 0 ? 0 : v;
      if (v is num) return v.toInt().clamp(0, 1 << 30);
      return 0;
    }

    final customer = i('unreadCustomer');
    final artisan = i('unreadArtisan');
    final totalRaw = i('unreadTotal');
    // Tutarlılık: taraflar toplamı varsa onu tercih et.
    final sides = customer + artisan;
    final total = sides > 0 ? sides : totalRaw;
    return ChatUnreadMeta(total: total, customer: customer, artisan: artisan);
  }

  Map<String, dynamic> toMap() => {
        'unreadTotal': total,
        'unreadCustomer': customer,
        'unreadArtisan': artisan,
      };
}

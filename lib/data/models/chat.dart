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

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
    this.moderationHidden = false,
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

  /// Yönetici şikayet üzerine mesajı kaldırdı. [deleted]'DAN AYRIDIR:
  /// gönderenin kendi silmesi değildir, iki tarafta da farklı metin görünür
  /// ve gönderen bunu geri alamaz. Yalnız CF (`adminModerateMessage`) yazar;
  /// eksik alan = görünür (eski mesajlarla uyum).
  final bool moderationHidden;

  /// İçerik gösterilmeli mi? Silinmiş VEYA yönetici tarafından kaldırılmışsa
  /// metin/foto GÖSTERİLMEZ — tek kapı, her iki durumu da kapsar.
  bool get isRedacted => deleted || moderationHidden;

  bool get hasImage => imageHandle != null && !isRedacted;

  /// Sohbet listesi önizlemesinde silinen mesaj için gösterilen metin.
  static const deletedPreview = 'Bu mesaj silindi';

  /// Yönetici kaldırdığında gösterilen metin (kullanıcı silmesinden AYRI:
  /// karşı taraf "gönderen sildi" sanmasın).
  static const moderatedPreview = 'Bu mesaj yönetici tarafından kaldırıldı';

  /// Mesajın yerinde gösterilecek açıklama; içerik görünüyorsa null.
  String? get redactedLabel => moderationHidden
      ? moderatedPreview
      : deleted
          ? deletedPreview
          : null;
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
    this.lastMessageSenderUid,
    this.archivedBy = const {},
    this.pinnedBy = const {},
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

  /// Son mesajı kim yazdı? Okundu/iletildi tiki yalnız KENDİ mesajımızda
  /// gösterilir (WhatsApp davranışı); null ise tik çizilmez.
  final String? lastMessageSenderUid;

  /// Sohbeti arşivleyen kullanıcılar. Arşiv KİŞİSELDİR: karşı taraf
  /// etkilenmez, yeni mesaj gelince sohbet arşivden kendiliğinden çıkar.
  final Set<String> archivedBy;

  /// Sohbeti listenin başına sabitleyen kullanıcılar (kişisel).
  final Set<String> pinnedBy;

  bool isArchivedFor(String uid) => archivedBy.contains(uid);

  bool isPinnedFor(String uid) => pinnedBy.contains(uid);

  DateTime get openedAt => createdAt ?? updatedAt;

  bool involves(String uid) => uid == customerUid || uid == artisanUid;

  /// Karşı tarafın uid'i — verilen kullanıcıya göre.
  String otherUid(String myUid) => myUid == customerUid ? artisanUid : customerUid;

  /// Karşı tarafın adı — verilen kullanıcıya göre.
  String otherName(String myUid) => myUid == customerUid ? artisanName : customerName;

  String? otherPhoto(String myUid) =>
      myUid == customerUid ? artisanPhotoUrl : customerPhotoUrl;

  ChatThread copyWith({
    String? lastMessage,
    DateTime? updatedAt,
    String? lastMessageSenderUid,
    Set<String>? archivedBy,
    Set<String>? pinnedBy,
  }) =>
      ChatThread(
        id: id,
        customerUid: customerUid,
        artisanUid: artisanUid,
        customerName: customerName,
        artisanName: artisanName,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt,
        lastMessage: lastMessage ?? this.lastMessage,
        artisanPhotoUrl: artisanPhotoUrl,
        customerPhotoUrl: customerPhotoUrl,
        lastMessageSenderUid: lastMessageSenderUid ?? this.lastMessageSenderUid,
        archivedBy: archivedBy ?? this.archivedBy,
        pinnedBy: pinnedBy ?? this.pinnedBy,
      );
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

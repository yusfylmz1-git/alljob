import 'dart:async';

import '../../../core/utils/contact_masker.dart';
import '../../../data/models/chat.dart';

/// Sohbet verisi soyutlaması (PRD Ekran E). Mock ile gerçek-zamanlı davranışı
/// (stream) taklit eder; Firebase gelince Firestore/RTDB ile değişir.
abstract interface class ChatRepository {
  /// Kullanıcının (müşteri veya usta) sohbet listesi — canlı akış.
  Stream<List<ChatThread>> watchThreads(String uid);

  /// Bir sohbetin mesajları — canlı akış.
  Stream<List<ChatMessage>> watchMessages(String chatId);

  ChatThread? getThread(String chatId);

  /// Müşteri ile usta arasında sohbet geçmişi var mı? Değerlendirme yalnızca
  /// sohbet geçmişi olan müşterilere açıktır (PRD §5, Ekran F).
  bool hasChatBetween({required String customerUid, required String artisanUid});

  /// Sohbeti [uid] için okundu işaretler (o ana kadarki mesajlar).
  void markRead({required String chatId, required String uid});

  /// [uid] için okunmamış mesaj sayısı (karşı taraftan gelen, henüz görülmemiş).
  int unreadCount({required String chatId, required String uid});

  /// [uid]'in bu sohbeti en son okuduğu an (okundu bilgisi için). Yoksa null.
  DateTime? lastReadAt({required String chatId, required String uid});

  /// Sohbeti başlatır (varsa mevcut olanı döner). chatId döner.
  String startChat({
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
  });

  /// Mesaj gönderir. İletişim bilgileri otomatik maskelenir (PRD §5).
  /// Maskeleme uygulandıysa (metin değiştiyse) true döner — UI uyarı gösterir.
  Future<bool> sendMessage({
    required String chatId,
    required String senderUid,
    String? text,
    String? imageHandle,
  });

  /// [senderUid], KENDİ mesajını siler (yumuşak silme): içerik kaldırılır,
  /// yerinde "Bu mesaj silindi" görünür. Silinen mesaj son mesajsa sohbet
  /// listesi önizlemesi de güncellenir.
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String senderUid,
  });
}

/// Bellek içi, gerçek-zamanlı taklit eden uygulama.
class MockChatRepository implements ChatRepository {
  final Map<String, ChatThread> _threads = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, StreamController<List<ChatMessage>>> _msgControllers = {};
  final StreamController<void> _threadsTick = StreamController<void>.broadcast();

  /// chatId → (uid → en son okuma anı). Okunmamış sayısı ve okundu bilgisi için.
  final Map<String, Map<String, DateTime>> _lastRead = {};

  int _seq = 0;

  static String chatIdFor(String customerUid, String artisanUid) =>
      'chat_${customerUid}__$artisanUid';

  StreamController<List<ChatMessage>> _ctrl(String chatId) =>
      _msgControllers.putIfAbsent(
          chatId, () => StreamController<List<ChatMessage>>.broadcast());

  @override
  Stream<List<ChatThread>> watchThreads(String uid) async* {
    yield _threadsFor(uid);
    yield* _threadsTick.stream.map((_) => _threadsFor(uid));
  }

  List<ChatThread> _threadsFor(String uid) {
    final list = _threads.values.where((t) => t.involves(uid)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) async* {
    yield List.unmodifiable(_messages[chatId] ?? const []);
    yield* _ctrl(chatId).stream;
  }

  @override
  ChatThread? getThread(String chatId) => _threads[chatId];

  @override
  bool hasChatBetween({
    required String customerUid,
    required String artisanUid,
  }) =>
      _threads.containsKey(chatIdFor(customerUid, artisanUid));

  @override
  void markRead({required String chatId, required String uid}) {
    _lastRead.putIfAbsent(chatId, () => {})[uid] = DateTime.now();
    // Mesaj akışını yeniden yay → gönderende okundu bilgisi tazelensin.
    final list = _messages[chatId];
    if (list != null) _ctrl(chatId).add(List.unmodifiable(list));
    _threadsTick.add(null); // Liste rozetleri güncellensin.
  }

  @override
  int unreadCount({required String chatId, required String uid}) {
    final list = _messages[chatId];
    if (list == null) return 0;
    final since = _lastRead[chatId]?[uid];
    return list
        .where((m) =>
            m.senderUid != uid &&
            (since == null || m.createdAt.isAfter(since)))
        .length;
  }

  @override
  DateTime? lastReadAt({required String chatId, required String uid}) =>
      _lastRead[chatId]?[uid];

  @override
  String startChat({
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
  }) {
    final id = chatIdFor(customerUid, artisanUid);
    _threads.putIfAbsent(
      id,
      () => ChatThread(
        id: id,
        customerUid: customerUid,
        artisanUid: artisanUid,
        customerName: customerName,
        artisanName: artisanName,
        customerPhotoUrl: customerPhotoUrl,
        artisanPhotoUrl: artisanPhotoUrl,
        updatedAt: DateTime.now(),
      ),
    );
    _threadsTick.add(null);
    return id;
  }

  @override
  Future<bool> sendMessage({
    required String chatId,
    required String senderUid,
    String? text,
    String? imageHandle,
  }) async {
    final masked = text == null ? null : ContactMasker.mask(text);
    final wasMasked = text != null && masked != text;

    final msg = ChatMessage(
      id: 'msg_${_seq++}',
      chatId: chatId,
      senderUid: senderUid,
      text: masked,
      imageHandle: imageHandle,
      createdAt: DateTime.now(),
    );

    final list = _messages.putIfAbsent(chatId, () => []);
    list.add(msg);
    _ctrl(chatId).add(List.unmodifiable(list));

    // Başlık özetini güncelle.
    final t = _threads[chatId];
    if (t != null) {
      _threads[chatId] = ChatThread(
        id: t.id,
        customerUid: t.customerUid,
        artisanUid: t.artisanUid,
        customerName: t.customerName,
        artisanName: t.artisanName,
        customerPhotoUrl: t.customerPhotoUrl,
        artisanPhotoUrl: t.artisanPhotoUrl,
        updatedAt: msg.createdAt,
        lastMessage: imageHandle != null ? '📷 Fotoğraf' : masked,
      );
      _threadsTick.add(null);
    }
    return wasMasked;
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String senderUid,
  }) async {
    final list = _messages[chatId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i < 0 || list[i].senderUid != senderUid) return;
    list[i] = ChatMessage(
      id: list[i].id,
      chatId: chatId,
      senderUid: senderUid,
      createdAt: list[i].createdAt,
      deleted: true,
    );
    _ctrl(chatId).add(List.unmodifiable(list));

    // Silinen son mesajsa liste önizlemesini de değiştir.
    final t = _threads[chatId];
    if (t != null && i == list.length - 1) {
      _threads[chatId] = ChatThread(
        id: t.id,
        customerUid: t.customerUid,
        artisanUid: t.artisanUid,
        customerName: t.customerName,
        artisanName: t.artisanName,
        customerPhotoUrl: t.customerPhotoUrl,
        artisanPhotoUrl: t.artisanPhotoUrl,
        updatedAt: t.updatedAt,
        lastMessage: ChatMessage.deletedPreview,
      );
      _threadsTick.add(null);
    }
  }

  void dispose() {
    for (final c in _msgControllers.values) {
      c.close();
    }
    _threadsTick.close();
  }
}

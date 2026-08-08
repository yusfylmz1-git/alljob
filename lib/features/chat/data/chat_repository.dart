import 'dart:async';

import '../../../data/models/chat.dart';

/// Sohbet verisi soyutlaması (PRD Ekran E). Mock ile gerçek-zamanlı davranışı
/// (stream) taklit eder; Firebase gelince Firestore/RTDB ile değişir.
abstract interface class ChatRepository {
  /// Kullanıcının (müşteri veya usta) sohbet listesi — canlı akış.
  Stream<List<ChatThread>> watchThreads(String uid);

  /// Bir sohbetin mesajları — canlı akış.
  /// Sohbet dökümanı yoksa/erişim yoksa stream hata vermez; hazır olunca
  /// dinlemeye başlar (UI "Bir sorun oluştu"ya kilitlenmesin).
  Stream<List<ChatMessage>> watchMessages(String chatId);

  ChatThread? getThread(String chatId);

  /// Müşteri ile usta arasında sohbet geçmişi var mı? Değerlendirme yalnızca
  /// sohbet geçmişi olan müşterilere açıktır (PRD §5, Ekran F).
  /// Bir çiftin TEK sohbeti vardır (kimlik ilandan türemez), bu yüzden ilan
  /// bilgisi sormaya gerek yoktur.
  ///
  /// DİKKAT: yalnız BELLEKTEKİ sohbetlere bakar (liste akışı bir kez
  /// çalışmışsa dolu olur). Sohbet listesine hiç girilmeden bu soruya cevap
  /// gerekiyorsa [fetchThread] kullanın — o sunucuya gider.
  bool hasChatBetween({
    required String customerUid,
    required String artisanUid,
  });

  /// Sohbeti SUNUCUDAN okur (bellekte yoksa da bulur).
  ///
  /// Değerlendirme ekranı gibi doğrudan derin bağlantıyla açılan yerlerde
  /// gereklidir: orada `watchThreads` hiç çalışmamış olabilir, bellek boştur
  /// ve [getThread]/[hasChatBetween] yanlışlıkla "sohbet yok" der.
  Future<ChatThread?> fetchThread(String chatId);

  /// Tek sohbeti CANLI izler (yoksa null yayar).
  ///
  /// [getThread]'in reaktif karşılığı: `customerStarted` / `lockedAt` gibi
  /// alanlar sunucuda değişince ekran kendiliğinden tazelenir. Sohbet ekranı
  /// ve ilan detayı bunu kullanır — bellek önbelleğine güvenmek, listeye hiç
  /// girilmeyen akışlarda sessizce yanlış durum gösteriyordu.
  Stream<ChatThread?> watchThread(String chatId);

  /// Sohbeti [uid] için okundu işaretler (o ana kadarki mesajlar).
  void markRead({required String chatId, required String uid});

  /// [uid] için okunmamış mesaj sayısı (karşı taraftan gelen, henüz görülmemiş).
  int unreadCount({required String chatId, required String uid});

  /// [uid]'in bu sohbeti en son okuduğu an (okundu bilgisi için). Yoksa null.
  DateTime? lastReadAt({required String chatId, required String uid});

  /// Sohbeti başlatır / var olanı hazırlar. Firestore'da döküman **hazır**
  /// olunca chatId döner. Navigasyondan önce `await` edilmeli.
  ///
  /// Bir çiftin TEK odası vardır: aynı kişiyle kaç ilan konuşulursa konuşulsun
  /// sohbet aynı yerde devam eder. [jobId]/[jobTitle] yalnızca **bağlam**
  /// olarak yazılır (sohbet başlığındaki ilan rozeti) — kimliğe girmez.
  Future<String> startChat({
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
    String? jobId,
    String? jobTitle,
  });

  /// Bilinen chatId için dökümanın okunabilir olmasını bekler (liste / bildirim
  /// deep-link). Önbellekte thread varsa recreate dener.
  Future<void> ensureChatReady(String chatId);

  /// Sohbeti ustaya AÇAR (`customerStarted = true`).
  ///
  /// Normalde bayrağı ilk müşteri mesajı yazar. Ancak müşteri hiç yazmadan
  /// doğrudan "Bu Ustayı Seç" diyebilir; o durumda seçilen usta — iş kendisine
  /// verilmiş olmasına rağmen — sohbete yazamaz ve "İletişimi müşteri başlatır"
  /// şeridinde kilitli kalırdı. İşi vermek iletişimi başlatmaktan daha güçlü
  /// bir niyet beyanıdır, bu yüzden seçim anında bayrak yazılır.
  ///
  /// Kurallar bu yazımı yalnız MÜŞTERİ'ye ve yalnız false→true yönünde açar,
  /// dolayısıyla usta kendi iznini açmak için çağıramaz.
  Future<void> markCustomerStarted(String chatId);

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

  /// Sohbeti YALNIZCA [uid] için siler (WhatsApp "Sohbeti sil"): karşı
  /// tarafın listesi/geçmişi etkilenmez. Sohbet [uid]'in listesinden düşer;
  /// karşı taraf yeni mesaj yazarsa yeniden belirir ama silme anından önceki
  /// mesajlar [uid]'e artık gösterilmez ([clearedAt] filtresi).
  Future<void> deleteThreadForMe({required String chatId, required String uid});

  /// [uid]'in bu sohbeti en son sildiği an; bu andan eski mesajlar ona
  /// gösterilmez. Hiç silmediyse null.
  DateTime? clearedAt({required String chatId, required String uid});

  /// Sohbeti [uid] için arşivler/arşivden çıkarır (kişisel; karşı taraf
  /// etkilenmez). Yeni mesaj gelince sohbet arşivden kendiliğinden çıkar.
  Future<void> setThreadArchived({
    required String chatId,
    required String uid,
    required bool archived,
  });

  /// Sohbeti [uid] için listenin başına sabitler/kaldırır (kişisel).
  Future<void> setThreadPinned({
    required String chatId,
    required String uid,
    required bool pinned,
  });

  /// Karşı taraf ([otherUid]) bu sohbeti en son ne zaman okudu? Kendi
  /// mesajımızın "okundu" tikini çizmek için kullanılır; bilinmiyorsa null.
  DateTime? lastReadBy({required String chatId, required String uid});

  /// Denormalize okunmamış sayacı (alt bar / menü rozeti).
  /// Thread listesini açmadan canlı dinlenir (`private/chatMeta`).
  Stream<ChatUnreadMeta> watchUnreadMeta(String uid);
}

/// Bellek içi, gerçek-zamanlı taklit eden uygulama.
class MockChatRepository implements ChatRepository {
  final Map<String, ChatThread> _threads = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, StreamController<List<ChatMessage>>> _msgControllers = {};
  final StreamController<void> _threadsTick = StreamController<void>.broadcast();

  /// chatId → (uid → en son okuma anı). Okunmamış sayısı ve okundu bilgisi için.
  final Map<String, Map<String, DateTime>> _lastRead = {};

  /// chatId → (uid → sohbeti sildiği an). Tek taraflı sohbet silme.
  final Map<String, Map<String, DateTime>> _clearedAt = {};

  int _seq = 0;

  ChatUnreadMeta _unreadMetaFor(String uid) {
    var customer = 0, artisan = 0;
    for (final t in _threadsFor(uid)) {
      final n = unreadCount(chatId: t.id, uid: uid);
      if (n <= 0) continue;
      if (t.artisanUid == uid) {
        artisan += n;
      } else {
        customer += n;
      }
    }
    return ChatUnreadMeta(
      total: customer + artisan,
      customer: customer,
      artisan: artisan,
    );
  }

  /// Firebase paritesi: KİŞİ BAZLI tek kimlik (ilan kimliğe girmez).
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
    final list = _threads.values.where((t) {
      if (!t.involves(uid)) return false;
      // Kullanıcının sildiği sohbet, silme anından sonra yeni mesaj
      // gelmediyse listede görünmez.
      final cleared = _clearedAt[t.id]?[uid];
      return cleared == null || t.updatedAt.isAfter(cleared);
    }).toList()
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
  Future<ChatThread?> fetchThread(String chatId) async => _threads[chatId];

  @override
  Stream<ChatThread?> watchThread(String chatId) async* {
    yield _threads[chatId];
    yield* _threadsTick.stream.map((_) => _threads[chatId]);
  }

  @override
  void markRead({required String chatId, required String uid}) {
    _lastRead.putIfAbsent(chatId, () => {})[uid] = DateTime.now();
    // Mesaj akışını yeniden yay → gönderende okundu bilgisi tazelensin.
    final list = _messages[chatId];
    if (list != null) _ctrl(chatId).add(List.unmodifiable(list));
    _threadsTick.add(null); // Liste rozetleri + unreadMeta güncellensin.
  }

  @override
  Stream<ChatUnreadMeta> watchUnreadMeta(String uid) async* {
    yield _unreadMetaFor(uid);
    yield* _threadsTick.stream.map((_) => _unreadMetaFor(uid));
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
  Future<String> startChat({
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
    String? jobId,
    String? jobTitle,
  }) async {
    // Kimlik ilandan TÜREMEZ; jobId yalnızca bağlam olarak saklanır.
    final id = chatIdFor(customerUid, artisanUid);
    final now = DateTime.now();
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
        createdAt: now,
        updatedAt: now,
        jobId: jobId,
        jobTitle: jobTitle,
      ),
    );
    _threadsTick.add(null);
    return id;
  }

  @override
  Future<void> ensureChatReady(String chatId) async {}

  @override
  Future<void> markCustomerStarted(String chatId) async {
    final t = _threads[chatId];
    if (t == null || t.customerStarted) return;
    _threads[chatId] = t.copyWith(customerStarted: true);
    _threadsTick.add(null);
  }

  @override
  Future<bool> sendMessage({
    required String chatId,
    required String senderUid,
    String? text,
    String? imageHandle,
  }) async {
    // Maskeleme KALDIRILDI (ürün kararı, oturum 2) — Firebase uygulamasıyla
    // parite: orada da `ContactMasker` artık çağrılmıyor.
    final msg = ChatMessage(
      id: 'msg_${_seq++}',
      chatId: chatId,
      senderUid: senderUid,
      text: text,
      imageHandle: imageHandle,
      createdAt: DateTime.now(),
    );

    final list = _messages.putIfAbsent(chatId, () => []);
    list.add(msg);
    _ctrl(chatId).add(List.unmodifiable(list));

    // Başlık özetini güncelle. Yeni mesaj sohbeti ALICI'nın arşivinden
    // çıkarır (WhatsApp davranışı); gönderenin kendi arşivi korunur.
    final t = _threads[chatId];
    if (t != null) {
      final receiver = t.otherUid(senderUid);
      _threads[chatId] = t.copyWith(
        lastMessage: imageHandle != null ? '📷 Fotoğraf' : text,
        updatedAt: msg.createdAt,
        lastMessageSenderUid: senderUid,
        archivedBy: t.archivedBy.contains(receiver)
            ? ({...t.archivedBy}..remove(receiver))
            : null,
        // Firebase paritesi: ilk müşteri mesajı sohbeti ustaya açar.
        customerStarted:
            senderUid == t.customerUid ? true : t.customerStarted,
      );
      _threadsTick.add(null);
    }

    // Maskeleme kaldırıldığı için hiçbir mesaj artık maskelenmiyor.
    return false;
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
    if (i < 0) return;
    if (list[i].senderUid != senderUid) return;
    list[i] = ChatMessage(
      id: list[i].id,
      chatId: chatId,
      senderUid: senderUid,
      deleted: true,
      createdAt: list[i].createdAt,
    );
    _ctrl(chatId).add(List.unmodifiable(list));
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
        lastMessage: ChatMessage.deletedPreview,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );
      _threadsTick.add(null);
    }
  }

  @override
  Future<void> deleteThreadForMe({
    required String chatId,
    required String uid,
  }) async {
    (_clearedAt[chatId] ??= {})[uid] = DateTime.now();
    _threadsTick.add(null);
  }

  @override
  DateTime? clearedAt({required String chatId, required String uid}) =>
      _clearedAt[chatId]?[uid];

  @override
  Future<void> setThreadArchived({
    required String chatId,
    required String uid,
    required bool archived,
  }) async {
    final t = _threads[chatId];
    if (t == null) return;
    final next = {...t.archivedBy};
    archived ? next.add(uid) : next.remove(uid);
    _threads[chatId] = t.copyWith(archivedBy: next);
    _threadsTick.add(null);
  }

  @override
  Future<void> setThreadPinned({
    required String chatId,
    required String uid,
    required bool pinned,
  }) async {
    final t = _threads[chatId];
    if (t == null) return;
    final next = {...t.pinnedBy};
    pinned ? next.add(uid) : next.remove(uid);
    _threads[chatId] = t.copyWith(pinnedBy: next);
    _threadsTick.add(null);
  }

  @override
  DateTime? lastReadBy({required String chatId, required String uid}) =>
      _lastRead[chatId]?[uid];

  void dispose() {
    for (final c in _msgControllers.values) {
      c.close();
    }
    _threadsTick.close();
  }
}

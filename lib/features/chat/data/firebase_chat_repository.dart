import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/contact_masker.dart';
import '../../../data/models/chat.dart';
import 'chat_repository.dart';

/// Firestore ile çalışan [ChatRepository].
///
/// Koleksiyon şekli:
///  - `chats/{chatId}`: participants[], customerUid, artisanUid, adlar/fotolar,
///    lastMessage, lastMessageSenderUid, updatedAt, lastRead{uid: Timestamp}
///  - `chats/{chatId}/messages/{id}`: senderUid, text, imageHandle, createdAt
///
/// [ChatRepository]'nin senkron metotları (getThread/unreadCount/lastReadAt/
/// hasChatBetween) Firestore async olduğundan, aktif stream'lerden beslenen
/// yerel ÖNBELLEKTEN yanıtlanır. Bu, gerçek kullanım akışlarını kapsar
/// (sohbet listesi açık → thread'ler önbellekte). Kesin okunmamış SAYISI ve
/// puan hesapları üretimde Cloud Functions'a taşınmalıdır (unreadCount 0/1 verir).
class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // --- Senkron metotlar için yerel önbellekler ---
  final Map<String, ChatThread> _threads = {};
  final Map<String, ({DateTime? at, String? sender})> _lastMsgMeta = {};
  final Map<String, Map<String, DateTime>> _lastRead = {};

  /// startChat'in `chats/{chatId}` yazımı devam ediyor olabilir. Mesaj gönderme
  /// kuralı bu dökümanın var olmasına bağlı (participants kontrolü), bu yüzden
  /// mesaj yazmadan önce ilgili yazımı bekleriz (yarış durumunu önler).
  final Map<String, Future<void>> _pendingChatDoc = {};

  static String chatIdFor(String customerUid, String artisanUid) =>
      'chat_${customerUid}__$artisanUid';

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  bool _legacyHealAttempted = false;

  /// `members` alanı olmayan ESKİ sohbet dökümanları yeni sorguda görünmez.
  /// Bir kez, eski desenle (participants array-contains) bulunabilenlere
  /// `members` alanını yazarak onarır. Kurallar eski desen sorgusuna izin
  /// vermezse sessizce vazgeçer (yeni dökümanlar zaten sorunsuz).
  Future<void> _healLegacyThreads(String uid) async {
    if (_legacyHealAttempted) return;
    _legacyHealAttempted = true;
    try {
      final snap =
          await _chats.where('participants', arrayContains: uid).get();
      for (final doc in snap.docs) {
        final members = doc.data()['members'];
        if (members is Map && members[uid] == true) continue;
        final derived = _membersFromChatId(doc.id) ??
            {
              for (final p
                  in (doc.data()['participants'] as List? ?? const []))
                p.toString(): true,
            };
        if (derived.isEmpty) continue;
        await doc.reference.set({'members': derived}, SetOptions(merge: true));
      }
    } catch (_) {
      // Erişim yoksa (kural ispatı) veya ağ hatasında onarım atlanır.
    }
  }

  @override
  Stream<List<ChatThread>> watchThreads(String uid) {
    // Üyelik `members.<uid> == true` EŞİTLİK filtresiyle sorgulanır: güvenlik
    // kuralı motoru bu ispatı garantili yapar (array-contains + `in` kuralı
    // sorgularda PERMISSION_DENIED verebiliyordu). Eşitlik filtresi otomatik
    // indexle çalıştığından orderBy kaldırıldı; sıralama istemcide yapılır.
    _healLegacyThreads(uid); // bir kez, arka planda; stream'i bekletmez.
    return _chats
        .where('members.$uid', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = <ChatThread>[];
      for (final doc in snap.docs) {
        final t = _threadFromDoc(doc.id, doc.data());
        _threads[doc.id] = t;
        _lastMsgMeta[doc.id] = (
          at: (doc.data()['updatedAt'] as Timestamp?)?.toDate(),
          sender: doc.data()['lastMessageSenderUid'] as String?,
        );
        _lastRead[doc.id] = _readMap(doc.data()['lastRead']);
        list.add(t);
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage(
                  id: d.id,
                  chatId: chatId,
                  senderUid: (d.data()['senderUid'] as String?) ?? '',
                  text: d.data()['text'] as String?,
                  imageHandle: d.data()['imageHandle'] as String?,
                  createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                ))
            .toList());
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
  int unreadCount({required String chatId, required String uid}) {
    final meta = _lastMsgMeta[chatId];
    if (meta == null || meta.at == null || meta.sender == null) return 0;
    if (meta.sender == uid) return 0; // son mesaj bizden → okunmamış yok
    final since = _lastRead[chatId]?[uid];
    // Cloud Functions olmadan kesin sayı yerine ikili gösterge (0/1).
    return (since == null || meta.at!.isAfter(since)) ? 1 : 0;
  }

  @override
  DateTime? lastReadAt({required String chatId, required String uid}) =>
      _lastRead[chatId]?[uid];

  @override
  void markRead({required String chatId, required String uid}) {
    final now = DateTime.now();
    (_lastRead[chatId] ??= {})[uid] = now; // önbelleği hemen güncelle
    _chats.doc(chatId).set({
      'lastRead': {uid: Timestamp.fromDate(now)},
    }, SetOptions(merge: true));
  }

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
    final now = DateTime.now();
    // Önbelleğe hemen ekle (getThread/hasChatBetween anında çalışsın).
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
        updatedAt: now,
      ),
    );
    // Yoksa oluştur (varsa alanları ezmeden bırak). Yazımı sakla ki ilk mesaj
    // gönderilmeden önce dökümanın (participants) hazır olması garanti olsun.
    _pendingChatDoc[id] = _chats.doc(id).set({
      'participants': [customerUid, artisanUid],
      // Güvenlik kuralları + liste sorgusu üyelik haritasını kullanır.
      'members': {customerUid: true, artisanUid: true},
      'customerUid': customerUid,
      'artisanUid': artisanUid,
      'customerName': customerName,
      'artisanName': artisanName,
      'customerPhotoURL': customerPhotoUrl,
      'artisanPhotoURL': artisanPhotoUrl,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
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
    final now = DateTime.now();

    // Sohbet dökümanının yazımı sürüyorsa bekle: mesaj kuralı participants'a
    // bakar, döküman yoksa reddedilir.
    final pending = _pendingChatDoc[chatId];
    if (pending != null) {
      await pending;
      _pendingChatDoc.remove(chatId);
    }

    await _chats.doc(chatId).collection('messages').add({
      'senderUid': senderUid,
      'text': masked,
      'imageHandle': imageHandle,
      'createdAt': Timestamp.fromDate(now),
    });

    await _chats.doc(chatId).set({
      'lastMessage': imageHandle != null ? '📷 Fotoğraf' : masked,
      'lastMessageSenderUid': senderUid,
      'updatedAt': Timestamp.fromDate(now),
      // members alanı olmayan eski dökümanları iyileştir (chatId'den türet).
      if (_membersFromChatId(chatId) != null)
        'members': _membersFromChatId(chatId),
    }, SetOptions(merge: true));

    return wasMasked;
  }

  /// `chat_<customerUid>__<artisanUid>` biçimindeki kimlikten üyelik haritası
  /// türetir; biçim beklenmedikse null döner.
  static Map<String, bool>? _membersFromChatId(String chatId) {
    if (!chatId.startsWith('chat_')) return null;
    final parts = chatId.substring(5).split('__');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return {parts[0]: true, parts[1]: true};
  }

  ChatThread _threadFromDoc(String id, Map<String, dynamic> d) => ChatThread(
        id: id,
        customerUid: (d['customerUid'] as String?) ?? '',
        artisanUid: (d['artisanUid'] as String?) ?? '',
        customerName: (d['customerName'] as String?) ?? '',
        artisanName: (d['artisanName'] as String?) ?? '',
        customerPhotoUrl: d['customerPhotoURL'] as String?,
        artisanPhotoUrl: d['artisanPhotoURL'] as String?,
        lastMessage: d['lastMessage'] as String?,
        updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, DateTime> _readMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      if (v is Timestamp) out[k.toString()] = v.toDate();
    });
    return out;
  }
}

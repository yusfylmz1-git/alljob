import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/contact_masker.dart';
import '../../../data/models/chat.dart';
import 'chat_repository.dart';

/// Firestore ile çalışan [ChatRepository].
///
/// Koleksiyon şekli:
///  - `chats/{chatId}`: participants[], members{}, customerUid, artisanUid,
///    adlar/fotolar, lastMessage, lastMessageSenderUid, updatedAt, lastRead
///  - `chats/{chatId}/messages/{id}`: senderUid, text, imageHandle, createdAt
///
/// **Kritik tasarım:** [startChat] döküman **hazır** olana kadar await edilir.
/// Mesaj dinleyicisi sohbet yokken permission-denied yiyip UI'yi kilitlemesin
/// diye [watchMessages] önce [ensureChatReady] yapar; stream hata verirse
/// birkaç kez yeniden bağlanır.
class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  final Map<String, ChatThread> _threads = {};
  final Map<String, ({DateTime? at, String? sender})> _lastMsgMeta = {};
  final Map<String, Map<String, DateTime>> _lastRead = {};
  final Map<String, Map<String, DateTime>> _clearedAt = {};

  /// chatId → tek uçuşan ensure Future (çift create yarışını önler: ??=).
  final Map<String, Future<void>> _pendingChatDoc = {};

  static String chatIdFor(String customerUid, String artisanUid) =>
      'chat_${customerUid}__$artisanUid';

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  bool _legacyHealAttempted = false;

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
    } catch (_) {/* kural/ağ */}
  }

  @override
  Stream<List<ChatThread>> watchThreads(String uid) {
    _healLegacyThreads(uid);
    return _chats.where('members.$uid', isEqualTo: true).snapshots().map((snap) {
      final list = <ChatThread>[];
      for (final doc in snap.docs) {
        final t = _threadFromDoc(doc.id, doc.data());
        _threads[doc.id] = t;
        _lastMsgMeta[doc.id] = (
          at: (doc.data()['updatedAt'] as Timestamp?)?.toDate(),
          sender: doc.data()['lastMessageSenderUid'] as String?,
        );
        _lastRead[doc.id] = _readMap(doc.data()['lastRead']);
        _clearedAt[doc.id] = _readMap(doc.data()['clearedAt']);
        final cleared = _clearedAt[doc.id]?[uid];
        if (cleared != null && !t.updatedAt.isAfter(cleared)) continue;
        list.add(t);
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) async* {
    // 1) Sohbet dökümanını hazırla (önbellek / pending).
    await ensureChatReady(chatId);

    // 2) Snapshot dinle; permission-denied olursa bekle-yeniden bağlan.
    //    StreamProvider ilk hatada "Bir sorun oluştu"ya kilitlenmesin.
    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await for (final list in _messageSnapshots(chatId)) {
          yield list;
        }
        return; // stream normal bitti
      } catch (e, st) {
        debugPrint(
            '[chat] watchMessages hata (deneme ${attempt + 1}/$maxAttempts) '
            '$chatId: $e\n$st');
        if (attempt == maxAttempts - 1) rethrow;
        await ensureChatReady(chatId);
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }
  }

  Stream<List<ChatMessage>> _messageSnapshots(String chatId) {
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
                  deleted: (d.data()['deleted'] as bool?) ?? false,
                  createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                ))
            .toList());
  }

  @override
  Future<void> ensureChatReady(String chatId) async {
    // Uçuşan create varsa onu bekle (tek Future paylaşılır).
    final pending = _pendingChatDoc[chatId];
    if (pending != null) {
      try {
        await pending;
      } catch (e) {
        debugPrint('[chat] pending ensure hata ($chatId): $e');
      }
    }

    // Önbellekte thread varsa (startChat veya liste) recreate dene.
    final cached = _threads[chatId];
    if (cached != null) {
      await _ensureChatDoc(
        id: chatId,
        customerUid: cached.customerUid,
        customerName: cached.customerName,
        customerPhotoUrl: cached.customerPhotoUrl,
        artisanUid: cached.artisanUid,
        artisanName: cached.artisanName,
        artisanPhotoUrl: cached.artisanPhotoUrl,
        now: DateTime.now(),
      );
      return;
    }

    // chatId'den uid türetilebiliyorsa iskelet oluşturmayı dene.
    final parts = _uidsFromChatId(chatId);
    if (parts != null) {
      await _ensureChatDoc(
        id: chatId,
        customerUid: parts.$1,
        customerName: 'Müşteri',
        customerPhotoUrl: null,
        artisanUid: parts.$2,
        artisanName: 'Usta',
        artisanPhotoUrl: null,
        now: DateTime.now(),
      );
    }
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
    if (meta.sender == uid) return 0;
    final since = _lastRead[chatId]?[uid];
    return (since == null || meta.at!.isAfter(since)) ? 1 : 0;
  }

  @override
  DateTime? lastReadAt({required String chatId, required String uid}) =>
      _lastRead[chatId]?[uid];

  @override
  void markRead({required String chatId, required String uid}) {
    final now = DateTime.now();
    (_lastRead[chatId] ??= {})[uid] = now;
    // ignore: discarded_futures
    Future<void>(() async {
      try {
        await _chats
            .doc(chatId)
            .update({'lastRead.$uid': Timestamp.fromDate(now)});
      } catch (e) {
        debugPrint('[chat] markRead atlandı ($chatId): $e');
      }
    });
  }

  @override
  Future<String> startChat({
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
  }) async {
    final id = chatIdFor(customerUid, artisanUid);
    final now = DateTime.now();
    _threads[id] = ChatThread(
      id: id,
      customerUid: customerUid,
      artisanUid: artisanUid,
      customerName: customerName,
      artisanName: artisanName,
      customerPhotoUrl: customerPhotoUrl,
      artisanPhotoUrl: artisanPhotoUrl,
      createdAt: _threads[id]?.createdAt ?? now,
      updatedAt: _threads[id]?.updatedAt ?? now,
      lastMessage: _threads[id]?.lastMessage,
    );

    await _ensureChatDoc(
      id: id,
      customerUid: customerUid,
      customerName: customerName,
      customerPhotoUrl: customerPhotoUrl,
      artisanUid: artisanUid,
      artisanName: artisanName,
      artisanPhotoUrl: artisanPhotoUrl,
      now: now,
    );
    return id;
  }

  /// Tek uçuş: aynı chatId için eşzamanlı çağrılar aynı Future'ı paylaşır.
  Future<void> _ensureChatDoc({
    required String id,
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
    required DateTime now,
  }) {
    final inflight = _pendingChatDoc[id];
    if (inflight != null) return inflight;

    final future = _ensureChatDocBody(
      id: id,
      customerUid: customerUid,
      customerName: customerName,
      customerPhotoUrl: customerPhotoUrl,
      artisanUid: artisanUid,
      artisanName: artisanName,
      artisanPhotoUrl: artisanPhotoUrl,
      now: now,
    );
    _pendingChatDoc[id] = future;
    future.whenComplete(() {
      if (identical(_pendingChatDoc[id], future)) {
        _pendingChatDoc.remove(id);
      }
    });
    return future;
  }

  Future<void> _ensureChatDocBody({
    required String id,
    required String customerUid,
    required String customerName,
    String? customerPhotoUrl,
    required String artisanUid,
    required String artisanName,
    String? artisanPhotoUrl,
    required DateTime now,
  }) async {
    // Var mı?
    try {
      final snap = await _chats.doc(id).get();
      if (snap.exists) {
        final data = snap.data();
        final members = data?['members'];
        final needHeal = members is! Map ||
            members[customerUid] != true ||
            members[artisanUid] != true;
        if (needHeal) {
          final derived =
              _membersFromChatId(id) ?? {customerUid: true, artisanUid: true};
          try {
            await _chats
                .doc(id)
                .set({'members': derived}, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[chat] members heal ($id): $e');
          }
        }
        // Önbelleği sunucu verisiyle tazele
        if (data != null) _threads[id] = _threadFromDoc(id, data);
        return;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('[chat] get reddi, create denenecek ($id): $e');
    }

    // Yok → oluştur
    try {
      await _chats.doc(id).set({
        'participants': [customerUid, artisanUid],
        'members': {customerUid: true, artisanUid: true},
        'customerUid': customerUid,
        'artisanUid': artisanUid,
        'customerName': customerName,
        'artisanName': artisanName,
        // Null-aware map elemanı: değer null ise anahtar yazılmaz.
        'customerPhotoURL': ?customerPhotoUrl,
        'artisanPhotoURL': ?artisanPhotoUrl,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Başka istemci oluşturmuş olabilir VEYA e-posta doğrulanmamış.
        try {
          final again = await _chats.doc(id).get();
          if (again.exists) {
            final data = again.data();
            if (data != null) _threads[id] = _threadFromDoc(id, data);
            return;
          }
        } catch (_) {/* ignore */}
        debugPrint(
          '[chat] sohbet oluşturulamadı ($id). '
          'Olası neden: e-posta doğrulanmamış / App Check / üye değil. $e',
        );
      }
      rethrow;
    }
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

    await ensureChatReady(chatId);

    await _chats.doc(chatId).collection('messages').add({
      'senderUid': senderUid,
      'text': masked,
      'imageHandle': imageHandle,
      'createdAt': Timestamp.fromDate(now),
    });

    final meta = <String, dynamic>{
      'lastMessage': imageHandle != null ? '📷 Fotoğraf' : masked,
      'lastMessageSenderUid': senderUid,
      'updatedAt': Timestamp.fromDate(now),
    };
    final members = _membersFromChatId(chatId);
    if (members != null) meta['members'] = members;
    await _chats.doc(chatId).set(meta, SetOptions(merge: true));

    return wasMasked;
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String senderUid,
  }) async {
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deleted': true,
      'text': FieldValue.delete(),
      'imageHandle': FieldValue.delete(),
    });

    final last = await _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (last.docs.isNotEmpty && last.docs.first.id == messageId) {
      await _chats.doc(chatId).set(
        {'lastMessage': ChatMessage.deletedPreview},
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<void> deleteThreadForMe({
    required String chatId,
    required String uid,
  }) async {
    final now = DateTime.now();
    (_clearedAt[chatId] ??= {})[uid] = now;
    await _chats.doc(chatId).update({
      'clearedAt.$uid': Timestamp.fromDate(now),
    });
  }

  @override
  DateTime? clearedAt({required String chatId, required String uid}) =>
      _clearedAt[chatId]?[uid];

  static Map<String, bool>? _membersFromChatId(String chatId) {
    final uids = _uidsFromChatId(chatId);
    if (uids == null) return null;
    return {uids.$1: true, uids.$2: true};
  }

  /// `chat_<customerUid>__<artisanUid>` → (customer, artisan).
  static (String, String)? _uidsFromChatId(String chatId) {
    if (!chatId.startsWith('chat_')) return null;
    final parts = chatId.substring(5).split('__');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return (parts[0], parts[1]);
  }

  ChatThread _threadFromDoc(String id, Map<String, dynamic> d) {
    final updated =
        (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return ChatThread(
      id: id,
      customerUid: (d['customerUid'] as String?) ?? '',
      artisanUid: (d['artisanUid'] as String?) ?? '',
      customerName: (d['customerName'] as String?) ?? '',
      artisanName: (d['artisanName'] as String?) ?? '',
      customerPhotoUrl: d['customerPhotoURL'] as String?,
      artisanPhotoUrl: d['artisanPhotoURL'] as String?,
      lastMessage: d['lastMessage'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: updated,
    );
  }

  Map<String, DateTime> _readMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      if (v is Timestamp) out[k.toString()] = v.toDate();
    });
    return out;
  }
}

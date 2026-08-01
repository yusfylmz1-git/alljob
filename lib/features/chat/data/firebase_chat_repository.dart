import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
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

  /// Son yazılan heal değeri — gereksiz chatMeta yazısını keser.
  final Map<String, String> _lastHealedMetaKey = {};

  /// Sohbet kimliği — İLAN BAZLI.
  ///
  /// [jobId] doluysa `chat_{müşteri}__{usta}__{jobId}`: her ilan kendi sohbet
  /// odasını alır, aynı çift farklı ilanlarda karışmaz.
  ///
  /// [jobId] boşsa ESKİ iki parçalı biçim (`chat_{müşteri}__{usta}`) üretilir —
  /// ürün/eleman sohbetleri ilana bağlı değildir ve ilan bazlı şemadan önce
  /// açılmış sohbetler bu kimlikle durmaya devam eder. İki biçim yan yana
  /// yaşar; [_uidsFromChatId] ikisini de çözer.
  static String chatIdFor(
    String customerUid,
    String artisanUid, {
    String? jobId,
  }) {
    final base = 'chat_${customerUid}__$artisanUid';
    return (jobId == null || jobId.isEmpty) ? base : '${base}__$jobId';
  }

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  DocumentReference<Map<String, dynamic>> _chatMetaRef(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('chatMeta');

  @override
  Stream<List<ChatThread>> watchThreads(String uid) {
    // `members` haritası olmayan LEGACY sohbetler için bir onarım taraması
    // burada DURMUYOR: tarama `participants array_contains` ile sorgulamak
    // zorundaydı ve kurallar bunu reddediyor (firestore.rules "chats" notu —
    // kural motoru array-contains'te üyelik ispatını yapamıyor). Yani onarım
    // hiçbir zaman çalışmıyordu, yalnızca her açılışta yutulan bir
    // permission-denied üretiyordu. Yeni sohbetler `members`i ilk yazımda
    // koyuyor (createChat); geriye dönük veri çıkarsa onarım istemciden değil
    // Admin SDK'lı bir Cloud Function'dan yapılmalıdır.
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
      // Liste açıkken sayacı thread'lerden yeniden hizala (eski hesap / drift).
      unawaited(_healUnreadMeta(uid, list));
      return list;
    });
  }

  @override
  Stream<ChatUnreadMeta> watchUnreadMeta(String uid) {
    return _chatMetaRef(uid).snapshots().map(
          (s) => ChatUnreadMeta.fromMap(s.data()),
        );
  }

  /// Thread listesinden doğru sayıyı yaz (yalnız değer değiştiyse).
  Future<void> _healUnreadMeta(String uid, List<ChatThread> threads) async {
    var customer = 0, artisan = 0;
    for (final t in threads) {
      final n = unreadCount(chatId: t.id, uid: uid);
      if (n <= 0) continue;
      if (t.artisanUid == uid) {
        artisan += n;
      } else {
        customer += n;
      }
    }
    final total = customer + artisan;
    final key = '$total|$customer|$artisan';
    if (_lastHealedMetaKey[uid] == key) return;
    _lastHealedMetaKey[uid] = key;
    try {
      await _chatMetaRef(uid).set({
        'unreadTotal': total,
        'unreadCustomer': customer,
        'unreadArtisan': artisan,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[chat] unreadMeta heal atlandı ($uid): $e');
      _lastHealedMetaKey.remove(uid);
    }
  }

  /// Okundu / CF drift: chatMeta'yı atomik düşür (negatife inmez).
  Future<void> _decrementUnreadMeta(
    String uid, {
    required bool asArtisan,
    int by = 1,
  }) async {
    if (by <= 0) return;
    final ref = _chatMetaRef(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? const <String, dynamic>{};
        int i(String k) {
          final v = data[k];
          if (v is int) return v;
          if (v is num) return v.toInt();
          return 0;
        }

        var customer = i('unreadCustomer');
        var artisan = i('unreadArtisan');
        if (asArtisan) {
          artisan = (artisan - by).clamp(0, 1 << 30);
        } else {
          customer = (customer - by).clamp(0, 1 << 30);
        }
        final total = customer + artisan;
        tx.set(
          ref,
          {
            'unreadTotal': total,
            'unreadCustomer': customer,
            'unreadArtisan': artisan,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      _lastHealedMetaKey.remove(uid);
    } catch (e) {
      debugPrint('[chat] unreadMeta decrement atlandı ($uid): $e');
    }
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
    // En yeni N mesaj (limit) — tüm geçmişi çekmek okuma/RAM şişirir.
    // descending + limit, sonra kronolojik (eskiden yeniye) sırala; UI reverse ListView.
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.chatMessagesFetchCap)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatMessage(
                id: d.id,
                chatId: chatId,
                senderUid: (d.data()['senderUid'] as String?) ?? '',
                text: d.data()['text'] as String?,
                imageHandle: d.data()['imageHandle'] as String?,
                deleted: (d.data()['deleted'] as bool?) ?? false,
                // Yalnız CF yazar; eksik alan = görünür (eski mesajlar).
                moderationHidden:
                    d.data()['moderationHidden'] == true,
                // Yaşam döngüsü bildirimi (yalnız CF yazar).
                isSystem: d.data()['type'] == 'system',
                createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ))
          .toList();
      return list.reversed.toList(growable: false);
    });
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
    // NOT: parse başarısızsa hiçbir şey yazılmaz ve hata da görünmez —
    // kimlik biçimi değişirse (ilan bazlı 3 parça) burası ilk kırılacak yerdir.
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
        // İskelette başlık bilinmez; kimlikten yalnız ilan numarası çıkar.
        jobId: _jobIdFromChatId(chatId),
        now: DateTime.now(),
      );
    }
  }

  @override
  ChatThread? getThread(String chatId) => _threads[chatId];

  @override
  Future<ChatThread?> fetchThread(String chatId) async {
    final cached = _threads[chatId];
    if (cached != null) return cached;
    try {
      final snap = await _chats.doc(chatId).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final t = _threadFromDoc(chatId, data);
      _threads[chatId] = t; // önbelleğe al: sonraki getThread çağrıları bulsun
      return t;
    } catch (e) {
      debugPrint('[chat] fetchThread ($chatId): $e');
      return null;
    }
  }

  @override
  bool hasChatBetween({
    required String customerUid,
    required String artisanUid,
    String? jobId,
  }) =>
      _threads.containsKey(chatIdFor(customerUid, artisanUid, jobId: jobId));

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
    final was = unreadCount(chatId: chatId, uid: uid);
    final thread = _threads[chatId];
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
      // Alt bar rozeti: thread listesini açmadan düşür.
      if (was > 0) {
        final artisanUid =
            thread?.artisanUid ?? _uidsFromChatId(chatId)?.$2;
        final asArtisan = artisanUid != null && artisanUid == uid;
        await _decrementUnreadMeta(uid, asArtisan: asArtisan, by: was);
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
    String? jobId,
    String? jobTitle,
  }) async {
    final id = chatIdFor(customerUid, artisanUid, jobId: jobId);
    final now = DateTime.now();
    final prev = _threads[id];
    _threads[id] = ChatThread(
      id: id,
      customerUid: customerUid,
      artisanUid: artisanUid,
      customerName: customerName,
      artisanName: artisanName,
      customerPhotoUrl: customerPhotoUrl,
      artisanPhotoUrl: artisanPhotoUrl,
      createdAt: prev?.createdAt ?? now,
      updatedAt: prev?.updatedAt ?? now,
      lastMessage: prev?.lastMessage,
      jobId: jobId,
      jobTitle: jobTitle,
      // Sunucudan gelen bayrakları koru: önbellek tazelemesi kilidi/başlangıcı
      // sıfırlarsa UI kilitli sohbette giriş kutusunu yeniden açardı.
      customerStarted: prev?.customerStarted ?? false,
      lockedAt: prev?.lockedAt,
      lockReason: prev?.lockReason,
    );

    await _ensureChatDoc(
      id: id,
      customerUid: customerUid,
      customerName: customerName,
      customerPhotoUrl: customerPhotoUrl,
      artisanUid: artisanUid,
      artisanName: artisanName,
      artisanPhotoUrl: artisanPhotoUrl,
      jobId: jobId,
      jobTitle: jobTitle,
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
    String? jobId,
    String? jobTitle,
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
      jobId: jobId,
      jobTitle: jobTitle,
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
    String? jobId,
    String? jobTitle,
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
        // İlan bazlı sohbet: kimlikten de türetilebilir ama alan olarak
        // yazmak sorgu/rules tarafını basitleştirir. Genel sohbette yazılmaz.
        'jobId': ?jobId,
        'jobTitle': ?jobTitle,
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
    // Yeni mesaj sohbeti ALICI'nın arşivinden çıkarır (WhatsApp davranışı).
    // Gönderenin kendi arşivi korunur — kendi yazdığı mesaj arşivi bozmaz.
    // NOT: `set(merge:true)` ile nokta notasyonu ALAN ADI sayılır, iç içe
    // haritayı güncellemez → iç içe map olarak yazılır (merge yalnız bu
    // anahtarı değiştirir, karşı tarafın kaydına dokunmaz).
    final thread = _threads[chatId];
    if (thread != null) {
      final receiver = thread.otherUid(senderUid);
      if (thread.archivedBy.contains(receiver)) {
        meta['archivedBy'] = {receiver: false};
      }
      // İLK müşteri mesajı sohbeti ustaya AÇAR. Kural motoru "bu sohbette
      // müşteri mesajı var mı" diye sorgulayamadığı için bayrak burada
      // DENORMALIZE yazılır; usta yazma izni buna bakar.
      if (senderUid == thread.customerUid && !thread.customerStarted) {
        meta['customerStarted'] = true;
        _threads[chatId] = thread.copyWith(customerStarted: true);
      }
    }
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

  @override
  Future<void> setThreadArchived({
    required String chatId,
    required String uid,
    required bool archived,
  }) async {
    // Kişisel alan: `archivedBy.<uid>`. true/false yerine silme kullanmıyoruz
    // ki karşı tarafın kaydı etkilenmesin (harita alanı tek tek yazılır).
    await _chats.doc(chatId).update({'archivedBy.$uid': archived});
  }

  @override
  Future<void> setThreadPinned({
    required String chatId,
    required String uid,
    required bool pinned,
  }) async {
    await _chats.doc(chatId).update({'pinnedBy.$uid': pinned});
  }

  @override
  DateTime? lastReadBy({required String chatId, required String uid}) =>
      _lastRead[chatId]?[uid];

  static Map<String, bool>? _membersFromChatId(String chatId) {
    final uids = _uidsFromChatId(chatId);
    if (uids == null) return null;
    return {uids.$1: true, uids.$2: true};
  }

  /// `chat_<müşteri>__<usta>[__<jobId>]` → (customer, artisan).
  ///
  /// İki biçim de çözülür: ilan bazlı (3 parça) ve eski genel sohbet (2 parça).
  /// jobId parçası burada YOK SAYILIR — uid'ler her iki biçimde de ilk iki
  /// parçadır.
  static (String, String)? _uidsFromChatId(String chatId) {
    if (!chatId.startsWith('chat_')) return null;
    final parts = chatId.substring(5).split('__');
    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
    return (parts[0], parts[1]);
  }

  /// Kimlikten ilan numarası — yalnız ilan bazlı (3 parçalı) sohbetlerde.
  /// Dokümandaki `jobId` alanı eksikse (eski/iskelet kayıt) yedek yol.
  static String? _jobIdFromChatId(String chatId) {
    if (!chatId.startsWith('chat_')) return null;
    final parts = chatId.substring(5).split('__');
    if (parts.length < 3 || parts[2].isEmpty) return null;
    // jobId'nin kendisi '__' içerebilir → 3. parçadan sonrası birleştirilir.
    return parts.sublist(2).join('__');
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
      lastMessageSenderUid: d['lastMessageSenderUid'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: updated,
      archivedBy: _flagSet(d['archivedBy']),
      pinnedBy: _flagSet(d['pinnedBy']),
      // Alan yoksa kimlikten türet: iskelet dokümanlarda (ensureChatReady)
      // jobId yazılamamış olabilir.
      jobId: (d['jobId'] as String?) ?? _jobIdFromChatId(id),
      jobTitle: d['jobTitle'] as String?,
      customerStarted: d['customerStarted'] == true,
      lockedAt: (d['lockedAt'] as Timestamp?)?.toDate(),
      lockReason: ChatLockReason.fromString(d['lockReason'] as String?),
    );
  }

  /// `{uid: true}` haritasından yalnız true olan uid'leri toplar (false
  /// yazılmış kayıtlar = arşivden çıkarılmış demektir).
  static Set<String> _flagSet(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String>{};
    raw.forEach((k, v) {
      if (v == true) out.add(k.toString());
    });
    return out;
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

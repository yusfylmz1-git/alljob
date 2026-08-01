import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/report.dart';
import 'admin_report.dart';

/// Transcript'teki tek mesaj (yalnız moderasyon görünümü).
class TranscriptMessage {
  const TranscriptMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.deleted,
    required this.moderationHidden,
    required this.createdAt,
  });

  final String id;
  final String senderUid;

  /// Gönderen KENDİ sildiyse null (içerik sunucuda da verilmez).
  final String? text;

  /// Gönderenin yumuşak silmesi.
  final bool deleted;

  /// Yönetici kaldırdı. Moderatöre metin YİNE gösterilir (kararı denetleyen
  /// kişi neyi kaldırdığını görebilmeli) — yalnız rozetle işaretlenir.
  final bool moderationHidden;

  final String createdAt;

  factory TranscriptMessage.fromMap(Map<String, dynamic> m) =>
      TranscriptMessage(
        id: (m['id'] ?? '').toString(),
        senderUid: (m['senderUid'] ?? '').toString(),
        text: m['text'] as String?,
        deleted: m['deleted'] == true,
        moderationHidden: m['moderationHidden'] == true,
        createdAt: (m['createdAt'] ?? '').toString(),
      );
}

/// `adminGetChatTranscript` yanıtı: mesajlar + uid→ad çözümü + şikayet edilen
/// mesajın kimliği (moderatör onu 100 mesaj içinde aramasın).
class ChatTranscript {
  const ChatTranscript({
    this.messages = const [],
    this.names = const {},
    this.reportedMessageId,
  });

  final List<TranscriptMessage> messages;

  /// uid → görünen ad. Eksik uid için UI uid'in kısaltmasını gösterir.
  final Map<String, String> names;

  /// Şikayet edilen mesajın kimliği; bilinmiyorsa null.
  final String? reportedMessageId;

  bool get isEmpty => messages.isEmpty;
}

/// Yönetici şikayet kuyruğu soyutlaması. Kayıtları YALNIZCA `admin:true`
/// claim'i olan kullanıcı okuyabilir/güncelleyebilir (Firestore kuralı).
abstract interface class AdminReportRepository {
  /// Tüm şikayetler — en yeni üstte. [openOnly] ise yalnız açık/incelenen.
  /// (Yalnızca menü rozeti için canlı sayım — liste artık [fetchPage] ile
  /// cursor sayfalanır.)
  Stream<List<Report>> watchReports({bool openOnly = false});

  /// Bir sayfa şikayet (createdAt'e göre en yeni üstte). [beforeCursor] = son
  /// kaydın ham `createdAt` metni → yalnız ondan eskiler gelir. Açık/kapalı
  /// süzme istemci tarafında yapılır (tek alan sorgu; bileşik indeks gerekmez).
  Future<List<Report>> fetchPage({String? beforeCursor, int limit});

  /// Bir şikayetin durumunu (ve varsa çözüm notunu) günceller. Kapanış
  /// durumlarında [resolvedBy]/`resolvedAt` de yazılır.
  Future<void> updateStatus(
    String id, {
    required ReportStatus status,
    required String resolvedBy,
    String? adminNote,
  });

  /// Şikayeti üstlenir ([assign] true → çağıran yöneticiye atanır) veya bırakır.
  Future<void> assignReport(
    String id, {
    required bool assign,
    required String adminUid,
  });

  /// Bağlamlı sohbet transcript (reportId + chatId zorunlu).
  Future<ChatTranscript> fetchChatTranscript({
    required String reportId,
    required String chatId,
    int limit = 100,
  });

  /// Eleman modülü içeriğini gizler/gösterir (`adminModerateStaffing` CF).
  /// [targetType] yalnız staffWorker | staffNeed olabilir.
  Future<void> moderateStaffing({
    required ReportTarget targetType,
    required String targetId,
    required bool hide,
    String? note,
  });

  /// Şikayet edilen sohbet mesajını kaldırır / geri alır
  /// (`adminModerateMessage` CF). Hedef mesaj SUNUCUDA şikayet kaydından
  /// türetilir — istemci chatId/msgId göndermez (rastgele mesaj gizlenemez).
  Future<void> moderateMessage({
    required String reportId,
    required bool hidden,
  });
}

/// Firestore `reports` koleksiyonuyla çalışan [AdminReportRepository].
/// `createdAt` ISO-8601 metin olduğundan `orderBy` sözlüksel sırayla doğru
/// çalışır (zamanla artan). Okuma izni kuralda `token.admin`'e bağlıdır.
class FirebaseAdminReportRepository implements AdminReportRepository {
  FirebaseAdminReportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// Canlı kuyruk penceresi. Milyonlarca kullanıcıda tüm koleksiyonu akıtmak
  /// olmaz; en yeni [_pageLimit] kayıt canlı gösterilir (eski kayıtlar için
  /// sayfalama ileride cursor ile eklenir). `createdAt` tek alan sıralaması
  /// otomatik indekslidir; bileşik indeks gerekmez.
  static const int _pageLimit = 200;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reports');

  @override
  Stream<List<Report>> watchReports({bool openOnly = false}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(_pageLimit)
        .snapshots()
        .map((snap) {
          final all = snap.docs
              .map((d) => Report.fromMap(d.id, d.data()))
              .toList();
          return openOnly ? all.where((r) => !r.status.isClosed).toList() : all;
        });
  }

  @override
  Future<List<Report>> fetchPage({String? beforeCursor, int limit = 30}) async {
    Query<Map<String, dynamic>> q = _col.orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => Report.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<void> updateStatus(
    String id, {
    required ReportStatus status,
    required String resolvedBy,
    String? adminNote,
  }) async {
    // Doğrudan Firestore yazımı YOK: karar + denetim kaydı sunucuda atomik
    // yazılsın diye `adminResolveReport` CF'inden geçer (kural da istemci
    // yazımını reddeder). [resolvedBy] sunucuda auth.uid'den alınır.
    await _functions.httpsCallable('adminResolveReport').call<Object?>({
      'reportId': id,
      'status': status.apiValue,
      if (adminNote != null && adminNote.trim().isNotEmpty)
        'note': adminNote.trim(),
    });
  }

  @override
  Future<void> assignReport(
    String id, {
    required bool assign,
    required String adminUid,
  }) async {
    // adminUid sunucuda auth.uid'den alınır; imza paritesi için taşınır.
    await _functions.httpsCallable('adminAssignReport').call<Object?>({
      'reportId': id,
      'assign': assign,
    });
  }

  @override
  Future<ChatTranscript> fetchChatTranscript({
    required String reportId,
    required String chatId,
    int limit = 100,
  }) async {
    final res = await _functions
        .httpsCallable('adminGetChatTranscript')
        .call<Object?>({
          'reportId': reportId,
          'chatId': chatId,
          'limit': limit,
        });
    final data = res.data;
    if (data is! Map || data['messages'] is! List) return const ChatTranscript();
    final names = <String, String>{};
    final rawNames = data['names'];
    if (rawNames is Map) {
      rawNames.forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) names['$k'] = v.trim();
      });
    }
    return ChatTranscript(
      messages: (data['messages'] as List)
          .whereType<Map>()
          .map((e) => TranscriptMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      names: names,
      reportedMessageId: data['reportedMessageId'] as String?,
    );
  }

  @override
  Future<void> moderateStaffing({
    required ReportTarget targetType,
    required String targetId,
    required bool hide,
    String? note,
  }) async {
    await _functions.httpsCallable('adminModerateStaffing').call<Object?>({
      'targetType': targetType.apiValue,
      'targetId': targetId,
      'decision': hide ? 'hide' : 'unhide',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  @override
  Future<void> moderateMessage({
    required String reportId,
    required bool hidden,
  }) async {
    // chatId/msgId GÖNDERİLMEZ: sunucu şikayet kaydından türetir.
    await _functions.httpsCallable('adminModerateMessage').call<Object?>({
      'reportId': reportId,
      'hidden': hidden,
    });
  }
}

/// Bellek-içi [AdminReportRepository] (testler ve Firebase'siz geliştirme).
class MockAdminReportRepository implements AdminReportRepository {
  MockAdminReportRepository([List<Report>? seed]) {
    if (seed != null) {
      for (final r in seed) {
        _items[r.id] = r;
      }
    }
  }

  final Map<String, Report> _items = {};
  final _changes = StreamController<void>.broadcast();

  List<Report> _query(bool openOnly) {
    final list =
        _items.values
            .where((r) => openOnly ? !r.status.isClosed : true)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<Report>> watchReports({bool openOnly = false}) async* {
    yield _query(openOnly);
    await for (final _ in _changes.stream) {
      yield _query(openOnly);
    }
  }

  @override
  Future<List<Report>> fetchPage({String? beforeCursor, int limit = 30}) async {
    final before = (beforeCursor == null || beforeCursor.isEmpty)
        ? null
        : DateTime.tryParse(beforeCursor);
    final sorted = _query(false); // en yeni üstte, tümü
    final list = before == null
        ? sorted
        : sorted.where((r) => r.createdAt.isBefore(before)).toList();
    return list.take(limit).toList();
  }

  @override
  Future<void> updateStatus(
    String id, {
    required ReportStatus status,
    required String resolvedBy,
    String? adminNote,
  }) async {
    final r = _items[id];
    if (r == null) return;
    _items[id] = Report(
      id: r.id,
      reporterUid: r.reporterUid,
      reportedUid: r.reportedUid,
      target: r.target,
      targetId: r.targetId,
      chatId: r.chatId,
      reason: r.reason,
      note: r.note,
      status: status,
      createdAt: r.createdAt,
      adminNote: (adminNote != null && adminNote.trim().isNotEmpty)
          ? adminNote.trim()
          : r.adminNote,
      resolvedBy: resolvedBy,
      resolvedAt: DateTime.now(),
      // Karara bağlanınca atama düşer (CF paritesi); aksi halde korunur.
      assignedTo: status.isClosed ? null : r.assignedTo,
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> assignReport(
    String id, {
    required bool assign,
    required String adminUid,
  }) async {
    final r = _items[id];
    if (r == null) return;
    _items[id] = Report(
      id: r.id,
      reporterUid: r.reporterUid,
      reportedUid: r.reportedUid,
      target: r.target,
      targetId: r.targetId,
      chatId: r.chatId,
      reason: r.reason,
      note: r.note,
      status: r.status,
      createdAt: r.createdAt,
      adminNote: r.adminNote,
      resolvedBy: r.resolvedBy,
      resolvedAt: r.resolvedAt,
      assignedTo: assign ? adminUid : null,
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<ChatTranscript> fetchChatTranscript({
    required String reportId,
    required String chatId,
    int limit = 100,
  }) async => const ChatTranscript();

  /// Gizlenen hedefler (test doğrulaması için).
  final Set<String> hiddenTargets = {};

  @override
  Future<void> moderateStaffing({
    required ReportTarget targetType,
    required String targetId,
    required bool hide,
    String? note,
  }) async {
    final key = '${targetType.apiValue}/$targetId';
    if (hide) {
      hiddenTargets.add(key);
    } else {
      hiddenTargets.remove(key);
    }
  }

  /// Kaldırılan mesajların şikayet kimlikleri (test doğrulaması için).
  final Set<String> hiddenMessageReports = {};

  @override
  Future<void> moderateMessage({
    required String reportId,
    required bool hidden,
  }) async {
    if (hidden) {
      hiddenMessageReports.add(reportId);
    } else {
      hiddenMessageReports.remove(reportId);
    }
  }

  void dispose() => _changes.close();
}

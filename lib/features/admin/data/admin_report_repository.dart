import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'admin_report.dart';

/// Yönetici şikayet kuyruğu soyutlaması. Kayıtları YALNIZCA `admin:true`
/// claim'i olan kullanıcı okuyabilir/güncelleyebilir (Firestore kuralı).
abstract interface class AdminReportRepository {
  /// Tüm şikayetler — en yeni üstte. [openOnly] ise yalnız açık/incelenen.
  Stream<List<Report>> watchReports({bool openOnly = false});

  /// Bir şikayetin durumunu (ve varsa çözüm notunu) günceller. Kapanış
  /// durumlarında [resolvedBy]/`resolvedAt` de yazılır.
  Future<void> updateStatus(
    String id, {
    required ReportStatus status,
    required String resolvedBy,
    String? adminNote,
  });
}

/// Firestore `reports` koleksiyonuyla çalışan [AdminReportRepository].
/// `createdAt` ISO-8601 metin olduğundan `orderBy` sözlüksel sırayla doğru
/// çalışır (zamanla artan). Okuma izni kuralda `token.admin`'e bağlıdır.
class FirebaseAdminReportRepository implements AdminReportRepository {
  FirebaseAdminReportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

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
      final all =
          snap.docs.map((d) => Report.fromMap(d.id, d.data())).toList();
      return openOnly ? all.where((r) => !r.status.isClosed).toList() : all;
    });
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
    final list = _items.values
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
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}

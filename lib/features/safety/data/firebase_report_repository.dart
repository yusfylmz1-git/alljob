import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/report.dart';
import 'report_repository.dart';

/// Firestore `reports/{id}` ile çalışan [ReportRepository].
/// ID formatını ve `reporterUid == auth.uid` şartını kural da doğrular.
/// `set` (üzerine yazma) kullanılır: aynı hedefi tekrar şikayet etmek yeni
/// kayıt üretmez, mevcut kaydı günceller (kuyruk şişmez; kuralda update dalı
/// create ile aynı şartlarla açık).
class FirebaseReportRepository implements ReportRepository {
  FirebaseReportRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required ReportTarget target,
    required String targetId,
    String? chatId,
    required ReportReason reason,
    String? note,
  }) {
    final id = reportDocId(
        target: target, targetId: targetId, reporterUid: reporterUid);
    return _db.collection('reports').doc(id).set({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'targetType': target.apiValue,
      'targetId': targetId,
      'chatId': ?chatId,
      'reason': reason.apiValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

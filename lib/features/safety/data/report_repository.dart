import '../../../data/models/report.dart';

/// İçerik/kullanıcı şikayeti soyutlaması (UGC politikası — P0).
///
/// Kayıtlar `reports` koleksiyonuna deterministik ID ile yazılır
/// ([reportDocId]): hedef başına şikayetçi başına TEK kayıt — aynı hedefi
/// tekrar şikayet etmek kaydı günceller. İstemci kayıtları OKUYAMAZ
/// (admin kuyruğu; admin fazında custom claim ile açılacak).
abstract interface class ReportRepository {
  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required ReportTarget target,
    required String targetId,
    String? chatId,
    required ReportReason reason,
    String? note,
  });
}

/// Bellek içi mock — testler ve Firebase'siz geliştirme için.
class MockReportRepository implements ReportRepository {
  /// docId → kayıt (test doğrulaması için görünür).
  final Map<String, Map<String, dynamic>> reports = {};

  @override
  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required ReportTarget target,
    required String targetId,
    String? chatId,
    required ReportReason reason,
    String? note,
  }) async {
    final id = reportDocId(
        target: target, targetId: targetId, reporterUid: reporterUid);
    reports[id] = {
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'targetType': target.apiValue,
      'targetId': targetId,
      'chatId': ?chatId,
      'reason': reason.apiValue,
      if (note != null && note.isNotEmpty) 'note': note,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

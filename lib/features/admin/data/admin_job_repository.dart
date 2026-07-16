import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/job.dart';

/// Yönetici ilan tarayıcısı + moderasyon.
abstract interface class AdminJobRepository {
  /// Sayfalı ilan listesi (`createdAt` desc). [status] veya [province] tek
  /// equality (ikisi birden değil — indeks basitliği).
  Future<List<Job>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    JobStatus? status,
    String? province,
  });

  /// hide | unhide | force_cancel
  Future<void> moderate(String jobId, {required String decision, String? note});
}

class FirebaseAdminJobRepository implements AdminJobRepository {
  FirebaseAdminJobRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<List<Job>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    JobStatus? status,
    String? province,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('jobs');
    // Tek equality tercih: status öncelikli, yoksa province.
    if (status != null) {
      q = q.where('status', isEqualTo: status.apiValue);
    } else if (province != null && province.trim().isNotEmpty) {
      q = q.where('province', isEqualTo: province.trim());
    }
    q = q.orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => Job.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<void> moderate(String jobId,
      {required String decision, String? note}) async {
    await _functions.httpsCallable('adminModerateJob').call<Object?>({
      'jobId': jobId,
      'decision': decision,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}

class MockAdminJobRepository implements AdminJobRepository {
  MockAdminJobRepository([List<Job>? seed]) {
    if (seed != null) {
      for (final j in seed) {
        _jobs[j.jobId] = j;
      }
    }
  }

  final Map<String, Job> _jobs = {};

  void put(Job job) => _jobs[job.jobId] = job;

  @override
  Future<List<Job>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    JobStatus? status,
    String? province,
  }) async {
    var list = _jobs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (status != null) {
      list = list.where((j) => j.status == status).toList();
    } else if (province != null && province.trim().isNotEmpty) {
      final p = province.trim();
      list = list.where((j) => j.province == p).toList();
    }
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      final cut = DateTime.tryParse(beforeCursor);
      if (cut != null) {
        list = list.where((j) => j.createdAt.isBefore(cut)).toList();
      }
    }
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  @override
  Future<void> moderate(String jobId,
      {required String decision, String? note}) async {
    final j = _jobs[jobId];
    if (j == null) return;
    // Mock: only force_cancel status change; hide fields not on const Job fully.
    if (decision == 'force_cancel') {
      _jobs[jobId] = j.copyWith(status: JobStatus.cancelled);
    }
  }
}

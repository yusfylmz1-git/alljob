import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/signout_safe_stream.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';
import 'job_repository.dart';

/// Firestore `jobs` + `offers` ile çalışan [JobRepository].
///
/// Feed sorgusu sunucuda meslek + durum eşitliğiyle filtrelenir (composite
/// index: `jobs (category, status)`); coğrafi eşleşme ve sıralama istemcide
/// yapılır (MVP ölçeği için yeterli). Diğer listeler tek eşitlik filtresiyle
/// çekilip istemcide sıralanır — ek composite index gerektirmez.
class FirebaseJobRepository implements JobRepository {
  FirebaseJobRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection('jobs');

  @override
  Future<String> createJob(Job job) async {
    final ref = _jobs.doc();
    await ref.set(job.toMap());
    return ref.id;
  }

  @override
  Stream<List<Job>> watchMyJobs(String customerUid) {
    return _jobs
        .where('customerId', isEqualTo: customerUid)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Job.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).signOutSafe('ilanlarım', customerUid);
  }

  @override
  Stream<List<Job>> watchNearbyJobs({
    String? professionCode,
    List<String>? professionCodes,
    required List<ServiceArea> serviceAreas,
  }) {
    // Basit sorgu: status + createdAt (mevcut composite index).
    // category whereIn + orderBy bazı cihazlarda FAILED_PRECONDITION / uzun
    // bekleme → ANR üretiyordu; meslek/bölge istemcide süzülür.
    final codes = (professionCodes ??
            (professionCode != null && professionCode.isNotEmpty
                ? [professionCode]
                : const <String>[]))
        .where((c) => c.trim().isNotEmpty)
        .toList();
    if (codes.isEmpty) {
      return Stream.value(const <Job>[]);
    }
    return _jobs
        .where('status', isEqualTo: JobStatus.open.apiValue)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.nearbyJobsFetchCap)
        .snapshots()
        .map((s) {
      try {
        final now = DateTime.now();
        final matched = s.docs
            .map((d) {
              try {
                return Job.fromMap(d.id, d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Job>()
            .where((j) => !j.moderationHidden)
            .where((j) => !j.isExpiredAt(now))
            .where((j) => j.matchesArtisan(
                  professionCodes: codes,
                  serviceAreas: serviceAreas,
                ))
            .toList();
        // Hemen Lazım üstte, kendi ilçesindekiler önce (bkz. job.dart).
        return sortJobsForArtisanFeed(matched, serviceAreas);
      } catch (_) {
        return const <Job>[];
      }
    });
  }

  @override
  Stream<List<Job>> watchOpenJobs({int limit = 30}) {
    // Sunucuda durum eşitliği + createdAt DESC sıralı, sınırlı sayıda ilan
    // (composite index: jobs status,createdAt). `fetchCap`, süresi dolan ilanlar
    // istemcide elenince yine de `limit` kadar dolu liste kalması için pay bırakır.
    final fetchCap =
        limit > AppConstants.openJobsFetchCap ? limit : AppConstants.openJobsFetchCap;
    return _jobs
        .where('status', isEqualTo: JobStatus.open.apiValue)
        .orderBy('createdAt', descending: true)
        .limit(fetchCap)
        .snapshots()
        .map((s) {
      final now = DateTime.now();
      final list = s.docs
          .map((d) => Job.fromMap(d.id, d.data()))
          .where((j) => !j.moderationHidden)
          .where((j) => !j.isExpiredAt(now))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  @override
  Future<Job?> getJob(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Job.fromMap(snap.id, snap.data()!);
  }

  @override
  Stream<Job?> watchJob(String jobId) {
    return _jobs.doc(jobId).snapshots().map(
        (d) => d.exists && d.data() != null ? Job.fromMap(d.id, d.data()!) : null);
  }

  @override
  Future<void> cancelJob({
    required String jobId,
    required JobCancelReason reason,
  }) async {
    await _jobs.doc(jobId).update({
      'status': JobStatus.cancelled.apiValue,
      'cancelReason': reason.apiValue,
    });
  }

  @override
  Future<void> updateJobContent({
    required String jobId,
    required String title,
    required String description,
    double? budget,
  }) async {
    // Kural: sahip, yalnız `open` ilanın yalnız bu içerik alanlarını yazabilir.
    await _jobs.doc(jobId).update({
      'title': title,
      'description': description,
      'budget': budget,
    });
  }

  @override
  Future<void> deleteJob(String jobId) async {
    await _jobs.doc(jobId).delete();
  }

}

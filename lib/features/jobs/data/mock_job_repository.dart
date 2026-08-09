import '../../../data/local/mock_database.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';
import 'job_repository.dart';

/// Bellek içi [JobRepository]. Tüm mock repo'lar ortak [MockDatabase]'i
/// paylaşır — böylece müşterinin açtığı ilan usta feed'inde görünür.
class MockJobRepository implements JobRepository {
  MockJobRepository(this._db);

  final MockDatabase _db;

  int _seq = 0;

  @override
  Future<String> createJob(Job job) async {
    final id = job.jobId.isNotEmpty
        ? job.jobId
        : 'job_${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
    _db.jobs[id] = job.jobId.isNotEmpty ? job : _withId(job, id);
    _db.notify();
    return id;
  }

  Job _withId(Job j, String id) => Job.fromMap(id, j.toMap());

  @override
  Stream<List<Job>> watchMyJobs(String customerUid) async* {
    yield _myJobs(customerUid);
    yield* _db.changes.map((_) => _myJobs(customerUid));
  }

  List<Job> _myJobs(String customerUid) {
    final list =
        _db.jobs.values.where((j) => j.customerId == customerUid).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<Job>> watchNearbyJobs({
    String? professionCode,
    List<String>? professionCodes,
    required List<ServiceArea> serviceAreas,
  }) async* {
    final codes = professionCodes ??
        (professionCode != null ? [professionCode] : const <String>[]);
    yield _nearby(codes, serviceAreas);
    yield* _db.changes.map((_) => _nearby(codes, serviceAreas));
  }

  List<Job> _nearby(List<String> professionCodes, List<ServiceArea> serviceAreas) {
    final now = DateTime.now();
    final list = _db.jobs.values.where((j) {
      if (j.status != JobStatus.open) return false;
      if (j.isExpiredAt(now)) return false;
      return j.matchesArtisan(
        professionCodes: professionCodes,
        serviceAreas: serviceAreas,
      );
    }).toList();
    return sortJobsForArtisanFeed(list, serviceAreas);
  }

  @override
  Stream<List<Job>> watchOpenJobs({int limit = 30}) async* {
    yield _openJobs(limit);
    yield* _db.changes.map((_) => _openJobs(limit));
  }

  List<Job> _openJobs(int limit) {
    final now = DateTime.now();
    final list = _db.jobs.values
        .where((j) => j.status == JobStatus.open && !j.isExpiredAt(now))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  @override
  Future<Job?> getJob(String jobId) async => _db.jobs[jobId];

  @override
  Stream<Job?> watchJob(String jobId) async* {
    yield _db.jobs[jobId];
    yield* _db.changes.map((_) => _db.jobs[jobId]);
  }

  @override
  Future<void> cancelJob({
    required String jobId,
    required JobCancelReason reason,
  }) async {
    final job = _db.jobs[jobId];
    if (job == null) return;
    _db.jobs[jobId] =
        job.copyWith(status: JobStatus.cancelled, cancelReason: reason);
    _db.notify();
  }

  @override
  Future<void> updateJobContent({
    required String jobId,
    required String title,
    required String description,
    double? budget,
  }) async {
    final job = _db.jobs[jobId];
    if (job == null) throw StateError('İlan bulunamadı');
    if (job.status != JobStatus.open) {
      throw StateError('Yalnızca açık ilan düzenlenebilir');
    }
    // copyWith null'u "koru" sayar; bütçe kaldırılabilsin diye map üzerinden.
    _db.jobs[jobId] = Job.fromMap(jobId, {
      ...job.toMap(),
      'title': title,
      'description': description,
      'budget': budget,
    });
    _db.notify();
  }

  @override
  Future<void> deleteJob(String jobId) async {
    if (_db.jobs.remove(jobId) == null) return; // zaten yok — silinmiş say
    _db.notify();
  }
}

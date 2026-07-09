import '../../../data/local/mock_database.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
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
    required String professionCode,
    required List<ServiceArea> serviceAreas,
  }) async* {
    yield _nearby(professionCode, serviceAreas);
    yield* _db.changes.map((_) => _nearby(professionCode, serviceAreas));
  }

  List<Job> _nearby(String professionCode, List<ServiceArea> serviceAreas) {
    final now = DateTime.now();
    final list = _db.jobs.values.where((j) {
      if (j.status != JobStatus.open) return false;
      if (j.isExpiredAt(now)) return false;
      return j.matchesArtisan(
        professionCode: professionCode,
        serviceAreas: serviceAreas,
      );
    }).toList()
      // Her yeni ilan en üstte (usta #3); acil ilanlar rozetle vurgulanır.
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
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
  Stream<List<Job>> watchAssignedJobs(String artisanUid) async* {
    yield _assigned(artisanUid);
    yield* _db.changes.map((_) => _assigned(artisanUid));
  }

  List<Job> _assigned(String artisanUid) {
    final list = _db.jobs.values
        .where((j) => j.selectedArtisanId == artisanUid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Job?> getJob(String jobId) async => _db.jobs[jobId];

  @override
  Stream<Job?> watchJob(String jobId) async* {
    yield _db.jobs[jobId];
    yield* _db.changes.map((_) => _db.jobs[jobId]);
  }

  @override
  Future<void> selectOffer({
    required String jobId,
    required String offerId,
    required String artisanId,
    required String customerId,
    required String chatId,
  }) async {
    final job = _db.jobs[jobId];
    if (job == null) return;

    // Seçilen teklif accepted, diğerleri rejected.
    for (final o in _db.offers.values.where((o) => o.jobId == jobId).toList()) {
      final newStatus =
          o.offerId == offerId ? OfferStatus.accepted : OfferStatus.rejected;
      if (o.status == OfferStatus.withdrawn) continue;
      _db.offers[o.offerId] =
          o.copyWith(status: newStatus, updatedAt: DateTime.now());
    }

    _db.jobs[jobId] = job.copyWith(
      status: JobStatus.workerSelected,
      selectedOfferId: offerId,
      selectedArtisanId: artisanId,
      chatId: chatId,
    );
    _db.notify();
  }

  @override
  Future<void> markStarted(String jobId) async {
    final job = _db.jobs[jobId];
    if (job == null) return;
    _db.jobs[jobId] = job.copyWith(status: JobStatus.inProgress);
    _db.notify();
  }

  @override
  Future<void> confirmDone({
    required String jobId,
    required bool byCustomer,
  }) async {
    final job = _db.jobs[jobId];
    if (job == null) return;
    final customerDone = byCustomer || job.customerConfirmedDone;
    final artisanDone = !byCustomer || job.artisanConfirmedDone;
    final bothDone = customerDone && artisanDone;
    _db.jobs[jobId] = job.copyWith(
      customerConfirmedDone: customerDone,
      artisanConfirmedDone: artisanDone,
      status: bothDone ? JobStatus.completed : job.status,
      // CF paritesi: tek taraflı onayda karşı tarafa 3 günlük yanıt süresi
      // başlar (canlıda `onJobWritten` yazar, süre dolunca `autoCompleteJobs`
      // işi tamamlar). Sayı functions/index.js AUTO_COMPLETE_DAYS ile eş.
      autoCompleteAt: bothDone
          ? null // copyWith null'u "koru" sayar; bothDone'da alan zaten kullanılmaz
          : job.autoCompleteAt ?? DateTime.now().add(const Duration(days: 3)),
    );
    if (bothDone && job.selectedArtisanId != null) {
      _db.incrementCompletedJobs(job.selectedArtisanId!);
    }
    _db.notify();
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
  Future<void> markRated(String jobId) async {
    final job = _db.jobs[jobId];
    if (job == null) return;
    _db.jobs[jobId] = job.copyWith(status: JobStatus.rated);
    _db.notify();
  }

  @override
  Future<void> reportDispute({
    required String jobId,
    required bool byCustomer,
    required JobDisputeReason reason,
    String? note,
  }) async {
    final job = _db.jobs[jobId];
    if (job == null) throw StateError('İlan bulunamadı');
    if (!job.status.canDispute) {
      throw StateError('Bu durumda sorun bildirilemez');
    }
    _db.jobs[jobId] = job.copyWith(
      status: JobStatus.disputed,
      disputedBy:
          byCustomer ? JobDisputeParty.customer : JobDisputeParty.artisan,
      disputeReason: reason,
      disputeNote: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      disputedAt: DateTime.now(),
      statusBeforeDispute: job.status,
    );
    _db.notify();
  }

  @override
  Future<void> withdrawDispute(String jobId) async {
    final job = _db.jobs[jobId];
    if (job == null) throw StateError('İlan bulunamadı');
    if (job.status != JobStatus.disputed || job.statusBeforeDispute == null) {
      throw StateError('Geri çekilecek bir şikayet yok');
    }
    _db.jobs[jobId] = job.copyWith(
      status: job.statusBeforeDispute,
      clearDispute: true,
    );
    _db.notify();
  }
}

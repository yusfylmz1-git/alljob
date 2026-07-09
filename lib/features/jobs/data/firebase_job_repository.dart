import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
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
  CollectionReference<Map<String, dynamic>> get _offers =>
      _db.collection('offers');

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
    });
  }

  @override
  Stream<List<Job>> watchNearbyJobs({
    required String professionCode,
    required List<ServiceArea> serviceAreas,
  }) {
    // Sunucuda kategori+durum eşitliği + createdAt DESC sıralı ilk N ilan
    // (composite index: jobs category,status,createdAt). Böylece koleksiyon
    // büyüdükçe okuma sayısı sabit kalır. Coğrafi eşleşme/süre dolumu istemcide.
    return _jobs
        .where('category', isEqualTo: professionCode)
        .where('status', isEqualTo: JobStatus.open.apiValue)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.nearbyJobsFetchCap)
        .snapshots()
        .map((s) {
      final now = DateTime.now();
      final list = s.docs
          .map((d) => Job.fromMap(d.id, d.data()))
          .where((j) => !j.isExpiredAt(now))
          .where((j) => j.matchesArtisan(
                professionCode: professionCode,
                serviceAreas: serviceAreas,
              ))
          .toList()
        // Her yeni ilan en üstte (usta #3); acil ilanlar rozetle vurgulanır.
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
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
          .where((j) => !j.isExpiredAt(now))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(limit).toList();
    });
  }

  @override
  Stream<List<Job>> watchAssignedJobs(String artisanUid) {
    return _jobs
        .where('selectedArtisanId', isEqualTo: artisanUid)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Job.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
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
  Future<void> selectOffer({
    required String jobId,
    required String offerId,
    required String artisanId,
    required String customerId,
    required String chatId,
  }) async {
    final batch = _db.batch();

    batch.update(_jobs.doc(jobId), {
      'status': JobStatus.workerSelected.apiValue,
      'selectedOfferId': offerId,
      'selectedArtisanId': artisanId,
      'chatId': chatId,
    });

    // `customerId` filtresi kural ispatı için zorunlu: `offers` okuma kuralı
    // sahipliği sorgu filtresinden kanıtlayamazsa liste sorgusunun TAMAMI
    // permission-denied olur (bkz. watchOffersForJob'daki aynı ders).
    // İki eşitlik filtresi → composite index gerekmez.
    final offersSnap = await _offers
        .where('jobId', isEqualTo: jobId)
        .where('customerId', isEqualTo: customerId)
        .get();
    for (final d in offersSnap.docs) {
      final status = OfferStatus.fromString(d.data()['status'] as String?);
      if (status == OfferStatus.withdrawn) continue;
      batch.update(d.reference, {
        'status': (d.id == offerId ? OfferStatus.accepted : OfferStatus.rejected)
            .apiValue,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> markStarted(String jobId) async {
    await _jobs.doc(jobId).update({'status': JobStatus.inProgress.apiValue});
  }

  @override
  Future<void> confirmDone({
    required String jobId,
    required bool byCustomer,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _jobs.doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final job = Job.fromMap(snap.id, snap.data()!);
      final customerDone = byCustomer || job.customerConfirmedDone;
      final artisanDone = !byCustomer || job.artisanConfirmedDone;
      final bothDone = customerDone && artisanDone;
      tx.update(ref, {
        'customerConfirmedDone': customerDone,
        'artisanConfirmedDone': artisanDone,
        if (bothDone) 'status': JobStatus.completed.apiValue,
      });
    });
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
  Future<void> markRated(String jobId) async {
    await _jobs.doc(jobId).update({'status': JobStatus.rated.apiValue});
  }

  @override
  Future<void> reportDispute({
    required String jobId,
    required bool byCustomer,
    required JobDisputeReason reason,
    String? note,
  }) async {
    // Transaction: `statusBeforeDispute` o anki durumdan okunmalı (kural,
    // eski durumla birebir eşleşmesini doğrular).
    await _db.runTransaction((tx) async {
      final ref = _jobs.doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('İlan bulunamadı');
      final job = Job.fromMap(snap.id, snap.data()!);
      if (!job.status.canDispute) {
        throw StateError('Bu durumda sorun bildirilemez');
      }
      tx.update(ref, {
        'status': JobStatus.disputed.apiValue,
        'disputedBy': (byCustomer
                ? JobDisputeParty.customer
                : JobDisputeParty.artisan)
            .apiValue,
        'disputeReason': reason.apiValue,
        if (note != null && note.trim().isNotEmpty)
          'disputeNote': note.trim(),
        'disputedAt': DateTime.now().toIso8601String(),
        'statusBeforeDispute': job.status.apiValue,
      });
    });
  }

  @override
  Future<void> withdrawDispute(String jobId) async {
    await _db.runTransaction((tx) async {
      final ref = _jobs.doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('İlan bulunamadı');
      final job = Job.fromMap(snap.id, snap.data()!);
      if (job.status != JobStatus.disputed || job.statusBeforeDispute == null) {
        throw StateError('Geri çekilecek bir şikayet yok');
      }
      tx.update(ref, {
        'status': job.statusBeforeDispute!.apiValue,
        'disputedBy': FieldValue.delete(),
        'disputeReason': FieldValue.delete(),
        'disputeNote': FieldValue.delete(),
        'disputedAt': FieldValue.delete(),
        'statusBeforeDispute': FieldValue.delete(),
      });
    });
  }
}

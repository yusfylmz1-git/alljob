import '../../../data/local/mock_database.dart';
import '../../../data/models/offer.dart';
import 'offer_repository.dart';

/// Bellek içi [OfferRepository]. `offerCount` bakımı burada yapılır (mock'ta
/// Cloud Functions yerine).
class MockOfferRepository implements OfferRepository {
  MockOfferRepository(this._db);

  final MockDatabase _db;

  @override
  Future<void> submitOffer(Offer offer) async {
    final existing = _db.offers[offer.offerId];
    _db.offers[offer.offerId] = offer;

    // Yeni teklif (veya daha önce geri çekilmiş) → sayacı artır.
    final isNewActive = existing == null ||
        existing.status == OfferStatus.withdrawn;
    if (isNewActive) {
      final job = _db.jobs[offer.jobId];
      if (job != null) {
        _db.jobs[offer.jobId] = job.copyWith(offerCount: job.offerCount + 1);
      }
    }
    _db.notify();
  }

  @override
  Stream<List<Offer>> watchOffersForJob(String jobId) async* {
    yield _forJob(jobId);
    yield* _db.changes.map((_) => _forJob(jobId));
  }

  List<Offer> _forJob(String jobId) {
    final list = _db.offers.values
        .where((o) => o.jobId == jobId && o.status != OfferStatus.withdrawn)
        .toList()
      // Kabul edilen en üstte, sonra en yeni.
      ..sort((a, b) {
        final aAcc = a.status == OfferStatus.accepted;
        final bAcc = b.status == OfferStatus.accepted;
        if (aAcc != bAcc) return aAcc ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  @override
  Stream<List<Offer>> watchMyOffers(String artisanUid) async* {
    yield _mine(artisanUid);
    yield* _db.changes.map((_) => _mine(artisanUid));
  }

  List<Offer> _mine(String artisanUid) {
    final list = _db.offers.values
        .where((o) => o.artisanId == artisanUid)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<Offer?> myOfferFor({
    required String jobId,
    required String artisanUid,
  }) async {
    final o = _db.offers[Offer.idFor(jobId, artisanUid)];
    if (o == null || o.status == OfferStatus.withdrawn) return null;
    return o;
  }

  @override
  Future<void> withdrawOffer({
    required String jobId,
    required String artisanUid,
  }) async {
    final id = Offer.idFor(jobId, artisanUid);
    final o = _db.offers[id];
    if (o == null || o.status == OfferStatus.withdrawn) return;
    _db.offers[id] =
        o.copyWith(status: OfferStatus.withdrawn, updatedAt: DateTime.now());
    final job = _db.jobs[jobId];
    if (job != null && job.offerCount > 0) {
      _db.jobs[jobId] = job.copyWith(offerCount: job.offerCount - 1);
    }
    _db.notify();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/offer.dart';
import 'offer_repository.dart';

/// Firestore `offers` ile çalışan [OfferRepository]. Tekillik döküman ID'si
/// ([Offer.idFor]) ile sağlanır. `jobs.offerCount` sayacını `onOfferWritten`
/// Cloud Function'ı tutar (istemci artık yazmaz) — böylece sayaç her zaman
/// tutarlıdır ve güvenlik kuralı istemciye offerCount yazma izni vermek
/// zorunda değildir.
class FirebaseOfferRepository implements OfferRepository {
  FirebaseOfferRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _db.collection('offers');

  @override
  Future<void> submitOffer(Offer offer) async {
    // offerCount sunucuda (onOfferWritten CF) güncellenir; istemci yalnızca
    // teklif dökümanını yazar.
    await _offers.doc(offer.offerId).set(offer.toMap());
  }

  @override
  Stream<List<Offer>> watchOffersForJob(String jobId) {
    return _offers.where('jobId', isEqualTo: jobId).snapshots().map((s) {
      final list = s.docs
          .map((d) => Offer.fromMap(d.id, d.data()))
          .where((o) => o.status != OfferStatus.withdrawn)
          .toList()
        ..sort((a, b) {
          final aAcc = a.status == OfferStatus.accepted;
          final bAcc = b.status == OfferStatus.accepted;
          if (aAcc != bAcc) return aAcc ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
      return list;
    });
  }

  @override
  Stream<List<Offer>> watchMyOffers(String artisanUid) {
    return _offers.where('artisanId', isEqualTo: artisanUid).snapshots().map((s) {
      final list = s.docs.map((d) => Offer.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Future<Offer?> myOfferFor({
    required String jobId,
    required String artisanUid,
  }) async {
    final snap = await _offers.doc(Offer.idFor(jobId, artisanUid)).get();
    if (!snap.exists || snap.data() == null) return null;
    final o = Offer.fromMap(snap.id, snap.data()!);
    return o.status == OfferStatus.withdrawn ? null : o;
  }

  @override
  Future<void> withdrawOffer({
    required String jobId,
    required String artisanUid,
  }) async {
    final ref = _offers.doc(Offer.idFor(jobId, artisanUid));
    final snap = await ref.get();
    if (!snap.exists) return;
    if (OfferStatus.fromString(snap.data()?['status'] as String?) ==
        OfferStatus.withdrawn) {
      return;
    }
    // offerCount'u onOfferWritten CF yeniden hesaplar (istemci dokunmaz).
    await ref.update({
      'status': OfferStatus.withdrawn.apiValue,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}

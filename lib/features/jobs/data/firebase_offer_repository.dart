import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/offer.dart';
import 'offer_repository.dart';

/// Firestore `offers` ile çalışan [OfferRepository]. Tekillik döküman ID'si
/// ([Offer.idFor]) ile sağlanır. `jobs.offerCount` sayacını `onOfferWritten`
/// Cloud Function'ı tutar (istemci artık yazmaz).
///
/// **Idempotent submit:** Döküman yoksa create; `withdrawn` ise yalnız
/// rules'ın izin verdiği alanlarla `pending`'e döner; zaten aktifse no-op.
/// Full `set` mevcut dökümanda permission-denied üretir (H1 alan kısıtı).
class FirebaseOfferRepository implements OfferRepository {
  FirebaseOfferRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _db.collection('offers');

  @override
  Future<void> submitOffer(Offer offer) async {
    final ref = _offers.doc(offer.offerId);
    final snap = await ref.get();

    if (!snap.exists) {
      // İlk ilgi: create (rules: isEmailVerified + H3 + open job).
      await ref.set(offer.toMap());
      return;
    }

    final data = snap.data() ?? const <String, dynamic>{};
    final status = OfferStatus.fromString(data['status'] as String?);

    // Zaten aktif ilgi → tekrar yazma (sohbet açmak yeterli).
    if (status == OfferStatus.pending || status == OfferStatus.accepted) {
      return;
    }

    // Geri çekilmiş → rules-legal alanlarla yeniden pending.
    if (status == OfferStatus.withdrawn) {
      await ref.update({
        'status': OfferStatus.pending.apiValue,
        'updatedAt': DateTime.now().toIso8601String(),
        'note': offer.note,
        'price': offer.price,
        'priceType': offer.priceType.apiValue,
      });
      return;
    }

    // rejected: başka usta seçildiyse iş kapalıdır; sessiz no-op.
  }

  @override
  Stream<List<Offer>> watchOffersForJob({
    required String jobId,
    required String customerId,
  }) {
    // customerId filtresi güvenlik kuralının sorgudan KANITLANMASI içindir.
    return _offers
        .where('jobId', isEqualTo: jobId)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((s) {
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
    await ref.update({
      'status': OfferStatus.withdrawn.apiValue,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}

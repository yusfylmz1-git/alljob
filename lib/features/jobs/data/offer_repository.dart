import '../../../data/models/offer.dart';

/// Teklif verisi soyutlaması. Bir usta bir ilana yalnızca 1 kez teklif verebilir
/// (#1); tekillik döküman ID'si ([Offer.idFor]) ile sağlanır. Aynı teklif
/// güncellenebilir (#7) veya geri çekilebilir.
abstract interface class OfferRepository {
  /// Teklifi oluşturur veya günceller (upsert). Yeni bir teklifse ilgili ilanın
  /// `offerCount` sayacı 1 artırılır; güncellemede değişmez.
  Future<void> submitOffer(Offer offer);

  /// Bir ilana gelen teklifler (müşteri incelemesi) — canlı akış.
  Stream<List<Offer>> watchOffersForJob(String jobId);

  /// Ustanın verdiği teklifler (Tekliflerim) — canlı akış.
  Stream<List<Offer>> watchMyOffers(String artisanUid);

  /// Ustanın bu ilana verdiği teklif (varsa) — teklif ver ekranını doldurmak için.
  Future<Offer?> myOfferFor({required String jobId, required String artisanUid});

  /// Ustanın teklifini geri çeker (#7). `offerCount` 1 azaltılır.
  Future<void> withdrawOffer({required String jobId, required String artisanUid});
}

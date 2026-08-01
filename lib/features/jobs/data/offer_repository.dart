import '../../../data/models/offer.dart';

/// Teklif verisi soyutlaması. Bir usta bir ilana yalnızca 1 kez teklif verebilir
/// (#1); tekillik döküman ID'si ([Offer.idFor]) ile sağlanır. Aynı teklif
/// güncellenebilir (#7) veya geri çekilebilir.
abstract interface class OfferRepository {
  /// Teklifi oluşturur veya günceller (upsert). Yeni bir teklifse ilgili ilanın
  /// `offerCount` sayacı 1 artırılır; güncellemede değişmez.
  Future<void> submitOffer(Offer offer);

  /// Bir ilana gelen teklifler (müşteri incelemesi) — canlı akış.
  ///
  /// [customerId] = ilan sahibinin uid'i. Firestore güvenlik kuralı okuma
  /// iznini "ilan sahibi müşteri" koşuluna bağlar; liste sorgularında bu
  /// koşulun SORGU FİLTRESİNDEN kanıtlanabilir olması gerekir — yalnız
  /// jobId'yle sorgu, kural yüzünden komple permission-denied alır.
  Stream<List<Offer>> watchOffersForJob({
    required String jobId,
    required String customerId,
  });

  /// Ustanın verdiği teklifler (Tekliflerim) — canlı akış.
  Stream<List<Offer>> watchMyOffers(String artisanUid);

  /// Bu müşterinin TÜM ilanlarına, BELİRLİ bir ustadan gelen ilgi kayıtları.
  ///
  /// Sohbet ekranındaki "Ustayı Seç" şeridi için: `chatId` ilandan TÜREMEZ
  /// (`chatIdFor(müşteri, usta)`), yani aynı çift bütün ilanlarında tek sohbeti
  /// paylaşır. Sohbetten hangi ilanların seçilebilir olduğu ancak bu kesişimle
  /// bulunur.
  ///
  /// [customerId] filtresi güvenlik kuralının SORGUDAN kanıtı için ZORUNLU
  /// (bkz. [watchOffersForJob] notu). `artisanId` ve `status` bilerek istemcide
  /// süzülür: tek eşitlik filtresi kalsın, composite index gerekmesin.
  Stream<List<Offer>> watchOffersFromArtisan({
    required String customerId,
    required String artisanId,
  });

  /// Ustanın bu ilana verdiği teklif (varsa) — teklif ver ekranını doldurmak için.
  Future<Offer?> myOfferFor({required String jobId, required String artisanUid});

  /// Ustanın teklifini geri çeker (#7). `offerCount` 1 azaltılır.
  Future<void> withdrawOffer({required String jobId, required String artisanUid});
}

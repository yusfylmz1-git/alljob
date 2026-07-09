import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';

/// İş ilanı verisi soyutlaması (çift taraflı pazaryeri). Mock ile başlar,
/// Firestore ile değiştirilir. Akışlar (Stream) gerçek-zamanlı listelemeyi
/// sağlar (Firestore snapshot / mock tick).
abstract interface class JobRepository {
  /// Yeni ilan oluşturur, oluşturulan jobId'yi döner.
  Future<String> createJob(Job job);

  /// Müşterinin kendi ilanları (İlanlarım) — en yeni en üstte.
  Stream<List<Job>> watchMyJobs(String customerUid);

  /// Ustaya uygun açık ilanlar (Yakındaki İşler, #1): meslek + hizmet bölgesi
  /// eşleşmesi. Süresi dolmuş/kapanmış ilanlar elenir.
  Stream<List<Job>> watchNearbyJobs({
    required String professionCode,
    required List<ServiceArea> serviceAreas,
  });

  /// Ustanın seçildiği (aktif/tamamlanan) işler — usta "İşlerim" / dashboard.
  Stream<List<Job>> watchAssignedJobs(String artisanUid);

  /// Herkese açık son ilanlar (Keşfet "İş İlanları" paneli): tüm açık ve
  /// süresi dolmamış ilanlar, en yeni en üstte, [limit] adetle sınırlı.
  Stream<List<Job>> watchOpenJobs({int limit = 30});

  Future<Job?> getJob(String jobId);

  /// Tek bir ilanı canlı izler (detay ekranı).
  Stream<Job?> watchJob(String jobId);

  /// Müşteri bir teklifi seçer (#6): ilan `workerSelected` olur, seçilen teklif
  /// `accepted`, diğer teklifler `rejected`; [chatId] ilana yazılır (sohbet
  /// çağıran tarafından açılmış olmalıdır). [customerId] = ilan sahibi;
  /// Firestore `offers` liste sorgusunun kural ispatı için zorunlu (kural
  /// `customerId == auth.uid` ister; filtresiz sorgu komple reddedilir).
  Future<void> selectOffer({
    required String jobId,
    required String offerId,
    required String artisanId,
    required String customerId,
    required String chatId,
  });

  /// Seçilen usta işe başladı → `inProgress`.
  Future<void> markStarted(String jobId);

  /// Bir taraf işi tamamlandı olarak onaylar. İki taraf da onaylayınca ilan
  /// `completed` olur (#10).
  Future<void> confirmDone({required String jobId, required bool byCustomer});

  /// Müşteri ilanı iptal eder (#11).
  Future<void> cancelJob({
    required String jobId,
    required JobCancelReason reason,
  });

  /// Taraflardan biri işle ilgili sorun bildirir → ilan `disputed` olur,
  /// yaşam döngüsü donar (önceki durum `statusBeforeDispute`'ta saklanır).
  /// Yalnızca workerSelected/inProgress/completed durumlarında çağrılabilir;
  /// aksi halde [StateError] fırlatır.
  Future<void> reportDispute({
    required String jobId,
    required bool byCustomer,
    required JobDisputeReason reason,
    String? note,
  });

  /// Sorunu bildiren taraf şikayetini geri çeker → ilan şikayet öncesi
  /// durumuna döner, dispute alanları temizlenir.
  Future<void> withdrawDispute(String jobId);

  /// Puanlama sonrası ilan `rated` olur.
  Future<void> markRated(String jobId);

  /// İlan içeriğini günceller (başlık/açıklama/bütçe). Yalnızca `open`
  /// durumdaki ilanlar için (kural da bunu doğrular); 1 saatlik düzenleme
  /// penceresi ([Job.editWindow]) UI/istemcide kesilir. [budget] null ise
  /// bütçe beklentisi kaldırılır.
  Future<void> updateJobContent({
    required String jobId,
    required String title,
    required String description,
    double? budget,
  });

  /// İlanı kalıcı olarak siler. Yalnızca bir ustaya bağlanmamış
  /// (open/expired/cancelled) ilanlar silinebilir ([Job.canDelete]); değilse
  /// [StateError] fırlatır. Bağlı teklifleri canlıda CF temizler.
  Future<void> deleteJob(String jobId);
}

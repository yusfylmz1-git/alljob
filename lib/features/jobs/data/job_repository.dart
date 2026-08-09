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

  /// Ustaya uygun açık ilanlar (Yakındaki İşler, #1): meslek(ler) + bölge.
  /// [professionCodes] boşsa [professionCode] kullanılır (geriye uyum).
  Stream<List<Job>> watchNearbyJobs({
    String? professionCode,
    List<String>? professionCodes,
    required List<ServiceArea> serviceAreas,
  });

  /// Açık + süresi dolmamış ilanlar (en yeni üstte, [limit]).
  /// Keşfet "İş İlanları" paneli (usta modu) ve testler.
  Stream<List<Job>> watchOpenJobs({int limit = 30});

  Future<Job?> getJob(String jobId);

  /// Tek bir ilanı canlı izler (detay ekranı).
  Stream<Job?> watchJob(String jobId);

  /// Müşteri ilanı iptal eder (#11).
  Future<void> cancelJob({
    required String jobId,
    required JobCancelReason reason,
  });

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

  /// İlanı kalıcı olarak siler. İlan bir duyuru olduğundan sahibi her zaman
  /// silebilir; sohbetler ilandan bağımsız yaşar, mesaj geçmişi gitmez.
  Future<void> deleteJob(String jobId);
}

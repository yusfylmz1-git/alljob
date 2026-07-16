import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import '../../auth/application/auth_controller.dart';
import 'firebase_job_repository.dart';
import 'firebase_offer_repository.dart';
import 'job_repository.dart';
import 'mock_job_repository.dart';
import 'mock_offer_repository.dart';
import 'offer_repository.dart';

/// Aktif iş ilanı repo'su. Backend seçimi [useFirebaseBackend] ile.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  if (useFirebaseBackend) return FirebaseJobRepository();
  return MockJobRepository(ref.watch(mockDatabaseProvider));
});

/// Aktif teklif repo'su.
final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  if (useFirebaseBackend) return FirebaseOfferRepository();
  return MockOfferRepository(ref.watch(mockDatabaseProvider));
});

/// Keşfet "İş İlanları" paneli (yalnız usta modu): tüm açık ilanlar, en yeni üstte.
final openJobsProvider = StreamProvider<List<Job>>(
  (ref) => ref.watch(jobRepositoryProvider).watchOpenJobs(),
);

/// Müşterinin kendi ilanları (İlanlarım).
final myJobsProvider = StreamProvider.family<List<Job>, String>(
  (ref, customerUid) =>
      ref.watch(jobRepositoryProvider).watchMyJobs(customerUid),
);

/// Tek bir ilanı canlı izler (detay ekranı).
final jobProvider = StreamProvider.family<Job?, String>(
  (ref, jobId) => ref.watch(jobRepositoryProvider).watchJob(jobId),
);

/// Sohbet ekranı üst bandı: bu sohbete bağlı aktif/bağlı iş.
final jobByChatIdProvider = StreamProvider.family<Job?, String>(
  (ref, chatId) => ref.watch(jobRepositoryProvider).watchJobByChatId(chatId),
);

/// Bir ilana gelen teklifler (müşteri incelemesi). Sorgu, güvenlik kuralının
/// gerektirdiği sahiplik kanıtı için oturumdaki kullanıcının uid'iyle filtreli
/// (yalnız ilan sahibi bu listeyi görür; ekran zaten sahibin görünümü).
final offersForJobProvider = StreamProvider.family<List<Offer>, String>(
  (ref, jobId) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return Stream.value(const <Offer>[]);
    return ref
        .watch(offerRepositoryProvider)
        .watchOffersForJob(jobId: jobId, customerId: uid);
  },
);

/// Ustanın verdiği teklifler (Tekliflerim).
final myOffersProvider = StreamProvider.family<List<Offer>, String>(
  (ref, artisanUid) =>
      ref.watch(offerRepositoryProvider).watchMyOffers(artisanUid),
);

/// Ustanın seçildiği işler (usta "İşlerim" / dashboard aktif iş).
final assignedJobsProvider = StreamProvider.family<List<Job>, String>(
  (ref, artisanUid) =>
      ref.watch(jobRepositoryProvider).watchAssignedJobs(artisanUid),
);

/// Oturum açmış ustaya uygun açık ilanlar (Yakındaki İşler).
///
/// ÖNEMLİ: `async*` + `await ref.watch(...future)` kullanma — Riverpod'da
/// async gap sonrası watch ANR / yeniden giriş döngüsü üretebiliyor.
/// Profil henüz yoksa boş liste; ekran profil loading'ini ayrıca gösterir.
final nearbyJobsProvider = StreamProvider<List<Job>>((ref) {
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  if (draft == null) {
    return Stream.value(const <Job>[]);
  }
  final profile = draft.profile;
  if (profile.professionCodes.isEmpty ||
      profile.serviceAreas.isEmpty ||
      !profile.isAvailable) {
    return Stream.value(const <Job>[]);
  }
  final uid = profile.uid;
  return ref.read(jobRepositoryProvider).watchNearbyJobs(
        professionCodes: profile.professionCodes,
        serviceAreas: profile.serviceAreas,
      ).map((jobs) => jobs.where((j) => j.customerId != uid).toList());
});

/// Ustanın şu an müsait olup olmadığı (feed/ekran mesajları için kısayol).
final artisanIsAvailableProvider = Provider<bool>((ref) {
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  return draft?.profile.isAvailable ?? false;
});

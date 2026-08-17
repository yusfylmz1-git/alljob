import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/job.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import '../../auth/application/auth_controller.dart';
import 'firebase_job_repository.dart';
import 'job_repository.dart';
import 'mock_job_repository.dart';

/// Aktif iş ilanı repo'su. Backend seçimi [useFirebaseBackend] ile.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  if (useFirebaseBackend) return FirebaseJobRepository();
  return MockJobRepository(ref.watch(mockDatabaseProvider));
});

/// Keşfet "İş İlanları" paneli (yalnız usta modu): tüm açık ilanlar, en yeni üstte.
final openJobsProvider = StreamProvider<List<Job>>(
  (ref) => ref.watch(jobRepositoryProvider).watchOpenJobs(),
);

/// Ana sayfadaki "Hemen Lazım" şeridi: açık Hemen Lazım ilanları, en yeni
/// üstte. [openJobsProvider] üzerinden süzülür — ayrı sorgu/indeks açmaz ve
/// ana sayfa yenilemesi (openJobs invalidate) bu bölümü de tazeler.
///
/// NOT: Buradaki liste açık ilanların son [AppConstants.openJobsFetchCap]
/// tanesinden süzülür; Hemen Lazım ilanı yoğun bir günde eskiler görünmeyebilir
/// — "Tümünü Gör" kendi listesine götürür.
final quickSupportJobsProvider = Provider<List<Job>>((ref) {
  final jobs = ref.watch(openJobsProvider).valueOrNull ?? const <Job>[];
  return jobs.where((j) => j.isQuickSupport).toList(growable: false);
});

/// Mağaza > Talepler: açık ürün talepleri, en yeni üstte.
///
/// [openJobsProvider] üzerinden süzülür — [quickSupportJobsProvider] ile
/// aynı desen: ayrı sorgu/indeks açmaz. Bu talepler USTA feed'ine düşmez
/// (`Job.matchesArtisan` erken `false` döner); burası tek görünür yerleri.
final productRequestsProvider = Provider<List<Job>>((ref) {
  final jobs = ref.watch(openJobsProvider).valueOrNull ?? const <Job>[];
  return jobs.where((j) => j.isProductRequest).toList(growable: false);
});

/// Müşterinin kendi ilanları (İlanlarım).
final myJobsProvider = StreamProvider.family<List<Job>, String>(
  (ref, customerUid) =>
      ref.watch(jobRepositoryProvider).watchMyJobs(customerUid),
);

/// Tek bir ilanı canlı izler (detay ekranı).
final jobProvider = StreamProvider.family<Job?, String>(
  (ref, jobId) => ref.watch(jobRepositoryProvider).watchJob(jobId),
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
  // MÜSAİTLİK burada ELEMEZ (2026-08-10, kullanıcı kararı): müsait olmayan
  // usta ilanları GÖRÜR ve bildirim ALIR, yalnız MESAJ ATAMAZ. Eskiden feed
  // tamamen boşalıyordu; usta müsaitliğini açmadan piyasada ne olduğunu
  // göremiyordu. Mesaj kapısı yerinde duruyor (_ArtisanOfferSection).
  if (profile.professionCodes.isEmpty || profile.serviceAreas.isEmpty) {
    return Stream.value(const <Job>[]);
  }
  final uid = profile.uid;
  return ref.read(jobRepositoryProvider).watchNearbyJobs(
        professionCodes: profile.professionCodes,
        serviceAreas: profile.serviceAreas,
      ).map((jobs) => jobs.where((j) => j.customerId != uid).toList());
});

/// Ustanın şu an müsait olup olmadığı (feed/ekran mesajları için kısayol).
/// `users.available` ile vitrin müsaitliğini birlikte okur.
final artisanIsAvailableProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (!user.available) return false;
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  if (draft != null && !draft.profile.isAvailable) return false;
  return true;
});

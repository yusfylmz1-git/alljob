import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import 'admin_dispute_repository.dart';
import 'admin_report.dart';
import 'admin_report_repository.dart';

/// Oturumdaki kullanıcı yönetici mi? (Auth custom claim'inden.)
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider.select((u) => u?.isAdmin ?? false));
});

final adminReportRepositoryProvider = Provider<AdminReportRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminReportRepository();
  final repo = MockAdminReportRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Şikayet kuyruğu (tüm kayıtlar, en yeni üstte). Yalnız yönetici için akar;
/// yönetici değilse boş (kural zaten okumayı reddeder — istemci de guard eder).
final adminReportsProvider = StreamProvider<List<Report>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const <Report>[]);
  return ref.watch(adminReportRepositoryProvider).watchReports();
});

/// Açık (çözülmemiş) şikayet sayısı — menü rozeti için.
final openReportCountProvider = Provider<int>((ref) {
  final list = ref.watch(adminReportsProvider).valueOrNull ?? const [];
  return list.where((r) => !r.status.isClosed).length;
});

final adminDisputeRepositoryProvider = Provider<AdminDisputeRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminDisputeRepository();
  final repo = MockAdminDisputeRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Hakemlik kuyruğu: `disputed` durumundaki işler (en yeni bildirilen üstte).
/// Yalnız yönetici için akar; değilse boş (kural okumayı zaten kısıtlamaz ama
/// istemci de guard eder — panel dışı istemci bu provider'ı watch etmez).
final adminDisputesProvider = StreamProvider<List<Job>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const <Job>[]);
  return ref.watch(adminDisputeRepositoryProvider).watchDisputes();
});

/// Açık anlaşmazlık sayısı — sekme/menü rozeti için.
final openDisputeCountProvider = Provider<int>((ref) {
  return ref.watch(adminDisputesProvider).valueOrNull?.length ?? 0;
});

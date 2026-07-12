import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';
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

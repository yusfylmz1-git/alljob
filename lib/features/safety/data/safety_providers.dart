import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/blocked_user.dart';
import '../../auth/application/auth_controller.dart';
import 'block_repository.dart';
import 'firebase_block_repository.dart';
import 'firebase_report_repository.dart';
import 'report_repository.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  if (useFirebaseBackend) return FirebaseBlockRepository();
  final repo = MockBlockRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (useFirebaseBackend) return FirebaseReportRepository();
  return MockReportRepository();
});

/// Oturumdaki kullanıcının engellediği kullanıcılar (canlı). Oturum yoksa boş.
final myBlockedListProvider = StreamProvider<List<BlockedUser>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(blockRepositoryProvider).watchBlocked(uid);
});

/// Hızlı üyelik kontrolü için uid kümesi (sohbet listesi filtresi, menüler).
final myBlockedUidsProvider = Provider<Set<String>>((ref) {
  final list = ref.watch(myBlockedListProvider).valueOrNull ?? const [];
  return {for (final b in list) b.uid};
});

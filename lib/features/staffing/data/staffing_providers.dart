import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/staffing.dart';
import 'firebase_staffing_repository.dart';
import 'staffing_repository.dart';

final staffingRepositoryProvider = Provider<StaffingRepository>((ref) {
  if (useFirebaseBackend) return FirebaseStaffingRepository();
  return MockStaffingRepository();
});

/// Açık iş arayan elemanlar. [dailyOnly]=true → yalnız gündelik.
final openWorkersProvider = StreamProvider.family<List<StaffWorkerListing>,
    ({String? province, bool? dailyOnly})>((ref, filter) {
  return ref.watch(staffingRepositoryProvider).watchOpenWorkers(
        province: filter.province,
        dailyOnly: filter.dailyOnly,
      );
});

final myWorkerListingProvider =
    StreamProvider.family<StaffWorkerListing?, String>((ref, uid) {
  return ref.watch(staffingRepositoryProvider).watchMyWorkerListing(uid);
});

final openStaffNeedsProvider = StreamProvider.family<List<StaffNeed>,
    ({String? province, bool? dailyOnly})>((ref, filter) {
  return ref.watch(staffingRepositoryProvider).watchOpenNeeds(
        province: filter.province,
        dailyOnly: filter.dailyOnly,
      );
});

final myStaffNeedsProvider =
    StreamProvider.family<List<StaffNeed>, String>((ref, uid) {
  return ref.watch(staffingRepositoryProvider).watchMyNeeds(uid);
});

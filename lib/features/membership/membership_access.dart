import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_runtime_config.dart';
import '../../core/constants/app_constants.dart';
import '../artisan/application/my_profile_controller.dart';
import 'membership_package.dart';

/// Usta Pro özellikleri (müsaitlik, yakındaki işler vb.) açık mı?
///
/// Öncelik:
/// 1. Sunucu `isPremium` (Play Billing doğrulaması — faz 2+)
/// 2. Seçili plan: Beta / Pro → açık; Ücretsiz → kapalı
/// 3. Plan seçilmemişse remote/local `premiumFreeDuringBeta`
bool artisanProUnlocked({
  required MembershipPackage? package,
  required bool hasPaidPremium,
  required bool freeDuringBetaGlobal,
}) {
  if (hasPaidPremium) return true;
  switch (package) {
    case MembershipPackage.free:
      return false;
    case MembershipPackage.beta:
    case MembershipPackage.pro:
      return true;
    case null:
      return freeDuringBetaGlobal;
  }
}

/// UI ve kapılar için tek kaynak.
final artisanProAccessProvider = Provider<bool>((ref) {
  final pack = ref.watch(selectedMembershipPackageProvider);
  final freeBeta = ref.watch(appRuntimeConfigProvider).valueOrNull
          ?.premiumFreeDuringBeta ??
      AppConstants.premiumFreeDuringBeta;
  final paid = ref.watch(myProfileControllerProvider).valueOrNull?.profile
          .hasActivePremium ??
      false;
  return artisanProUnlocked(
    package: pack,
    hasPaidPremium: paid,
    freeDuringBetaGlobal: freeBeta,
  );
});

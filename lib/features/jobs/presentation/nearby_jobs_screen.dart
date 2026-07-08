import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// Usta: Yakınımdaki İş İlanları — meslek + hizmet bölgesi eşleşen açık ilanlar.
class NearbyJobsScreen extends ConsumerWidget {
  const NearbyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(artisanIsAvailableProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Hizmetlerim',
        subtitle: 'Yakınındaki iş ilanları',
        icon: Icons.handyman_outlined,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('İletişimlerim'),
            onPressed: () => context.push(RoutePaths.panelOffers),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.work),
      body: !available
          ? const _NotAvailableNotice()
          : ref.watch(nearbyJobsProvider).when(
            loading: () => const SkeletonList(),
            error: (e, _) => Center(child: Text('İşler yüklenemedi.\n$e')),
            data: (jobs) => jobs.isEmpty
                ? const _EmptyNearby()
                : ResponsiveCenter(
                    maxWidth: 720,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => NearbyJobCard(job: jobs[i]),
                    ),
                  ),
          ),
    );
  }
}

/// Usta müsait değilken gösterilir: iş ilanları görünmez.
class _NotAvailableNotice extends ConsumerWidget {
  const _NotAvailableNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    final isPremium = draft?.profile.hasActivePremium ?? false;

    Future<void> enable() async {
      final ctrl = ref.read(myProfileControllerProvider.notifier);
      if (!isPremium) {
        context.push(RoutePaths.panelPremium);
        return;
      }
      final ok = await ctrl.setAvailable(true);
      if (context.mounted && ok) context.showInfo('Artık müsait görünüyorsunuz.');
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.warningSurface, shape: BoxShape.circle),
              child: const Icon(Icons.do_not_disturb_on_outlined,
                  size: 34, color: AppColors.warning),
            ),
            const SizedBox(height: 16),
            Text('Şu an müsait değilsiniz',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'İş ilanlarını görmek ve müşterilerin sizi bulabilmesi için '
              '"Müsait" olmanız gerekir. Müsaitlik Premium üyelik gerektirir.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: enable,
              icon: Icon(isPremium ? Icons.check_circle_outline : Icons.workspace_premium),
              label: Text(isPremium ? 'Müsait Ol' : 'Premium Ol ve Müsait Görün'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.work_outline,
                  size: 34, color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Yakında iş ilanı yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Mesleğinize ve hizmet bölgenize uygun yeni ilanlar burada görünecek. '
              'Profilinizin (meslek + bölge) dolu olduğundan emin olun.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

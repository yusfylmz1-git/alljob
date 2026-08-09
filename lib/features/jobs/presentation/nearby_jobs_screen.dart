import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/surface_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/geo_models.dart' show ServiceArea;
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/shop_completion.dart';
import '../../artisan/presentation/widgets/shop_completion_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../membership/membership_access.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// Usta "İşler" sekmesi: meslek + hizmet bölgesi eşleşen açık ilanlar.
///
/// Eskiden ikinci bir "İlgilendiğim" sekmesi vardı (teklif verdiğim ilanlar).
/// Teklif akışı kalktı — usta ilan sahibine doğrudan mesaj atar, "ilgilendiğim
/// iş" kaydı diye bir şey yok; takip mesaj kutusundan yürür.
class NearbyJobsScreen extends ConsumerWidget {
  NearbyJobsScreen({super.key});

  /// Yan menü açıkken geri tuşunun menüyü kapatabilmesi için (madde 4).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MainTabScope(
      tab: MainTab.work,
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: const SurfaceAppBar(
          title: 'İşler',
          subtitle: 'Yakınındaki açık ilanlar',
          icon: Icons.handyman_outlined,
        ),
        drawer: const AppMenuDrawer(),
        bottomNavigationBar: const MainBottomBar(current: MainTab.work),
        body: const _NearbyTab(),
      ),
    );
  }
}

/// "Yakınımdaki" sekmesinin gövdesi (eski ekranın tamamı).
class _NearbyTab extends ConsumerWidget {
  const _NearbyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(myProfileControllerProvider);
    final hasAccess = ref.watch(artisanProAccessProvider);

    return profileAsync.when(
      loading: () => const SkeletonList(),
      error: (_, _) => ErrorView(
        message:
            'Profil yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
        onRetry: () => ref.invalidate(myProfileControllerProvider),
      ),
      data: (draft) {
        if (!hasAccess) return const _PlanLockedNotice();

        final completion = user == null
            ? null
            : ShopCompletion.from(user: user, draft: draft);

        if (completion != null && !completion.canMatchJobs) {
          return _ProfileIncompleteNotice(completion: completion);
        }
        // MÜSAİTLİK artık listeyi KAPATMAZ (2026-08-10, kullanıcı kararı):
        // usta ilanları görür ve bildirim alır, yalnız mesaj atamaz. Eskiden
        // burada tam ekran "müsait değilsiniz" duvarı vardı ve usta piyasada
        // ne olduğunu göremiyordu. Uyarı artık listenin üstünde şerit olarak
        // durur; mesaj kapısı ilan detayında zaten korunuyor.
        // İlan listesi ayrı widget — nested .when + çift watch ANR riskini azaltır.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!draft.profile.isAvailable) const _NotAvailableBanner(),
            Expanded(child: _NearbyJobsBody(completion: completion)),
          ],
        );
      },
    );
  }
}

class _NearbyJobsBody extends ConsumerWidget {
  const _NearbyJobsBody({required this.completion});
  final ShopCompletion? completion;

  Future<void> _refresh(WidgetRef ref) => awaitRefresh(() async {
        ref.invalidate(nearbyJobsProvider);
        try {
          await ref.read(nearbyJobsProvider.future);
        } catch (_) {}
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(nearbyJobsProvider);
    // Hemen Lazım ilanları il geneline gelir → kendi ilçesindekiler
    // "Yakınında" rozetiyle ayrışsın (sıralamada da öndeler).
    final myAreas = ref
            .watch(myProfileControllerProvider)
            .valueOrNull
            ?.profile
            .serviceAreas ??
        const <ServiceArea>[];

    return jobsAsync.when(
      loading: () => const SkeletonList(),
      error: (_, _) => RefreshableEmpty(
        onRefresh: () => _refresh(ref),
        child: ErrorView(
          message:
              'İşler yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
          onRetry: () => ref.invalidate(nearbyJobsProvider),
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return RefreshableEmpty(
            onRefresh: () => _refresh(ref),
            child: _EmptyNearby(completion: completion),
          );
        }
        final showBanner =
            completion != null && !completion!.isComplete;
        return ResponsiveCenter(
          maxWidth: 720,
          child: PullToRefresh(
            onRefresh: () => _refresh(ref),
            child: ListView.builder(
              physics: kPullRefreshPhysics,
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length + (showBanner ? 1 : 0),
              itemBuilder: (context, i) {
                if (showBanner && i == 0) {
                  return Column(
                    children: [
                      ShopCompletionBanner(
                        completion: completion!,
                        compact: true,
                        title: 'Vitrini güçlendirin',
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                final idx = showBanner ? i - 1 : i;
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: idx < jobs.length - 1 ? 12 : 0),
                  child: NearbyJobCard(
                    job: jobs[idx],
                    // Rozet yalnız il geneline gelen Hemen Lazım ilanlarında
                    // anlamlı; klasik ilanlar zaten hep kendi ilçesinden.
                    isNearby: jobs[idx].isQuickSupport &&
                        jobs[idx].isNearbyForAreas(myAreas),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PlanLockedNotice extends StatelessWidget {
  const _PlanLockedNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.premiumSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium_outlined,
                  size: 34, color: palette.premium),
            ),
            const SizedBox(height: 16),
            Text(
              'Pro özellikler kilitli',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Yakındaki işleri görmek ve müsait görünmek için Beta veya Pro '
              'plan seçin. Beta şu an ücretsiz.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  context.push('${RoutePaths.packageSelect}?change=1'),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Beta planına geç'),
            ),
            TextButton(
              onPressed: () => context.push(RoutePaths.panelPremium),
              child: const Text('Pro hakkında'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIncompleteNotice extends StatelessWidget {
  const _ProfileIncompleteNotice({required this.completion});
  final ShopCompletion completion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ShopCompletionBanner(
          completion: completion,
          title: 'Önce vitrininizi tamamlayın',
        ),
        const SizedBox(height: 16),
        Text(
          'Yakındaki işler, seçtiğiniz meslek ve hizmet bölgelerine göre '
          'eşleşir. Eksik adımları tamamlayınca ilanlar burada listelenir.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.inkMuted,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}


/// Usta müsait değilken listenin ÜSTÜNDE duran şerit.
///
/// İlanlar görünmeye devam eder (ve bildirim gelir); kapalı olan tek şey
/// mesaj göndermektir. Eskiden burada tam ekran bir duvar vardı ve usta
/// müsaitliğini açmadan piyasayı hiç göremiyordu.
class _NotAvailableBanner extends ConsumerWidget {
  const _NotAvailableBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final hasAccess = ref.watch(artisanProAccessProvider);

    Future<void> enable() async {
      if (!hasAccess) {
        context.push(RoutePaths.panelPremium);
        return;
      }
      final ok =
          await ref.read(myProfileControllerProvider.notifier).setAvailable(true);
      if (context.mounted && ok) {
        context.showInfo('Artık müsait görünüyorsunuz.');
      }
    }

    return Material(
      color: palette.warningSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.do_not_disturb_on_outlined,
                size: 20, color: palette.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Müsait değilsiniz — ilanları görebilir ama mesaj '
                'gönderemezsiniz.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.ink,
                      height: 1.3,
                    ),
              ),
            ),
            TextButton(
              onPressed: enable,
              child: const Text('Müsait ol'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby({required this.completion});
  final ShopCompletion? completion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined,
                size: 48, color: context.palette.inkFaint),
            const SizedBox(height: 14),
            Text(
              'Yakında iş ilanı yok',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Meslek ve bölgenize uygun açık ilan bulunamadı. '
              'Vitrininizi güncel tutun; yeni ilanlar burada görünür.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.palette.inkMuted, height: 1.4),
            ),
            if (completion != null && !completion!.isComplete) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push(RoutePaths.panelEdit),
                child: const Text('Profili düzenle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

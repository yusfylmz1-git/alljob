import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// "Hemen Lazım" ilanlarının tam listesi (ana sayfa şeridinden "Tümünü Gör").
///
/// Misafire de açıktır (vitrin); ilan detayı ve teklif vermek oturum ister —
/// misafire üstte giriş çağrısı gösterilir.
class QuickSupportJobsScreen extends ConsumerWidget {
  const QuickSupportJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openJobsProvider);
    final quick = ref.watch(quickSupportJobsProvider);
    final isGuest = ref.watch(currentUserProvider) == null;
    final palette = context.palette;

    Future<void> refresh() => awaitRefresh(() async {
          ref.invalidate(openJobsProvider);
          await ref.read(openJobsProvider.future);
        });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: palette.warning, size: 22),
            const SizedBox(width: 6),
            const Flexible(child: Text(kQuickSupportName)),
          ],
        ),
      ),
      body: jobsAsync.when(
        loading: () => const SkeletonList(count: 5),
        error: (_, _) => RefreshableEmpty(
          onRefresh: refresh,
          child: const _Empty(
            icon: Icons.error_outline_rounded,
            title: 'İlanlar yüklenemedi',
            message: 'Bağlantınızı kontrol edip tekrar deneyin.',
          ),
        ),
        data: (_) {
          if (quick.isEmpty) {
            return RefreshableEmpty(
              onRefresh: refresh,
              child: const _Empty(
                icon: Icons.bolt_outlined,
                title: 'Şu an açık $kQuickSupportName ilanı yok',
                message:
                    'Market, taşıma, kısa gidiş gibi işler için ilan verildiğinde '
                    'burada listelenir.',
              ),
            );
          }
          return ResponsiveCenter(
            maxWidth: 720,
            child: PullToRefresh(
              onRefresh: refresh,
              child: ListView.separated(
                physics: kPullRefreshPhysics,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                itemCount: quick.length + 1,
                separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 12 : 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _Header(count: quick.length, isGuest: isGuest);
                  }
                  return NearbyJobCard(
                    job: quick[i - 1],
                    ctaText: 'Detayı Gör',
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bilgi bandı + (misafirse) giriş çağrısı.
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.isGuest});

  final int count;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.warningSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_rounded, color: palette.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count açık ilan · Market, taşıma, kısa gidiş gibi uzmanlık '
                  'gerektirmeyen kısa işler.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (isGuest) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.infoSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'İlan ayrıntısını görmek ve iletişime geçmek için giriş yapın.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.push(RoutePaths.login),
                  child: const Text('Giriş'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
            Icon(icon, size: 48, color: palette.inkFaint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

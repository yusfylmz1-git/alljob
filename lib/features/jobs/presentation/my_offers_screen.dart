import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/offer.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';

/// Usta: ilgilendiğim / teklif verdiğim işler.
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İlgilendiğim işler',
        icon: Icons.work_history_outlined,
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ref.watch(myOffersProvider(user.uid)).when(
                loading: () => const SkeletonList(),
                error: (_, _) => RefreshableEmpty(
                  onRefresh: () => awaitRefresh(() async {
                    ref.invalidate(myOffersProvider(user.uid));
                    await ref.read(myOffersProvider(user.uid).future);
                  }),
                  child: const ErrorView(
                      message: 'Liste yüklenemedi. Bağlantınızı kontrol edip '
                          'tekrar deneyin.'),
                ),
                data: (offers) {
                  final active =
                      offers.where((o) => o.status != OfferStatus.withdrawn).toList();
                  if (active.isEmpty) {
                    return RefreshableEmpty(
                      onRefresh: () => awaitRefresh(() async {
                        ref.invalidate(myOffersProvider(user.uid));
                        await ref.read(myOffersProvider(user.uid).future);
                      }),
                      child: const _EmptyOffers(),
                    );
                  }
                  return ResponsiveCenter(
                    maxWidth: 720,
                    child: PullToRefresh(
                      onRefresh: () => awaitRefresh(() async {
                        ref.invalidate(myOffersProvider(user.uid));
                        await ref.read(myOffersProvider(user.uid).future);
                      }),
                      child: ListView.separated(
                        physics: kPullRefreshPhysics,
                        padding: const EdgeInsets.all(16),
                        itemCount: active.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MyOfferTile(offer: active[i]),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _MyOfferTile extends StatelessWidget {
  const _MyOfferTile({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color fg, Color bg, String label) = switch (offer.status) {
      OfferStatus.pending =>
        (palette.info, palette.infoSurface, 'İlgileniyorsunuz'),
      OfferStatus.accepted =>
        (palette.success, palette.successSurface, 'Seçildiniz'),
      OfferStatus.rejected =>
        (palette.inkMuted, palette.surfaceMuted, 'Seçilmedi'),
      OfferStatus.withdrawn =>
        (palette.inkMuted, palette.surfaceMuted, 'Geri çekildi'),
    };
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.jobDetail(offer.jobId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        offer.jobTitle.isNotEmpty
                            ? offer.jobTitle
                            : 'İş ilanı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('İlanı görüntüle',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: palette.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(label,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

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
              decoration: BoxDecoration(
                  color: context.palette.primaryContainer,
                  shape: BoxShape.circle),
              child: Icon(Icons.local_offer_outlined,
                  size: 34, color: context.palette.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Henüz bir işle ilgilenmediniz',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Hizmetlerim (yakındaki işler) bölümünden ilanları inceleyip '
              'ilgilendiğiniz işlere başvurun.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

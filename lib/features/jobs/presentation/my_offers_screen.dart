import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/offer.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';

/// Usta: iletişime geçtiğim işler (İletişimlerim).
class MyOffersScreen extends ConsumerWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İletişimlerim',
        icon: Icons.forum_outlined,
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ref.watch(myOffersProvider(user.uid)).when(
                loading: () => const SkeletonList(),
                error: (_, _) => const ErrorView(
                    message: 'Liste yüklenemedi. Bağlantınızı kontrol edip '
                        'tekrar deneyin.'),
                data: (offers) {
                  final active =
                      offers.where((o) => o.status != OfferStatus.withdrawn).toList();
                  if (active.isEmpty) return const _EmptyOffers();
                  return ResponsiveCenter(
                    maxWidth: 720,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: active.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MyOfferTile(offer: active[i]),
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
    final (Color fg, Color bg, String label) = switch (offer.status) {
      OfferStatus.pending => (AppColors.info, AppColors.infoSurface, 'İletişimde'),
      OfferStatus.accepted =>
        (AppColors.success, AppColors.successSurface, 'Seçildiniz'),
      OfferStatus.rejected =>
        (AppColors.inkMuted, AppColors.surfaceMuted, 'Seçilmedi'),
      OfferStatus.withdrawn =>
        (AppColors.inkMuted, AppColors.surfaceMuted, 'Geri çekildi'),
    };
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.jobDetail(offer.jobId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
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
                            ?.copyWith(color: AppColors.inkMuted)),
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
              decoration: const BoxDecoration(
                  color: AppColors.primaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.local_offer_outlined,
                  size: 34, color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Henüz iletişime geçmediniz',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Yakınımdaki İşler bölümünden ilanları inceleyip müşterilerle iletişime geçin.',
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

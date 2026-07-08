import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/favorite.dart';
import '../../auth/application/auth_controller.dart';
import '../data/favorite_providers.dart';

/// Müşterinin favori ustaları (#14).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Favorilerim',
        icon: Icons.favorite_border_rounded,
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ref.watch(favoritesProvider(user.uid)).when(
                loading: () => const SkeletonList(),
                error: (e, _) => Center(child: Text('Favoriler yüklenemedi.\n$e')),
                data: (favs) => favs.isEmpty
                    ? const _EmptyFavorites()
                    : ResponsiveCenter(
                        maxWidth: 720,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: favs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _FavoriteTile(fav: favs[i]),
                        ),
                      ),
              ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.fav});
  final Favorite fav;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.artisanProfile(fav.artisanUid)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: fav.photoUrl != null
                        ? AppImage(handle: fav.photoUrl)
                        : const Icon(Icons.person,
                            color: AppColors.onPrimaryContainer),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fav.artisanName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(fav.professionNameTR,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.inkMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.star),
                        const SizedBox(width: 2),
                        Text('${fav.rating.toStringAsFixed(1)} (${fav.totalReviews})',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

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
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border,
                  size: 34, color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Henüz favoriniz yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Beğendiğiniz ustaları favorilere ekleyin, sonra kolayca ulaşın.',
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

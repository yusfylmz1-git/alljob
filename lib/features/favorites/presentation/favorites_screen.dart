import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/premium_surface_card.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../core/widgets/surface_app_bar.dart';
import '../../../data/models/favorite.dart';
import '../../auth/application/auth_controller.dart';
import '../data/favorite_providers.dart';

/// Takip ekranı — Instagram düzeni: iki sekme, tek sayfa.
///
/// - **Takipçiler**: seni takip edenler (`followersProvider`)
/// - **Takip**: senin takip ettiklerin (`favoritesProvider`)
///
/// Rol ayrımı YOK: herkes herkesi takip edebilir. Takip edilen kişinin usta
/// vitrini varsa meslek/puan satırı çizilir ([Favorite.hasArtisanInfo]),
/// yoksa yalnız ad + fotoğraf görünür.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key, this.initialTab});

  /// `followers` → Takipçiler sekmesi açık gelir. Profil sayacından gelen
  /// derin bağlantı bunu kullanır (takipçi sayacına dokununca doğru liste).
  final String? initialTab;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab == 'followers' ? 0 : 1,
  );

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: SurfaceAppBar(
        title: 'Takip',
        icon: Icons.people_alt_outlined,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Takipçiler'),
            Tab(text: 'Takip'),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : TabBarView(
              controller: _tab,
              children: [
                _FollowList(uid: user.uid, followers: true),
                _FollowList(uid: user.uid, followers: false),
              ],
            ),
    );
  }
}

/// Tek liste gövdesi — iki sekme de aynı kodu kullanır.
class _FollowList extends ConsumerWidget {
  const _FollowList({required this.uid, required this.followers});

  final String uid;

  /// true → beni takip edenler; false → benim takip ettiklerim.
  final bool followers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        followers ? followersProvider(uid) : favoritesProvider(uid);
    final async = ref.watch(provider);

    Future<void> refresh() => awaitRefresh(() async {
          ref.invalidate(provider);
          await ref.read(provider.future);
        });

    return async.when(
      loading: () => const SkeletonList(),
      error: (_, _) => RefreshableEmpty(
        onRefresh: refresh,
        child: const ErrorView(
          message: 'Liste yüklenemedi. Bağlantınızı kontrol edip tekrar '
              'deneyin.',
        ),
      ),
      data: (list) => list.isEmpty
          ? RefreshableEmpty(
              onRefresh: refresh,
              child: _EmptyFollow(followers: followers),
            )
          : ResponsiveCenter(
              maxWidth: 720,
              child: PullToRefresh(
                onRefresh: refresh,
                child: ListView.separated(
                  physics: kPullRefreshPhysics,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _FollowTile(fav: list[i], followers: followers),
                ),
              ),
            ),
    );
  }
}

class _FollowTile extends StatelessWidget {
  const _FollowTile({required this.fav, required this.followers});

  final Favorite fav;

  /// Takipçi listesinde KARŞI TARAF takip edendir; takip listesinde ise
  /// takip edilendir. Gösterilecek kişi buna göre seçilir.
  final bool followers;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final otherUid = followers ? fav.followerUid : fav.followedUid;
    final name = followers ? fav.followerName : fav.followedName;
    final photo = followers ? fav.customerPhotoUrl : fav.photoUrl;
    // Meslek/puan yalnız takip EDİLEN usta ise anlamlı (takipçi sıradan
    // kullanıcı olabilir).
    final showArtisan = !followers && fav.hasArtisanInfo;

    return PremiumSurfaceCard(
      // Genel profil: usta vitrini varsa ekran `/artisan/:uid`'e devreder.
      // Doğrudan artisanProfile'a gitmek, usta OLMAYAN kişide boş ekran
      // gösteriyordu.
      onTap: () => context.push(RoutePaths.userProfile(otherUid)),
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.hairline),
              color: palette.primaryContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? AppImage(
                    handle: photo,
                    fit: BoxFit.cover,
                    width: 52,
                    height: 52,
                    memCacheWidth: 104,
                    memCacheHeight: 104,
                  )
                : Icon(Icons.person, color: palette.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Kullanıcı' : name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (showArtisan) ...[
                  const SizedBox(height: 2),
                  Text(
                    fav.professionNameTR,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.inkMuted),
                  ),
                  if (fav.totalReviews > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 15, color: palette.star),
                        const SizedBox(width: 2),
                        Text(
                          '${fav.rating.toStringAsFixed(1)} '
                          '(${fav.totalReviews})',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.inkFaint),
        ],
      ),
    );
  }
}

class _EmptyFollow extends StatelessWidget {
  const _EmptyFollow({required this.followers});
  final bool followers;

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
                color: palette.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                followers
                    ? Icons.people_outline_rounded
                    : Icons.person_add_alt_1_outlined,
                size: 34,
                color: palette.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              followers
                  ? 'Henüz takipçin yok'
                  : 'Henüz kimseyi takip etmiyorsun',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              followers
                  ? 'Profilini paylaş; işlerini beğenenler seni takip etsin.'
                  : 'Beğendiğin ustaları takip et, yeni işlerinden haberdar ol.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

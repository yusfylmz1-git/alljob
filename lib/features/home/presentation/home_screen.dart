import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/job_providers.dart';
import '../../products/data/product_providers.dart';
import 'widgets/home_discover.dart';
import 'widgets/home_featured.dart';
import 'widgets/home_guest_banner.dart';
import 'widgets/home_quick_access.dart';
import 'widgets/home_stats.dart';
import 'widgets/home_tools.dart';

/// Ana Sayfa — Ustasından'ın canlı vitrini. Uygulamaya giren önce burayı
/// görür: sade karşılama + 3 ana aksiyon + "Bugün Ustasından'da" keşif
/// kartları + öne çıkan ustalar + minimal istatistik. Aşağı çekince
/// veriye bağlı bölümler tazelenir.
///
/// Arama BURADA YOK: Keşfet sekmesinde gerçek arama/filtre var, ana sayfadaki
/// kutu yalnız oraya yönlendirdiği için kaldırıldı.
///
/// Misafir dâhil herkese açıktır. Amaç yalnız "usta arama" değil; usta +
/// müşteri + iş + ürün ekosistemini keşfedilir kılmak.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = user == null;
    final isArtisan = user?.isArtisan ?? false;

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: Column(
        children: [
          const _HomeHero(),
          Expanded(
            child: ResponsiveCenter(
              maxWidth: 760,
              child: RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView(
                  // Aşağı çekme, içerik ekranı doldurmasa da çalışmalı.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: _sections(isGuest: isGuest, isArtisan: isArtisan),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.home),
    );
  }

  /// Aşağı çekince veriye bağlı bölümleri tazeler. Her provider kendi
  /// hatasını yutar (biri düşerse diğerleri yine yenilenir); aksi hâlde tek
  /// bir hatalı bölüm yenilemenin tamamını iptal ederdi.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeStatsProvider);
    ref.invalidate(oneChikanUstalarProvider);
    ref.invalidate(discoverProductsProvider);
    ref.invalidate(openJobsProvider);

    await Future.wait<void>([
      for (final f in <Future<Object?>>[
        ref.read(homeStatsProvider.future),
        ref.read(oneChikanUstalarProvider.future),
        ref.read(discoverProductsProvider.future),
        ref.read(openJobsProvider.future),
      ])
        f.then<void>((_) {}, onError: (_) {}),
    ]);
  }

  /// Bölüm sırası: aksiyon → keşif → öne çıkanlar → istatistik (ana sayfa
  /// vitrin/keşif ağırlıklı akar).
  /// Veriye bağlı bölümler (keşif/istatistik) boşsa kendini gizler.
  List<Widget> _sections({required bool isGuest, required bool isArtisan}) {
    const gap = SizedBox(height: 24);

    // Usta: iş/ürün vitrini + araçlar önce.
    if (isArtisan) {
      return const [
        HomeQuickAccess(),
        gap,
        HomeFeatured(), // Son İş İlanları / ürünler
        gap,
        HomeTools(), // Usta Araçları
        gap,
        HomeDiscover(),
        gap,
        HomeStats(),
      ];
    }

    // Misafir & Müşteri: keşif/vitrin ağırlıklı.
    return [
      if (isGuest) const HomeGuestBanner(),
      const HomeQuickAccess(),
      gap,
      const HomeDiscover(), // 🔥 Bugün Ustasından'da
      gap,
      const HomeFeatured(), // ⭐ Öne Çıkan Ustalar (+ürün/iş)
      gap,
      const HomeStats(), // 📊 minimal büyüme sayaçları
      if (isGuest) ...[gap, const HomeTools()],
    ];
  }
}

/// Üst karşılama alanı: menü + marka + selamlama + bildirim/giriş.
class _HomeHero extends ConsumerWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final palette = context.palette;

    final ad = user?.displayName.trim() ?? '';
    final selam = user == null || ad.isEmpty
        ? 'Hoş geldiniz 👋'
        : 'Merhaba, ${ad.split(' ').first} 👋';

    return Container(
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DrawerMenuButton(),
                  const SizedBox(width: 4),
                  const BrandMark(size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selam,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Bugün ne yapalım?',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                  if (user == null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Giriş'),
                      onPressed: () => context.push(RoutePaths.login),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

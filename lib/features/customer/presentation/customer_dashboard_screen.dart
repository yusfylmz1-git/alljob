import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sepette_hizmet/core/constants/app_constants.dart'
    show AppConstants;

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../jobs/presentation/widgets/jobs_explore_panel.dart';
import '../application/artisan_search_controller.dart';
import 'widgets/artisan_card.dart';
import 'widgets/detailed_search_sheet.dart';

/// Ekran A — Keşfet: lacivert hero içinde metin arama kutusu + "Detaylı Arama"
/// açılır paneli, altında usta sonuç ızgarası (responsive).
///
/// TEK LİSTE (2026-08-08 sadeleştirmesi): yalnız ustalar. Ürünler modülü
/// kaldırıldı, İlanlar alt bardaki kendi sekmesinde. Sekme çubuğu kalktı.
class CustomerDashboardScreen extends ConsumerStatefulWidget {
  const CustomerDashboardScreen({
    super.key,
    this.initialTab,
    this.initialProfession,
  });

  /// Eski derin bağlantılarla uyum için korunur; artık tek liste olduğundan
  /// yok sayılır.
  final String? initialTab;

  /// Ana Sayfa "Kategoriler"den gelen başlangıç meslek kodu. Verilirse
  /// liste bu meslekle filtreli açılır.
  final String? initialProfession;

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Ustalar listesi HER MODDA hemen yüklenir. Eskiden usta modunda erken
    // çıkılıyordu (o modda sekme gizliydi); artık sekme her modda görünüyor,
    // arama başlatılmazsa liste BOŞ açılırdı.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ana Sayfa "Kategoriler"den bir meslek koduyla gelindiyse filtreyi
      // uygula ve taze ara (kullanıcı özellikle o kategoriyi seçti).
      final prof = widget.initialProfession;
      if (prof != null && prof.isNotEmpty) {
        ref.read(customerFilterProvider.notifier).setProfession(prof);
        ref.read(artisanSearchControllerProvider.notifier).search();
        return;
      }

      final state = ref.read(artisanSearchControllerProvider).valueOrNull;
      if (state == null || !state.hasSearched) {
        ref.read(artisanSearchControllerProvider.notifier).search();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(artisanSearchControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainTabScope(
      tab: MainTab.explore,
      child: Scaffold(
      drawer: const AppMenuDrawer(),
      body: Column(
        children: [
          const _HeroHeader(),
          // KEŞFET İKİ SEKME: Ustalar | İlanlar (2026-08-08).
          // İlan akışı alt bardaki ayrı sekmeden BURAYA taşındı — "usta ara"
          // ve "iş ara" aynı keşif yüzeyinde toplandı.
          Material(
            color: context.palette.card,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Ustalar', icon: Icon(Icons.handyman_rounded, size: 20)),
                Tab(text: 'İlanlar', icon: Icon(Icons.campaign_rounded, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ArtisansExplorePanel(scrollController: _scrollController),
                const _JobsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.explore),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: kompakt üst bar (menü + marka + bildirim). Arama Ustalar sekmesinde.
// Sistem duyurusu → Bildirimler ekranı (Keşfet’i boğmamak için).
// ---------------------------------------------------------------------------

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero gradyanı KOYU: ikonlar beyaz kalmalı.
              const DrawerMenuButton(color: Colors.white),
              const SizedBox(width: 4),
              const BrandMark(size: 44),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
              ),
              const NotificationBell(color: Colors.white),
              if (user == null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Giriş'),
                  onPressed: () => context.push(RoutePaths.login),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ustalar paneli: arama + (müşteri) iş ilanı CTA + sonuçlar
// ---------------------------------------------------------------------------

class _ArtisansExplorePanel extends ConsumerWidget {
  const _ArtisansExplorePanel({required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isCustomer = user != null && !user.isArtisan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SearchRow(),
              if (isCustomer) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('İş İlanı Ver'),
                  onPressed: () => context.push(RoutePaths.newJob),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _ResultsArea(scrollController: scrollController),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Arama satırı: metin kutusu (yazdıkça arar) + Detaylı Arama butonu (#1)
// ---------------------------------------------------------------------------

class _SearchRow extends ConsumerStatefulWidget {
  const _SearchRow();

  @override
  ConsumerState<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends ConsumerState<_SearchRow> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(customerFilterProvider).query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(customerFilterProvider.notifier).setQuery(value);
    _debounce?.cancel();
    // Yazdıkça ara — kısa bir bekleme ile gereksiz sorgu önlenir.
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(artisanSearchControllerProvider.notifier).search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = ref.watch(customerFilterProvider).activeCount;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) =>
                  ref.read(artisanSearchControllerProvider.notifier).search(),
              decoration: InputDecoration(
                hintText: 'Usta adı veya meslek arayın…',
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 12),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Temizle',
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Detaylı arama: mevcut filtre ekranı açılır pencere olarak gelir.
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Detaylı'),
              onPressed: () => showDetailedSearchSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sonuç alanı
// ---------------------------------------------------------------------------

class _ResultsArea extends ConsumerWidget {
  const _ResultsArea({required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(artisanSearchControllerProvider);

    return searchAsync.when(
      loading: () => const ResponsiveCenter(
        maxWidth: 1120,
        child: _ArtisanGridSkeleton(),
      ),
      error: (e, _) => const _Centered(
        icon: Icons.error_outline_rounded,
        title: 'Bir hata oluştu',
        message: 'Lütfen tekrar deneyin.',
      ),
      data: (state) {
        if (!state.hasSearched) {
          return _Centered(
            icon: Icons.search_rounded,
            title: 'Usta aramaya hazır',
            message: 'Usta adı veya meslek yazın; dilerseniz detaylı arama ile '
                'il / ilçe seçin. Filtre zorunlu değil.',
            actionLabel: 'Tüm ustaları göster',
            onAction: () =>
                ref.read(artisanSearchControllerProvider.notifier).search(),
            secondaryLabel: 'İş ilanı ver',
            onSecondary: () => context.push(RoutePaths.newJob),
          );
        }
        if (state.items.isEmpty) {
          return _Centered(
            icon: Icons.person_search_rounded,
            title: 'Sonuç bulunamadı',
            message:
                'Bu kriterlere uygun usta yok. Filtreleri gevşetin veya '
                'ilan verip ustaların size ulaşmasını sağlayın.',
            actionLabel: 'Filtreleri temizle',
            onAction: () {
              ref.read(customerFilterProvider.notifier).clearAll();
              ref.read(artisanSearchControllerProvider.notifier).search();
            },
            secondaryLabel: 'İş ilanı ver',
            onSecondary: () => context.push(RoutePaths.newJob),
          );
        }
        return _ResultsGrid(state: state, scrollController: scrollController);
      },
    );
  }
}

class _ResultsGrid extends ConsumerWidget {
  const _ResultsGrid({required this.state, required this.scrollController});

  final ArtisanSearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showFooter = state.hasMore;
    return ResponsiveCenter(
      maxWidth: 1120,
      child: PullToRefresh(
        onRefresh: () => awaitRefresh(
          () => ref.read(artisanSearchControllerProvider.notifier).search(),
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: kPullRefreshPhysics,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('Ustalar', style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${state.items.length}${state.hasMore ? '+' : ''}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              sliver: SliverGrid(
                // Kare tile: telefon ~2, tablet 3–4, masaüstü 5+ sütun.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 168,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // Daha yüksek hücre → daha büyük daire foto.
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final artisan = state.items[index];
                    return ArtisanCard(
                      artisan: artisan,
                      onTap: () =>
                          context.push(RoutePaths.artisanProfile(artisan.uid)),
                    );
                  },
                  childCount: state.items.length,
                ),
              ),
            ),
            if (showFooter)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Yükleme: kare usta ızgarasına benzer iskelet.
class _ArtisanGridSkeleton extends StatelessWidget {
  const _ArtisanGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 168,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: const Column(
          children: [
            Expanded(child: Center(child: Skeleton.circle(size: 56))),
            SizedBox(height: 8),
            Skeleton(width: 72, height: 12, radius: 6),
            SizedBox(height: 6),
            Skeleton(width: 56, height: 10, radius: 5),
            SizedBox(height: 8),
            Skeleton(width: 48, height: 18, radius: 20),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // SingleChildScrollView: klavye açılınca sonuç alanı daralır — içerik
    // sığmazsa taşma şeridi yerine kaydırılabilir kalsın.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 36, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Keşfet "İlanlar" sekmesi — erişim kapısı + liste.
///
/// İlan listesi yalnız **usta modu açık** ve **müsait** kullanıcıya görünür:
/// müsait olmayan usta zaten aramada da çıkmaz, ilan sahibine haber veremez.
/// Kapı burada tek yerde; panelin kendisi kapı bilmez.
class _JobsTab extends ConsumerWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final palette = context.palette;
    final theme = Theme.of(context);

    Widget notice(IconData icon, String title, String body, {Widget? action}) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 24),
          Icon(icon, size: 44, color: palette.inkMuted),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action],
        ],
      );
    }

    if (user == null) {
      return notice(
        Icons.login_rounded,
        'İlanları görmek için giriş yap',
        'İş ilanlarını görüntülemek ve teklif vermek için hesabına giriş yap.',
        action: Center(
          child: FilledButton(
            onPressed: () => context.push(RoutePaths.login),
            child: const Text('Giriş yap'),
          ),
        ),
      );
    }

    if (!user.isArtisan) {
      return notice(
        Icons.handyman_outlined,
        'İlanlar usta moduna özel',
        'İş ilanlarını görmek için Profil sayfasından "Usta modu" anahtarını '
        'aç. İlan vermek için usta olman gerekmez.',
        action: Center(
          child: FilledButton(
            onPressed: () => context.push(RoutePaths.profile),
            child: const Text('Profile git'),
          ),
        ),
      );
    }

    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    if (draft != null && !draft.profile.isAvailable) {
      return notice(
        Icons.do_not_disturb_on_outlined,
        'Şu an müsait görünmüyorsun',
        'Müsait olmadığın sürece ilan listesi kapalıdır; aramada da '
        'görünmezsin. Profilinden müsaitliği açabilirsin.',
        action: Center(
          child: FilledButton(
            onPressed: () => context.push(RoutePaths.profile),
            child: const Text('Müsaitliği aç'),
          ),
        ),
      );
    }

    return const JobsExplorePanel();
  }
}

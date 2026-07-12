import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/job_providers.dart';
import '../../jobs/presentation/widgets/job_widgets.dart';
import '../application/artisan_search_controller.dart';
import 'widgets/artisan_card.dart';
import 'widgets/detailed_search_sheet.dart';

/// Ekran A — Keşfet: lacivert hero içinde metin arama kutusu + "Detaylı Arama"
/// açılır paneli, altında usta sonuç ızgarası (responsive).
class CustomerDashboardScreen extends ConsumerStatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

/// Dar ekranda sonuç alanı görünümü: usta listesi veya iş ilanları.
enum _ExploreView { artisans, jobs }

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen> {
  final _scrollController = ScrollController();
  _ExploreView _view = _ExploreView.artisans;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Sahibinden benzeri: uygulamaya girince ustalar hemen listelensin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(artisanSearchControllerProvider).valueOrNull;
      if (state == null || !state.hasSearched) {
        ref.read(artisanSearchControllerProvider.notifier).search();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: Column(
        children: [
          const _HeroHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Geniş ekran: ustaların hemen yanında ilan paneli.
                if (constraints.maxWidth >= 1000) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child:
                            _ResultsArea(scrollController: _scrollController),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      const SizedBox(width: 400, child: _JobsPanel()),
                    ],
                  );
                }
                // Dar ekran: Ustalar / İş İlanları arasında geçiş.
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SegmentedButton<_ExploreView>(
                        segments: const [
                          ButtonSegment(
                            value: _ExploreView.artisans,
                            icon: Icon(Icons.engineering_outlined, size: 18),
                            label: Text('Ustalar'),
                          ),
                          ButtonSegment(
                            value: _ExploreView.jobs,
                            icon: Icon(Icons.campaign_outlined, size: 18),
                            label: Text('İş İlanları'),
                          ),
                        ],
                        selected: {_view},
                        onSelectionChanged: (s) =>
                            setState(() => _view = s.first),
                      ),
                    ),
                    Expanded(
                      child: _view == _ExploreView.artisans
                          ? _ResultsArea(scrollController: _scrollController)
                          : const _JobsPanel(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.explore),
    );
  }
}

// ---------------------------------------------------------------------------
// İş ilanları paneli — başkalarının verdiği açık ilanlar (herkes görür)
// ---------------------------------------------------------------------------

class _JobsPanel extends ConsumerWidget {
  const _JobsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(openJobsProvider);

    return jobsAsync.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, _) => const _Centered(
        icon: Icons.error_outline_rounded,
        title: 'İlanlar yüklenemedi',
        message: 'Lütfen tekrar deneyin.',
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return const _Centered(
            icon: Icons.campaign_outlined,
            title: 'Henüz açık ilan yok',
            message: 'Müşterilerin verdiği iş ilanları burada listelenir.',
          );
        }
        return ResponsiveCenter(
          maxWidth: 720,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            itemCount: jobs.length + 1,
            separatorBuilder: (_, i) =>
                SizedBox(height: i == 0 ? 12 : 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Row(
                  children: [
                    Text('İş İlanları', style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${jobs.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return NearbyJobCard(job: jobs[i - 1], ctaText: 'Detayı Gör');
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero başlık: marka + karşılama + arama satırı + hızlı eylemler
// ---------------------------------------------------------------------------

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isCustomer = user != null && !user.isArtisan;

    return Container(
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Sol üst menü: moda özgü özellikler (AppMenuDrawer).
                  // Karşı moda mesaj düşerse üzerinde kırmızı nokta belirir.
                  const DrawerMenuButton(),
                  const SizedBox(width: 4),
                  const BrandMark(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'Usta Cepte',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  // Sağ üst: bildirim merkezi (girişli kullanıcıda görünür).
                  const NotificationBell(),
                  if (user == null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Giriş Yap'),
                      onPressed: () => context.push(RoutePaths.login),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Hangi ustaya ihtiyacınız var?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Usta adı veya meslek yazın; bölge seçmek için detaylı '
                'aramayı kullanın.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              const _SearchRow(),
              // İş ilanı verme yalnızca müşteri hesabıyla girişte görünür (#2).
              if (isCustomer) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('İş İlanı Ver'),
                  onPressed: () => context.push(RoutePaths.newJob),
                ),
              ],
            ],
          ),
        ),
      ),
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
        child: SkeletonList(count: 6),
      ),
      error: (e, _) => const _Centered(
        icon: Icons.error_outline_rounded,
        title: 'Bir hata oluştu',
        message: 'Lütfen tekrar deneyin.',
      ),
      data: (state) {
        if (!state.hasSearched) {
          return const _Centered(
            icon: Icons.search_rounded,
            title: 'Usta aramaya hazır',
            message: 'Usta adı/meslek yazın veya detaylı aramayı kullanın. '
                'Hiçbir filtre zorunlu değildir.',
          );
        }
        if (state.items.isEmpty) {
          return const _Centered(
            icon: Icons.person_search_rounded,
            title: 'Sonuç bulunamadı',
            message:
                'Bu kriterlere uygun usta yok. Farklı bir bölge veya meslek deneyin.',
          );
        }
        return _ResultsGrid(state: state, scrollController: scrollController);
      },
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.state, required this.scrollController});

  final ArtisanSearchState state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showFooter = state.hasMore;
    return ResponsiveCenter(
      maxWidth: 1120,
      child: CustomScrollView(
        controller: scrollController,
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            sliver: SliverGrid(
              // Geniş yatay kartlar — dar ekranda tek sütun, genişte 2 sütun.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // Kompakt usta kartı (tek blok satır) — eski ferah kart 152 idi.
                mainAxisExtent: 84,
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
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

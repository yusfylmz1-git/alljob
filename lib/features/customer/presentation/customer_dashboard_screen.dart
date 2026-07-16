import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:usta_cepte/core/constants/app_constants.dart'
    show AppConstants;

import '../../../core/config/app_runtime_config.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
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
import '../../jobs/data/job_providers.dart';
import '../../jobs/presentation/widgets/job_widgets.dart';
import '../application/artisan_search_controller.dart';
import 'widgets/artisan_card.dart';
import 'widgets/detailed_search_sheet.dart';

/// Ekran A — Keşfet: lacivert hero içinde metin arama kutusu + "Detaylı Arama"
/// açılır paneli, altında usta sonuç ızgarası (responsive).
/// "İş İlanları" sekmesi yalnız usta modunda; müşteri başkalarının ilanını görmez.
class CustomerDashboardScreen extends ConsumerStatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

/// Keşfet sekmeleri. [jobs] yalnız usta modunda segmentte görünür.
enum _ExploreView { artisans, jobs, staff }

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
    final runtime = ref.watch(appRuntimeConfigProvider).valueOrNull;
    final showAnn = runtime?.hasAnnouncement == true;
    // Yalnız usta modu: müşteri (ve misafir) başkalarının iş ilanlarını görmez.
    final showJobsTab =
        ref.watch(currentUserProvider.select((u) => u?.isArtisan ?? false));
    // Müşteriye geçince jobs sekmesinde kalınırsa ustalar'a düş.
    final effectiveView =
        (!showJobsTab && _view == _ExploreView.jobs) ? _ExploreView.artisans : _view;

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: Column(
        children: [
          const _HeroHeader(),
          if (showAnn) _PlatformAnnouncementBanner(config: runtime!),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SegmentedButton<_ExploreView>(
                    segments: [
                      const ButtonSegment(
                        value: _ExploreView.artisans,
                        icon: Icon(Icons.engineering_outlined, size: 18),
                        label: Text('Ustalar'),
                      ),
                      if (showJobsTab)
                        const ButtonSegment(
                          value: _ExploreView.jobs,
                          icon: Icon(Icons.campaign_outlined, size: 18),
                          label: Text('İş İlanları'),
                        ),
                      const ButtonSegment(
                        value: _ExploreView.staff,
                        icon: Icon(Icons.badge_outlined, size: 18),
                        label: Text('Eleman'),
                      ),
                    ],
                    selected: {effectiveView},
                    onSelectionChanged: (s) =>
                        setState(() => _view = s.first),
                  ),
                ),
                Expanded(
                  child: switch (effectiveView) {
                    _ExploreView.artisans =>
                      _ResultsArea(scrollController: _scrollController),
                    _ExploreView.jobs => const _JobsPanel(),
                    _ExploreView.staff => const _StaffExplorePanel(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.explore),
    );
  }
}

// ---------------------------------------------------------------------------
// Eleman paneli — Keşfet sekmesi (iş arıyorum / eleman arıyorum)
// ---------------------------------------------------------------------------

class _StaffExplorePanel extends ConsumerWidget {
  const _StaffExplorePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    void go(String path) {
      if (user == null) {
        context.push(RoutePaths.login);
        return;
      }
      context.push(path);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Eleman',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Başvuru formu yok. Net seçin: iş mi arıyorsunuz, eleman mı?',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 16),
        _ExplorePathTile(
          badge: 'ELEMAN',
          title: 'İş arıyorum',
          subtitle: 'Müsait profilinizi yayınlayın; işveren size yazsın',
          color: palette.info,
          surface: palette.infoSurface,
          icon: Icons.work_outline_rounded,
          onTap: () => go(RoutePaths.staffMyWorker),
          secondaryLabel: 'İşveren ilanlarına bak',
          onSecondary: () => go(RoutePaths.staffNeeds),
          primaryButtonLabel: 'Eleman profilim',
        ),
        const SizedBox(height: 12),
        _ExplorePathTile(
          badge: 'İŞVEREN',
          title: 'Eleman arıyorum',
          subtitle: 'Listeden eleman seçin ve sohbeti siz başlatın',
          color: palette.primary,
          surface: palette.primaryContainer,
          icon: Icons.person_search_rounded,
          onTap: () => go(RoutePaths.staffWorkers),
          secondaryLabel: 'İşveren ilanı aç',
          onSecondary: () => go(RoutePaths.staffNeedNew),
          primaryButtonLabel: 'Eleman ara',
        ),
      ],
    );
  }
}

class _ExplorePathTile extends StatelessWidget {
  const _ExplorePathTile({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.surface,
    required this.icon,
    required this.onTap,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryButtonLabel,
  });

  final String badge;
  final String title;
  final String subtitle;
  final Color color;
  final Color surface;
  final IconData icon;
  final VoidCallback onTap;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryButtonLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.3,
                        )),
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: palette.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onTap, child: Text(primaryButtonLabel)),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: onSecondary, child: Text(secondaryLabel)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// İş ilanları paneli — yalnız usta modu (müşteri Keşfet'te görmez)
// ---------------------------------------------------------------------------

class _JobsPanel extends ConsumerWidget {
  const _JobsPanel();

  Future<void> _refresh(WidgetRef ref) => awaitRefresh(() async {
        ref.invalidate(openJobsProvider);
        await ref.read(openJobsProvider.future);
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(openJobsProvider);

    return jobsAsync.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, _) => RefreshableEmpty(
        onRefresh: () => _refresh(ref),
        child: const _Centered(
          icon: Icons.error_outline_rounded,
          title: 'İlanlar yüklenemedi',
          message: 'Lütfen tekrar deneyin.',
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return RefreshableEmpty(
            onRefresh: () => _refresh(ref),
            child: const _Centered(
              icon: Icons.campaign_outlined,
              title: 'Henüz açık ilan yok',
              message:
                  'Bölgenizdeki müşteriler ilan verince burada listelenir.',
            ),
          );
        }
        return ResponsiveCenter(
          maxWidth: 720,
          child: PullToRefresh(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              physics: kPullRefreshPhysics,
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
          ),
        );
      },
    );
  }
}

/// Admin `adminConfig/runtime` duyuru bandı (Keşfet).
class _PlatformAnnouncementBanner extends StatelessWidget {
  const _PlatformAnnouncementBanner({required this.config});
  final AppRuntimeConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = (config.announcementTitle ?? '').trim();
    final body = (config.announcementBody ?? '').trim();
    return Material(
      color: palette.warningSurface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: palette.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: palette.inkMuted,
                              height: 1.3,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                    AppConstants.appName,
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
                  // Biraz dikey: avatar + ad + meslek + puan + durum.
                  childAspectRatio: 0.78,
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
        childAspectRatio: 0.78,
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

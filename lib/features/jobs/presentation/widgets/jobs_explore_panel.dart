import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pull_to_refresh.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/job_providers.dart';
import '../job_explore_filter.dart';
import '../job_filter_sheet.dart';
import 'job_widgets.dart';

/// Keşfet → İşler (usta modu): metin arama + detaylı filtre + liste.
class JobsExplorePanel extends ConsumerStatefulWidget {
  const JobsExplorePanel({super.key});

  @override
  ConsumerState<JobsExplorePanel> createState() => _JobsExplorePanelState();
}

class _JobsExplorePanelState extends ConsumerState<JobsExplorePanel> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  JobExploreFilter _filter = const JobExploreFilter();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _filter = _filter.copyWith(query: value));
    });
  }

  Future<void> _openFilters() async {
    final next = await showJobFilterSheet(context, initial: _filter);
    if (next == null || !mounted) return;
    setState(() => _filter = next.copyWith(query: _searchCtrl.text));
  }

  void _clearAll() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _filter = const JobExploreFilter());
  }

  Future<void> _refresh() => awaitRefresh(() async {
        ref.invalidate(openJobsProvider);
        await ref.read(openJobsProvider.future);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final jobsAsync = ref.watch(openJobsProvider);
    final filterCount = _filter.activeDetailCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _JobsSearchRow(
            controller: _searchCtrl,
            filterCount: filterCount,
            onChanged: _onQueryChanged,
            onFilter: _openFilters,
            onClearQuery: () {
              _searchCtrl.clear();
              _onQueryChanged('');
            },
          ),
        ),
        Expanded(
          child: jobsAsync.when(
            loading: () => const SkeletonList(count: 4),
            error: (_, _) => RefreshableEmpty(
              onRefresh: _refresh,
              child: _JobsEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'İlanlar yüklenemedi',
                message: 'Lütfen tekrar deneyin.',
              ),
            ),
            data: (allJobs) {
              final jobs = _filter.apply(allJobs);

              if (allJobs.isEmpty) {
                return RefreshableEmpty(
                  onRefresh: _refresh,
                  child: const _JobsEmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Henüz açık ilan yok',
                    message:
                        'Bölgenizdeki müşteriler ilan verince burada listelenir.',
                  ),
                );
              }

              if (jobs.isEmpty) {
                return RefreshableEmpty(
                  onRefresh: _refresh,
                  child: _JobsEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Filtreye uygun ilan yok',
                    message:
                        'Arama veya filtreleri gevşetin; daha fazla ilan görebilirsiniz.',
                    actionLabel: 'Filtreleri temizle',
                    onAction: _clearAll,
                  ),
                );
              }

              return ResponsiveCenter(
                maxWidth: 720,
                child: PullToRefresh(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: kPullRefreshPhysics,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: jobs.length + 1,
                    separatorBuilder: (_, i) =>
                        SizedBox(height: i == 0 ? 12 : 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Row(
                          children: [
                            Text('İlanlar',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _filter.hasAnyFilter
                                    ? '${jobs.length}/${allJobs.length}'
                                    : '${jobs.length}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_filter.hasAnyFilter) ...[
                              const Spacer(),
                              TextButton(
                                onPressed: _clearAll,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: palette.inkMuted,
                                ),
                                child: const Text('Temizle'),
                              ),
                            ],
                          ],
                        );
                      }
                      return NearbyJobCard(
                        job: jobs[i - 1],
                        ctaText: 'Detayı Gör',
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JobsSearchRow extends StatelessWidget {
  const _JobsSearchRow({
    required this.controller,
    required this.filterCount,
    required this.onChanged,
    required this.onFilter,
    required this.onClearQuery,
  });

  final TextEditingController controller;
  final int filterCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.6,
              ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'İlan veya bölge ara…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Temizle',
                          onPressed: onClearQuery,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Filtre'),
              onPressed: onFilter,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsEmptyState extends StatelessWidget {
  const _JobsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

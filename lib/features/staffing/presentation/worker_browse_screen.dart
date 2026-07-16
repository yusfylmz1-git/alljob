import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../data/staffing_providers.dart';
import 'worker_detailed_search_sheet.dart';
import 'worker_search_filter.dart';

/// ELEMAN ARIYORUM — müsait eleman listesi.
class WorkerBrowseScreen extends ConsumerStatefulWidget {
  const WorkerBrowseScreen({super.key});

  @override
  ConsumerState<WorkerBrowseScreen> createState() => _WorkerBrowseScreenState();
}

class _WorkerBrowseScreenState extends ConsumerState<WorkerBrowseScreen> {
  WorkerSearchFilter _filter = const WorkerSearchFilter();
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _applyQuery(String q) {
    setState(() => _filter = _filter.copyWith(query: q));
  }

  Future<void> _openDetailed() async {
    final result = await showWorkerDetailedSearchSheet(
      context,
      initial: _filter,
    );
    if (result != null && mounted) {
      setState(() => _filter = result.copyWith(query: _queryCtrl.text));
    }
  }

  void _clearAll() {
    _queryCtrl.clear();
    setState(() => _filter = const WorkerSearchFilter());
  }

  @override
  Widget build(BuildContext context) {
    final serverFilter = (
      province: (_filter.province == null || _filter.province!.isEmpty)
          ? null
          : _filter.province,
      dailyOnly: _filter.dailyOnly ? true : null,
    );
    final async = ref.watch(openWorkersProvider(serverFilter));
    final palette = context.palette;
    final detailCount = _filter.activeDetailCount;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'İşveren · Eleman ara',
        icon: Icons.person_search_outlined,
        actions: [
          if (_filter.query.trim().isNotEmpty || detailCount > 0)
            IconButton(
              tooltip: 'Filtreleri temizle',
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ResponsiveCenter(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'İŞVEREN · Müsait eleman listesi — sohbeti siz başlatırsınız',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: _applyQuery,
                    onSubmitted: _applyQuery,
                    decoration: InputDecoration(
                      hintText: 'Meslek, başlık, il… (örn. boya nilüfer)',
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_queryCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _queryCtrl.clear();
                                _applyQuery('');
                              },
                            ),
                          IconButton(
                            tooltip: 'Detaylı arama',
                            icon: Badge(
                              isLabelVisible: detailCount > 0,
                              label: Text('$detailCount'),
                              child: const Icon(Icons.tune_rounded),
                            ),
                            onPressed: _openDetailed,
                          ),
                        ],
                      ),
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    avatar: Icon(
                      _filter.dailyOnly
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: const Text('Gündelik eleman'),
                    selected: _filter.dailyOnly,
                    onSelected: (v) => setState(() {
                      _filter = _filter.copyWith(dailyOnly: v);
                    }),
                  ),
                  if (_filter.hasDetailFilters ||
                      _filter.query.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (_filter.query.trim().isNotEmpty)
                          InputChip(
                            label: Text('“${_filter.query.trim()}”'),
                            onDeleted: () {
                              _queryCtrl.clear();
                              _applyQuery('');
                            },
                          ),
                        if (_filter.province != null)
                          InputChip(
                            label: Text(_filter.district != null
                                ? '${_filter.province} / ${_filter.district}'
                                : _filter.province!),
                            onDeleted: () => setState(() {
                              _filter = _filter.copyWith(
                                clearProvince: true,
                                clearDistrict: true,
                              );
                            }),
                          ),
                        if (_filter.rateType != null)
                          InputChip(
                            label: Text(_filter.rateType!.labelTR),
                            onDeleted: () => setState(() {
                              _filter =
                                  _filter.copyWith(clearRateType: true);
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (_, _) => RefreshableEmpty(
                onRefresh: () => awaitRefresh(() async {
                  ref.invalidate(openWorkersProvider(serverFilter));
                  await ref.read(openWorkersProvider(serverFilter).future);
                }),
                child: ErrorView(
                  message: 'Liste yüklenemedi.',
                  onRetry: () =>
                      ref.invalidate(openWorkersProvider(serverFilter)),
                ),
              ),
              data: (raw) {
                Future<void> refresh() => awaitRefresh(() async {
                      ref.invalidate(openWorkersProvider(serverFilter));
                      await ref
                          .read(openWorkersProvider(serverFilter).future);
                    });
                final list = _filter.applyClientFilters(raw);
                if (list.isEmpty) {
                  return RefreshableEmpty(
                    onRefresh: refresh,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          raw.isEmpty
                              ? 'Müsait eleman yok.'
                              : 'Aramanıza uyan sonuç yok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.inkMuted),
                        ),
                      ),
                    ),
                  );
                }
                return ResponsiveCenter(
                  maxWidth: 720,
                  child: PullToRefresh(
                    onRefresh: refresh,
                    child: ListView.separated(
                      physics: kPullRefreshPhysics,
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text('${list.length} sonuç',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.inkMuted));
                        }
                      final w = list[i - 1];
                      return Material(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context
                              .push(RoutePaths.staffWorkerDetail(w.id)),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.border),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                    name: w.displayName,
                                    photo: w.photoUrl,
                                    size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(w.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                        '${w.professionLabel} · ${w.placeLabel}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: palette.inkMuted),
                                      ),
                                      Text(
                                        [
                                          w.rateLabel,
                                          if (w.isDaily) 'Gündelik',
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: palette.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: palette.inkFaint),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

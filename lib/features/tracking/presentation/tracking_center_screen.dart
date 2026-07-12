import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/track_item.dart';
import '../application/track_filter.dart';
import '../application/tracking_controller.dart';
import '../data/tracking_providers.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/track_card.dart';

class TrackingCenterScreen extends ConsumerStatefulWidget {
  const TrackingCenterScreen({super.key});

  @override
  ConsumerState<TrackingCenterScreen> createState() =>
      _TrackingCenterScreenState();
}

class _TrackingCenterScreenState extends ConsumerState<TrackingCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TrackFilter _filter = const TrackFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet(List<TrackItem> all) async {
    final result = await showTrackFilterSheet(
      context,
      current: _filter,
      allTags: collectTags(all),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(activeTracksProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Takip Merkezi',
        icon: Icons.checklist_rounded,
        subtitle: tracksAsync.valueOrNull == null
            ? null
            : _subtitle(tracksAsync.value!),
        actions: [
          IconButton(
            tooltip: 'Çöp Kutusu',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push(RoutePaths.trackingTrash),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.trackingNew),
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
      ),
      body: tracksAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Takipleriniz yüklenemedi. Lütfen tekrar deneyin.',
        ),
        data: (all) {
          final filtered = _filter.apply(all, query: _query);
          return Column(
            children: [
              _SearchAndFilter(
                controller: _searchController,
                filter: _filter,
                onQuery: (v) => setState(() => _query = v),
                onStatus: (s) =>
                    setState(() => _filter = _filter.copyWith(status: s)),
                onOpenFilters: () => _openFilterSheet(all),
              ),
              Expanded(
                child: all.isEmpty
                    ? const _FirstRunEmpty()
                    : filtered.isEmpty
                        ? const _NoResultEmpty()
                        : ResponsiveCenter(
                            maxWidth: 720,
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                return TrackCard(
                                  item: item,
                                  onTap: () => context
                                      .push(RoutePaths.trackDetail(item.id)),
                                  onToggleDone: () => ref
                                      .read(trackingControllerProvider)
                                      .toggleDone(item),
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(List<TrackItem> items) {
    if (items.isEmpty) return 'Henüz takip yok';
    final open = items.where((t) => !t.isDone).length;
    return '$open aktif · ${items.length} takip';
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.filter,
    required this.onQuery,
    required this.onStatus,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final TrackFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<TrackStatusFilter> onStatus;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ResponsiveCenter(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Takiplerinde ara',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Aramayı temizle',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                    ),
              filled: true,
              fillColor: palette.surfaceMuted,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in TrackStatusFilter.values) ...[
                        _StatusChip(
                          label: s.labelTR,
                          selected: filter.status == s,
                          onTap: () => onStatus(s),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _FilterButton(
                count: filter.advancedCount,
                onTap: onOpenFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filtresi',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.primary : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : palette.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gelişmiş filtre düğmesi; aktif filtre varsa sayısını rozet olarak gösterir.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = count > 0;
    return Tooltip(
      message: 'Filtrele ve sırala',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? palette.primaryContainer : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune,
                  size: 18,
                  color: active ? palette.primary : palette.inkMuted),
              if (active) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hiç kayıt yokken: ilk kayıt daveti (uygulamanın boş-durum dili).
class _FirstRunEmpty extends StatelessWidget {
  const _FirstRunEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
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
              child: Icon(Icons.checklist_rounded,
                  size: 34, color: palette.onPrimaryContainer),
            ),
            const SizedBox(height: 18),
            Text(
              'İlk takibini oluştur',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Randevu, görev, hatırlatma… Aklındaki her şeyi buraya not et, '
              'takipte kal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arama/filtre sonucu boşsa.
class _NoResultEmpty extends StatelessWidget {
  const _NoResultEmpty();

  @override
  Widget build(BuildContext context) {
    return const ErrorView(
      icon: Icons.search_off_rounded,
      title: 'Sonuç bulunamadı',
      message: 'Aramanı veya filtreyi değiştirmeyi dene.',
    );
  }
}

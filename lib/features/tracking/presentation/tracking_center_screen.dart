import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/track_item.dart';
import '../application/tracking_controller.dart';
import '../data/tracking_providers.dart';
import 'widgets/track_card.dart';

/// Durum filtresi (Faz 1 sade filtre; tam filtre paneli Faz 4).
enum _StatusFilter { all, active, done }

class TrackingCenterScreen extends ConsumerStatefulWidget {
  const TrackingCenterScreen({super.key});

  @override
  ConsumerState<TrackingCenterScreen> createState() =>
      _TrackingCenterScreenState();
}

class _TrackingCenterScreenState extends ConsumerState<TrackingCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrackItem> _apply(List<TrackItem> items) {
    final q = _query.trim().toLowerCase();
    return items.where((t) {
      switch (_filter) {
        case _StatusFilter.active:
          if (t.isDone) return false;
        case _StatusFilter.done:
          if (!t.isDone) return false;
        case _StatusFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          (t.note?.toLowerCase().contains(q) ?? false) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
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
          final filtered = _apply(all);
          return Column(
            children: [
              _SearchAndFilter(
                controller: _searchController,
                filter: _filter,
                onQuery: (v) => setState(() => _query = v),
                onFilter: (f) => setState(() => _filter = f),
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
    required this.onFilter,
  });

  final TextEditingController controller;
  final _StatusFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<_StatusFilter> onFilter;

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
              _FilterChip(
                label: 'Tümü',
                selected: filter == _StatusFilter.all,
                onTap: () => onFilter(_StatusFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Aktif',
                selected: filter == _StatusFilter.active,
                onTap: () => onFilter(_StatusFilter.active),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Tamamlanan',
                selected: filter == _StatusFilter.done,
                onTap: () => onFilter(_StatusFilter.done),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return GestureDetector(
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

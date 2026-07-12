import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/track_item.dart';
import '../application/tracking_controller.dart';
import '../data/tracking_providers.dart';

final _fullFmt = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR');

class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({super.key, required this.trackId});

  final String trackId;

  Future<void> _delete(
      BuildContext context, WidgetRef ref, TrackItem item) async {
    final ctrl = ref.read(trackingControllerProvider);
    await ctrl.moveToTrash(item.id);
    if (!context.mounted) return;
    context.showUndo(
      '"${item.title}" çöp kutusuna taşındı',
      onAction: () => ctrl.restore(item.id),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeTracksProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Takip',
        actions: [
          if (async.valueOrNull?.any((t) => t.id == trackId) ?? false) ...[
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(RoutePaths.trackEdit(trackId)),
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                final item = async.value!.firstWhere((t) => t.id == trackId);
                _delete(context, ref, item);
              },
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Takip yüklenemedi. Lütfen tekrar deneyin.',
        ),
        data: (list) {
          final item = list.firstWhereOrNull((t) => t.id == trackId);
          if (item == null) {
            return const ErrorView(
              icon: Icons.inventory_2_outlined,
              title: 'Bulunamadı',
              message: 'Bu takip silinmiş ya da taşınmış olabilir.',
            );
          }
          return _Detail(item: item);
        },
      ),
      bottomNavigationBar: async.valueOrNull
                  ?.firstWhereOrNull((t) => t.id == trackId) ==
              null
          ? null
          : _DoneBar(
              item: async.value!.firstWhere((t) => t.id == trackId),
              onToggle: (item) =>
                  ref.read(trackingControllerProvider).toggleDone(item),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.item});
  final TrackItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return ResponsiveCenter(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ListView(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                    color: item.isDone ? palette.inkMuted : palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(done: item.isDone),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.flag_outlined,
                label: 'Öncelik: ${item.priority.labelTR}',
              ),
              for (final t in item.tags)
                _InfoChip(icon: Icons.label_outline, label: t),
            ],
          ),
          if (item.note != null && item.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            _Card(
              child: Text(
                item.note!.trim(),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Oluşturuldu: ${_fullFmt.format(item.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
          ),
          if (item.updatedAt != item.createdAt)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Güncellendi: ${_fullFmt.format(item.updatedAt)}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = done ? palette.success : palette.warning;
    final surface = done ? palette.successSurface : palette.warningSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : Icons.schedule,
              size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            done ? 'Tamamlandı' : 'Aktif',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.inkMuted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: palette.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.item, required this.onToggle});
  final TrackItem item;
  final ValueChanged<TrackItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          // bottomNavigationBar'da ResponsiveCenter/Align kullanma (gövdeyi
          // 0px'e indirir — Oturum 41 regresyonu). Center(heightFactor:1).
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AppButton(
                label: item.isDone
                    ? 'Aktif olarak işaretle'
                    : 'Tamamlandı olarak işaretle',
                icon: item.isDone ? Icons.undo : Icons.check_circle_outline,
                variant: item.isDone
                    ? AppButtonVariant.outlined
                    : AppButtonVariant.filled,
                onPressed: () => onToggle(item),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

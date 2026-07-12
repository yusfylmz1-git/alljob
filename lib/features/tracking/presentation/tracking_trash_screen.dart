import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/track_item.dart';
import '../application/tracking_controller.dart';
import '../data/tracking_providers.dart';

final _dayFmt = DateFormat('d MMM yyyy', 'tr_TR');

class TrackingTrashScreen extends ConsumerWidget {
  const TrackingTrashScreen({super.key});

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çöp kutusunu boşalt?'),
        content: const Text(
            'Buradaki tüm kayıtlar kalıcı olarak silinir. Bu işlem geri '
            'alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Boşalt'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(trackingControllerProvider).emptyTrash();
    if (!context.mounted) return;
    context.showSuccess('Çöp kutusu boşaltıldı.');
  }

  Future<void> _deleteForever(
      BuildContext context, WidgetRef ref, TrackItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalıcı olarak sil?'),
        content: Text('"${item.title}" kalıcı olarak silinecek. Bu işlem '
            'geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(trackingControllerProvider).deletePermanently(item.id);
    if (!context.mounted) return;
    context.showSuccess('Kalıcı olarak silindi.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trashedTracksProvider);
    final count = async.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Çöp Kutusu',
        icon: Icons.delete_outline,
        actions: [
          if (count > 0)
            TextButton(
              onPressed: () => _emptyTrash(context, ref),
              child: const Text('Boşalt',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Çöp kutusu yüklenemedi. Lütfen tekrar deneyin.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const ErrorView(
              icon: Icons.delete_outline,
              title: 'Çöp kutusu boş',
              message: 'Sildiğiniz takipler, kalıcı olarak silinene kadar '
                  'burada bekler.',
            );
          }
          return ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = items[i];
                return _TrashRow(
                  item: item,
                  onRestore: () async {
                    await ref
                        .read(trackingControllerProvider)
                        .restore(item.id);
                    if (context.mounted) {
                      context.showSuccess('Takip geri alındı.');
                    }
                  },
                  onDeleteForever: () => _deleteForever(context, ref, item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final TrackItem item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (item.deletedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_dayFmt.format(item.deletedAt!)} tarihinde silindi',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.inkFaint),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Geri al',
            icon: Icon(Icons.restore, color: palette.primary),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Kalıcı sil',
            icon: Icon(Icons.delete_forever_outlined, color: palette.danger),
            onPressed: onDeleteForever,
          ),
        ],
      ),
    );
  }
}

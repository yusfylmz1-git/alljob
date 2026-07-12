import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/track_item.dart';

final _dayFmt = DateFormat('d MMM', 'tr_TR');
final _timeFmt = DateFormat('HH:mm', 'tr_TR');

/// Takip listesindeki tek kart. Uygulamanın kart dili: 16px köşe, yumuşak
/// gölge, `context.palette`. Sol dairesel kutu tamamlanmayı açar/kapatır;
/// karta dokununca detaya gider.
class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleDone,
  });

  final TrackItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final done = item.isDone;

    return TapScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckCircle(done: done, onTap: onToggleDone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: done ? palette.inkFaint : palette.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: palette.inkFaint,
                    ),
                  ),
                  if (item.note != null && item.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.note!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  ],
                  if (_hasMeta) ...[
                    const SizedBox(height: 8),
                    _MetaRow(item: item),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  bool get _hasMeta =>
      item.priority != TrackPriority.normal ||
      item.tags.isNotEmpty ||
      item.hasReminder;
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? palette.success : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? palette.success : palette.borderStrong,
              width: 2,
            ),
          ),
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Öncelik / etiket / hatırlatma küçük rozetleri.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final TrackItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chips = <Widget>[];

    if (item.priority == TrackPriority.high) {
      chips.add(_Pill(
        icon: Icons.flag_rounded,
        label: 'Yüksek',
        color: palette.danger,
        surface: palette.dangerSurface,
      ));
    } else if (item.priority == TrackPriority.low) {
      chips.add(_Pill(
        icon: Icons.outlined_flag,
        label: 'Düşük',
        color: palette.inkMuted,
        surface: palette.surfaceMuted,
      ));
    }

    if (item.hasReminder) {
      final r = item.reminderAt!;
      final now = DateTime.now();
      final sameDay =
          r.year == now.year && r.month == now.month && r.day == now.day;
      chips.add(_Pill(
        icon: Icons.notifications_active_outlined,
        label: sameDay ? _timeFmt.format(r) : _dayFmt.format(r),
        color: palette.info,
        surface: palette.infoSurface,
      ));
    }

    for (final t in item.tags.take(2)) {
      chips.add(_Pill(
        icon: Icons.label_outline,
        label: t,
        color: palette.inkMuted,
        surface: palette.surfaceMuted,
      ));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.surface,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/premium_surface_card.dart';
import '../../../../data/models/staffing.dart';

/// Minimal eleman kartı — liste / Keşfet ortak.
class StaffWorkerCard extends StatelessWidget {
  const StaffWorkerCard({
    super.key,
    required this.worker,
    required this.onTap,
  });

  final StaffWorkerListing worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return PremiumSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 16,
      glass: false,
      child: Row(
        children: [
          AppAvatar(
            name: worker.displayName,
            photo: worker.photoUrl,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.title.isEmpty ? worker.displayName : worker.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (worker.professionLabel.isNotEmpty)
                      worker.professionLabel,
                    worker.placeLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MiniChip(
                      label: worker.rateLabel,
                      fg: palette.primary,
                      bg: palette.primaryContainer,
                    ),
                    if (worker.isDaily)
                      _MiniChip(
                        label: 'Gündelik',
                        fg: palette.info,
                        bg: palette.infoSurface,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: palette.inkMuted),
        ],
      ),
    );
  }
}

/// Minimal işveren ilanı kartı — liste / Keşfet ortak.
class StaffNeedCard extends StatelessWidget {
  const StaffNeedCard({
    super.key,
    required this.need,
    this.onTap,
    this.onContact,
    this.showContact = true,
  });

  final StaffNeed need;
  final VoidCallback? onTap;
  final VoidCallback? onContact;
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final date = need.workDate == null
        ? null
        : DateFormat('d MMM', 'tr_TR').format(need.workDate!);

    return PremiumSurfaceCard(
      onTap: onTap ?? onContact,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      borderRadius: 16,
      glass: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumIconWell(
                size: 44,
                child: Icon(
                  need.isDaily
                      ? Icons.today_rounded
                      : Icons.work_outline_rounded,
                  size: 20,
                  color: palette.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      need.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${need.employerName} · ${need.placeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (need.detail.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              need.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniChip(
                      label: '${need.neededCount} kişi',
                      fg: palette.inkMuted,
                      bg: palette.surfaceMuted,
                    ),
                    _MiniChip(
                      label: need.rateLabel,
                      fg: palette.primary,
                      bg: palette.primaryContainer,
                    ),
                    if (need.isDaily)
                      _MiniChip(
                        label: 'Gündelik',
                        fg: palette.info,
                        bg: palette.infoSurface,
                      ),
                    if (date != null)
                      _MiniChip(
                        label: date,
                        fg: palette.inkMuted,
                        bg: palette.surfaceMuted,
                      ),
                  ],
                ),
              ),
              if (showContact && onContact != null)
                TextButton(
                  onPressed: onContact,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Yaz'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

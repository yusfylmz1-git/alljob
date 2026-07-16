import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/shop_completion.dart';

/// Eksik vitrin adımlarını gösteren kompakt funnel kartı.
class ShopCompletionBanner extends StatelessWidget {
  const ShopCompletionBanner({
    super.key,
    required this.completion,
    this.compact = false,
    this.title = 'Vitrininizi tamamlayın',
  });

  final ShopCompletion completion;
  final bool compact;
  final String title;

  Future<void> _openEdit(BuildContext context) async {
    final next = completion.nextMissing;
    await AppAnalytics.shopCompletionCta(
      step: next?.id,
      percent: completion.percent,
    );
    if (!context.mounted) return;
    final path = next == null
        ? RoutePaths.panelEdit
        : RoutePaths.panelEditFocus(next.id);
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    if (completion.isComplete) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;
    final next = completion.nextMissing;

    return Material(
      color: palette.warningSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEdit(context),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: palette.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '%${completion.percent}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: palette.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: completion.progress,
                  minHeight: 6,
                  backgroundColor: palette.card.withValues(alpha: 0.6),
                  color: palette.warning,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Sıradaki: ${next.label} — ${next.hint}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!compact) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in completion.steps)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          s.ok ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: s.ok ? palette.success : palette.inkFaint,
                        ),
                        label: Text(s.label, style: const TextStyle(fontSize: 12)),
                        backgroundColor: s.ok
                            ? palette.success.withValues(alpha: 0.1)
                            : palette.card.withValues(alpha: 0.5),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openEdit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(next == null ? 'Vitrini düzenle' : 'Şimdi tamamla'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

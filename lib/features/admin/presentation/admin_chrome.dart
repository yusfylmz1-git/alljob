import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Admin ops konsolu renkleri (tüketici gradyanından bağımsız, sade “console”).
abstract final class AdminChrome {
  static const Color railBg = Color(0xFF0F172A);
  static const Color railFg = Color(0xFFE2E8F0);
  static const Color railMuted = Color(0xFF94A3B8);
  static const Color railSelected = Color(0xFF38BDF8);
  static const Color railSelectedBg = Color(0x1A38BDF8);
  static const Color topBarBg = Color(0xFF111827);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);

  /// Sayfa üst şeridi: başlık + alt yazı + aksiyonlar (GradientAppBar yerine).
  static PreferredSizeWidget pageHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    List<Widget>? actions,
  }) {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.palette.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// KPI / özet kartı (dashboard).
  static Widget metricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
    VoidCallback? onTap,
    String? hint,
  }) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    final child = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: context.palette.inkFaint),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.palette.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.palette.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

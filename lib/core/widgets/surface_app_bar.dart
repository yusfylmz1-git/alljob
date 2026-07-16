import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Liste / hub ekranları için sade premium app bar.
///
/// Gradyan yok: kart yüzeyi + ince alt çizgi + primary accent çizgisi.
/// [GradientAppBar] ile aynı API — drop-in değişim.
///
/// Kullanım: `SurfaceAppBar(title: 'İlanlarım')`.
class SurfaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SurfaceAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final IconData? icon;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 58 : 72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: palette.card,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: palette.ink),
      actionsIconTheme: IconThemeData(color: palette.ink),
      toolbarHeight: preferredSize.height,
      titleSpacing: 4,
      // leading: dokunulmaz (drawer / geri).
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          boxShadow: AppTheme.softShadow,
          border: Border(
            bottom: BorderSide(color: palette.hairline),
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 2.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.primary.withValues(alpha: 0),
                  palette.primary.withValues(alpha: 0.55),
                  palette.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: palette.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.inkMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}

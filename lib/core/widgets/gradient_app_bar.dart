import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// İkincil ekranların (İlanlarım, Bildirimler, Favorilerim…) sade başlıklarını
/// Keşfet/Profil hero'suyla aynı dile getiren drop-in app bar: lacivert
/// gradyan + hafif turuncu ışık, beyaz metin, alttan yuvarlatılmış köşeler.
///
/// Kullanım: `AppBar(title: Text('İlanlarım'))` → `GradientAppBar(title: 'İlanlarım')`.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.icon,
  });

  final String title;

  /// İsteğe bağlı ikinci satır (ör. "3 açık ilan").
  final String? subtitle;
  final List<Widget>? actions;

  /// Başlığın solunda küçük bir ikon rozeti (isteğe bağlı).
  final IconData? icon;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 60 : 76);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      toolbarHeight: preferredSize.height,
      flexibleSpace: const _GradientBackground(),
      titleSpacing: 4,
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
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
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          gradient: RadialGradient(
            center: Alignment(0.85, -1.2),
            radius: 1.1,
            colors: [Color(0x47EA580C), Color(0x00EA580C)],
          ),
        ),
      ),
    );
  }
}

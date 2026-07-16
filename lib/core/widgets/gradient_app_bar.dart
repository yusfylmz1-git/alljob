import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// İkincil ekran app bar: moda göre gradyan, beyaz metin, yuvarlatılmış alt,
/// hafif gölge. API geriye uyumlu — sayfa kodu değişmez.
///
/// Kullanım: `GradientAppBar(title: 'İlanlarım')`.
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
  Size get preferredSize => Size.fromHeight(subtitle == null ? 62 : 78);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Action ikonları gradyan üzerinde daha okunaklı “cam” daire.
    // IconButton dışındaki widget'lar (FilledButton vb.) olduğu gibi kalır.
    final styledActions = actions
        ?.map((w) {
          if (w is IconButton) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Material(
                color: Colors.white.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white, size: 22),
                  child: w,
                ),
              ),
            );
          }
          return w;
        })
        .toList();

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
      // leading: dokunulmaz — drawer hamburger / varsayılan geri bozulmasın.
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
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
                    height: 1.15,
                    shadows: const [
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
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
      actions: styledActions,
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    // Üst bar zemini aktif moda göre (müşteri mavi / usta yeşil).
    return Container(
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sağ üst cam ışıltı
          Container(
            decoration: const BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(22)),
              gradient: RadialGradient(
                center: Alignment(0.88, -1.15),
                radius: 1.15,
                colors: [Color(0x28FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          // Alt kenar ince highlight
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

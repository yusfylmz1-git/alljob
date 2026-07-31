import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Ortak “cam / premium” kart kabuğu — usta kartı, iş ilanı, favori listesi.
///
/// BackdropFilter yok (liste performansı). Yarı saydam gradyan + ışıltı + gölge.
class PremiumSurfaceCard extends StatelessWidget {
  const PremiumSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 18,
    this.accentBorder,
    this.accentWidth = 1.2,
    /// false: düz kart (iş ilanı listeleri). true: cam gradyan (usta kartı).
    this.glass = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  /// null = varsayılan hairline; premium vb. için özel renk.
  final Color? accentBorder;
  final double accentWidth;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final borderColor = accentBorder ??
        palette.hairline.withValues(alpha: isDark ? 0.9 : 1);

    final glassFill = Color.alphaBlend(
      palette.primary.withValues(alpha: isDark ? 0.06 : 0.03),
      palette.card.withValues(alpha: isDark ? 0.92 : 0.94),
    );

    final BoxDecoration decoration;
    if (glass) {
      decoration = BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor, width: accentWidth),
        boxShadow: AppTheme.softShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.08 : 0.72),
            glassFill,
            palette.card,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      );
    } else {
      // Düz yüzey: iş/ilan listeleri — gradyan yok, sade okunur.
      decoration = BoxDecoration(
        color: palette.card,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: accentWidth),
        boxShadow: AppTheme.softShadow,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: palette.primary.withValues(alpha: 0.04),
        splashColor: palette.primary.withValues(alpha: 0.08),
        child: Ink(
          decoration: decoration,
          child: Stack(
            children: [
              if (glass)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(borderRadius - 1),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white
                                .withValues(alpha: isDark ? 0.10 : 0.50),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste satırlarında sol ikon/emoji için cam kutu.
class PremiumIconWell extends StatelessWidget {
  const PremiumIconWell({
    super.key,
    required this.child,
    this.size = 44,
    this.color,
  });

  final Widget child;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (color ?? palette.surfaceMuted)
            .withValues(alpha: isDark ? 0.5 : 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline.withValues(alpha: 0.9)),
      ),
      child: child,
    );
  }
}

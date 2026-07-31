import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/tap_scale.dart';

/// Keşfet üst sekme çubuğu — renkli ikon kartları, minimal ve responsive.
///
/// Seçili sekme soft glow + dolgulu yüzey; diğerleri pastel ve sakin.
/// Dar ekranda yatay kaydırma, geniş ekranda eşit genişlik.
class ExploreTabBar<T> extends StatelessWidget {
  const ExploreTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<ExploreTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final count = items.length;
        final gap = maxW < 360 ? 8.0 : 10.0;
        final padH = maxW < 360 ? 10.0 : 12.0;
        const padV = 10.0;
        final minTile = maxW < 340 ? 68.0 : 76.0;
        final needed =
            padH * 2 + minTile * count + gap * (count > 1 ? count - 1 : 0);
        final scroll = needed > maxW + 0.5;
        final tileH = maxW < 360 ? 78.0 : 86.0;

        Widget tile(ExploreTabItem<T> item, {required bool expand}) {
          final child = _ExploreTabTile<T>(
            item: item,
            selected: item.value == selected,
            height: tileH,
            onTap: () => _select(item.value),
          );
          if (expand) return Expanded(child: child);
          return SizedBox(width: minTile, child: child);
        }

        final children = <Widget>[
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: gap),
            tile(items[i], expand: !scroll),
          ],
        ];

        final row = Row(
          mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
          children: children,
        );

        return Container(
          padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
          decoration: BoxDecoration(
            color: isDark
                ? palette.surfaceMuted.withValues(alpha: 0.55)
                : palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: palette.hairline.withValues(alpha: isDark ? 0.9 : 1),
            ),
            boxShadow: isDark ? null : AppTheme.softShadow,
          ),
          child: scroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: row,
                )
              : row,
        );
      },
    );
  }

  void _select(T value) {
    if (value == selected) return;
    HapticFeedback.selectionClick();
    onChanged(value);
  }
}

class ExploreTabItem<T> {
  const ExploreTabItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final T value;
  final String label;
  final IconData icon;
  final Color accent;
}

class _ExploreTabTile<T> extends StatelessWidget {
  const _ExploreTabTile({
    required this.item,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final ExploreTabItem<T> item;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = item.accent;
    // Seçili değilken biraz soluk; seçilince doygun + glow.
    final top = Color.lerp(
      accent,
      Colors.white,
      selected ? 0.14 : (isDark ? 0.06 : 0.22),
    )!;
    final bottom = Color.lerp(
      accent,
      Colors.black,
      selected ? 0.10 : (isDark ? 0.18 : 0.06),
    )!;
    final dim = selected ? 1.0 : (isDark ? 0.72 : 0.82);

    return Opacity(
      opacity: dim,
      child: TapScale(
        scale: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Color.lerp(accent, const Color(0xFF67E8F9), 0.55)!
                      .withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: isDark ? 0.12 : 0.35),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 0),
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withValues(alpha: 0.16),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: selected ? 36 : 34,
                      height: selected ? 36 : 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        size: selected ? 20 : 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        height: 1.1,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                        letterSpacing: selected ? 0.15 : 0,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0x33000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// İçeriği yatayda ortalar ve geniş ekranlarda (web/tablet/masaüstü) maksimum
/// genişlikle sınırlar. Böylece dropdown/liste tüm ekrana yayılmaz, mobil-öncesi
/// tasarım büyük ekranlarda da düzgün görünür.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Ekran genişliğine göre kırılım noktaları — responsive düzen kararları için.
class Breakpoints {
  Breakpoints._();
  static const double compact = 600; // telefon
  static const double medium = 1000; // tablet / küçük masaüstü

  /// Genişliğe göre sütun sayısı (kart ızgarası için).
  static int columnsFor(double width) {
    if (width >= medium) return 3;
    if (width >= compact) return 2;
    return 1;
  }
}

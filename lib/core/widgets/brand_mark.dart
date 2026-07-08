import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marka logosu rozeti: turuncu gradyanlı yuvarlatılmış kare içinde
/// usta ikonu. Splash, giriş, başlık gibi tüm ekranlarda ortak kullanılır.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  /// Rozetin kenar uzunluğu (kare).
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.handyman_rounded,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}

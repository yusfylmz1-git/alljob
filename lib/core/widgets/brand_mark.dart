import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uygulama içi marka logosu.
///
/// Kaynak: `assets/brand/logo.png` (kare, şeffaf; içerik dolu kırpılmış).
/// Varsayılan: yalnız PNG, [size] alanını doldurur (`BoxFit.cover` ile
/// küçük boşluk kalmaz). Dosya yoksa el aleti ikonu yedek.
///
/// TEK GÖRSEL: uygulamanın her yeri aynı logoyu kullanır. Yan menü için bir
/// süre ayrı bir `yan_logo.png` denendi; görünüm tutmadığı için geri alındı.
/// Dosyanın kendisi 2026-08-15 denetiminde SİLİNDİ — kod hiç yüklemediği hâlde
/// 4,85 MB olarak pakete giriyordu (toplam varlıkların yarısı).
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 48,
    this.showBackground = false,
  });

  /// Logo kenar uzunluğu (mantıksal px).
  final double size;

  /// true: turuncu gradyan rozet. Varsayılan false (yalnız PNG).
  final bool showBackground;

  static const String assetPath = 'assets/brand/logo.png';

  @override
  Widget build(BuildContext context) {
    // cover: PNG içindeki boşluk/aspect yüzünden “ufak” kalmayı engeller.
    final logo = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.handyman_rounded,
        size: size * 0.55,
        color: showBackground ? Colors.white : AppColors.primary,
      ),
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRect(child: logo),
      );
    }

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
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        assetPath,
        width: size * 0.88,
        height: size * 0.88,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Icon(
          Icons.handyman_rounded,
          size: size * 0.55,
          color: Colors.white,
        ),
      ),
    );
  }
}

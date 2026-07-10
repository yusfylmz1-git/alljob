import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema-farkındalıklı semantik renk paleti.
///
/// [AppColors] açık temanın sabitlerini tutar; bu extension her iki tema için
/// aynı SEMANTİK isimleri sunar. Ekranlar `context.palette.ink` gibi erişir;
/// tema değişince renkler otomatik uyum sağlar. Yeni kodda statik
/// `AppColors.x` yerine HEP `context.palette.x` kullanılmalı (statik erişim
/// yalnızca tema kurulumunda ve gradyan sabitlerinde kalır).
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.background,
    required this.card,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.hairline,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.info,
    required this.infoSurface,
    required this.verified,
    required this.star,
    required this.premium,
    required this.premiumSurface,
  });

  // ── Marka ──
  final Color primary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  // ── Mürekkep (metin) ──
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  // ── Yüzeyler ──
  final Color background;

  /// Kart/yüzey zemini (açık temada beyaz).
  final Color card;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color hairline;

  // ── Semantik ──
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;
  final Color info;
  final Color infoSurface;

  // ── Özel vurgular ──
  final Color verified;
  final Color star;
  final Color premium;
  final Color premiumSurface;

  /// Açık tema: [AppColors] sabitlerinin birebir karşılığı.
  static const AppPalette light = AppPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    inkFaint: AppColors.inkFaint,
    background: AppColors.background,
    card: Colors.white,
    surfaceMuted: AppColors.surfaceMuted,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    hairline: AppColors.hairline,
    success: AppColors.success,
    successSurface: AppColors.successSurface,
    warning: AppColors.warning,
    warningSurface: AppColors.warningSurface,
    danger: AppColors.danger,
    dangerSurface: AppColors.dangerSurface,
    info: AppColors.info,
    infoSurface: AppColors.infoSurface,
    verified: AppColors.verified,
    star: AppColors.star,
    premium: AppColors.premium,
    premiumSurface: AppColors.premiumSurface,
  );

  /// Koyu tema: `AppTheme._darkScheme` ile uyumlu, elle seçilmiş tonlar.
  /// Vurgu renkleri koyu zeminde okunacak kadar açık; "surface" tonları
  /// zeminden bir kademe ayrışan lacivert-gri katmanlar.
  static const AppPalette dark = AppPalette(
    primary: Color(0xFFFF8A4C),
    primaryDark: Color(0xFFEA580C),
    primaryContainer: Color(0xFF7C2D12),
    onPrimaryContainer: Color(0xFFFFEDD5),
    secondary: Color(0xFF9DB8D4),
    secondaryContainer: Color(0xFF27415C),
    onSecondaryContainer: Color(0xFFDCE7F3),
    ink: Color(0xFFF2F4F7),
    inkMuted: Color(0xFF98A2B3),
    inkFaint: Color(0xFF667085),
    background: Color(0xFF101623),
    card: Color(0xFF1D2433),
    surfaceMuted: Color(0xFF242C3D),
    border: Color(0xFF344054),
    borderStrong: Color(0xFF475467),
    hairline: Color(0xFF273043),
    success: Color(0xFF32D583),
    successSurface: Color(0xFF10352A),
    warning: Color(0xFFFDB022),
    warningSurface: Color(0xFF3E2A08),
    danger: Color(0xFFF97066),
    dangerSurface: Color(0xFF44140F),
    info: Color(0xFF7DAFFF),
    infoSurface: Color(0xFF16294A),
    verified: Color(0xFF7DAFFF),
    star: Color(0xFFFDB022),
    premium: Color(0xFFE9A23B),
    premiumSurface: Color(0xFF362508),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? background,
    Color? card,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? hairline,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? info,
    Color? infoSurface,
    Color? verified,
    Color? star,
    Color? premium,
    Color? premiumSurface,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      background: background ?? this.background,
      card: card ?? this.card,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      hairline: hairline ?? this.hairline,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      verified: verified ?? this.verified,
      star: star ?? this.star,
      premium: premium ?? this.premium,
      premiumSurface: premiumSurface ?? this.premiumSurface,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      secondary: c(secondary, other.secondary),
      secondaryContainer: c(secondaryContainer, other.secondaryContainer),
      onSecondaryContainer:
          c(onSecondaryContainer, other.onSecondaryContainer),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      background: c(background, other.background),
      card: c(card, other.card),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      hairline: c(hairline, other.hairline),
      success: c(success, other.success),
      successSurface: c(successSurface, other.successSurface),
      warning: c(warning, other.warning),
      warningSurface: c(warningSurface, other.warningSurface),
      danger: c(danger, other.danger),
      dangerSurface: c(dangerSurface, other.dangerSurface),
      info: c(info, other.info),
      infoSurface: c(infoSurface, other.infoSurface),
      verified: c(verified, other.verified),
      star: c(star, other.star),
      premium: c(premium, other.premium),
      premiumSurface: c(premiumSurface, other.premiumSurface),
    );
  }
}

/// Ekranların palete tek satırla erişmesi için kısayol:
/// `context.palette.success` gibi.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

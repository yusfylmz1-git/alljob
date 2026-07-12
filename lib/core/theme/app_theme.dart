import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_accent.dart';
import 'app_colors.dart';
import 'app_palette.dart';

/// Uygulamanın açık ve koyu temaları.
///
/// Tasarım dili: Inter tipografisi, elle seçilmiş renk paleti (seed türetmesi
/// yok), yumuşak gölgeli beyaz kartlar, dolgulu (filled) input alanları ve
/// 12px köşe yarıçaplı butonlar. Tüm bileşen stilleri burada merkezîdir;
/// ekranlar mümkün olduğunca temaya yaslanır.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  /// Kart ve yüzeylerde kullanılan yumuşak gölge.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Yüzen öğeler (alt bar, cam paneller) için daha belirgin gölge.
  static List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(0xFF101828).withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Aktif moda göre vurgu rengi enjekte edilmiş temalar. [accent] verilmezse
  /// müşteri (mavi) varsayılanı kullanılır — misafir/oturumsuz akış için.
  static ThemeData light([AppAccent? accent]) =>
      _build(Brightness.light, accent ?? AppAccent.customerLight);
  static ThemeData dark([AppAccent? accent]) =>
      _build(Brightness.dark, accent ?? AppAccent.customerDark);

  static ColorScheme _lightScheme() => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.info,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.infoSurface,
        onTertiaryContainer: Color(0xFF0B4A9E),
        error: AppColors.danger,
        onError: Colors.white,
        errorContainer: AppColors.dangerSurface,
        onErrorContainer: Color(0xFF7A271A),
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMuted,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Color(0xFFF7F8FA),
        surfaceContainer: AppColors.surfaceMuted,
        surfaceContainerHigh: Color(0xFFECEEF2),
        surfaceContainerHighest: Color(0xFFE4E7EC),
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFF1D2939),
        onInverseSurface: Color(0xFFF2F4F7),
        inversePrimary: Color(0xFFFFB787),
      );

  static ColorScheme _darkScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFF8A4C),
        onPrimary: Color(0xFF431407),
        primaryContainer: Color(0xFF7C2D12),
        onPrimaryContainer: Color(0xFFFFEDD5),
        secondary: Color(0xFF9DB8D4),
        onSecondary: Color(0xFF0F2438),
        secondaryContainer: Color(0xFF27415C),
        onSecondaryContainer: Color(0xFFDCE7F3),
        tertiary: Color(0xFF7DAFFF),
        onTertiary: Color(0xFF0B2B5C),
        tertiaryContainer: Color(0xFF1D4B8F),
        onTertiaryContainer: Color(0xFFE0EDFF),
        error: Color(0xFFF97066),
        onError: Color(0xFF55160C),
        errorContainer: Color(0xFF912018),
        onErrorContainer: Color(0xFFFEE4E2),
        surface: Color(0xFF161B26),
        onSurface: Color(0xFFF2F4F7),
        onSurfaceVariant: Color(0xFF98A2B3),
        surfaceContainerLowest: Color(0xFF0C111D),
        surfaceContainerLow: Color(0xFF101623),
        surfaceContainer: Color(0xFF1D2433),
        surfaceContainerHigh: Color(0xFF242C3D),
        surfaceContainerHighest: Color(0xFF2C354A),
        outline: Color(0xFF475467),
        outlineVariant: Color(0xFF344054),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFFF2F4F7),
        onInverseSurface: Color(0xFF1D2939),
        inversePrimary: AppColors.primary,
      );

  static ThemeData _build(Brightness brightness, AppAccent accent) {
    final isLight = brightness == Brightness.light;
    // Vurgu (primary) ailesini aktif moda göre değiştir; geri kalan tüm renk
    // rolleri (yüzey/metin/semantik) markayla aynı kalır.
    final scheme = (isLight ? _lightScheme() : _darkScheme()).copyWith(
      primary: accent.primary,
      onPrimary: accent.onPrimary,
      primaryContainer: accent.primaryContainer,
      onPrimaryContainer: accent.onPrimaryContainer,
      inversePrimary: accent.inversePrimary,
    );

    final scaffoldBg =
        isLight ? AppColors.background : scheme.surfaceContainerLow;
    final cardColor = isLight ? Colors.white : scheme.surfaceContainer;
    final borderColor = scheme.outlineVariant;
    // Kart kenarları daha ince (nefes alan) bir çizgi kullanır.
    final cardBorderColor = isLight ? AppColors.hairline : scheme.outlineVariant;
    final fillColor = isLight ? Colors.white : scheme.surfaceContainer;

    final textTheme = _textTheme(scheme);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [
        (isLight ? AppPalette.light : AppPalette.dark).copyWith(
          primary: accent.primary,
          primaryDark: accent.primaryDark,
          primaryContainer: accent.primaryContainer,
          onPrimaryContainer: accent.onPrimaryContainer,
        ),
      ],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight ? Colors.white : scheme.surface,
        foregroundColor: scheme.onSurface,
        shape: Border(bottom: BorderSide(color: borderColor)),
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? AppColors.inkFaint : scheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Yükseklik 50; genişlik doğal (tam genişlik için AppButton).
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ).copyWith(
          // Basılıyken bir ton koyulaş — canlı his verir.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.black.withValues(alpha: 0.06);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cardBorderColor),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            isLight ? AppColors.surfaceMuted : scheme.surfaceContainerHigh,
        side: BorderSide(color: borderColor),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          side: BorderSide(color: borderColor),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        strokeCap: StrokeCap.round,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: textTheme.titleSmall,
      ),
    );
  }

  /// Inter tabanlı tipografi ölçeği: başlıklarda sıkı letter-spacing ve
  /// güçlü ağırlıklar, gövdede rahat okunurluk.
  static TextTheme _textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    TextStyle s(double size, FontWeight weight,
        {double? spacing, double? height, Color? color}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing ?? 0,
        height: height,
        color: color ?? ink,
      );
    }

    return TextTheme(
      displayLarge: s(48, FontWeight.w800, spacing: -1.2, height: 1.1),
      displayMedium: s(38, FontWeight.w800, spacing: -1.0, height: 1.12),
      displaySmall: s(32, FontWeight.w800, spacing: -0.8, height: 1.15),
      headlineLarge: s(28, FontWeight.w800, spacing: -0.7, height: 1.2),
      headlineMedium: s(24, FontWeight.w700, spacing: -0.5, height: 1.22),
      headlineSmall: s(20, FontWeight.w700, spacing: -0.4, height: 1.25),
      titleLarge: s(18, FontWeight.w700, spacing: -0.3, height: 1.3),
      titleMedium: s(16, FontWeight.w600, spacing: -0.2, height: 1.35),
      titleSmall: s(14, FontWeight.w600, spacing: -0.1, height: 1.4),
      bodyLarge: s(16, FontWeight.w400, height: 1.5),
      bodyMedium: s(14, FontWeight.w400, height: 1.5),
      bodySmall: s(12, FontWeight.w400, height: 1.45, color: muted),
      labelLarge: s(14, FontWeight.w600, spacing: -0.1),
      labelMedium: s(12, FontWeight.w500),
      labelSmall: s(11, FontWeight.w500, spacing: 0.1),
    );
  }
}

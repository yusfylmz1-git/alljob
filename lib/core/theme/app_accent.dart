import 'package:flutter/material.dart';

/// Aktif kullanıcı moduna (müşteri / usta) göre değişen VURGU renk seti.
///
/// Uygulamanın markası (logo, hero gradyanı) sabit kalır; ancak etkileşim
/// vurgusu — butonlar, FAB, bağlantılar, odak kenarları, sekmeler, çipler,
/// `GradientAppBar` ışıması — moda göre çevrilir:
///  - **Müşteri (ve misafir):** güven veren tatlı mavi.
///  - **Usta:** profesyonel zümrüt yeşili.
///
/// [AppTheme] bu seti hem `ColorScheme`'in primary ailesine hem de
/// [AppPalette]'in primary alanlarına enjekte eder; mod değişince
/// `ThemeExtension.lerp` sayesinde renkler yumuşakça geçer.
class AppAccent {
  const AppAccent({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;

  // ── Müşteri: tatlı mavi ───────────────────────────────────────────────
  static const AppAccent customerLight = AppAccent(
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    primaryDark: Color(0xFF1D4ED8),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    inversePrimary: Color(0xFF93C5FD),
  );

  static const AppAccent customerDark = AppAccent(
    primary: Color(0xFF6BA5FF),
    onPrimary: Color(0xFF0A2A5E),
    primaryDark: Color(0xFF3B82F6),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDBEAFE),
    inversePrimary: Color(0xFF2563EB),
  );

  // ── Usta: zümrüt yeşil ────────────────────────────────────────────────
  static const AppAccent artisanLight = AppAccent(
    primary: Color(0xFF059669),
    onPrimary: Colors.white,
    primaryDark: Color(0xFF047857),
    primaryContainer: Color(0xFFD1FAE5),
    onPrimaryContainer: Color(0xFF064E3B),
    inversePrimary: Color(0xFF6EE7B7),
  );

  static const AppAccent artisanDark = AppAccent(
    primary: Color(0xFF34D399),
    onPrimary: Color(0xFF063D2E),
    primaryDark: Color(0xFF059669),
    primaryContainer: Color(0xFF064E3B),
    onPrimaryContainer: Color(0xFFD1FAE5),
    inversePrimary: Color(0xFF059669),
  );

  /// Moda + parlaklığa göre doğru seti seçer.
  static AppAccent resolve({required bool artisan, required bool isDark}) {
    if (artisan) return isDark ? artisanDark : artisanLight;
    return isDark ? customerDark : customerLight;
  }
}

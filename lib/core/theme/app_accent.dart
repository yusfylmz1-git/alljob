import 'package:flutter/material.dart';

/// Tek bir parlaklık (açık VEYA koyu) için VURGU renk seti.
///
/// Uygulamanın markası (logo, `brandGradient`) sabit kalır; ancak etkileşim
/// vurgusu — butonlar, FAB, bağlantılar, odak kenarları, sekmeler, çipler,
/// üst bar / hero gradyanı — aktif moda ve kullanıcının SEÇTİĞİ renge göre
/// değişir. Hazır renkler [AccentOption] içinde tanımlıdır; [AppTheme] bu seti
/// hem `ColorScheme`'in primary ailesine hem de [AppPalette]'e enjekte eder.
class AppAccent {
  const AppAccent({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
    required this.heroTop,
    required this.heroBottom,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;

  /// Hero başlık/üst bar gradyanının üst-alt durakları (beyaz metin okunacak
  /// kadar koyu). Her iki tema için ortaktır.
  final Color heroTop;
  final Color heroBottom;
}

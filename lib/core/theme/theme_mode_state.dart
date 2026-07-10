import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'theme_mode_v1';

/// Kullanıcının tema tercihi (Sistem / Açık / Koyu). Varsayılan SİSTEM:
/// cihaz karanlık moddaysa uygulama da karanlık açılır. Gerçek değer
/// `main.dart`'ta cihaz kayıtlarından okunup ProviderScope override'ı ile
/// verilir (onboarding kalıbı); testler override'sız SİSTEM ile çalışır.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// Kalıcı tercih anahtarı ↔ ThemeMode eşlemesi.
ThemeMode _fromKey(String? key) => switch (key) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String _toKey(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// Cihazdan tema tercihini okur; hata/kayıt yoksa SİSTEM.
Future<ThemeMode> readThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return _fromKey(prefs.getString(_kThemeModeKey));
  } catch (_) {
    return ThemeMode.system;
  }
}

/// Tema tercihini kalıcı olarak kaydeder.
Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _toKey(mode));
  } catch (_) {/* kalıcı yazım başarısızsa tercih bu oturumla sınırlı kalır */}
}

/// Menüde gösterilen kısa etiket.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Açık',
      ThemeMode.dark => 'Koyu',
      ThemeMode.system => 'Sistem',
    };

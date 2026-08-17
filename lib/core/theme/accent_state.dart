import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent_options.dart';

/// Tek uygulama vurgu rengi (mod switch kalktı).
const String _kAccentKey = 'accent_app_v1';
const String _kLegacyCustomerKey = 'accent_customer_v1';
const String _kLegacyArtisanKey = 'accent_artisan_v1';

/// Uygulama vurgu rengi (seçenek id'si). `main.dart` cihazdan okuyup override eder.
final accentIdProvider = StateProvider<String>((_) => kDefaultAccentId);

bool _isValid(String? v) =>
    v != null && kAccentOptions.any((o) => o.id == v);

Future<String> readAccentId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final neu = prefs.getString(_kAccentKey);
    if (_isValid(neu)) return neu!;

    // Göç: eski müşteri → usta tercihi.
    final legacy = prefs.getString(_kLegacyCustomerKey) ??
        prefs.getString(_kLegacyArtisanKey);
    final id = _isValid(legacy) ? legacy! : kDefaultAccentId;
    if (_isValid(legacy)) {
      await prefs.setString(_kAccentKey, id);
    }
    return id;
  } catch (_) {
    return kDefaultAccentId;
  }
}

Future<void> saveAccentId(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentKey, id);
  } catch (_) {/* oturumla sınırlı */}
}

// Eski API (test uyumu).
Future<String> readCustomerAccentId() => readAccentId();
Future<String> readArtisanAccentId() => readAccentId();
Future<void> saveCustomerAccentId(String id) => saveAccentId(id);
Future<void> saveArtisanAccentId(String id) => saveAccentId(id);

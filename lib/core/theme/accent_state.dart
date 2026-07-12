import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent_options.dart';

const String _kCustomerAccentKey = 'accent_customer_v1';
const String _kArtisanAccentKey = 'accent_artisan_v1';

/// Müşteri modundaki vurgu rengi (seçenek id'si). Gerçek değer `main.dart`'ta
/// cihazdan okunup ProviderScope override'ı ile verilir (tema kalıbı);
/// testler override'sız varsayılanla çalışır.
final customerAccentIdProvider =
    StateProvider<String>((_) => kDefaultCustomerAccentId);

/// Usta modundaki vurgu rengi (seçenek id'si).
final artisanAccentIdProvider =
    StateProvider<String>((_) => kDefaultArtisanAccentId);

Future<String> _read(String key, String fallback) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(key);
    // Yalnız geçerli bir seçenek id'si ise kullan (kaldırılan renklere karşı).
    return kAccentOptions.any((o) => o.id == v) ? v! : fallback;
  } catch (_) {
    return fallback;
  }
}

Future<void> _save(String key, String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, id);
  } catch (_) {/* kalıcı yazım başarısızsa tercih bu oturumla sınırlı kalır */}
}

Future<String> readCustomerAccentId() =>
    _read(_kCustomerAccentKey, kDefaultCustomerAccentId);
Future<String> readArtisanAccentId() =>
    _read(_kArtisanAccentKey, kDefaultArtisanAccentId);

Future<void> saveCustomerAccentId(String id) => _save(_kCustomerAccentKey, id);
Future<void> saveArtisanAccentId(String id) => _save(_kArtisanAccentKey, id);

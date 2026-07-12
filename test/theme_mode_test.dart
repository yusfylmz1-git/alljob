import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/core/theme/app_accent.dart';
import 'package:usta_cepte/core/theme/app_palette.dart';
import 'package:usta_cepte/core/theme/app_theme.dart';
import 'package:usta_cepte/core/theme/theme_mode_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('her iki tema da AppPalette extension taşır (koyu ≠ açık)', () {
    final light = AppTheme.light().extension<AppPalette>();
    final dark = AppTheme.dark().extension<AppPalette>();
    expect(light, isNotNull);
    expect(dark, isNotNull);
    // Koyu palet gerçekten farklı tonlar içermeli (yanlışlıkla aynı
    // paletin iki temaya da takılmadığının regresyon kilidi).
    expect(light!.card, isNot(equals(dark!.card)));
    expect(light.ink, isNot(equals(dark.ink)));
  });

  test('mod vurgusu: müşteri mavi, usta yeşil (ColorScheme + AppPalette)', () {
    const blue = Color(0xFF2563EB);
    const green = Color(0xFF059669);

    final customer = AppTheme.light(AppAccent.customerLight);
    final artisan = AppTheme.light(AppAccent.artisanLight);

    // Etkileşim vurgusu (primary) moda göre değişir.
    expect(customer.colorScheme.primary, blue);
    expect(artisan.colorScheme.primary, green);
    expect(customer.extension<AppPalette>()!.primary, blue);
    expect(artisan.extension<AppPalette>()!.primary, green);
    expect(customer.colorScheme.primary,
        isNot(equals(artisan.colorScheme.primary)));

    // Marka DIŞI roller (yüzey/metin) her iki modda AYNI kalır (yalnız vurgu
    // değişir — tüm tema baştan boyanmaz).
    expect(customer.colorScheme.surface, artisan.colorScheme.surface);
    expect(customer.extension<AppPalette>()!.ink,
        artisan.extension<AppPalette>()!.ink);

    // resolve() doğru seti seçer.
    expect(AppAccent.resolve(artisan: false, isDark: false).primary, blue);
    expect(AppAccent.resolve(artisan: true, isDark: false).primary, green);
    expect(AppAccent.resolve(artisan: false, isDark: true).primary,
        AppAccent.customerDark.primary);
  });

  test('tema tercihi kalıcı kayıt: yaz → oku roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await readThemeMode(), ThemeMode.system); // kayıt yoksa Sistem

    await saveThemeMode(ThemeMode.dark);
    expect(await readThemeMode(), ThemeMode.dark);

    await saveThemeMode(ThemeMode.light);
    expect(await readThemeMode(), ThemeMode.light);

    await saveThemeMode(ThemeMode.system);
    expect(await readThemeMode(), ThemeMode.system);
  });

  test('bozuk kayıt Sistem tercihine düşer', () async {
    SharedPreferences.setMockInitialValues({'theme_mode_v1': 'neon'});
    expect(await readThemeMode(), ThemeMode.system);
  });
}

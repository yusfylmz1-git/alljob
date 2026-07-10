import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/core/theme/app_palette.dart';
import 'package:usta_cepte/core/theme/app_theme.dart';
import 'package:usta_cepte/core/theme/theme_mode_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('her iki tema da AppPalette extension taşır (koyu ≠ açık)', () {
    final light = AppTheme.light.extension<AppPalette>();
    final dark = AppTheme.dark.extension<AppPalette>();
    expect(light, isNotNull);
    expect(dark, isNotNull);
    // Koyu palet gerçekten farklı tonlar içermeli (yanlışlıkla aynı
    // paletin iki temaya da takılmadığının regresyon kilidi).
    expect(light!.card, isNot(equals(dark!.card)));
    expect(light.ink, isNot(equals(dark.ink)));
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

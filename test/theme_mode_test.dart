import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/core/theme/accent_options.dart';
import 'package:usta_cepte/core/theme/accent_state.dart';
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

  test('vurgu rengi seçenekleri temaya doğru enjekte edilir', () {
    const blue = Color(0xFF2563EB);
    const green = Color(0xFF059669);

    final blueTheme = AppTheme.light(accentById('blue').light);
    final greenTheme = AppTheme.light(accentById('emerald').light);

    // Seçilen renk primary'ye (ColorScheme + AppPalette) uygulanır.
    expect(blueTheme.colorScheme.primary, blue);
    expect(greenTheme.colorScheme.primary, green);
    expect(blueTheme.extension<AppPalette>()!.primary, blue);
    expect(greenTheme.extension<AppPalette>()!.primary, green);

    // Üst bar / hero gradyanı da seçilen renge göre değişir.
    expect(blueTheme.extension<AppPalette>()!.heroTop,
        isNot(equals(greenTheme.extension<AppPalette>()!.heroTop)));

    // Marka DIŞI roller (yüzey/metin) renk seçiminden ETKİLENMEZ.
    expect(blueTheme.colorScheme.surface, greenTheme.colorScheme.surface);
    expect(blueTheme.extension<AppPalette>()!.ink,
        greenTheme.extension<AppPalette>()!.ink);

    // 6 seçenek var; hepsi benzersiz id; bilinmeyen id varsayılana düşer.
    expect(kAccentOptions, hasLength(6));
    expect(kAccentOptions.map((o) => o.id).toSet(), hasLength(6));
    expect(kAccentOptions.map((o) => o.id),
        containsAll(<String>['pink', 'teal']));
    expect(accentById('yok-boyle').id, kDefaultCustomerAccentId);
    expect(accentById(null, fallbackId: kDefaultArtisanAccentId).id,
        kDefaultArtisanAccentId);
  });

  test('vurgu rengi kalıcı kayıt: müşteri/usta bağımsız roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    // Kayıt yoksa varsayılanlar (müşteri mavi, usta yeşil).
    expect(await readCustomerAccentId(), kDefaultCustomerAccentId);
    expect(await readArtisanAccentId(), kDefaultArtisanAccentId);

    await saveCustomerAccentId('violet');
    await saveArtisanAccentId('orange');
    expect(await readCustomerAccentId(), 'violet');
    expect(await readArtisanAccentId(), 'orange');

    // Geçersiz id (kaldırılmış renk) varsayılana düşer.
    SharedPreferences.setMockInitialValues({'accent_customer_v1': 'neon'});
    expect(await readCustomerAccentId(), kDefaultCustomerAccentId);
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

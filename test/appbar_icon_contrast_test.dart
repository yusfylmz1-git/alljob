import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/theme/app_palette.dart';

/// İkon kontrastı sözleşmesi (2026-08-08).
///
/// Menü (☰) ve bildirim zili eskiden SABİT beyazdı. Profil gibi hero
/// gradyanı olmayan ekranlarda beyaz zemine beyaz ikon düşüyor, ikonlar
/// görünmüyordu. Artık varsayılan marka rengi; beyaz yalnızca koyu
/// gradyan üstünde AÇIKÇA istenir.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Varsayılan renk temaya duyarlı', () {
    test('menü düğmesi sabit beyaz DEĞİL', () {
      final s = read('lib/core/widgets/app_menu_drawer.dart');
      expect(s.contains('this.color = Colors.white'), isFalse);
      expect(s.contains('color ?? context.palette.primary'), isTrue);
    });

    test('bildirim zili sabit beyaz DEĞİL', () {
      final s = read('lib/core/widgets/notification_bell.dart');
      expect(s.contains('this.color = Colors.white'), isFalse);
      expect(s.contains('color ?? context.palette.primary'), isTrue);
    });

    test('rozet kenarlığı zemin rengini kullanıyor', () {
      final s = read('lib/core/widgets/notification_bell.dart');
      expect(s.contains('scaffoldBackgroundColor'), isTrue);
    });
  });

  group('Koyu gradyan üstünde beyaz AÇIKÇA veriliyor', () {
    test('ana sayfa hero', () {
      final s = read('lib/features/home/presentation/home_screen.dart');
      expect(s.contains('DrawerMenuButton(color: Colors.white)'), isTrue);
      expect(s.contains('NotificationBell(color: Colors.white)'), isTrue);
    });

    test('keşfet hero', () {
      final s = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      expect(s.contains('DrawerMenuButton(color: Colors.white)'), isTrue);
      expect(s.contains('NotificationBell(color: Colors.white)'), isTrue);
    });

    test('profil düzenle (GradientAppBar)', () {
      final s = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      expect(s.contains('NotificationBell(color: Colors.white)'), isTrue);
    });
  });

  group('Profil ekranı varsayılanı kullanır (renk VERMEZ)', () {
    test('gradyan yok → marka rengi devreye girsin', () {
      final s = read('lib/features/profile/presentation/profile_screen.dart');
      expect(s.contains('const DrawerMenuButton()'), isTrue);
      expect(s.contains('const NotificationBell()'), isTrue);
      // Beyaz verilirse hata geri gelir.
      expect(s.contains('DrawerMenuButton(color: Colors.white)'), isFalse);
      expect(s.contains('NotificationBell(color: Colors.white)'), isFalse);
    });
  });

  group('Marka rengi her iki temada da zeminden ayrışır', () {
    test('açık tema: primary beyaz değil', () {
      expect(AppPalette.light.primary, isNot(Colors.white));
    });

    test('koyu tema: primary siyah değil', () {
      expect(AppPalette.dark.primary, isNot(Colors.black));
    });
  });
}

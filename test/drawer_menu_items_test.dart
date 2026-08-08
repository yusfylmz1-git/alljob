import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Yan menü içeriği sözleşmesi (2026-08-08).
///
/// "Takip Ettiklerim" ve "Bildirimler" menüden kaldırıldı: ikisinin de
/// daha yakın girişi var. Menüden çıkarmak ERİŞİMİ kaldırmamalı.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String drawer;
  setUpAll(() => drawer = read('lib/core/widgets/app_menu_drawer.dart'));

  group('Menüden kaldırıldı', () {
    test('"Takip Ettiklerim" satırı YOK', () {
      expect(drawer.contains("Text('Takip Ettiklerim')"), isFalse);
      expect(drawer.contains('RoutePaths.favorites'), isFalse);
    });

    test('"Bildirimler" satırı YOK', () {
      expect(drawer.contains("Text('Bildirimler')"), isFalse);
      expect(drawer.contains('panelNotifications'), isFalse);
    });

    test('kırık rota sabiti tamamen silindi', () {
      // '/panel/notifications' router'da tanımlı değildi; sabit kalırsa
      // biri yeniden bağlar ve aynı hata geri döner.
      final paths = read('lib/core/router/route_paths.dart');
      expect(paths.contains('static const String panelNotifications'), isFalse);
    });
  });

  group('ERİŞİM korundu (başka girişlerden)', () {
    test('takip: profil ekranından açılıyor', () {
      final profil =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(profil.contains('RoutePaths.favorites'), isTrue);
    });

    test('bildirimler: zil ikonundan açılıyor', () {
      final zil = read('lib/core/widgets/notification_bell.dart');
      expect(zil.contains('RoutePaths.notifications'), isTrue);
    });

    test('rotalar router\'da hâlâ tanımlı', () {
      final router = read('lib/core/router/app_router.dart');
      expect(router.contains('path: RoutePaths.favorites'), isTrue);
      expect(router.contains('path: RoutePaths.notifications'), isTrue);
    });
  });

  group('Kalan menü satırları duruyor', () {
    test('İş İlanı Ver · İlanlarım · Hesap Ayarları · Yardım · Çıkış', () {
      expect(drawer.contains("Text('İş İlanı Ver')"), isTrue);
      expect(drawer.contains("Text('İlanlarım')"), isTrue);
      expect(drawer.contains('RoutePaths.myJobs'), isTrue);
    });
  });
}

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
    test('takip: profil sayaçlarından açılıyor', () {
      // Kod ortak başlığa taşındı (2026-08-09): profile_header.dart.
      final header = read('lib/core/widgets/profile_header.dart');
      expect(header.contains('RoutePaths.favorites'), isTrue);
      expect(header.contains('RoutePaths.followers'), isTrue);
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
    test('İlanlarım · Hesap Ayarları · Yardım · Çıkış', () {
      expect(drawer.contains("Text('İlanlarım')"), isTrue);
      expect(drawer.contains('RoutePaths.myJobs'), isTrue);
    });

    // 2026-08-09: "İş İlanı Ver" menüden KALKTI.
    // 2026-08-10: "Yeni İlan" hero'dan İlanlar sekmesi sağ üste taşındı.
    test('"İş İlanı Ver" menüde YOK; Yeni İlan İlanlar sekmesinde', () {
      expect(drawer.contains("Text('İş İlanı Ver')"), isFalse,
          reason: 'İlan verme menüye geri eklenmiş — mükerrer giriş.');

      final kesfet = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      // Hero'da olmamalı: _HeroHeader içinde "Yeni İlan" yok.
      expect(kesfet.contains("label: const Text('Yeni İlan')"), isTrue,
          reason: 'İlanlar sekmesi sağ üstteki Yeni İlan kaybolmuş.');
      expect(kesfet.contains('RoutePaths.newJob'), isTrue,
          reason: 'Giriş ilan verme rotasına gitmiyor.');
      // Kapı: usta MODU değil usta PROFİLİ.
      expect(kesfet.contains('!user.hasArtisanProfile'), isTrue,
          reason: 'İlanlar hasArtisanProfile ile açılmalı.');
      expect(kesfet.contains('!user.isArtisan'), isFalse,
          reason: 'İlanlar artık isArtisan (aktif mod) ile kilitlenmemeli.');
    });
  });
}

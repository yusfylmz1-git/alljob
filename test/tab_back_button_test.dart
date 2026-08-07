import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Alt bar sekmelerinde DONANIM GERİ TUŞU sözleşmesi.
///
/// Sekmeler `context.go()` ile açılır ve bu **geçmiş yığını bırakmaz** →
/// `canPop()` false olur ve geri tuşu doğrudan sisteme düşerek uygulamayı
/// kapatır. Kullanıcı beklentisi Ana Sayfa'ya dönmek (B-01'de giriş
/// ekranında yaşanan sorunun aynısı).
///
/// Ekranlar Firebase/Riverpod'a bağlı olduğu için sözleşme kaynak üzerinden
/// doğrulanır.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('MainTabScope sözleşmesi', () {
    late String bar;
    setUpAll(() => bar = read('lib/core/widgets/role_bottom_bar.dart'));

    test('MainTabScope tanımlı', () {
      expect(bar.contains('class MainTabScope'), isTrue);
    });

    test('Ana Sayfa dışındaki sekmelerde pop ENGELLENİR', () {
      // canPop: isHome → yalnız Ana Sayfa'da sistem davranışı (çıkış).
      expect(bar.contains('canPop: isHome'), isTrue);
    });

    test('iç yığın varsa pop, yoksa Ana Sayfa', () {
      // Detaydan gelindiyse önce o ekran kapanmalı; kök sekmedeyse home.
      expect(bar.contains('if (context.canPop())'), isTrue);
      expect(bar.contains('context.go(RoutePaths.home)'), isTrue);
    });
  });

  group('sekme ekranları korumayı uyguluyor', () {
    test('Profil ve Keşfet MainTabScope ile sarılı', () {
      for (final p in [
        'lib/features/profile/presentation/profile_screen.dart',
        'lib/features/customer/presentation/customer_dashboard_screen.dart',
        'lib/features/jobs/presentation/nearby_jobs_screen.dart',
      ]) {
        expect(read(p).contains('MainTabScope('), isTrue,
            reason: '$p sekme koruması olmadan geri tuşunda uygulamayı '
                'kapatır.');
      }
    });

    test('seçim modlu ekranlar kendi PopScope\'unda ele alır', () {
      // Mesajlar ve İlanlarım'da zaten seçim modu için PopScope vardı;
      // iç içe PopScope yerine mevcut mantık genişletildi.
      for (final p in [
        'lib/features/chat/presentation/chat_list_screen.dart',
        'lib/features/jobs/presentation/my_jobs_screen.dart',
      ]) {
        final s = read(p);
        expect(s.contains('canPop: false'), isTrue,
            reason: '$p: geri tuşu her durumda ele alınmalı.');
        expect(s.contains('_exitSelection()'), isTrue,
            reason: '$p: seçim modu davranışı korunmalı.');
        expect(s.contains('context.go(RoutePaths.home)'), isTrue,
            reason: '$p: kök sekmede Ana Sayfa\'ya dönmeli.');
      }
    });
  });
}

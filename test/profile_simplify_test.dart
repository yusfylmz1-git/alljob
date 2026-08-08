import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Profil sadeleştirme (Faz 1-3) sözleşme testleri.
///
/// Bu değişiklikler bilgi mimarisini değiştirir; sessizce geri alınırsa
/// kullanıcı "yine karışık" der ama sebebi görünmez. Kaynak üzerinden
/// doğrulanır — ekranlar Firebase/Riverpod'a bağlı olduğu için widget
/// testiyle tam kurulamıyor.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Faz 1 · alt bar rol ayrımı yapmaz', () {
    late String bar;
    setUpAll(() => bar = read('lib/core/widgets/role_bottom_bar.dart'));

    test('alt bar HERKESTE AYNI 4 sekme', () {
      // 2026-08-08: "İlanlar" sekmesi Keşfet'e taşındı; alt barda rol bazlı
      // hiçbir sekme kalmadı.
      expect(bar.contains('showWork'), isFalse);
      expect(bar.contains("label: 'Ana Sayfa'"), isTrue);
      expect(bar.contains("label: 'Keşfet'"), isTrue);
      expect(bar.contains("label: 'Mesajlar'"), isTrue);
      expect(bar.contains("label: 'Profil'"), isTrue);
    });

    test('sekme adı role göre DEĞİŞMEZ', () {
      // Eskiden: label: isArtisan ? 'İşler' : 'İlanlarım'.
      expect(bar.contains("isArtisan ? 'İşler' : 'İlanlarım'"), isFalse);
    });
  });

  group('Mükerrer giriş yok', () {
    test('"İlanlarım" profilde YOK, yan menüde VAR (usta modunda)', () {
      final profile =
          read('lib/features/profile/presentation/profile_screen.dart');
      final drawer = read('lib/core/widgets/app_menu_drawer.dart');

      // Profilde satır olarak bulunmamalı: alt bardaki "İlanlar" sekmesi ve
      // menü girişiyle üç kez tekrar ediyordu.
      expect(profile.contains("title: 'İlanlarım'"), isFalse,
          reason: 'İlanlarım profile geri eklenmiş — mükerrer.');

      // Menüde, yalnız usta modunda.
      expect(drawer.contains("title: const Text('İlanlarım')"), isTrue);
      expect(drawer.contains('if (user.isArtisan)'), isTrue,
          reason: 'İlanlarım usta modu koşuluna bağlı olmalı.');
    });

    test('yan menüde mod geçiş satırı YOK', () {
      final drawer = read('lib/core/widgets/app_menu_drawer.dart');
      // Mod değişimi yalnız profildeki anahtardan yapılır; iki ayrı yer
      // "hangi moddayım?" karışıklığını besliyordu (B-16).
      // Metin YORUMDA geçebilir (neden kaldırıldığını anlatır); asıl kontrol
      // ListTile başlığı olarak DURMAMASI.
      expect(drawer.contains("Text('Usta Moduna Geç')"), isFalse);
      expect(drawer.contains("Text('Müşteri Moduna Geç')"), isFalse);
      expect(drawer.contains('_switchMode('), isFalse);
    });

    test('karşı mod okunmamış rozeti kaybolmadı', () {
      // Rozet menüdeki mod satırındaydı; o satır kalkınca profildeki
      // anahtara taşındı. Taşınmasaydı kullanıcı diğer taraftaki mesajı
      // hiç fark etmezdi.
      final profile =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(profile.contains('otherModeUnreadProvider'), isTrue);
    });

    test('Keşfet TEK LİSTE: rol ayrımı ve sekme çubuğu yok', () {
      final explore = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      // Önce usta modunda "Ustalar" gizleniyordu; sonra rol ayrımı kalktı;
      // Ürünler modülü de silinince tek sekme kaldı ve çubuk gereksizleşti.
      expect(explore.contains('if (!isArtisan)'), isFalse);
      expect(explore.contains('ExploreTabBar'), isFalse,
          reason: 'Tek liste kaldı; sekme çubuğu geri gelmiş.');
      expect(explore.contains('_ArtisansExplorePanel'), isTrue);
    });
  });

  group('Faz 2 · HESABIM profilden çıkarıldı', () {
    late String profile;
    late String drawer;
    late String paths;

    setUpAll(() {
      profile = read('lib/features/profile/presentation/profile_screen.dart');
      drawer = read('lib/core/widgets/app_menu_drawer.dart');
      paths = read('lib/core/router/route_paths.dart');
    });

    test('accountSettings rotası tanımlı', () {
      expect(paths.contains("accountSettings = '/profile/account'"), isTrue);
    });

    test('AccountSettingsScreen var ve _AccountGroup onu besliyor', () {
      expect(profile.contains('class AccountSettingsScreen'), isTrue);
      // _AccountGroup artık YALNIZ bu ekranda kullanılmalı.
      expect(profile.contains('_AccountGroup(user: user)'), isTrue);
    });

    test('yan menüde Hesap Ayarları girişi var', () {
      expect(drawer.contains('Hesap Ayarları'), isTrue);
      expect(drawer.contains('RoutePaths.accountSettings'), isTrue);
    });

    test('profil gövdesinde HESABIM bölümü YOK', () {
      expect(profile.contains("_SectionLabel('HESABIM')"), isFalse,
          reason: 'HESABIM profile geri taşınmış — sadeleştirme bozuldu.');
    });
  });

  group('Faz 3 · profil başlığı', () {
    late String profile;
    setUpAll(() =>
        profile = read('lib/features/profile/presentation/profile_screen.dart'));

    test('mod göstergesi YAZILI ve anahtarlı (B-16)', () {
      // Renk tek başına yetmiyordu; durum yazıyla görünmeli. Başlıktaki
      // rozet kaldırıldı — anahtar aynı bilgiyi hem gösteriyor hem
      // değiştirilebilir kılıyor (mükerrer metin kalmadı).
      expect(profile.contains('class _ArtisanModeSwitch'), isTrue);
      expect(profile.contains("'Usta modu'"), isTrue);
      expect(profile.contains('Açık — iş alabilir'), isTrue);
      expect(profile.contains('Kapalı — yalnız hizmet alıyorsun'), isTrue);
    });

    test('Instagram başlık düzeni: avatar solda, sayaçlar yanında', () {
      expect(profile.contains('class _HeroStats'), isTrue);
      expect(profile.contains('class _StatCell'), isTrue);
      expect(profile.contains('class _AvatarWithEdit'), isTrue);
      // Aksiyon çubuğu (Profili düzenle / Profilime bak)
      expect(profile.contains('class _HeroAction'), isTrue);
      expect(profile.contains("'Profili düzenle'"), isTrue);
    });

    test('usta sayaçları gerçek veriden okunur', () {
      // completedJobs / averageRating CF tarafından yazılır (kural 3);
      // istemci uydurmaz.
      expect(profile.contains('completedJobs'), isTrue);
      expect(profile.contains('averageRating'), isTrue);
    });
  });
}

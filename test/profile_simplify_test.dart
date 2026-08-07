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

    test('"İlanlar" sekmesi YALNIZ usta modunda görünür', () {
      expect(bar.contains('final showWork = isArtisan;'), isTrue,
          reason: 'showWork = user != null olsaydı sekme müşteride de '
              'görünürdü (B-16 kaynağı).');
    });

    test('sekme adı role göre DEĞİŞMEZ', () {
      // Eskiden: label: isArtisan ? 'İşler' : 'İlanlarım' → aynı sekme iki
      // farklı isimle görünüyordu, "hangi moddayım?" karışıklığını besliyordu.
      expect(bar.contains("isArtisan ? 'İşler' : 'İlanlarım'"), isFalse,
          reason: 'Role göre değişen sekme adı geri gelmiş.');
      expect(bar.contains("label: 'İlanlar'"), isTrue);
    });
  });

  group('Mükerrer giriş yok', () {
    test('profilde tek "İlanlarım" satırı var', () {
      final profile =
          read('lib/features/profile/presentation/profile_screen.dart');
      // Usta modunda _ArtisanHome + _CustomerHome birlikte çizilir; ikisinde
      // de "İlanlarım" olursa satır İKİ KEZ görünür (kullanıcı bildirdi).
      final hits = "'İlanlarım'".allMatches(profile).length;
      expect(hits, 1,
          reason: 'İlanlarım yalnız _CustomerHome içinde olmalı; '
              '_ArtisanHome herkeste çizilen o bölümün üstüne biner.');
    });

    test('Keşfet rol ayrımı yapmaz: Ustalar her modda görünür', () {
      final explore = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      // Eskiden usta modunda "Ustalar" sekmesi gizleniyordu (if (!isArtisan)).
      expect(explore.contains('if (!isArtisan)'), isFalse);
      expect(explore.contains('if (isArtisan)'), isFalse);
      expect(explore.contains("label: 'Ustalar'"), isTrue);
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

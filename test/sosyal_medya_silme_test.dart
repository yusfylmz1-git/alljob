import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/data/models/artisan_profile.dart';
import 'package:sepette_hizmet/data/models/social_links.dart';

/// Madde 9 — "sosyal medya kaydetmiyor".
///
/// Kök neden kaydetmede DEĞİL, geri okumada: ortak alanlar (telefon / sosyal
/// medya / hakkımda) 2026-08-08'de `users`'a taşındı, `artisanProfiles`'taki
/// kopya DONDU (artık yazılmıyor). Okuma tarafı `users` boşsa donmuş kopyaya
/// düşüyordu — kullanıcı bağlantıyı silip kaydedince ekran yeniden açılışta
/// eski değeri geri getiriyordu.
///
/// Ayrım: "alan YOK" (göç etmemiş kayıt → geri düş) ile "alan VAR ama boş"
/// (kullanıcı sildi → boş kalsın). `AppUser.ortakAlanlarGocmus` bunu taşır.
void main() {
  AppUser kullanici({
    Map<String, dynamic>? map,
  }) =>
      AppUser.fromMap('u1', map ?? const {});

  /// Okuma tarafındaki birleştirme (my_profile_controller.dart) — testte
  /// aynı kararı uygular, davranış sözleşmesi burada kilitlenir.
  ArtisanProfile birlestir(AppUser user, ArtisanProfile profile) {
    return user.ortakAlanlarGocmus
        ? profile.copyWith(
            publicPhone: user.publicPhone,
            clearPublicPhone: user.publicPhone == null,
            socialLinks: user.socialLinks,
            aboutText: user.aboutText,
          )
        : profile.copyWith(
            publicPhone: user.publicPhone ?? profile.publicPhone,
            socialLinks:
                user.socialLinks.hasAny ? user.socialLinks : profile.socialLinks,
            aboutText: user.aboutText.trim().isNotEmpty
                ? user.aboutText
                : profile.aboutText,
          );
  }

  /// Göç öncesinden kalma usta kaydı: kopya HÂLÂ dolu.
  ArtisanProfile eskiUstaKaydi() => ArtisanProfile.initial('u1').copyWith(
        socialLinks: const SocialLinks(instagram: 'eski_hesap'),
        publicPhone: '05321112233',
        aboutText: 'Eski hakkımda',
      );

  group('Göç bayrağı — AppUser.fromMap', () {
    test('alan hiç yoksa göç etmemiş', () {
      expect(kullanici().ortakAlanlarGocmus, isFalse);
    });

    test('alan varsa BOŞ olsa bile göç etmiş', () {
      // Kullanıcının bağlantıyı sildiği hâl: anahtar var, değeri null.
      final u = kullanici(map: {'socialLinks': null});
      expect(
        u.ortakAlanlarGocmus,
        isTrue,
        reason: 'Anahtarın VARLIĞI göçün kanıtı; değeri boş olabilir.',
      );
      expect(u.socialLinks.hasAny, isFalse);
    });

    test('alanlardan biri bile yetiyor', () {
      expect(kullanici(map: {'aboutText': ''}).ortakAlanlarGocmus, isTrue);
      expect(kullanici(map: {'publicPhone': null}).ortakAlanlarGocmus, isTrue);
    });

    test('copyWith bayrağı DÜŞÜRMEZ', () {
      // Sayaçlardaki tuzağın aynısı: taşınmazsa her copyWith'te false'a
      // döner ve silinen bağlantı geri gelirdi.
      final u = kullanici(map: {'socialLinks': null});
      expect(u.copyWith(displayName: 'Yeni Ad').ortakAlanlarGocmus, isTrue);
    });
  });

  group('Silinen bağlantı geri GELMEZ (asıl bulgu)', () {
    test('sosyal medya silinince boş kalır', () {
      // users: alan var, boş (kullanıcı sildi) · artisanProfiles: eski değer
      final birlesik = birlestir(
        kullanici(map: {'socialLinks': null}),
        eskiUstaKaydi(),
      );
      expect(
        birlesik.socialLinks.instagram,
        isNull,
        reason: 'Donmuş usta kaydındaki "eski_hesap" geri gelmemeli.',
      );
    });

    test('telefon silinince boş kalır', () {
      final birlesik = birlestir(
        kullanici(map: {'publicPhone': null}),
        eskiUstaKaydi(),
      );
      expect(
        birlesik.publicPhone,
        isNull,
        reason: 'copyWith(publicPhone: null) "değiştirme" demek — '
            'clearPublicPhone bayrağı şart.',
      );
    });

    test('hakkımda silinince boş kalır', () {
      final birlesik = birlestir(
        kullanici(map: {'aboutText': ''}),
        eskiUstaKaydi(),
      );
      expect(birlesik.aboutText, isEmpty);
    });
  });

  group('Göç etmemiş kayıt hâlâ geri düşer (fazlasını yapma)', () {
    test('users boşsa eski usta kaydı okunur', () {
      // Bu davranış KASITLI: göç öncesi profiller ilk açılışta boş
      // görünmesin. Düzeltme bunu bozmamalı.
      final birlesik = birlestir(kullanici(), eskiUstaKaydi());
      expect(birlesik.socialLinks.instagram, 'eski_hesap');
      expect(birlesik.publicPhone, '05321112233');
      expect(birlesik.aboutText, 'Eski hakkımda');
    });
  });

  group('Göç etmiş kayıtta users kazanır', () {
    test('dolu değer usta kaydının üstüne yazar', () {
      final birlesik = birlestir(
        kullanici(map: {
          'socialLinks': {'instagram': 'yeni_hesap'},
          'publicPhone': '05339998877',
          'aboutText': 'Yeni hakkımda',
        }),
        eskiUstaKaydi(),
      );
      expect(birlesik.socialLinks.instagram, 'yeni_hesap');
      expect(birlesik.publicPhone, '05339998877');
      expect(birlesik.aboutText, 'Yeni hakkımda');
    });
  });
}

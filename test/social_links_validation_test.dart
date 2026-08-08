import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/social_links.dart';

/// Sosyal medya / web girdisi doğrulama sözleşmesi (2026-08-09).
///
/// Amaç: kullanıcı hatasını en aza indirmek. İki ilke:
///   1. Anlaşılabilen girdiyi DÜZELT (URL yapıştır → kullanıcı adı).
///   2. Anlaşılamayanı SESSİZCE SİLME, sebebini SÖYLE.
void main() {
  group('Kullanıcı adı: yapıştırılan bağlantıyı çözer', () {
    test('@ işareti atılır', () {
      expect(SocialLinks.normalizeHandle('@ahmet_usta'), 'ahmet_usta');
      expect(SocialLinks.normalizeHandle('@@ahmet'), 'ahmet');
    });

    test('tam URL kullanıcı adına iner', () {
      expect(
        SocialLinks.normalizeHandle('https://instagram.com/ahmet_usta/?hl=tr'),
        'ahmet_usta',
      );
      expect(
        SocialLinks.normalizeHandle('www.tiktok.com/@dansci'),
        'dansci',
      );
      expect(
        SocialLinks.normalizeHandle('https://youtube.com/@kanal#tab'),
        'kanal',
      );
    });

    test('NOKTALI kullanıcı adı GEÇERLİ (ahmet.usta)', () {
      // Eski kural "nokta varsa alan adıdır" diyordu ve Instagram'da çok
      // yaygın olan bu adları eliyordu.
      expect(SocialLinks.normalizeHandle('ahmet.usta'), 'ahmet.usta');
      expect(SocialLinks.normalizeHandle('@a.b.c'), 'a.b.c');
    });

    test('tire ve alt çizgi geçerli', () {
      expect(SocialLinks.normalizeHandle('ahmet-usta_34'), 'ahmet-usta_34');
    });
  });

  group('Kullanıcı adı: geçersiz girdiler', () {
    test('BOŞLUK reddedilir', () {
      // Eskiden "Ahmet Usta 34" aynen kaydediliyor, link kırık çıkıyordu.
      expect(SocialLinks.normalizeHandle('Ahmet Usta 34'), isNull);
      expect(SocialLinks.normalizeHandle('ahmet usta'), isNull);
    });

    test('yalnız alan adı reddedilir (kullanıcı adı yok)', () {
      expect(SocialLinks.normalizeHandle('instagram.com'), isNull);
      expect(SocialLinks.normalizeHandle('www.tiktok.com'), isNull);
      expect(SocialLinks.normalizeHandle('https://instagram.com/'), isNull);
    });

    test('geçersiz karakterler reddedilir', () {
      expect(SocialLinks.normalizeHandle('ahmet!usta'), isNull);
      expect(SocialLinks.normalizeHandle('<script>'), isNull);
    });

    test('aşırı uzun ad reddedilir', () {
      expect(SocialLinks.normalizeHandle('a' * 41), isNull);
    });

    test('boş girdi null (alan isteğe bağlı)', () {
      expect(SocialLinks.normalizeHandle(''), isNull);
      expect(SocialLinks.normalizeHandle('   '), isNull);
      expect(SocialLinks.normalizeHandle(null), isNull);
    });
  });

  group('Hata mesajları SEBEBİ söylüyor', () {
    test('boş girdi hata DEĞİL', () {
      expect(SocialLinks.handleError('', platform: 'Instagram'), isNull);
      expect(SocialLinks.handleError(null, platform: 'Instagram'), isNull);
    });

    test('geçerli girdi hata vermez', () {
      expect(
        SocialLinks.handleError('ahmet.usta', platform: 'Instagram'),
        isNull,
      );
      expect(
        SocialLinks.handleError('https://instagram.com/ahmet/',
            platform: 'Instagram'),
        isNull,
      );
    });

    test('boşlukta "boşluk içeremez" der', () {
      final m = SocialLinks.handleError('ahmet usta', platform: 'Instagram');
      expect(m, isNotNull);
      expect(m!.contains('boşluk'), isTrue);
    });

    test('alan adı yazılınca platformu adıyla uyarır', () {
      final m = SocialLinks.handleError('instagram.com', platform: 'Instagram');
      expect(m, isNotNull);
      expect(m!.contains('Instagram'), isTrue);
      expect(m.contains('kullanıcı adını'), isTrue);
    });

    test('WhatsApp: rakamsız girdi', () {
      final m = SocialLinks.whatsappError('abc');
      expect(m, isNotNull);
      expect(m!.contains('Telefon'), isTrue);
      expect(SocialLinks.whatsappError('0532 123 45 67'), isNull);
      expect(SocialLinks.whatsappError(''), isNull);
    });

    test('web: tehlikeli şema açıkça reddedilir', () {
      final m = SocialLinks.websiteError('javascript:alert(1)');
      expect(m, isNotNull);
      expect(m!.contains('http'), isTrue);
      expect(SocialLinks.websiteError('ornek.com'), isNull);
      expect(SocialLinks.websiteError(''), isNull);
    });

    test('web: noktasız girdi yönlendirir', () {
      final m = SocialLinks.websiteError('ornek');
      expect(m, isNotNull);
      expect(m!.contains('ornek.com'), isTrue);
    });
  });

  group('Telefon: yerel yazımı E.164 yapar', () {
    test('TR kısayolları', () {
      expect(SocialLinks.normalizeWhatsapp('0532 123 45 67'), '+905321234567');
      expect(SocialLinks.normalizeWhatsapp('532 123 45 67'), '+905321234567');
      expect(SocialLinks.normalizeWhatsapp('+90 532 123 45 67'),
          '+905321234567');
    });

    test('çok kısa/uzun reddedilir', () {
      expect(SocialLinks.normalizeWhatsapp('123'), isNull);
      expect(SocialLinks.normalizeWhatsapp('9' * 20), isNull);
    });
  });

  group('Web: şema tamamlanır, tehlikeli olan reddedilir', () {
    test('şemasız adrese https eklenir', () {
      expect(SocialLinks.normalizeWebsite('ornek.com'), 'https://ornek.com');
      expect(SocialLinks.normalizeWebsite('www.ornek.com'),
          'https://www.ornek.com');
    });

    test('yalnız http/https', () {
      expect(SocialLinks.normalizeWebsite('javascript:alert(1)'), isNull);
      expect(SocialLinks.normalizeWebsite('file:///etc/passwd'), isNull);
    });

    test('alan adı noktasız olamaz', () {
      expect(SocialLinks.normalizeWebsite('localhost'), isNull);
      expect(SocialLinks.normalizeWebsite('ornek'), isNull);
    });
  });

  group('Üretilen bağlantılar doğru', () {
    const s = SocialLinks(
      instagram: 'ahmet.usta',
      youtube: 'kanal',
      tiktok: 'dansci',
      whatsapp: '+905321234567',
      website: 'https://ornek.com',
    );

    test('platform URL biçimleri', () {
      expect(s.instagramUrl, 'https://instagram.com/ahmet.usta');
      expect(s.youtubeUrl, 'https://youtube.com/@kanal');
      expect(s.tiktokUrl, 'https://tiktok.com/@dansci');
      expect(s.websiteUrl, 'https://ornek.com');
    });

    test('wa.me + işareti almaz', () {
      expect(s.whatsappUrl, 'https://wa.me/905321234567');
    });
  });

  group('UI: geçersiz girdi SESSİZCE SİLİNMİYOR', () {
    late String form;
    setUpAll(() => form = File(
            'lib/features/artisan/presentation/artisan_profile_edit_screen.dart')
        .readAsStringSync());

    test('hata varsa metin kutuda KALIYOR', () {
      // Eski davranış KOŞULSUZ atamaydı → geçersiz girdi sessizce siliniyordu.
      // Artık atama `hata == null` dalının içinde.
      expect(form.contains('if (hata == null) controller.text'), isTrue);
      // Koşulsuz atama (satır başında) kalmamalı.
      final kosulsuz = RegExp(
        r'^\s+controller\.text = normalized \?\? .{2};\s*$',
        multiLine: true,
      );
      expect(kosulsuz.hasMatch(form), isFalse);
    });

    test('errorText gösteriliyor', () {
      expect(form.contains('errorText: _errors[label]'), isTrue);
      expect(form.contains('required String? Function(String) validate'),
          isTrue);
    });

    test('her alanın doğrulayıcısı bağlı', () {
      expect(form.contains("SocialLinks.handleError(v, platform: 'Instagram')"),
          isTrue);
      expect(form.contains('validate: SocialLinks.whatsappError'), isTrue);
      expect(form.contains('validate: SocialLinks.websiteError'), isTrue);
    });

    test('otomatik düzeltme kapalı (kullanıcı adı bozulmasın)', () {
      expect(form.contains('autocorrect: false'), isTrue);
    });
  });

  group('Profilde görünüyor ve TIKLANABİLİR', () {
    late String header;
    setUpAll(() =>
        header = File('lib/core/widgets/profile_header.dart').readAsStringSync());

    test('satırlar model URL\'lerini kullanıyor', () {
      expect(header.contains('s.instagramUrl'), isTrue);
      expect(header.contains('s.whatsappUrl'), isTrue);
      expect(header.contains('s.websiteUrl'), isTrue);
    });

    test('telefon tel: ile aranıyor', () {
      expect(header.contains("'tel:"), isTrue);
    });

    test('dokunulabilir ve hata yutulmuyor', () {
      expect(header.contains('launchUrl'), isTrue);
      expect(header.contains('Bağlantı açılamadı.'), isTrue);
    });

    test('usta profilindeki ESKİ kaynak kaldırıldı', () {
      // profile.socialLinks (artisanProfiles) artık okunmuyor; tek kaynak
      // users → ProfileBioDetails.
      final usta = File(
              'lib/features/customer/presentation/artisan_profile_screen.dart')
          .readAsStringSync();
      expect(usta.contains('_SocialLinksRow('), isFalse);
      expect(usta.contains('profile.socialLinks.hasAny'), isFalse);
    });
  });
}

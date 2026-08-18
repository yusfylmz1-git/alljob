import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/core/utils/phone_format.dart';
import 'package:sepette_hizmet/data/models/social_links.dart';

/// 2026-08-19 cihaz bulgusu: profil HİÇBİR ŞEKİLDE kaydedilemiyordu.
///
/// Belirti: "Profil kaydedilemedi: sunucu reddetti. Hizmet bölgeleriniz ve
/// sosyal medya alanlarınızı kontrol edin." Kullanıcı sosyal medya alanını
/// boşaltsa bile hata sürüyordu.
///
/// Kök neden: `publicPhone` alanına E.164 TR cep şartı eklenmişti
/// (2026-08-18), ama profilde ESKİ biçimde numara (`+902222222222` — `+90`
/// ile başlıyor ama cep değil) duruyordu. `save()` bu değeri her seferinde
/// `users/{uid}`e yazmaya çalışıyor, kural reddediyordu. Reddedilen alan
/// telefondu; hata mesajı yanlış alanı işaret ettiği için kullanıcı sosyal
/// medyayı düzeltmeye çalışıyordu.
///
/// Çift test (kural 7): düzeltme çalışıyor MU, ve fazlasını yapmıyor MU
/// (geçerli numara korunmalı, sosyal medya normalizasyonu bozulmamalı).
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Kaydetme, eski biçimli telefonda kilitlenmez', () {
    test('kurala takılan eski değerler normalize edilemez → temizlenir', () {
      // Canlıda bulunan gerçek değerler.
      for (final eski in ['+902222222222', '+901111111111']) {
        expect(normalizeTrMobile(eski), isNull,
            reason: '$eski cep numarası değil; çözümlenmemeli.');
      }
    });

    test('save() yazmadan önce normalize ediyor', () {
      final src =
          read('lib/features/artisan/application/my_profile_controller.dart');
      expect(src.contains('normalizeTrMobile'), isTrue,
          reason: 'Ham publicPhone doğrudan yazılırsa eski kayıt yine '
              'permission-denied verir.');
      // Çözümlenemeyen değer boş dizeye düşmeli (alanı sil), null'a değil:
      // null "değiştirme" demektir ve bozuk değer dokümanda kalırdı.
      expect(src.contains("normalizeTrMobile(ham) ?? ''"), isTrue);
    });

    test('GEÇERLİ numara korunur — düzeltme fazlasını yapmıyor', () {
      expect(normalizeTrMobile('+905321234567'), '+905321234567');
      expect(normalizeTrMobile('0532 123 45 67'), '+905321234567');
    });

    test('kural ile istemci aynı biçimi zorluyor (kural 2)', () {
      final rules = read('firestore.rules');
      expect(rules.contains(r'^\\+905[0-9]{9}$'), isTrue);
      // Alanı temizlemek (boş dize) kural tarafından da kabul edilmeli;
      // aksi hâlde "bozuk numarayı sil" yolu da reddedilirdi.
      expect(rules.contains("d.publicPhone == ''"), isTrue);
    });

    test('hata mesajı yanlış alanı suçlamıyor', () {
      final src =
          read('lib/features/artisan/application/my_profile_controller.dart');
      expect(src.contains('sosyal medya alanlarınızı kontrol edin'), isFalse,
          reason: 'Ret telefondan gelirken kullanıcı sosyal medyayı '
              'düzeltmeye çalışıyordu.');
    });
  });

  group('Sosyal medya alanı kaydı engellemez', () {
    test('geçersiz kullanıcı adı null olur — kayıt yine de geçer', () {
      // Kullanıcı isteği: "hesap yoksa bile o şekilde kaydetsin".
      // Geçersiz girdi sunucuya HİÇ gitmez (null), kayıt reddedilmez.
      for (final ham in ['ahmet usta', 'instagram.com', '@@@', 'a b c']) {
        expect(SocialLinks.normalizeHandle(ham), isNull);
        expect(SocialLinks.handleError(ham, platform: 'Instagram'), isNotNull,
            reason: 'Kullanıcı neden boş kaydedildiğini görebilmeli.');
      }
    });

    test('var olmayan ama BİÇİMİ geçerli hesap kaydedilir', () {
      // Kullanıcı isteği: hesabın gerçekten var olup olmadığı denetlenmez.
      expect(SocialLinks.normalizeHandle('olmayan_hesap_12345'),
          'olmayan_hesap_12345');
    });

    test('yazarken de doğrulanıyor (odak kaybını beklemiyor)', () {
      final ekran = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(ekran.contains('onChanged: (ham) {'), isTrue,
          reason: 'Hata yalnız odak kaybında hesaplanırsa, yazıp doğrudan '
              'Kaydet\'e basan kullanıcı uyarıyı hiç görmüyor.');
    });

    test('geçerli hesap profilde tıklanınca açılır', () {
      final header = read('lib/core/widgets/profile_header.dart');
      expect(header.contains('instagramUrl'), isTrue);
      expect(header.contains('launchUrl'), isTrue);
      // Model doğru URL üretmeli.
      const s = SocialLinks(instagram: 'ahmet_usta');
      expect(s.instagramUrl, 'https://instagram.com/ahmet_usta');
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/core/utils/phone_format.dart';

/// İletişim numarası girişi (2026-08-18).
///
/// SMS doğrulaması kaldırıldığı için numara artık ELLE giriliyor. Doğrulama
/// katmanı tek savunmadır: hatalı girdi hem kullanıcıyı yanıltır (WhatsApp
/// düğmesi çalışmayan numaraya gider) hem de herkese açık alana serbest
/// metin sızmasına yol açar.
void main() {
  group('normalizeTrMobile · geçerli yazımlar E.164 olur', () {
    // Kullanıcı numarayı çok farklı biçimlerde yazar; hepsi TEK biçime
    // inmeli ki veritabanında karışık kayıt oluşmasın.
    const beklenen = '+905321234567';

    for (final girdi in [
      '0532 123 45 67',
      '05321234567',
      '532 123 45 67',
      '5321234567',
      '+90 532 123 45 67',
      '+905321234567',
      '905321234567',
      '(0532) 123-45-67',
      '  0532-123-45-67  ',
    ]) {
      test('"$girdi" → $beklenen', () {
        expect(normalizeTrMobile(girdi), beklenen);
      });
    }
  });

  group('normalizeTrMobile · geçersiz girdiler reddedilir', () {
    final gecersiz = <String, String>{
      '': 'boş',
      '053212345': 'eksik hane',
      '053212345678': 'fazla hane',
      '02121234567': 'sabit hat (5 ile başlamıyor)',
      '03121234567': 'sabit hat',
      'abcdefghij': 'harf',
      '+1 555 123 4567': 'yabancı numara',
      '+905321234567890': 'aşırı uzun',
      '0000000000': 'cep öneki yok',
    };

    gecersiz.forEach((girdi, neden) {
      test('"$girdi" reddedilir ($neden)', () {
        expect(normalizeTrMobile(girdi), isNull);
      });
    });
  });

  group('trPhoneError · kullanıcıya anlamlı mesaj', () {
    test('boş girdi HATA DEĞİL (alan isteğe bağlı)', () {
      expect(trPhoneError(''), isNull);
      expect(trPhoneError('   '), isNull);
    });

    test('geçerli numarada hata yok', () {
      expect(trPhoneError('0532 123 45 67'), isNull);
    });

    test('eksik hanede ne yapılacağı söyleniyor', () {
      final m = trPhoneError('0532 123');
      expect(m, isNotNull);
      expect(m!.toLowerCase().contains('eksik'), isTrue);
    });

    test('sabit hatta örnek gösteriliyor', () {
      final m = trPhoneError('02121234567');
      expect(m, isNotNull);
      // Kullanıcı ne yazacağını görmeli; ham kural metni yetmez.
      expect(m!.contains('0532'), isTrue);
    });

    test('hata metinleri Türkçe (dil kuralı)', () {
      for (final g in ['0532 123', '02121234567', '123']) {
        final m = trPhoneError(g);
        expect(m, isNotNull);
        expect(RegExp(r'[a-zA-Z]{4,}').allMatches(m!).isNotEmpty, isTrue,
            reason: 'Mesaj boş görünüyor: $m');
        expect(m.toLowerCase().contains('error'), isFalse,
            reason: 'İngilizce sızmış: $m');
      }
    });
  });

  group('formatTrPhone · okunur gösterim', () {
    test('E.164 → 0532 123 45 67', () {
      expect(formatTrPhone('+905321234567'), '0532 123 45 67');
    });

    test('beklenmedik biçim ham döner (bozuk gösterim yerine)', () {
      expect(formatTrPhone('+15551234567'), '+15551234567');
    });

    test('gidiş-dönüş: biçimlendir → çözümle aynı numaraya döner', () {
      const e164 = '+905321234567';
      expect(normalizeTrMobile(formatTrPhone(e164)), e164);
    });
  });

  group('Güvenlik · istemci ve kural aynı biçimi zorlar (kural 2)', () {
    String read(String p) => File(p).readAsStringSync();

    test('firestore.rules publicPhone için E.164 deseni istiyor', () {
      final rules = read('firestore.rules');
      // Yalnız uzunluk tavanı YETMEZ: doğrudan SDK çağrısıyla bu alana
      // reklam metni / bağlantı yazılabilirdi (alan herkese açık okunur).
      expect(rules.contains(r'^\\+905[0-9]{9}$'), isTrue,
          reason: 'publicPhone biçim şartı kuraldan düşmüş.');
    });

    test('mock repo aynı reddi veriyor (kural 1: mock paritesi)', () {
      final mock = read('lib/features/auth/data/mock_auth_repository.dart');
      expect(mock.contains(r'^\+905[0-9]{9}$'), isTrue,
          reason: 'Mock kuralı taklit etmezse hata yalnız canlıda çıkar.');
    });

    test('hassas phoneNumber hâlâ herkese açık dokümanda yasak', () {
      final rules = read('firestore.rules');
      expect(rules.contains("'phoneNumber'"), isTrue,
          reason: 'Yayınlanan numara (publicPhone) ile hassas numara '
              '(phoneNumber) ayrımı korunmalı.');
    });
  });

  group('Akış · numara → görünürlük → WhatsApp', () {
    String read(String p) => File(p).readAsStringSync();

    test('numara giriş alanı Hesap Ayarları’nda var', () {
      final ekran =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(ekran.contains('_PhoneEditSheet'), isTrue);
      expect(ekran.contains('normalizeTrMobile'), isTrue,
          reason: 'Kayıt E.164’e çevrilmeden yazılıyor.');
    });

    test('kaydet düğmesi geçersiz numarada pasif', () {
      final ekran =
          read('lib/features/profile/presentation/profile_screen.dart');
      // `onPressed: gecerli ? ... : null` — sessiz başarısızlık olmasın.
      expect(ekran.contains('onPressed: gecerli'), isTrue);
    });

    test('numara kaldırılınca vitrin görünürlüğü de kapanır', () {
      final ekran =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(ekran.contains('setPhoneVisibility(show: false)'), isTrue,
          reason: 'Numara silinince "görünsün" açık kalırsa profil '
              'tutarsız duruma düşer.');
    });

    test('WhatsApp düğmesi yalnız yayınlanmış numaraya bakar', () {
      final chat = read('lib/features/chat/presentation/chat_screen.dart');
      expect(chat.contains('other.publicPhone'), isTrue);
      // Hassas alan sohbette KULLANILMAMALI.
      expect(chat.contains('other.phoneNumber'), isFalse,
          reason: 'Hassas numara sohbete sızıyor.');
    });
  });
}

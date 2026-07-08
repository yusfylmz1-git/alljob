import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/core/utils/contact_masker.dart';

void main() {
  group('ContactMasker (PRD §5)', () {
    test('telefon numarasını maskeler', () {
      expect(ContactMasker.mask('Beni ara 0532 123 45 67 lütfen'),
          isNot(contains('123 45 67')));
      expect(ContactMasker.containsContact('05321234567'), isTrue);
    });

    test('e-postayı maskeler', () {
      final out = ContactMasker.mask('mail: ahmet@example.com');
      expect(out, isNot(contains('ahmet@example.com')));
      expect(ContactMasker.containsContact('ahmet@example.com'), isTrue);
    });

    test('bağlantıyı ve alan adını maskeler', () {
      expect(ContactMasker.containsContact('siteme bak www.usta.com'), isTrue);
      expect(ContactMasker.containsContact('https://wa.me/905321234567'), isTrue);
    });

    test('sosyal medya kullanıcı adını maskeler', () {
      expect(ContactMasker.containsContact('instagram: @ahmet_usta'), isTrue);
      expect(ContactMasker.containsContact('bana @kullanici_adi yaz'), isTrue);
    });

    test('normal mesajı değiştirmez', () {
      const msg = 'Merhaba, yarın saat 3 gibi gelebilir misiniz?';
      expect(ContactMasker.mask(msg), msg);
      expect(ContactMasker.containsContact(msg), isFalse);
    });
  });
}

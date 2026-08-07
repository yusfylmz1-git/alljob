import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/utils/contact_masker.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';

void main() {
  // Sohbet akışında maskeleme KALDIRILDI (ürün kararı, oturum 2). Sınıfın
  // kendisi duruyor ve çalışır durumda — başka bir yerde gerekirse diye —
  // ama `sendMessage` onu artık ÇAĞIRMIYOR.
  group('Sohbet mesajları maskelenmez (ürün kararı)', () {
    test('telefon numarası olduğu gibi kaydedilir', () async {
      final repo = MockChatRepository();
      const chatId = 'chat_c1__a1';
      const text = 'Beni ara 0532 123 45 67';

      final wasMasked = await repo.sendMessage(
        chatId: chatId,
        senderUid: 'c1',
        text: text,
      );

      expect(wasMasked, isFalse,
          reason: 'Maskeleme kaldırıldı — dönüş her zaman false olmalı.');

      final messages = await repo.watchMessages(chatId).first;
      expect(messages.single.text, text,
          reason: 'Mesaj metni DEĞİŞTİRİLMEDEN saklanmalı.');

      repo.dispose();
    });

    test('e-posta ve sosyal medya da olduğu gibi kalır', () async {
      final repo = MockChatRepository();
      const chatId = 'chat_c2__a2';
      const text = 'ahmet@example.com · instagram: @ahmet_usta';

      await repo.sendMessage(chatId: chatId, senderUid: 'c2', text: text);

      final messages = await repo.watchMessages(chatId).first;
      expect(messages.single.text, text);

      repo.dispose();
    });
  });

  // Sınıf hâlâ doğru çalışıyor mu? (Sohbette kullanılmıyor ama bozulmamalı.)
  group('ContactMasker (sınıf korunuyor, sohbette KULLANILMIYOR)', () {
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

import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/local/mock_database.dart';
import 'package:usta_cepte/data/models/chat.dart';
import 'package:usta_cepte/features/chat/data/chat_repository.dart';

void main() {
  group('MockChatRepository', () {
    test('sohbet başlatır ve mesaj gönderir', () async {
      final repo = MockChatRepository();
      final chatId = repo.startChat(
        customerUid: 'c1',
        customerName: 'Müşteri',
        artisanUid: 'a1',
        artisanName: 'Usta',
      );
      expect(repo.getThread(chatId), isNotNull);

      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'Merhaba');
      final msgs = await repo.watchMessages(chatId).first;
      expect(msgs.length, 1);
      expect(msgs.first.text, 'Merhaba');
    });

    test('iletişim bilgisi maskelenir ve uyarı döner', () async {
      final repo = MockChatRepository();
      final chatId = repo.startChat(
        customerUid: 'c1',
        customerName: 'Müşteri',
        artisanUid: 'a1',
        artisanName: 'Usta',
      );
      final masked =
          await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'ara 0532 123 45 67');
      expect(masked, isTrue);
      final msgs = await repo.watchMessages(chatId).first;
      expect(msgs.first.text, isNot(contains('123 45 67')));
    });

    test('sohbet listesi ilgili kullanıcı için görünür', () async {
      final repo = MockChatRepository();
      repo.startChat(
        customerUid: 'c1', customerName: 'M', artisanUid: 'a1', artisanName: 'U');
      final threads = await repo.watchThreads('a1').first;
      expect(threads.length, 1);
      expect(threads.first.involves('a1'), isTrue);
    });

    test('okunmamış sayısı ve okundu işaretleme çalışır', () async {
      final repo = MockChatRepository();
      final chatId = repo.startChat(
        customerUid: 'c1', customerName: 'M', artisanUid: 'a1', artisanName: 'U');
      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'Merhaba');

      // Usta için 1 okunmamış; kendi mesajı gönderen müşteri için 0.
      expect(repo.unreadCount(chatId: chatId, uid: 'a1'), 1);
      expect(repo.unreadCount(chatId: chatId, uid: 'c1'), 0);
      expect(repo.lastReadAt(chatId: chatId, uid: 'a1'), isNull);

      repo.markRead(chatId: chatId, uid: 'a1');
      expect(repo.unreadCount(chatId: chatId, uid: 'a1'), 0);
      expect(repo.lastReadAt(chatId: chatId, uid: 'a1'), isNotNull);
    });

    test('mesaj silme: içerik kalkar, önizleme güncellenir, '
        'başkasının mesajı silinemez', () async {
      final repo = MockChatRepository();
      final chatId = repo.startChat(
        customerUid: 'c1', customerName: 'M', artisanUid: 'a1', artisanName: 'U');
      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'İlk');
      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'Gizli no');
      var msgs = await repo.watchMessages(chatId).first;
      final lastId = msgs.last.id;

      // Başkası (usta) müşterinin mesajını silemez.
      await repo.deleteMessage(
          chatId: chatId, messageId: lastId, senderUid: 'a1');
      msgs = await repo.watchMessages(chatId).first;
      expect(msgs.last.deleted, isFalse);

      // Gönderen silebilir: içerik kalkar, bayrak konur, önizleme değişir.
      await repo.deleteMessage(
          chatId: chatId, messageId: lastId, senderUid: 'c1');
      msgs = await repo.watchMessages(chatId).first;
      expect(msgs.last.deleted, isTrue);
      expect(msgs.last.text, isNull);
      expect(msgs.last.hasImage, isFalse);
      expect(repo.getThread(chatId)!.lastMessage, ChatMessage.deletedPreview);

      // Son OLMAYAN mesaj silinince önizleme değişmez.
      expect(msgs.first.deleted, isFalse);
    });

    test('sohbeti benden sil: listeden düşer, karşı tarafta kalır, '
        'yeni mesajla boş döner', () async {
      final repo = MockChatRepository();
      final chatId = repo.startChat(
        customerUid: 'c1', customerName: 'M', artisanUid: 'a1', artisanName: 'U');
      await repo.sendMessage(chatId: chatId, senderUid: 'a1', text: 'Eski');

      await repo.deleteThreadForMe(chatId: chatId, uid: 'c1');
      // Silen tarafın listesinden düşer; karşı tarafta durur.
      expect(await repo.watchThreads('c1').first, isEmpty);
      expect(await repo.watchThreads('a1').first, hasLength(1));
      // Silme anı kaydedilir → eski mesajlar UI'da filtrelenir.
      expect(repo.clearedAt(chatId: chatId, uid: 'c1'), isNotNull);
      expect(repo.clearedAt(chatId: chatId, uid: 'a1'), isNull);

      // Karşı taraf yeni mesaj yazınca sohbet yeniden belirir. (Küçük bekleme:
      // silme ile mesaj aynı zaman damgasına denk gelirse "sonra" sayılmaz.)
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.sendMessage(chatId: chatId, senderUid: 'a1', text: 'Yeni');
      expect(await repo.watchThreads('c1').first, hasLength(1));
    });

    test('hasChatBetween sohbet geçmişini doğrular (PRD §5)', () {
      final repo = MockChatRepository();
      expect(
        repo.hasChatBetween(customerUid: 'c1', artisanUid: 'a1'),
        isFalse,
      );
      repo.startChat(
        customerUid: 'c1', customerName: 'M', artisanUid: 'a1', artisanName: 'U');
      expect(
        repo.hasChatBetween(customerUid: 'c1', artisanUid: 'a1'),
        isTrue,
      );
      // Farklı usta için hâlâ false.
      expect(
        repo.hasChatBetween(customerUid: 'c1', artisanUid: 'a2'),
        isFalse,
      );
    });
  });

  group('MockDatabase.addReview (PRD §3/§5)', () {
    test('değerlendirme ekler ve ortalama puanı günceller', () {
      final db = MockDatabase();
      final before = db.artisans['artisan_0']!.profile;

      db.addReview(
        artisanUid: 'artisan_0',
        customerUid: 'c1',
        customerName: 'Müşteri',
        rating: 5,
        tags: const ['Temiz işçilik', 'Zamanında geldi'],
      );

      final rec = db.artisans['artisan_0']!;
      expect(rec.profile.totalReviews, before.totalReviews + 1);
      expect(rec.profile.totalRatingSum, before.totalRatingSum + 5);
      expect(rec.reviews.first.rating, 5);
      expect(rec.reviews.first.tags, contains('Temiz işçilik'));
    });

    test('aynı müşteri aynı ustayı 2. kez değerlendiremez (kural paritesi)', () {
      final db = MockDatabase();
      final first = db.addReview(
        artisanUid: 'artisan_0',
        customerUid: 'c1',
        customerName: 'Müşteri',
        rating: 5,
        tags: const [],
      );
      expect(first, isTrue);

      final countAfterFirst = db.artisans['artisan_0']!.profile.totalReviews;
      final second = db.addReview(
        artisanUid: 'artisan_0',
        customerUid: 'c1',
        customerName: 'Müşteri',
        rating: 1,
        tags: const [],
      );
      expect(second, isFalse);
      expect(db.artisans['artisan_0']!.profile.totalReviews, countAfterFirst);

      // Farklı müşteri hâlâ değerlendirebilir.
      final other = db.addReview(
        artisanUid: 'artisan_0',
        customerUid: 'c2',
        customerName: 'Diğer',
        rating: 4,
        tags: const [],
      );
      expect(other, isTrue);
    });
  });
}

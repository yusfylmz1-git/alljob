import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/social_links.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';

/// Mesajlar ekranının profesyonel liste davranışları: arşivleme, sabitleme,
/// okundu tiki verisi. Ayrıca profil sosyal bağlantı normalizasyonu.
void main() {
  Future<(MockChatRepository, String)> seed() async {
    final repo = MockChatRepository();
    final chatId = await repo.startChat(
      customerUid: 'c1',
      customerName: 'Müşteri',
      artisanUid: 'a1',
      artisanName: 'Usta',
    );
    return (repo, chatId);
  }

  group('Sohbet arşivleme', () {
    test('arşiv KİŞİSELDİR: yalnız arşivleyeni etkiler', () async {
      final (repo, chatId) = await seed();
      await repo.setThreadArchived(chatId: chatId, uid: 'c1', archived: true);

      final t = repo.getThread(chatId)!;
      expect(t.isArchivedFor('c1'), isTrue);
      expect(t.isArchivedFor('a1'), isFalse, reason: 'karşı taraf etkilenmez');
    });

    test('arşivden çıkarma bayrağı temizler', () async {
      final (repo, chatId) = await seed();
      await repo.setThreadArchived(chatId: chatId, uid: 'c1', archived: true);
      await repo.setThreadArchived(chatId: chatId, uid: 'c1', archived: false);
      expect(repo.getThread(chatId)!.isArchivedFor('c1'), isFalse);
    });

    test('yeni mesaj sohbeti ALICI arşivinden çıkarır, gönderende bırakır',
        () async {
      final (repo, chatId) = await seed();
      // İki taraf da arşivlemiş olsun.
      await repo.setThreadArchived(chatId: chatId, uid: 'c1', archived: true);
      await repo.setThreadArchived(chatId: chatId, uid: 'a1', archived: true);

      // Usta yazıyor → müşterinin (alıcı) arşivi düşer, ustanınki kalır.
      await repo.sendMessage(chatId: chatId, senderUid: 'a1', text: 'Merhaba');

      final t = repo.getThread(chatId)!;
      expect(t.isArchivedFor('c1'), isFalse, reason: 'alıcının arşivi düşer');
      expect(t.isArchivedFor('a1'), isTrue, reason: 'gönderenin arşivi kalır');
    });
  });

  group('Sohbet sabitleme', () {
    test('sabitleme kişiseldir ve geri alınabilir', () async {
      final (repo, chatId) = await seed();
      await repo.setThreadPinned(chatId: chatId, uid: 'c1', pinned: true);

      var t = repo.getThread(chatId)!;
      expect(t.isPinnedFor('c1'), isTrue);
      expect(t.isPinnedFor('a1'), isFalse);

      await repo.setThreadPinned(chatId: chatId, uid: 'c1', pinned: false);
      t = repo.getThread(chatId)!;
      expect(t.isPinnedFor('c1'), isFalse);
    });

    test('mesaj gönderimi sabitlemeyi bozmaz', () async {
      final (repo, chatId) = await seed();
      await repo.setThreadPinned(chatId: chatId, uid: 'c1', pinned: true);
      await repo.sendMessage(chatId: chatId, senderUid: 'a1', text: 'Selam');
      expect(repo.getThread(chatId)!.isPinnedFor('c1'), isTrue);
    });
  });

  group('Okundu tiki verisi', () {
    test('son mesajın göndereni kaydedilir', () async {
      final (repo, chatId) = await seed();
      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'Merhaba');
      expect(repo.getThread(chatId)!.lastMessageSenderUid, 'c1');
    });

    test('lastReadBy okumadan önce null, markRead sonrası doludur', () async {
      final (repo, chatId) = await seed();
      expect(repo.lastReadBy(chatId: chatId, uid: 'a1'), isNull);

      await repo.sendMessage(chatId: chatId, senderUid: 'c1', text: 'Merhaba');
      repo.markRead(chatId: chatId, uid: 'a1');

      final readAt = repo.lastReadBy(chatId: chatId, uid: 'a1');
      expect(readAt, isNotNull);
      // Okuma anı son mesajdan geri değil → gönderende çift tik çizilir.
      expect(readAt!.isBefore(repo.getThread(chatId)!.updatedAt), isFalse);
    });
  });

  group('SocialLinks normalizasyonu', () {
    test('tam URL kullanıcı adına indirgenir', () {
      expect(SocialLinks.normalizeHandle('https://instagram.com/ahmet_usta/?hl=tr'),
          'ahmet_usta');
      expect(SocialLinks.normalizeHandle('@ahmet_usta'), 'ahmet_usta');
      expect(SocialLinks.normalizeHandle('  '), isNull);
      // Yalnız alan adı yazıldıysa kullanıcı adı yok.
      expect(SocialLinks.normalizeHandle('instagram.com'), isNull);
    });

    test('web sitesi https ile tamamlanır; kötü şema reddedilir', () {
      expect(SocialLinks.normalizeWebsite('ornek.com'), 'https://ornek.com');
      expect(SocialLinks.normalizeWebsite('http://ornek.com'),
          'http://ornek.com');
      expect(SocialLinks.normalizeWebsite('javascript:alert(1)'), isNull);
      expect(SocialLinks.normalizeWebsite('localhost'), isNull);
    });

    test('WhatsApp TR yerel yazımı E.164 olur', () {
      expect(SocialLinks.normalizeWhatsapp('0532 123 45 67'), '+905321234567');
      expect(SocialLinks.normalizeWhatsapp('5321234567'), '+905321234567');
      expect(SocialLinks.normalizeWhatsapp('+905321234567'), '+905321234567');
      expect(SocialLinks.normalizeWhatsapp('123'), isNull);
    });

    test('bağlantı adresleri kullanıcı adından türetilir', () {
      const s = SocialLinks(
        instagram: 'ahmet',
        youtube: 'ahmetkanal',
        tiktok: 'ahmettiktok',
        whatsapp: '+905321234567',
        website: 'https://ornek.com',
      );
      expect(s.instagramUrl, 'https://instagram.com/ahmet');
      expect(s.youtubeUrl, 'https://youtube.com/@ahmetkanal');
      expect(s.tiktokUrl, 'https://tiktok.com/@ahmettiktok');
      expect(s.whatsappUrl, 'https://wa.me/905321234567');
      expect(s.hasAny, isTrue);
      expect(SocialLinks.empty.hasAny, isFalse);
    });

    test('toMap/fromMap gidiş-dönüşü korur; boş alanlar null yazılır', () {
      const s = SocialLinks(instagram: 'ahmet', website: 'https://ornek.com');
      final back = SocialLinks.fromMap(s.toMap());
      expect(back.instagram, 'ahmet');
      expect(back.website, 'https://ornek.com');
      expect(back.youtube, isNull);
      expect(s.toMap()['tiktok'], isNull);
    });
  });
}

// Regresyon: mesaj gönderim hatası SEBEBİNE göre anlatılır (2026-08-20).
//
// Kapalı test bulgusu: testçi mesaj atamıyor, ekranda kırmızı şerit
// "Mesaj gönderilemedi. Bağlantını kontrol edip tekrar dene." Ağı sorunsuzdu.
//
// Asıl sebep: sohbet dokümanı oluşturulamıyordu, çünkü `firestore.rules`
// chats/create kuralı `isEmailVerified()` şart koşuyor ve kullanıcı e-posta
// ile kaydolup doğrulama bağlantısına tıklamamıştı. Google ile girenler
// otomatik doğrulanmış sayıldığı için hata YALNIZ bazı kişilerde çıkıyordu.
//
// `catch (_)` her hatayı tek metne indirdiği için sebep hiç görünmüyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  late String chatScreen;
  late String rules;

  setUpAll(() {
    chatScreen = read('lib/features/chat/presentation/chat_screen.dart');
    rules = read('firestore.rules');
  });

  group('Gönderim hatası sebebe göre ayrışır', () {
    test('hata YUTULMUYOR — sebebe erişiliyor', () {
      // `catch (_)` sebebi atardı; artık nesne yakalanıp incelenmeli.
      expect(chatScreen.contains('void _showSendFailure(Object error)'), isTrue,
          reason: 'Sebebe göre dallanan hata işleyici kaldırılmış.');
      expect(chatScreen.contains('_showSendFailure(e)'), isTrue,
          reason: 'Gönderim catch bloğu işleyiciyi çağırmıyor.');
    });

    test('permission-denied + doğrulanmamış e-posta AYRI ele alınıyor', () {
      expect(chatScreen.contains("code == 'permission-denied'"), isTrue);
      expect(chatScreen.contains('!user.emailVerified'), isTrue,
          reason: 'E-posta doğrulama durumu kontrol edilmiyor — kullanıcı '
              'yine "bağlantını kontrol et" görür.');
      expect(chatScreen.contains('_promptEmailVerification'), isTrue);
    });

    test('doğrulama bağlantısı YENİDEN GÖNDERİLEBİLİYOR', () {
      // Sebebi söyleyip çözümü sunmamak kullanıcıyı yine kilitler.
      expect(chatScreen.contains('sendEmailVerification()'), isTrue,
          reason: 'Diyalogda yeniden gönderme eylemi yok.');
    });

    test('ağ hatası HÂLÂ ağ hatası olarak anlatılıyor (fazlasını yapmadı)', () {
      expect(chatScreen.contains("code == 'unavailable'"), isTrue);
      expect(chatScreen.contains('Bağlantını kontrol edip tekrar dene.'), isTrue,
          reason: 'Gerçek ağ hatasının metni kaybolmuş.');
    });
  });

  group('Kural ile istemci aynı şeyi söylüyor', () {
    // CLAUDE.md değişmez kural 2: kural + istemci birlikte değişir.
    test('chats/create e-posta doğrulaması İSTİYOR', () {
      // İstemcideki açıklama bu kurala dayanıyor; kural kalkarsa istemci
      // kullanıcıya var olmayan bir şart anlatır.
      expect(rules.contains('isEmailVerified()'), isTrue);
    });

    test('mesaj yazma e-posta doğrulaması İSTEMİYOR', () {
      // Asimetri bilinçli: sohbeti AÇMAK doğrulama ister, mevcut sohbete
      // yazmak istemez. Bu yüzden hata ilk mesajda çıkar.
      final mesajBlok = rules.substring(rules.indexOf('match /messages/'));
      final createBlok = mesajBlok.substring(
        mesajBlok.indexOf('allow create:'),
        mesajBlok.indexOf('allow update:'),
      );
      expect(createBlok.contains('isEmailVerified()'), isFalse,
          reason: 'Mesaj yazmaya da doğrulama şartı eklenmiş — o zaman hata '
              'ilk mesajda değil HER mesajda çıkar, teşhis değişir.');
    });
  });
}

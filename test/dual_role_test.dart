import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/data/models/user_role.dart';
import 'package:usta_cepte/features/auth/data/auth_repository.dart';
import 'package:usta_cepte/features/auth/data/mock_auth_repository.dart';
import 'package:usta_cepte/features/chat/data/chat_repository.dart';

void main() {
  group('Tek hesap, çift rol (AppUser)', () {
    test('yeni kullanıcı: usta profili yok, müşteri modunda', () {
      final user = AppUser(
        uid: 'u1',
        displayName: 'Yeni Kullanıcı',
        email: 'yeni@test.com',
        createdAt: DateTime.now(),
      );
      expect(user.hasArtisanProfile, isFalse);
      expect(user.activeMode, UserRole.customer);
      expect(user.isArtisan, isFalse);
    });

    test('eski "role: artisan" kaydı → usta profili + usta modu', () {
      final user = AppUser.fromMap('u2', {
        'displayName': 'Eski Usta',
        'email': 'eski@test.com',
        'role': 'artisan',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(user.hasArtisanProfile, isTrue);
      expect(user.activeMode, UserRole.artisan);
    });

    test('toMap/fromMap roundtrip yeni alanları korur', () {
      final user = AppUser(
        uid: 'u3',
        displayName: 'Çift Rol',
        email: 'cift@test.com',
        hasArtisanProfile: true,
        activeMode: UserRole.customer, // usta profili var ama müşteri modunda
        createdAt: DateTime(2026, 2, 2),
      );
      final restored = AppUser.fromMap('u3', user.toMap());
      expect(restored.hasArtisanProfile, isTrue);
      expect(restored.activeMode, UserRole.customer);
      expect(restored.isCustomer, isTrue);
    });
  });

  group('MockAuthRepository çift rol akışı', () {
    test('kayıt → Hizmet Vermeye Başla → mod geçişleri', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);

      final user = await repo.register(
        displayName: 'Deneme',
        email: 'deneme@test.com',
        password: '123456',
      );
      expect(user.hasArtisanProfile, isFalse);
      expect(user.activeMode, UserRole.customer);

      // Usta profili olmadan usta moduna geçilemez.
      expect(() => repo.setActiveMode(UserRole.artisan),
          throwsA(AuthException.noArtisanProfile));

      final artisan = await repo.becomeArtisan();
      expect(artisan.hasArtisanProfile, isTrue);
      expect(artisan.activeMode, UserRole.artisan);

      final backToCustomer = await repo.setActiveMode(UserRole.customer);
      expect(backToCustomer.activeMode, UserRole.customer);
      expect(backToCustomer.hasArtisanProfile, isTrue); // profil kalıcı

      final artisanAgain = await repo.setActiveMode(UserRole.artisan);
      expect(artisanAgain.activeMode, UserRole.artisan);
    });

    test('mod değişikliği yeniden girişte korunur (hesap deposu)', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);

      await repo.register(
        displayName: 'Kalıcı',
        email: 'kalici@test.com',
        password: '123456',
      );
      await repo.becomeArtisan();
      await repo.signOut();

      final again =
          await repo.login(email: 'kalici@test.com', password: '123456');
      expect(again.hasArtisanProfile, isTrue);
      expect(again.activeMode, UserRole.artisan);
    });

    test('demo usta hesabı usta modunda açılır', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);
      final usta =
          await repo.login(email: 'usta@test.com', password: '123456');
      expect(usta.hasArtisanProfile, isTrue);
      expect(usta.isArtisan, isTrue);
    });
  });

  group('Çapraz mod okunmamış ayrımı (☰ rozeti)', () {
    test('okunmamışlar thread.artisanUid ile tarafa ayrılır', () async {
      final chat = MockChatRepository();
      addTearDown(chat.dispose);

      // dual: hem müşteri (usta a1 ile) hem usta (müşteri c9 ile) sohbette.
      final asCustomer = chat.startChat(
          customerUid: 'dual', customerName: 'Çift Rol',
          artisanUid: 'a1', artisanName: 'Usta A');
      final asArtisan = chat.startChat(
          customerUid: 'c9', customerName: 'Müşteri C',
          artisanUid: 'dual', artisanName: 'Çift Rol');

      await chat.sendMessage(
          chatId: asCustomer, senderUid: 'a1', text: 'Müşteri tarafına mesaj');
      await chat.sendMessage(
          chatId: asArtisan, senderUid: 'c9', text: 'Usta tarafına mesaj 1');
      await chat.sendMessage(
          chatId: asArtisan, senderUid: 'c9', text: 'Usta tarafına mesaj 2');

      // unreadBySideProvider'ın yaptığı ayrımın birebir aynısı:
      final threads = await chat.watchThreads('dual').first;
      var customerSide = 0, artisanSide = 0;
      for (final t in threads) {
        final n = chat.unreadCount(chatId: t.id, uid: 'dual');
        if (t.artisanUid == 'dual') {
          artisanSide += n;
        } else {
          customerSide += n;
        }
      }
      expect(customerSide, 1); // a1'den gelen
      expect(artisanSide, 2); // c9'dan gelenler

      // Müşteri modundayken çapraz rozet usta tarafını gösterir; okununca söner.
      chat.markRead(chatId: asArtisan, uid: 'dual');
      expect(chat.unreadCount(chatId: asArtisan, uid: 'dual'), 0);
    });
  });
}

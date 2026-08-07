import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/chat.dart';
import 'package:sepette_hizmet/data/models/favorite.dart';

/// Serbest pazaryeri sözleşmesi (2026-08-08).
///
/// **Faz 5 — mesaj:** iki taraf da baştan yazabilir. Eskiden usta, müşteri
/// yazana kadar (`customerStarted`) mesaj gönderemezdi.
///
/// **Faz 4 — takip:** herkes herkesi takip eder. Eskiden yalnız müşteri,
/// ustayı takip edebiliyordu.
void main() {
  ChatThread thread({DateTime? lockedAt}) => ChatThread(
        id: 'chat_c1__a1__job1',
        customerUid: 'c1',
        artisanUid: 'a1',
        customerName: 'Müşteri',
        artisanName: 'Usta',
        updatedAt: DateTime(2026, 1, 1),
        jobId: 'job1',
        lockedAt: lockedAt,
      );

  group('Faz 5 · mesajlaşma serbest', () {
    test('usta, müşteri yazmadan da mesaj atabilir', () {
      final t = thread();
      expect(t.customerStarted, isFalse);
      expect(t.canSend('a1'), isTrue,
          reason: 'customerStarted kısıtı kaldırıldı.');
      expect(t.canSend('c1'), isTrue);
    });

    test('KİLİT hâlâ herkesi durdurur', () {
      // Tek kalan engel: müşteri başka ustayla anlaşınca sohbet kilitlenir.
      final t = thread(lockedAt: DateTime(2026, 2, 1));
      expect(t.canSend('c1'), isFalse);
      expect(t.canSend('a1'), isFalse);
    });

    test('kural ve istemci aynı mantığı uygular (CLAUDE.md kural 2)', () {
      final rules = File('firestore.rules').readAsStringSync();
      final fn = RegExp(r'function senderMayWrite\(\) \{.*?\n        \}',
              dotAll: true)
          .firstMatch(rules);
      expect(fn, isNotNull);
      final body = fn!.group(0)!;
      // Yalnız kilit kontrolü kalmalı; customerStarted şartı gitmeli.
      expect(body.contains('lockedAt'), isTrue);
      expect(body.contains('customerStarted'), isFalse,
          reason: 'Kural hâlâ müşteri başlatmasını şart koşuyor — istemciyle '
              'ayrıştı.');
    });
  });

  group('Faz 4 · takip yönsüz', () {
    test('takma adlar: follower/followed', () {
      final f = Favorite(
        customerUid: 'u_takip_eden',
        artisanUid: 'u_takip_edilen',
        artisanName: 'Ahmet',
        professionNameTR: 'Elektrikçi',
        rating: 4.5,
        totalReviews: 10,
        createdAt: DateTime(2026, 1, 1),
        customerName: 'Veli',
      );

      expect(f.followerUid, 'u_takip_eden');
      expect(f.followedUid, 'u_takip_edilen');
      expect(f.followedName, 'Ahmet');
      expect(f.followerName, 'Veli');
    });

    test('Firestore alan adları DEĞİŞMEDİ (veri göçü yok)', () {
      // `customerUid`/`artisanUid` tarihsel adlar; yeniden adlandırmak
      // mevcut kayıtları okunamaz yapardı (CLAUDE.md kural 6 mantığı).
      final f = Favorite(
        customerUid: 'a',
        artisanUid: 'b',
        artisanName: 'X',
        professionNameTR: 'Y',
        rating: 0,
        totalReviews: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      final map = f.toMap();
      expect(map.containsKey('customerUid'), isTrue);
      expect(map.containsKey('artisanUid'), isTrue);
      expect(Favorite.idFor('a', 'b'), 'a__b');
    });

    test('takip düğmesi usta modunda GİZLENMİYOR', () {
      final btn = File(
        'lib/features/favorites/presentation/favorite_button.dart',
      ).readAsStringSync();
      // Eskiden: if (isArtisan) return const SizedBox.shrink();
      expect(btn.contains('if (isArtisan) return'), isFalse,
          reason: 'Usta modunda takip düğmesi yine gizleniyor.');
      // Kendini takip etme engeli KALMALI.
      expect(btn.contains('user.uid == artisanUid'), isTrue);
    });
  });
}

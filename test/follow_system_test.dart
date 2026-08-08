import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_notification.dart';
import 'package:sepette_hizmet/data/models/favorite.dart';

/// Instagram tarzı takip sistemi sözleşmesi (2026-08-08).
///
/// Herkes herkesi takip eder; takip edilen kişinin usta olması gerekmez.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Model · usta-özel alanlar İSTEĞE BAĞLI', () {
    test('sıradan kullanıcı takibi meslek/puan olmadan kurulur', () {
      // Eskiden professionNameTR/rating/totalReviews ZORUNLUYDU — usta
      // olmayan biri takip edilemiyordu.
      final f = Favorite(
        customerUid: 'follower',
        artisanUid: 'followed',
        artisanName: 'Ali',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(f.followerUid, 'follower');
      expect(f.followedUid, 'followed');
      expect(f.hasArtisanInfo, isFalse,
          reason: 'Usta bilgisi yoksa meslek/puan satırı çizilmemeli.');
    });

    test('usta takibinde meslek/puan taşınır', () {
      final f = Favorite(
        customerUid: 'c',
        artisanUid: 'a',
        artisanName: 'Ahmet Usta',
        professionNameTR: 'Elektrikçi',
        rating: 4.7,
        totalReviews: 12,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(f.hasArtisanInfo, isTrue);
      expect(f.followedName, 'Ahmet Usta');
    });

    test('Firestore alan adları korunuyor (veri göçü yok)', () {
      final map = Favorite(
        customerUid: 'a',
        artisanUid: 'b',
        artisanName: 'X',
        createdAt: DateTime(2026, 1, 1),
      ).toMap();
      expect(map.containsKey('customerUid'), isTrue);
      expect(map.containsKey('artisanUid'), isTrue);
    });
  });

  group('Takip düğmesi herkes için', () {
    late String btn;
    setUpAll(() => btn = read(
        'lib/features/favorites/presentation/favorite_button.dart'));

    test('usta-özel alanlar zorunlu DEĞİL', () {
      expect(btn.contains("this.professionNameTR = ''"), isTrue);
      expect(btn.contains('this.rating = 0'), isTrue);
      expect(btn.contains('this.totalReviews = 0'), isTrue);
    });

    test('kendini takip engeli duruyor', () {
      expect(btn.contains('user.uid == artisanUid'), isTrue);
    });

    test('mesaj rol varsaymıyor', () {
      // Eskiden "Ustayı takip ediyorsunuz." yazıyordu — takip edilen usta
      // olmayabilir.
      expect(btn.contains('Ustayı takip ediyorsunuz'), isFalse);
      expect(btn.contains("'Takip ediliyor.'"), isTrue);
    });
  });

  group('Takip ekranı · iki sekme', () {
    late String scr;
    setUpAll(() => scr = read(
        'lib/features/favorites/presentation/favorites_screen.dart'));

    test('Takipçiler ve Takip sekmeleri var', () {
      expect(scr.contains("Tab(text: 'Takipçiler')"), isTrue);
      expect(scr.contains("Tab(text: 'Takip')"), isTrue);
      expect(scr.contains('followersProvider'), isTrue);
      expect(scr.contains('favoritesProvider'), isTrue);
    });

    test('takipçi sayacı DOĞRU sekmeye gider', () {
      // Hata buydu: takipçi sayacına dokununca "Takip Ettiklerim" açılıyordu.
      final paths = read('lib/core/router/route_paths.dart');
      expect(paths.contains("followers = '/favorites?tab=followers'"), isTrue);

      final profile =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(profile.contains('RoutePaths.followers'), isTrue);
    });
  });

  group('Karşılıklı takip rozeti', () {
    test('isFollowedByProvider ters yönde sorguluyor', () {
      final p = read('lib/features/favorites/data/favorite_providers.dart');
      expect(p.contains('isFollowedByProvider'), isTrue);
      // customerUid = karşı taraf (takip eden), artisanUid = ben.
      expect(p.contains('customerUid: otherUid'), isTrue);
      expect(p.contains('artisanUid: me'), isTrue);
    });

    test('profilde "Seni takip ediyor" rozeti var', () {
      final s = read(
          'lib/features/customer/presentation/artisan_profile_screen.dart');
      expect(s.contains('_FollowsYouBadge'), isTrue);
      expect(s.contains('Seni takip ediyor'), isTrue);
    });
  });

  group('Takip bildirimi', () {
    late String cf;
    setUpAll(() => cf = read('functions/index.js'));

    test('onFollowCreated tanımlı', () {
      expect(cf.contains('exports.onFollowCreated'), isTrue);
      expect(cf.contains('document: "favorites/{favId}"'), isTrue);
    });

    test('spam koruması: deterministik bildirim kimliği', () {
      // `follow_{followerUid}` → takip-bırak-takip aynı dokümanı ezer,
      // listede tek satır kalır (Instagram davranışı).
      expect(cf.contains('`follow_\${followerUid}`'), isTrue);
    });

    test('kendini takip bildirimi gitmez', () {
      expect(cf.contains('if (followerUid === followedUid) return;'), isTrue);
    });

    test('takip bildirimi "iş güncellemeleri" tercihine bağlı DEĞİL', () {
      // Kullanıcı iş bildirimlerini kapatınca takipçi haberi susmamalı.
      expect(cf.contains('if (t === "follow") return "chat";'), isTrue);
    });

    test('istemci follow bildirimini tanıyor ve profile götürüyor', () {
      final model = read('lib/data/models/app_notification.dart');
      expect(model.contains("isFollow => type == 'follow'"), isTrue);
      expect(model.contains('actorUid'), isTrue);

      final push = read('lib/features/notifications/data/push_service.dart');
      expect(push.contains("case 'follow':"), isTrue);
      expect(push.contains('RoutePaths.artisanProfile(actorUid)'), isTrue);
    });
  });

  group('Bildirim modeli', () {
    test('fromMap actorUid okur', () {
      final n = AppNotification.fromMap('n1', {
        'type': 'follow',
        'title': 'Yeni takipçi',
        'body': 'Ali seni takip etmeye başladı.',
        'actorUid': 'u_ali',
      });
      expect(n.isFollow, isTrue);
      expect(n.actorUid, 'u_ali');
    });
  });
}

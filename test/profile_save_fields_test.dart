import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B-04 regresyonu — profil kaydında SUNUCUYA AİT alanlar yazılmamalı.
///
/// `firestore.rules` iki grubu ayrı ayrı korur:
///  1. Sayaç/premium/moderasyon alanları → `affectedKeys().hasAny([...])`
///     ile tamamen yasak (CF yazar).
///  2. **Doğrulama aynaları** (`isVerified`, `emailVerified`) → `verifiedClaimOk`
///     ve `emailVerifiedMirrorOk` bunların true olmasını Auth token'ıyla
///     karşılaştırır. Profilde true yazılı ama token'da karşılığı yoksa
///     TÜM KAYIT `permission-denied` ile reddedilir.
///
/// Cihazda görülen hata buydu: "Kaydetme başarısız" (sonra B-04 ile
/// "sunucu reddetti" diye görünür oldu). `saveMyProfile` bu alanları
/// `toMap()`'ten çıkarmıyordu.
///
/// `FirebaseMyProfileRepository` gerçek Firestore'a bağlı olduğu için birim
/// testiyle çağrılamaz; sözleşme kaynak üzerinden doğrulanır.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/artisan/data/firebase_my_profile_repository.dart',
    ).readAsStringSync();
  });

  /// `saveMyProfile` gövdesi: imzadan bir sonraki üst düzey metoda kadar.
  String saveBody() {
    final start = source.indexOf('Future<void> saveMyProfile(');
    expect(start, greaterThan(-1), reason: 'saveMyProfile bulunamadı.');
    final next = source.indexOf('Future<void> markVerified', start);
    expect(next, greaterThan(start),
        reason: 'markVerified sınır olarak bulunamadı.');
    return source.substring(start, next);
  }

  group('B-04 · sunucuya ait alanlar yazımdan çıkarılır', () {
    test('doğrulama aynaları (isVerified/emailVerified) remove edilir', () {
      final body = saveBody();
      expect(body.contains("remove('isVerified')"), isTrue,
          reason: 'isVerified yazılırsa verifiedClaimOk tüm kaydı reddeder.');
      expect(body.contains("remove('emailVerified')"), isTrue,
          reason: 'emailVerified yazılırsa emailVerifiedMirrorOk reddeder.');
    });

    test('sayaç ve premium alanları da remove edilir', () {
      final body = saveBody();
      for (final f in [
        'averageRating',
        'totalReviews',
        'totalRatingSum',
        'topTags',
        'completedJobs',
        'isPremium',
        'premiumExpiresAt',
      ]) {
        expect(body.contains("remove('$f')"), isTrue,
            reason: '$f yalnız CF tarafından yazılır (CLAUDE.md kural 3).');
      }
    });

    test('kural hâlâ bu alanları koruyor (sözleşme kontrolü)', () {
      // Kural gevşetilirse yukarıdaki remove'ların gerekçesi düşer.
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules.contains("'isVerified'"), isTrue);
      expect(rules.contains('function emailVerifiedMirrorOk()'), isTrue);
      expect(rules.contains("'isPremium','premiumExpiresAt'"), isTrue);
    });
  });

  group('B-04 · doğrulama alanlarının MEŞRU yolu korunuyor', () {
    test('markVerified metodu tanımlı kalır', () {
      expect(source.contains('Future<void> markVerified'), isTrue);
    });
  });
}

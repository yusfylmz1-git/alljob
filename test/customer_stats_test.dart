import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';

/// Faz 6 · müşteri sayaçları (`completedJobsAsCustomer`,
/// `reviewCountAsCustomer`).
///
/// Sayaçlar herkese açık `users/{uid}` dokümanında ama YALNIZ CF yazar
/// (CLAUDE.md kural 3). İstemci yazabilseydi kullanıcı kendi "tamamlanan iş"
/// sayısını şişirirdi.
void main() {
  AppUser user({int done = 0, int reviews = 0}) => AppUser(
        uid: 'u1',
        displayName: 'Test',
        email: 't@x.com',
        createdAt: DateTime.utc(2026, 1, 1),
        completedJobsAsCustomer: done,
        reviewCountAsCustomer: reviews,
      );

  group('model · sayaçlar okunur ama YAZILMAZ', () {
    test('fromMap sayaçları okur, alan yoksa 0', () {
      final withCounts = AppUser.fromMap('u1', {
        'displayName': 'Ali',
        'completedJobsAsCustomer': 7,
        'reviewCountAsCustomer': 3,
      });
      expect(withCounts.completedJobsAsCustomer, 7);
      expect(withCounts.reviewCountAsCustomer, 3);

      final empty = AppUser.fromMap('u2', {'displayName': 'Veli'});
      expect(empty.completedJobsAsCustomer, 0);
      expect(empty.reviewCountAsCustomer, 0);
    });

    test('toMap sayaçları YAZMAZ (kural tüm kaydı reddederdi)', () {
      // B-04 dersi: sunucuya ait alan toMap'e sızarsa kural permission-denied
      // verir ve HİÇBİR değişiklik kaydedilmez.
      final map = user(done: 5, reviews: 2).toMap();
      expect(map.containsKey('completedJobsAsCustomer'), isFalse);
      expect(map.containsKey('reviewCountAsCustomer'), isFalse);
    });

    test('copyWith sayaçları DÜŞÜRMEZ', () {
      // B-19'daki tuzağın aynısı: yeni alan copyWith'e eklenmezse her
      // çağrıda 0'a düşer ve profil sayacı sıfırlanmış görünür.
      final before = user(done: 4, reviews: 9);
      final after = before
          .copyWith(displayName: 'Yeni Ad')
          .copyWith(phoneVerified: true);

      expect(after.completedJobsAsCustomer, 4);
      expect(after.reviewCountAsCustomer, 9);
      expect(after.displayName, 'Yeni Ad');
    });
  });

  group('kural · sayaçlar istemciye kapalı', () {
    late String rules;
    setUpAll(() => rules = File('firestore.rules').readAsStringSync());

    test('update: notSettingPublicPii sayaçları engeller', () {
      final fn = RegExp(
        r'function notSettingPublicPii\(\) \{.*?\n      \}',
        dotAll: true,
      ).firstMatch(rules);
      expect(fn, isNotNull);
      final body = fn!.group(0)!;
      expect(body.contains('completedJobsAsCustomer'), isTrue,
          reason: 'İstemci kendi tamamlanan-iş sayısını yazabilirdi.');
      expect(body.contains('reviewCountAsCustomer'), isTrue);
    });

    test('create: sayaçlarla doğan doküman reddedilir', () {
      expect(
        rules.contains(
            "'completedJobsAsCustomer', 'reviewCountAsCustomer'"),
        isTrue,
        reason: 'create allowlist sayaçları dışlamalı — kullanıcı ilk kayıtta '
            'şişirilmiş sayaçla doğamaz.',
      );
    });
  });

  group('CF · sayaçları yazan tek yer', () {
    late String cf;
    setUpAll(() => cf = File('functions/index.js').readAsStringSync());

    test('tamamlanan iş sayacını artıran kod YOK (akış kalktı)', () {
      // `completedJobsAsCustomer` eskiden iş `completed`a geçince artardı.
      // İş tamamlama akışı 2026-08-08'de kalktı → o geçiş hiç üretilmiyor,
      // artıran kod da 2026-08-09'da silindi. Alan modelde/kuralda duruyor
      // (eski kayıtlar okunabilsin) ama hiçbir yerde gösterilmiyor.
      //
      // Bu kod geri gelirse: onu tetikleyecek bir durum geçişi var mı?
      expect(cf.contains('completedJobsAsCustomer: FieldValue.increment(1)'),
          isFalse);
    });

    test('değerlendirme ADEDİ yazılır, PUAN yazılmaz', () {
      // Gizlilik: müşterinin aldığı puan private/rating altında kalır;
      // herkese açık dokümana yalnız sayı gider.
      expect(cf.contains('reviewCountAsCustomer: n'), isTrue);
      expect(cf.contains('averageRatingAsCustomer'), isFalse,
          reason: 'Müşteri PUANI herkese açık dokümana yazılmamalı.');
    });
  });
}

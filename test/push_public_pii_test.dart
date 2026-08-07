import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B-15 regresyonu — public `users/{uid}` PII temizliği.
///
/// Kural (`firestore.rules` → `notSettingPublicPii`) bu dökümandaki
/// `email` / `fcmTokens` alanları için YALNIZ SİLMEYE izin verir: yazım
/// sonrası anahtar `request.resource.data` içinde HİÇ kalmamalıdır.
///
/// `FieldValue.arrayRemove` alanı boş diziye indirir ama anahtar durur →
/// `permission-denied`. Hesap değiştirirken uygulamayı durduran hata buydu.
///
/// `PushService` `FirebaseFirestore.instance`'ı doğrudan kullandığı için
/// birim testiyle çağrılamaz; bu yüzden sözleşme KAYNAK ÜZERİNDEN doğrulanır.
/// Kaba görünse de asıl regresyonu yakalar: biri `delete()` yerine tekrar
/// `arrayRemove` yazarsa test kırılır.
void main() {
  group('B-15 · public fcmTokens temizliği yalnız delete() ile yapılır', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/features/notifications/data/push_service.dart',
      ).readAsStringSync();
    });

    test('public users dökümanına arrayRemove YAZILMAZ', () {
      // Public döküman yazımları `_db.collection('users').doc(uid)` ile başlar.
      // Private yol (`.collection('private').doc('push')`) arrayRemove/Union
      // kullanmakta serbesttir — kural orayı kısıtlamaz.
      final publicWrites = RegExp(
        r"_db\s*\.collection\('users'\)\s*\.doc\(uid\)\s*\.set\(\{(.*?)\}",
        dotAll: true,
      ).allMatches(source);

      expect(
        publicWrites,
        isNotEmpty,
        reason: 'Public users yazımı bulunamadı — test güncellenmeli.',
      );

      for (final m in publicWrites) {
        final body = m.group(1)!;
        expect(
          body.contains('arrayRemove'),
          isFalse,
          reason: 'Public users dökümanında arrayRemove kural tarafından '
              'reddedilir (anahtar kalır). FieldValue.delete() kullanın.\n'
              'Bulunan yazım: $body',
        );
      }
    });

    test('_stripPublicToken alanı delete() ile kaldırır', () {
      final fn = RegExp(
        r'Future<void> _stripPublicToken\(.*?\n  \}',
        dotAll: true,
      ).firstMatch(source);

      expect(fn, isNotNull, reason: '_stripPublicToken bulunamadı.');
      final body = fn!.group(0)!;

      expect(body.contains("'fcmTokens': FieldValue.delete()"), isTrue,
          reason: 'fcmTokens delete() ile silinmeli.');
      expect(body.contains('arrayRemove'), isFalse,
          reason: 'arrayRemove anahtarı bırakır → permission-denied.');
    });

    test('kural sözleşmesi hâlâ "anahtar kalmamalı" diyor', () {
      // Kod tarafını kurala bağlar: kural gevşetilirse bu test düşer ve
      // yukarıdaki iki testin gerekçesi gözden geçirilir.
      final rules = File('firestore.rules').readAsStringSync();
      final fn = RegExp(
        r'function notSettingPublicPii\(\) \{.*?\n      \}',
        dotAll: true,
      ).firstMatch(rules);

      expect(fn, isNotNull, reason: 'notSettingPublicPii bulunamadı.');
      final body = fn!.group(0)!;

      expect(body.contains("!('fcmTokens' in request.resource.data)"), isTrue,
          reason: 'Kural fcmTokens için "anahtar kalmamalı" şartını '
              'uygulamayı bıraktıysa _stripPublicToken gözden geçirilmeli.');
    });
  });
}

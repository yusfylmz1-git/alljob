import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:usta_cepte/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email doğrulaması', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('gecersiz'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('şifre minimum uzunluk', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('123'), isNotNull);
    });

    test('şifre tekrarı eşleşmesi', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
      expect(Validators.confirmPassword('abc123', 'xyz789'), isNotNull);
    });

    test('metinde telefon numarası tespiti', () {
      expect(Validators.phoneInText.hasMatch('Beni 0532 123 45 67 ara'), isTrue);
      expect(Validators.phoneInText.hasMatch('Merhaba nasılsınız'), isFalse);
    });
  });

  testWidgets('derleme kontrolü', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}

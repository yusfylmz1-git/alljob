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

    test('displayName güvenli karakterler', () {
      expect(Validators.displayName('Ali Veli'), isNull);
      expect(Validators.displayName("O'Brien"), isNull);
      expect(Validators.displayName('Jean-Luc'), isNull);
      expect(Validators.displayName('  Ayşe  Yılmaz '), isNull);
      // Sembol / enjeksiyon denemeleri
      expect(Validators.displayName('-/*-*/-*/****"""'), isNotNull);
      expect(Validators.displayName('***"""'), isNotNull);
      expect(Validators.displayName('!!!'), isNotNull);
      expect(Validators.displayName('12'), isNotNull); // az harf
      expect(Validators.displayName('ab'), isNotNull); // kısa
      expect(Validators.displayName(''), isNotNull);
      expect(Validators.displayName('Ali<script>'), isNotNull);
    });

    test('normalizeDisplayName boşluk ve kontrol karakteri', () {
      expect(Validators.normalizeDisplayName('  Ali   Veli  '), 'Ali Veli');
      expect(
        Validators.normalizeDisplayName('Ali\u0000Veli'),
        'AliVeli',
      );
    });

    test('experienceYears tavanı', () {
      expect(Validators.experienceYears('15'), isNull);
      expect(Validators.experienceYears(''), isNull);
      expect(Validators.experienceYears('60'), isNull);
      expect(Validators.experienceYears('61'), isNotNull);
      expect(Validators.experienceYears('21331231'), isNotNull);
      expect(Validators.clampExperienceYears(21331231), 60);
      expect(Validators.clampExperienceYears(-3), 0);
    });

    test('freeText sembol spam', () {
      expect(
        Validators.freeText('Banyo bataryası değişimi', min: 5, max: 80),
        isNull,
      );
      expect(
        Validators.freeText('********"""', min: 3, max: 80, required: true),
        isNotNull,
      );
      expect(
        Validators.freeText('Ali\u0000test', min: 3, max: 80),
        isNotNull,
      );
    });
  });

  testWidgets('derleme kontrolü', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}

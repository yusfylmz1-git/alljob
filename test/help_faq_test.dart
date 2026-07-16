import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/features/help/help_faq.dart';

void main() {
  test('SSS kategorileri ve içerik dolu', () {
    expect(kFaqCategories, containsAll(['Genel', 'Müşteri', 'Usta']));
    expect(kFaqItems, isNotEmpty);
    for (final c in kFaqCategories) {
      final n = kFaqItems.where((f) => f.category == c).length;
      expect(n, greaterThan(0), reason: '$c kategorisi boş olmamalı');
    }
    for (final f in kFaqItems) {
      expect(f.question.trim(), isNotEmpty);
      expect(f.answer.trim().length, greaterThan(20));
    }
  });
}

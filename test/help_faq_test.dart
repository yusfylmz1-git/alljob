import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/help/help_faq.dart';

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

  test('her sorunun kategorisi sekme listesinde VAR (sessiz kaybolma yok)', () {
    // Yardım ekranı sekmeleri `kFaqCategories`'ten üretilir ve soruları
    // `category == secilen` ile süzer. Listede olmayan bir kategoriye yazılan
    // soru HİÇBİR sekmede görünmez — hata vermez, sessizce kaybolur.
    // ("Eleman" kategorisi tam olarak böyle kaybolmuştu.)
    for (final f in kFaqItems) {
      expect(
        kFaqCategories,
        contains(f.category),
        reason: '"${f.question}" sorusunun kategorisi (${f.category}) '
            'kFaqCategories listesinde yok → ekranda hiç görünmez',
      );
    }
  });
}

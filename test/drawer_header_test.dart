import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Çekmece başlığı sözleşmesi (2026-08-08).
///
/// Logo bandın ALTINDAN taşar ("askıda" hissi) ve ana sayfaya götürür.
void main() {
  late String src;
  setUpAll(() =>
      src = File('lib/core/widgets/app_menu_drawer.dart').readAsStringSync());

  group('Askıdaki logo', () {
    test('logo büyüdü (104) ve bandın altına taşıyor', () {
      expect(src.contains('_logoBoyut = 104'), isTrue);
      expect(src.contains('_tasma = 26'), isTrue);
      expect(src.contains('bottom: -_tasma'), isTrue);
    });

    test('taşan parça KIRPILMIYOR', () {
      // Clip.none olmazsa logonun alt yarısı görünmez — "askıda" hissi ölür.
      expect(src.contains('clipBehavior: Clip.none'), isTrue);
    });

    test('taşma kadar alt boşluk var (menü satırı binmesin)', () {
      expect(src.contains('12, 12, 12, 8 + _tasma'), isTrue);
    });

    test('gölge ile zeminden ayrılıyor', () {
      expect(src.contains('BoxShadow'), isTrue);
    });

    test('yan menü görselini kullanıyor', () {
      expect(src.contains('variant: BrandLogo.drawer'), isTrue);
    });
  });

  group('Ana sayfa bağlantısı', () {
    test('logo dokunulabilir + erişilebilir', () {
      expect(src.contains('_anaSayfayaGit'), isTrue);
      expect(src.contains("label: 'Ana sayfa'"), isTrue);
    });

    test('go kullanıyor, push DEĞİL', () {
      // push olsaydı geri tuşu kullanıcıyı önceki sekmeye atardı.
      expect(src.contains('context.go(RoutePaths.home)'), isTrue);
      expect(src.contains('context.push(RoutePaths.home)'), isFalse);
    });

    test('önce çekmece kapanıyor', () {
      final i = src.indexOf('void _anaSayfayaGit');
      final govde = src.substring(i, i + 400);
      expect(govde.indexOf('Navigator.pop'),
          lessThan(govde.indexOf('context.go')));
    });

    test('zaten ana sayfadaysa gereksiz geçiş YOK', () {
      expect(src.contains('if (yol == RoutePaths.home) return;'), isTrue);
    });
  });
}

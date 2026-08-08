import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/widgets/brand_mark.dart';

/// Marka görselleri sözleşmesi (2026-08-08).
///
/// Eksik bir varlık `flutter analyze` ile YAKALANMAZ: uygulama içi logo
/// sessizce yedek ikona düşer, launcher ikonu ise üretim komutunda patlar.
/// Bu yüzden dosya varlığı testle bağlanıyor.
void main() {
  group('BrandMark görselleri diskte var', () {
    for (final v in BrandLogo.values) {
      test('${v.name} → ${v.assetPath}', () {
        expect(File(v.assetPath).existsSync(), isTrue,
            reason: '${v.assetPath} yok — BrandMark yedek ikona düşer');
      });
    }

    test('yan menü ayrı görsel kullanıyor', () {
      final drawer = File('lib/core/widgets/app_menu_drawer.dart')
          .readAsStringSync();
      expect(drawer.contains('variant: BrandLogo.drawer'), isTrue);
    });

    test('her varyant FARKLI dosyaya bakıyor', () {
      final yollar = BrandLogo.values.map((v) => v.assetPath).toSet();
      expect(yollar.length, BrandLogo.values.length);
    });
  });

  group('pubspec varlıkları gerçekten var', () {
    late String pubspec;
    setUpAll(() => pubspec = File('pubspec.yaml').readAsStringSync());

    test('launcher ikonu (image_path) diskte', () {
      // pubspec'te tanımlı ama dosya yoksa "dart run flutter_launcher_icons"
      // hata verir; bunu derleme anında değil BURADA görmek isteriz.
      final m = RegExp(r'image_path:\s*(\S+)').firstMatch(pubspec);
      expect(m, isNotNull);
      final yol = m!.group(1)!;
      expect(File(yol).existsSync(), isTrue,
          reason: '$yol pubspec.yaml içinde tanımlı ama diskte YOK');
    });

    test('adaptive foreground diskte', () {
      final m =
          RegExp(r'adaptive_icon_foreground:\s*(\S+)').firstMatch(pubspec);
      expect(m, isNotNull);
      final yol = m!.group(1)!;
      expect(File(yol).existsSync(), isTrue,
          reason: '$yol pubspec.yaml içinde tanımlı ama diskte YOK');
    });
  });
}

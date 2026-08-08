import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/widgets/brand_mark.dart';

/// Marka görselleri sözleşmesi (2026-08-08).
///
/// Eksik bir varlık `flutter analyze` ile YAKALANMAZ: uygulama içi logo
/// sessizce yedek ikona düşer, launcher ikonu ise üretim komutunda patlar.
/// Bu yüzden dosya varlığı testle bağlanıyor.
void main() {
  group('BrandMark görseli diskte var', () {
    test('logo.png duruyor', () {
      expect(File(BrandMark.assetPath).existsSync(), isTrue,
          reason: '${BrandMark.assetPath} yok — BrandMark yedek ikona düşer');
    });

    test('TEK görsel: yan menü de aynı logoyu kullanıyor', () {
      // Bir süre ayrı bir yan_logo.png denendi, görünüm tutmadı.
      // Çekmece başlığı tekrar ana logoya bağlı.
      final drawer =
          File('lib/core/widgets/app_menu_drawer.dart').readAsStringSync();
      expect(drawer.contains('const BrandMark(size: 72)'), isTrue);
      expect(drawer.contains('BrandLogo'), isFalse);
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

  group('Çekmece logosu ana sayfaya götürür', () {
    late String drawer;
    setUpAll(() => drawer =
        File('lib/core/widgets/app_menu_drawer.dart').readAsStringSync());

    test('logo dokunulabilir ve erişilebilir', () {
      expect(drawer.contains('_goHome'), isTrue);
      expect(drawer.contains("label: 'Ana sayfa'"), isTrue);
    });

    test('go kullanıyor, push DEĞİL', () {
      // push olsaydı geri tuşu kullanıcıyı önceki sekmeye atardı.
      expect(drawer.contains('context.go(RoutePaths.home)'), isTrue);
      expect(drawer.contains('context.push(RoutePaths.home)'), isFalse);
    });

    test('rota pop ÖNCESİ okunuyor', () {
      // pop sonrası okumak kapanmış çekmecenin bağlamından okumak olurdu.
      final i = drawer.indexOf('void _goHome');
      final govde = drawer.substring(i, i + 420);
      expect(govde.indexOf('GoRouterState.of'),
          lessThan(govde.indexOf('Navigator.pop')));
    });

    test('zaten ana sayfadaysa gereksiz geçiş YOK', () {
      expect(drawer.contains('if (!zatenAnaSayfa)'), isTrue);
    });
  });
}

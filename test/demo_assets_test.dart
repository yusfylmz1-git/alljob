import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/demo_assets.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/features/storage/storage_repository.dart';

/// Demo görsel yükleyicisi (`demo_assets.dart`).
///
/// Buradaki en kritik doğrulama **handle deseninin eşleşmesi**: görselin
/// yüklendiği anahtar ile personaya yazılan anahtar birebir aynı olmalı.
/// Farklı olurlarsa fotoğraflar yüklenir ama hiçbir ekranda görünmez —
/// sessiz ve fark edilmesi zor bir arıza.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('handle deseni MockDatabase.demoPhoto ile BİREBİR aynı', () {
    for (final name in kDemoAvatarNames) {
      expect(
        demoAssetHandle('avatar', name),
        MockDatabase.demoPhoto('avatar', name),
        reason: 'Yükleme anahtarı ile persona anahtarı farklı → fotoğraf '
            'yüklenir ama ekranda görünmez.',
      );
    }
    expect(demoAssetHandle('work', 'work_tiler_1'),
        MockDatabase.demoPhoto('work', 'work_tiler_1'));
    expect(demoAssetHandle('product', 'prod_1'),
        MockDatabase.demoPhoto('product', 'prod_1'));
  });

  test('handle local:// ile başlar (AppImage yalnız bunu tanır)', () {
    expect(demoAssetHandle('avatar', 'demo_kerem'),
        'local://demo/avatar/demo_kerem');
  });

  test('beklenen dosya sayıları: 10 avatar + 9 iş + 8 ürün', () {
    expect(kDemoAvatarNames, hasLength(10));
    expect(kDemoWorkNames, hasLength(9));
    expect(kDemoProductNames, hasLength(8));
  });

  test('her personanın avatar adı listede var', () {
    final db = MockDatabase(withDemoPersonas: true);
    for (final uid in db.demoUsers.keys) {
      expect(kDemoAvatarNames, contains(uid),
          reason: '$uid için avatar dosya adı tanımlı değil → '
              'NASIL-KULLANILIR.md eksik kalır.');
    }
  });

  group('Gerçek assets/demo/ içeriği', () {
    // Bu testler DİSKTEKİ gerçek dosyalara bakar. Fotoğraflar henüz
    // konmamışsa (ya da yayın öncesi çıkarılmışsa) atlanır — fotoğrafsız
    // çalışmak desteklenen durumdur, testi kırmamalıdır.
    final dir = Directory('assets/demo');

    List<File> imagesIn(String kind) {
      final d = Directory('assets/demo/$kind');
      if (!d.existsSync()) return const [];
      return d
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('.gitkeep'))
          .toList();
    }

    test('konan her görselin uzantısı TANINIYOR', () {
      if (!dir.existsSync()) return;

      // demo_assets.dart içindeki listeyle aynı olmalı.
      const taninan = {
        '.jpg', '.jpeg', '.jfif', '.png', '.webp', //
      };

      final taninmayan = <String>[];
      for (final kind in ['avatar', 'work', 'product']) {
        for (final f in imagesIn(kind)) {
          final name = f.path.split(RegExp(r'[/\\]')).last;
          final dot = name.lastIndexOf('.');
          if (dot < 0) {
            taninmayan.add(name);
            continue;
          }
          if (!taninan.contains(name.substring(dot).toLowerCase())) {
            taninmayan.add(name);
          }
        }
      }

      expect(taninmayan, isEmpty,
          reason: 'Bu dosyalar sessizce atlanır ve ekranda görünmez. '
              'Çözüm: demo_assets.dart içindeki _kImageExtensions listesine '
              'uzantıyı ekleyin ya da dosyayı .jpg olarak kaydedin.');
    });

    test('konan her görselin adı beklenen listede', () {
      if (!dir.existsSync()) return;

      String stem(File f) {
        final name = f.path.split(RegExp(r'[/\\]')).last;
        final dot = name.lastIndexOf('.');
        return dot < 0 ? name : name.substring(0, dot);
      }

      for (final entry in {
        'avatar': kDemoAvatarNames,
        'work': kDemoWorkNames,
        'product': kDemoProductNames,
      }.entries) {
        for (final f in imagesIn(entry.key)) {
          expect(entry.value, contains(stem(f)),
              reason: '${f.path} beklenen adlar arasında değil → yüklenmez. '
                  'Doğru adlar: assets/demo/NASIL-KULLANILIR.md');
        }
      }
    });

    test('görseller aşırı büyük değil (açılış yavaşlamasın)', () {
      if (!dir.existsSync()) return;

      const limitMb = 5;
      final buyukler = <String>[];
      for (final kind in ['avatar', 'work', 'product']) {
        for (final f in imagesIn(kind)) {
          final mb = f.lengthSync() / (1024 * 1024);
          if (mb > limitMb) {
            buyukler.add('${f.path} (${mb.toStringAsFixed(1)} MB)');
          }
        }
      }

      expect(buyukler, isEmpty,
          reason: '$limitMb MB üstü görseller açılışı yavaşlatır. '
              'Küçültmek görüntü kalitesini düşürmez (ekranda zaten '
              'küçültülerek çiziliyor).');
    });
  });

  test('görsel varsa depoya doğru handle ile yazılır', () async {
    // rootBundle'ı sahte bir görselle besle → gerçek dosya gerekmez.
    const path = 'assets/demo/avatar/demo_kerem.jpg';
    final fakeJpeg = Uint8List.fromList(List.filled(64, 7));

    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = const StringCodec().decodeMessage(message);
        if (key == path) return fakeJpeg.buffer.asByteData();
        if (key == 'AssetManifest.bin') return null;
        return null;
      },
    );
    addTearDown(() => binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));

    final storage = MockStorageRepository();
    await storage.uploadBytes(
      path: 'demo/avatar/demo_kerem',
      bytes: fakeJpeg,
      contentType: 'image/jpeg',
    );

    // uploadBytes handle'ı `local://$path` olarak birebir üretir.
    expect(storage.localBytes('local://demo/avatar/demo_kerem'), isNotNull);
    expect(
      storage.localBytes(MockDatabase.demoPhoto('avatar', 'demo_kerem')),
      isNotNull,
      reason: 'Personanın beklediği anahtarla okunabilmeli.',
    );
  });
}

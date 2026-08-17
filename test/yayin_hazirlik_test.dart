import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// YAYIN MUHAFIZLARI — mağaza ekran görüntüsü çalışmasının yayına sızmasını
/// engeller.
///
/// Demo seti çekilirken iki geçici değişiklik yapılır:
///   1. `backend_config.dart` → `useFirebaseBackend = false` (mock modu)
///   2. `pubspec.yaml` → `assets/demo/` kayıtları (27 fotoğraf)
///
/// İkisi de yayına çıkarsa ağır sonuç doğurur; bu testler `flutter test`
/// her koşuşunda uyarır. Ayrıntı: `vault/06-Test/Demo-Veri-Seti.md`.
void main() {
  group('Yayın hazırlığı muhafızları', () {
    test('backend_config yayın modunda (mock modu commit edilmemiş)', () {
      final src =
          File('lib/core/config/backend_config.dart').readAsStringSync();

      expect(
        src.contains('const bool useFirebaseBackend = true'),
        isTrue,
        reason: 'MOCK MODU AÇIK KALMIŞ. Bu hâliyle yayınlanan sürümde her '
            'kullanıcı bellek içi sahte veriye düşer: giriş yapamaz, verileri '
            'kaybolmuş görünür, uygulama kapanınca her şey silinir. '
            'Düzeltme: backend_config.dart içinde useFirebaseBackend = true.',
      );

      expect(
        src.contains('const bool useFirebaseStorage = true'),
        isTrue,
        reason: 'Storage mock\'ta kalmış: yüklenen fotoğraflar kalıcı olmaz.',
      );
    });

    test('demo görselleri pubspec\'e kayıtlı DEĞİL (APK şişmesin)', () {
      final src = File('pubspec.yaml').readAsStringSync();

      // Yorum satırlarını ele — açıklama metni eşleşmesin, yalnız gerçek kayıt.
      final assetLines = src
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('- assets/'))
          .toList();

      expect(
        assetLines.any((l) => l.contains('assets/demo/')),
        isFalse,
        reason: 'Demo görselleri (~5 MB) yayın paketine giriyor. '
            'Düzeltme: pubspec.yaml içindeki "- assets/demo/..." satırlarını '
            'silin. Görseller yerelde kalır, ekran görüntüsü çekerken '
            'geri eklenir.',
      );
    });

    test('demo görselleri repoya commit edilmiyor', () {
      final src = File('.gitignore').readAsStringSync();

      expect(src.contains('assets/demo/'), isTrue,
          reason: 'Demo fotoğrafları .gitignore\'da olmalı; telifli görsel '
              'repoya girmemeli.');
    });
  });
}

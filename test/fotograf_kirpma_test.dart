import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/core/constants/app_constants.dart';

/// Fotoğraf kırpma altyapısı (2026-08-14 cihaz bulgusu).
///
/// BELİRTİ: "resimler eklendiğinde bazen yarım çıkıyor", "profil fotoğrafı
/// yayık görünüyor".
///
/// KÖK NEDEN: kırpma adımı YOKTU. Kullanıcı hangi oranda fotoğraf seçerse
/// seçsin, kart `AspectRatio` + `BoxFit.cover` ile onu zorla çerçeveye
/// sığdırıyordu — dikey fotoğrafın altı/üstü kesiliyordu.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Kırpma altyapısı var', () {
    test('image_cropper bağımlılığı eklendi', () {
      expect(read('pubspec.yaml').contains('image_cropper'), isTrue);
    });

    test('Android manifest UCropActivity kaydı içeriyor', () {
      // Kayıt olmadan kırpıcı ActivityNotFoundException verir ve fotoğraf
      // kırpılmadan yüklenir — hata sessizce geri döner.
      final m = read('android/app/src/main/AndroidManifest.xml');
      expect(m.contains('com.yalantis.ucrop.UCropActivity'), isTrue);
    });

    test('ortak PhotoPicker servisi tek giriş noktası', () {
      final p = read('lib/core/utils/photo_picker.dart');
      expect(p.contains('class PhotoPicker'), isTrue);
      expect(p.contains('pickPhoto'), isTrue);
      expect(p.contains('pickMultiPhoto'), isTrue);
      // Üç şekil: profil / ürün-ilan / belge.
      expect(p.contains('enum PhotoShape'), isTrue);
      for (final s in ['square', 'portrait', 'free']) {
        expect(p.contains(s), isTrue, reason: '$s şekli tanımsız.');
      }
    });

    test('kırpma iptal edilse bile fotoğraf kaybolmuyor', () {
      // Kullanıcı kırpmayı iptal ederse seçimi boşa düşürmek sinir bozucu
      // olurdu — ham hâliyle devam edilir.
      final p = read('lib/core/utils/photo_picker.dart');
      expect(p.contains('if (cropped == null) return picked.readAsBytes()'),
          isTrue);
    });
  });

  group('Fotoğraf yükleyen TÜM ekranlar kırpmadan geçiyor', () {
    // Bir ekran doğrudan `ImagePicker().pickImage` çağırırsa kırpma atlanır
    // ve "yarım çıkma" hatası o ekranda geri döner.
    const ekranlar = [
      'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      'lib/features/products/presentation/product_edit_screen.dart',
      'lib/features/jobs/presentation/create_job_screen.dart',
      'lib/features/profile/presentation/profile_screen.dart',
    ];

    for (final yol in ekranlar) {
      final ad = yol.split('/').last;
      test('$ad PhotoPicker kullanıyor', () {
        expect(read(yol).contains('PhotoPicker.'), isTrue,
            reason: '$ad kırpmayı atlıyor — fotoğraf yarım çıkar.');
      });
    }

    test('profil fotoğrafı 1:1 KİLİTLİ', () {
      // Avatar her yerde yuvarlak çizilir; kare olmayan kaynak "yayık"
      // görünüyordu.
      final e = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(e.contains('PhotoShape.square'), isTrue,
          reason: 'Profil fotoğrafı kare kırpılmıyor — avatar yayık görünür.');
    });

    test('sertifika/belge SERBEST kırpma', () {
      // Zorunlu oran belgenin metnini keser.
      final e = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(e.contains('PhotoShape.free'), isTrue,
          reason: 'Belgeye zorunlu oran dayatılıyor — metin kesilir.');
    });
  });

  group('Kart oranı ile kırpma oranı AYNI', () {
    // En kritik kural: kırpma 4:5 ama kart 1.15 ise kırpma HİÇBİR ŞEY
    // çözmez — kart yine kesip atar.
    test('sabitler tanımlı ve dikey (4:5)', () {
      expect(AppConstants.photoAspectWidth, 4);
      expect(AppConstants.photoAspectHeight, 5);
      // Dikey olmalı: genişlik < yükseklik.
      expect(
        AppConstants.photoAspectWidth < AppConstants.photoAspectHeight,
        isTrue,
      );
    });

    test('ürün kartı sabitten okuyor (sabit sayı DEĞİL)', () {
      final c =
          read('lib/features/products/presentation/widgets/product_card.dart');
      expect(c.contains('AppConstants.photoAspectWidth'), isTrue,
          reason: 'Kart oranı elle yazılmış — kırpma oranıyla ayrışır.');
      expect(c.contains('aspectRatio: 1.15'), isFalse,
          reason: 'Eski yatay oran geri gelmiş.');
    });

    test('ürün ızgaraları kart oranına uyuyor', () {
      for (final yol in [
        'lib/features/products/presentation/artisan_products_screen.dart',
        'lib/features/products/presentation/widgets/products_explore_panel.dart',
      ]) {
        expect(read(yol).contains('AppConstants.photoCardAspectRatio'), isTrue,
            reason: '$yol eski oranda — kart içeriği taşar.');
      }
    });
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/constants/app_constants.dart';
import 'package:sepette_hizmet/core/widgets/job_thumb.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart'
    show kProfessionNames;

/// Ana sayfa düzeni + marka adı sözleşmesi (2026-08-08).
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Marka adı: İlanda Hizmet', () {
    test('appName güncellendi', () {
      expect(AppConstants.appName, 'İlanda Hizmet');
    });

    test('kullanıcıya görünen metinlerde "Sepette Hizmet" kalmadı', () {
      // billing_config'teki tek geçiş, ürün kimliğinin neden eski adında
      // kaldığını anlatan TARİHSEL yorumdur — bilerek duruyor.
      const izinli = 'billing_config.dart';
      final kalan = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith(izinli)) continue;
        if (f.readAsStringSync().contains('Sepette Hizmet')) {
          kalan.add(f.path);
        }
      }
      expect(kalan, isEmpty, reason: 'eski marka adı kaldı: $kalan');
    });

    test('Android/iOS uygulama etiketi güncellendi', () {
      expect(
        read('android/app/src/main/AndroidManifest.xml')
            .contains('android:label="İlanda Hizmet"'),
        isTrue,
      );
      expect(
        read('ios/Runner/Info.plist').contains('<string>İlanda Hizmet</string>'),
        isTrue,
      );
    });

    test('SATIN ALMA kimliği paket adıyla hizalı (CLAUDE.md sabiti)', () {
      // Play/App Store kaydı yokken usta_cepte_* → sepette_hizmet_* çekildi.
      // Console'da ürün açıldıktan sonra bu kimlik kilitlenir.
      expect(
        read('lib/features/membership/billing_config.dart')
            .contains("kProMonthlyProductId = 'sepette_hizmet_pro_monthly'"),
        isTrue,
      );
    });
  });

  group('Bölüm sırası', () {
    test('ustalar → ilanlar → hemen lazım → keşif', () {
      final s = read('lib/features/home/presentation/home_screen.dart');
      final featured = s.indexOf('HomeFeatured()');
      final quick = s.indexOf('HomeQuickSupport()');
      final discover = s.indexOf('HomeDiscover()');
      final access = s.indexOf('HomeQuickAccess()');

      expect(access, lessThan(featured), reason: 'aksiyonlar en üstte');
      expect(featured, lessThan(quick),
          reason: 'Öne Çıkan Ustalar + Son İlanlar, Hemen Lazım ÖNCESİ');
      expect(quick, lessThan(discover));
    });

    test('HomeFeatured içinde ustalar → ürünler → ilanlar', () {
      final s =
          read('lib/features/home/presentation/widgets/home_featured.dart');
      expect(s.indexOf("'Öne Çıkan Ustalar'"),
          lessThan(s.indexOf("'Son Paylaşılan Ürünler'")));
      expect(s.indexOf("'Son Paylaşılan Ürünler'"),
          lessThan(s.indexOf("'Son İş İlanları'")));
    });
  });

  group('Usta Bul kartı', () {
    late String s;
    setUpAll(() => s = read(
        'lib/features/home/presentation/widgets/home_quick_access.dart'));

    test('çekiç süsü kaldırıldı', () {
      expect(s.contains('Icons.handyman_rounded'), isFalse);
      expect(s.contains('size: 104'), isFalse);
    });

    test('düğme SAĞDA (Row düzeni) — dikey yığın değil', () {
      expect(s.contains('child: Row('), isTrue);
      // Başlık artık tek satır: elle satır kırma kalktı.
      expect(s.contains(r'İhtiyacın olan\nustayı bul.'), isFalse);
    });

    test('İş İlanı Ver altında ürün talebi var', () {
      final ilan = s.indexOf("'İş İlanı Ver'");
      final talep = s.indexOf("'Mağaza İçin Ürün Talebi Oluştur'");
      expect(ilan, greaterThan(-1));
      expect(talep, greaterThan(ilan));
      expect(s.contains('newProductRequestJob'), isTrue);
    });
  });

  group('İlan kartları dar + görselli', () {
    test('Son İş İlanları JobThumb kullanıyor', () {
      final s =
          read('lib/features/home/presentation/widgets/home_featured.dart');
      expect(s.contains('JobThumb('), isTrue);
      expect(s.contains('photos: is_.photos'), isTrue);
    });

    test('Hemen Lazım JobThumb kullanıyor', () {
      final s =
          read('lib/features/home/presentation/widgets/home_quick_support.dart');
      expect(s.contains('JobThumb('), isTrue);
      expect(s.contains('photos: job.photos'), isTrue);
    });

    test('iki şerit AYNI yükseklikte (92)', () {
      final f =
          read('lib/features/home/presentation/widgets/home_featured.dart');
      final q =
          read('lib/features/home/presentation/widgets/home_quick_support.dart');
      expect(f.contains('tall ? 288 : 92'), isTrue);
      expect(q.contains('height: 92'), isTrue);
    });
  });

  group('JobThumb: fotoğraf yoksa meslek ikonu', () {
    testWidgets('fotoğraf YOKSA ikon çizilir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: JobThumb(photos: [], category: 'plumber'),
        ),
      ));
      expect(find.byIcon(Icons.plumbing_rounded), findsOneWidget);
    });

    testWidgets('BOŞ dize fotoğraf sayılmaz', (tester) async {
      // Eski kayıtlarda photos: [''] gelebiliyor — kırık görsel çizilmemeli.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: JobThumb(photos: ['', '  '], category: 'electrician'),
        ),
      ));
      expect(find.byIcon(Icons.electrical_services_rounded), findsOneWidget);
    });

    test('her meslek kodu bir görsel alır (çökme yok)', () {
      for (final kod in kProfessionNames.keys) {
        final v = jobVisualFor(kod);
        expect(v.icon, isNotNull, reason: kod);
      }
    });

    test('bilinmeyen kod nötr ikona düşer', () {
      expect(jobVisualFor('boyle_bir_meslek_yok').icon,
          Icons.handyman_rounded);
    });

    test('ön ek eşleşmesi çalışıyor (yeni meslek eklenirse)', () {
      // professions.json'a 'auto_kaporta' eklenirse araç grubuna düşmeli.
      expect(jobVisualFor('auto_yeni_bir_sey').color,
          jobVisualFor('auto_body').color);
    });

    test('Hemen Lazım kategorisi acil rengini alır', () {
      expect(jobVisualFor('quick_support').icon, Icons.bolt_rounded);
      expect(jobVisualFor('other').icon, Icons.bolt_rounded);
    });
  });
}

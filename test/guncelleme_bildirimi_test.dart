// Regresyon: yeni sürüm çıkınca menüde uyarı görünür (2026-08-23).
//
// Kapalı test geri bildirimi: "güncelleme bildirimi yok — yeni güncel
// version varsa 3 çizgi menüde görünmesi lazım." Eski APK'da kalan
// testçiler zaten düzeltilmiş hataları yeniden bildiriyordu.
//
// Tasarım: sunucudaki `config/app` dokümanı (`latestVersion`,
// `minSupportedVersion`, `updateUrl`, `updateNote`) çalışan sürümle
// karşılaştırılır. Doküman herkese açık okunur, İSTEMCİYE KAPALI yazılır.
//
// Çift test (kural 7): uyarı çıkıyor MU + fazlasını yapmıyor MU.
// "Fazlası" = güncel kullanıcıyı rahatsız etmek ya da sunucu susunca
// yanlış uyarı vermek.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/constants/app_constants.dart';
import 'package:sepette_hizmet/data/models/app_version_info.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  AppVersionInfo info(String latest, {String? min}) =>
      AppVersionInfo(latestVersion: latest, minSupportedVersion: min);

  group('Sürüm sabiti pubspec ile SENKRON', () {
    test('AppConstants.appVersion == pubspec version', () {
      // `package_info_plus` eklemek yerine sabit tutuldu; senkron riskini
      // kapatan tek şey bu testtir. Sürüm yükseltip burayı unutan biri
      // kullanıcılara "güncelleme var" derken aslında güncel sürümü
      // gösteriyor olurdu.
      final pubspec = read('pubspec.yaml');
      final satir = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(pubspec);
      expect(satir, isNotNull, reason: 'pubspec.yaml içinde version yok.');

      final tam = satir!.group(1)!; // örn. 1.2.0+6
      final ad = tam.split('+').first;

      expect(AppConstants.appVersion, ad,
          reason: 'pubspec sürümü $ad ama AppConstants.appVersion '
              '${AppConstants.appVersion}. İKİSİNİ BİRDEN güncelleyin.');
    });
  });

  group('Sürüm karşılaştırma sayısaldır', () {
    test('1.10.0 > 1.9.0 (alfabetik tuzağı)', () {
      // Dize karşılaştırmasıyla '1.10.0' < '1.9.0' çıkardı ve 1.10.0'daki
      // kullanıcı sonsuza dek "güncelleme var" uyarısı görürdü.
      expect(compareVersions('1.10.0', '1.9.0') > 0, isTrue);
      expect(compareVersions('1.9.0', '1.10.0') < 0, isTrue);
    });

    test('eşit sürümler 0 döner', () {
      expect(compareVersions('1.2.0', '1.2.0'), 0);
    });

    test('eksik parça 0 sayılır: 1.2 == 1.2.0', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
    });

    test('build numarası (+6) yok sayılır', () {
      // Play'de artan ama kullanıcıya görünmeyen sayı; sürüm farkı değil.
      expect(compareVersions('1.2.0+6', '1.2.0+99'), 0);
    });

    test('baştaki v kabul edilir', () {
      expect(compareVersions('v1.3.0', '1.3.0'), 0);
    });

    test('bozuk değer ÇÖKMEZ', () {
      // Sunucuya elle yanlış değer yazılırsa uygulama düşmemeli.
      expect(() => compareVersions('abc', '1.0.0'), returnsNormally);
      expect(() => compareVersions('', ''), returnsNormally);
    });
  });

  group('Güncelleme durumu', () {
    test('yeni sürüm varsa uyarı ÇIKAR', () {
      expect(info('1.3.0').statusFor('1.2.0'), UpdateStatus.available);
    });

    test('minSupportedVersion altındaysa ZORUNLU', () {
      final s = info('1.3.0', min: '1.2.0').statusFor('1.1.0');
      expect(s, UpdateStatus.zorunlu);
      expect(s.isRequired, isTrue);
    });

    test('zorunlu sınırın TAM ÜSTÜ zorunlu değil', () {
      // `<` sınırı: minSupported'a eşit sürüm hâlâ desteklenir.
      expect(info('1.3.0', min: '1.2.0').statusFor('1.2.0'),
          UpdateStatus.available);
    });
  });

  group('Fazlasını yapmıyor — yanlış uyarı vermiyor', () {
    test('güncel kullanıcıya uyarı YOK', () {
      final s = info('1.2.0').statusFor('1.2.0');
      expect(s, UpdateStatus.upToDate);
      expect(s.hasUpdate, isFalse,
          reason: 'Güncel kullanıcıya her açılışta satır göstermek menüyü '
              'şişirir ve gerçek uyarı fark edilmez.');
    });

    test('kullanıcı sunucudan İLERİDEYSE uyarı YOK', () {
      // Beta/dahili derleme mağazadakinden yeni olabilir.
      expect(info('1.2.0').statusFor('1.5.0'), UpdateStatus.upToDate);
    });

    test('sunucu BOŞ değer yazdıysa uyarı YOK', () {
      // Doküman oluşturulmuş ama alan doldurulmamış olabilir; "0.0.0'a
      // güncelleyin" demek kullanıcıyı olmayan sürümü aramaya yollar.
      expect(info('').statusFor('1.2.0'), UpdateStatus.upToDate);
      expect(info('0.0.0').statusFor('1.2.0'), UpdateStatus.upToDate);
    });

    test('minSupportedVersion yoksa kimse ZORLANMAZ', () {
      expect(info('9.9.9').statusFor('1.0.0'), UpdateStatus.available,
          reason: 'Güvenli varsayılan: alan boşken zorunlu güncelleme yok.');
    });
  });

  group('Sunucu bilgisi yoksa sessiz kalır', () {
    test('provider hatayı YUTUYOR', () {
      final p = read('lib/core/update/app_update_providers.dart');
      expect(p.contains('catch (_)'), isTrue,
          reason: 'Ağ/kural hatası uygulamayı düşürmemeli — güncelleme '
              'bildirimi yardımcı bir özelliktir.');
      expect(p.contains('return UpdateStatus.upToDate;'), isTrue,
          reason: 'Bilgi yokken varsayılan "güncel" olmalı, "güncelle" değil.');
    });
  });

  group('Menüde görünürlük', () {
    late String drawer;
    setUpAll(() => drawer = read('lib/core/widgets/app_menu_drawer.dart'));

    test('çekmecede güncelleme satırı var', () {
      expect(drawer.contains('_UpdateTile'), isTrue);
    });

    test('güncelken satır HİÇ çizilmiyor', () {
      expect(
          drawer.contains(
              'if (!status.hasUpdate) return const SizedBox.shrink();'),
          isTrue,
          reason: 'Güncel kullanıcıya boş satır göstermek menüyü şişirir.');
    });

    test('hamburger ikonunda rozet yanıyor', () {
      // Satır ancak çekmece AÇILINCA görünür; kullanıcının bakması için
      // bir sebep gerekir.
      expect(drawer.contains('crossUnread > 0 || guncelleme'), isTrue,
          reason: 'Menü rozeti güncellemeyi yansıtmıyor — kullanıcı '
              'çekmeceyi açmadan haberdar olamaz.');
    });

    test('mağaza bağlantısı yoksa siteye düşülüyor', () {
      expect(drawer.contains('AppConstants.siteUrl'), isTrue,
          reason: 'updateUrl boşken düğme hiçbir yere gitmemeli değil — '
              'kullanıcı yine de güncel sürüme ulaşabilmeli.');
    });
  });

  group('Güvenlik: sürüm bilgisi istemciden YAZILAMAZ', () {
    late String rules;
    setUpAll(() => rules = read('firestore.rules'));

    test('config koleksiyonu okumaya açık, yazmaya KAPALI', () {
      final blok = RegExp(
        r'match /config/\{docId\} \{(.*?)\}',
        dotAll: true,
      ).firstMatch(rules);
      expect(blok, isNotNull, reason: 'config kuralı tanımlı değil.');

      final govde = blok!.group(1)!;
      expect(govde.contains('allow read: if true;'), isTrue,
          reason: 'Misafir de güncelleme uyarısını görebilmeli.');
      expect(govde.contains('allow write: if false;'), isTrue,
          reason: 'Buraya yazabilen biri minSupportedVersion ile herkesi '
              'kilitleyebilir veya updateUrl ile sahte APK dağıtabilir.');
    });
  });
}

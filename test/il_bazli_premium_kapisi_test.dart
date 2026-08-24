// Regresyon: premium kapısı İL FARKINDA (2026-08-23).
//
// Şehir bazlı Pro geçişi: bir il ücretli döneme geçtiğinde YALNIZ o ildeki
// aboneliksiz kullanıcıların müsaitliği düşer. Diğer iller beta'da kalır.
//
// Eskiden `premiumFreeDuringBeta` tek bir bool'du: ya herkes ücretsiz ya
// kimse. Şehir şehir geçiş bu yapıyla imkânsızdı.
//
// Çift test (kural 7): ücretli il kapanıyor MU + diğer iller ETKİLENMİYOR MU.
// İkincisi kritik — tek bir yanlış il adı yüzünden ülke genelinde müsaitlik
// kapanırsa geri dönüşü zor bir itibar kaybı olur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/config/app_runtime_config.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Ücretli il kapıyı kapatır', () {
    test('ücretli ildeki kullanıcı ücretsiz DEĞİL', () {
      expect(
        premiumFreeForUser(
          userProvinces: const ['Bursa'],
          premiumFreeDuringBeta: true,
          paidProvinces: const ['Bursa'],
        ),
        isFalse,
      );
    });

    test('çok illi eski kayıtta BİR il yeterli', () {
      // Tek il kuralı öncesi kayıtlar çok illi olabilir; illerden biri
      // ücretliyse abonelik başlar.
      expect(
        premiumFreeForUser(
          userProvinces: const ['Balıkesir', 'Bursa'],
          premiumFreeDuringBeta: true,
          paidProvinces: const ['Bursa'],
        ),
        isFalse,
      );
    });

    test('büyük/küçük harf ve boşluk kapıyı ATLATMIYOR', () {
      // Admin panelinden " bursa" yazılması yüzünden geçiş sessizce
      // çalışmamamalı.
      for (final yazim in [' bursa', 'BURSA', 'Bursa ', 'bUrSa']) {
        expect(
          premiumFreeForUser(
            userProvinces: const ['Bursa'],
            premiumFreeDuringBeta: true,
            paidProvinces: [yazim],
          ),
          isFalse,
          reason: '"$yazim" yazımı kapıyı atlattı.',
        );
      }
    });
  });

  group('Fazlasını yapmıyor — diğer iller ETKİLENMİYOR', () {
    test('başka ildeki kullanıcı ücretsiz KALIR', () {
      expect(
        premiumFreeForUser(
          userProvinces: const ['Balıkesir'],
          premiumFreeDuringBeta: true,
          paidProvinces: const ['Bursa'],
        ),
        isTrue,
        reason: 'Bursa geçince Balıkesirli usta da kapanırsa ülke genelinde '
            'müsaitlik düşer.',
      );
    });

    test('liste BOŞKEN davranış eskisiyle BİREBİR aynı', () {
      // Değişikliğin en önemli güvencesi: bugün hiçbir şey değişmemeli.
      expect(
        premiumFreeForUser(
          userProvinces: const ['Bursa'],
          premiumFreeDuringBeta: true,
        ),
        isTrue,
      );
      expect(
        premiumFreeForUser(
          userProvinces: const ['Bursa'],
          premiumFreeDuringBeta: false,
        ),
        isFalse,
      );
    });

    test('BÖLGESİZ kullanıcı ücretliye alınmaz', () {
      // Hangi ile ait olduğu bilinmiyor; ücretliye almak yanlış olurdu.
      expect(
        premiumFreeForUser(
          userProvinces: const [],
          premiumFreeDuringBeta: true,
          paidProvinces: const ['Bursa'],
        ),
        isTrue,
      );
    });

    test('beta bayrağı KAPALIYSA il listesi fark etmez', () {
      // Ülke geneli kapanış hâlâ mümkün olmalı — eski davranış korunuyor.
      expect(
        premiumFreeForUser(
          userProvinces: const ['Balıkesir'],
          premiumFreeDuringBeta: false,
          paidProvinces: const ['Bursa'],
        ),
        isFalse,
      );
    });
  });

  group('Yapılandırma güvenli okunuyor', () {
    test('bozuk paidProvinces BOŞ listeye düşer', () {
      // Yanlış tipte bir değer yüzünden kimsenin müsaitliği kapanmamalı.
      final cfg = AppRuntimeConfig.fromMap({'paidProvinces': 'Bursa'});
      expect(cfg.paidProvinces, isEmpty);
    });

    test('boş dizeler ayıklanıyor', () {
      final cfg = AppRuntimeConfig.fromMap({
        'paidProvinces': ['Bursa', '', '  ', 'Ankara'],
      });
      expect(cfg.paidProvinces, ['Bursa', 'Ankara']);
    });

    test('alan hiç yoksa boş liste', () {
      expect(AppRuntimeConfig.fromMap({}).paidProvinces, isEmpty);
      expect(const AppRuntimeConfig().paidProvinces, isEmpty);
    });
  });

  group('Kapı TEK yerden okunuyor', () {
    test('müsaitlik provider\'ı merkezi kapıyı kullanıyor', () {
      // Eskiden `profile.isAvailable` çağrılıyordu ve o getter YEREL sabiti
      // okuyordu — remote yapılandırmayı hiç görmüyordu. Şehir geçişinde
      // sessiz bir delik olurdu.
      final jp = read('lib/features/jobs/data/job_providers.dart');
      expect(jp.contains('premiumFreeDuringBeta: ref.watch(premiumFreeForMeProvider)'),
          isTrue,
          reason: 'Müsaitlik provider\'ı yerel sabite geri dönmüş.');
    });

    test('arama ve ana sayfa AYNI listeyi geçiyor', () {
      // Biri geçirip diğeri geçirmezse usta aramada gizlenir ama ana
      // sayfada öne çıkmaya devam ederdi.
      final arama =
          read('lib/features/customer/application/artisan_search_controller.dart');
      final home = read('lib/features/home/presentation/widgets/home_featured.dart');
      expect(arama.contains('paidProvinces: _paidProvinces'), isTrue);
      expect(home.contains('paidProvinces: cfg?.paidProvinces'), isTrue);
    });

    test('her usta KENDİ iliyle değerlendiriliyor', () {
      // Arama sonucunda tek bir bool yetmez: Bursa ücretliyken Balıkesirli
      // usta hâlâ listede görünmeli.
      for (final yol in [
        'lib/features/artisan/data/firebase_artisan_repository.dart',
        'lib/features/artisan/data/mock_artisan_repository.dart',
      ]) {
        expect(read(yol).contains('userProvinces: p.serviceAreas'), isTrue,
            reason: '$yol her ustayı kendi iliyle değerlendirmiyor.');
      }
    });
  });

  group('Geçiş GERİ ALINABİLİR', () {
    test('kapı hiçbir veri YAZMIYOR', () {
      // İl listeden çıkınca herkes eski hâline dönmeli; kapı yazsaydı
      // dönüş için toplu işlem gerekirdi.
      final kaynak = read('lib/core/config/app_runtime_config.dart');
      final blok = RegExp(
        r'bool premiumFreeForUser\(\{(.*?)\n\}',
        dotAll: true,
      ).firstMatch(kaynak);
      expect(blok, isNotNull);
      final govde = blok!.group(1)!;
      expect(govde.contains('set('), isFalse);
      expect(govde.contains('update('), isFalse);
      expect(govde.contains('await'), isFalse,
          reason: 'Kapı saf bir fonksiyon olmalı — yan etkisiz.');
    });

    test('admin ekranı geri alınabilirliği SÖYLÜYOR', () {
      final ekran =
          read('lib/features/admin/presentation/admin_settings_screen.dart');
      expect(ekran.contains('Hiçbir veri değişmez'), isTrue,
          reason: 'Yönetici geçişin geri alınabilir olduğunu bilmeli.');
    });
  });

  group('Sunucu allowlistinde — SESSİZ başarısızlık yok', () {
    late String js;
    setUpAll(() => js = read('functions/index.js'));

    test('adminUpdateConfig paidProvinces YAZIYOR', () {
      // Bu testin varlık sebebi gerçek bir açık: alan allowlist'e
      // eklenmeden admin ekranından il eklemek SESSİZCE çalışmıyordu.
      // `adminUpdateConfig` yalnız izin verilen alanları yazar, gerisini
      // yok sayar — yönetici geçişi yaptığını sanıyor, sunucuda hiçbir şey
      // değişmiyordu.
      expect(js.contains('Array.isArray(patch.paidProvinces)'), isTrue,
          reason: 'paidProvinces allowlist dışında kalmış — admin ekranı '
              'çalışıyor görünür ama sunucu yok sayar.');
      expect(js.contains('next.paidProvinces = tekil;'), isTrue);
    });

    test('liste tekilleştiriliyor ve sınırlı', () {
      // Aynı il iki kez eklenirse liste şişmesin; 81'den fazlası yazım
      // hatası ya da kötüye kullanım demektir.
      expect(js.contains('new Set(iller)'), isTrue);
      expect(js.contains('tekil.length > 81'), isTrue);
    });

    test('ilk yazımda güvenli varsayılan', () {
      // Seed'de olmazsa ilk config yazımından sonra alan hiç doğmaz.
      expect(js.contains('paidProvinces: [],'), isTrue);
    });
  });
}

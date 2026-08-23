// Regresyon: usta / mağaza YALNIZ TEK İLDE hizmet verir (2026-08-23).
//
// Kullanıcı kararı: "biz istediğimiz kadar il seçimi yapabiliyoruz usta
// profilinde. bunu engelleyelim. yalnızca tek il seçimi olsun. mağaza
// sahiplerinin hizmet bölgesi belli olsun diye sadece bunu yapıyoruz."
//
// İKİ GEREKÇE:
//  1. Sınırsız il seçen usta "her yere giderim" diyordu ama gerçekte
//     gitmiyordu; müşteri cevapsız kalıyordu.
//  2. Şehir bazlı Pro geçişini delerdi — bir il ücretliyken usta yanına
//     komşu il ekleyip kapıdan kaçmayı öğrenirdi.
//
// Çift test (kural 7): ikinci il ENGELLENİYOR MU + aynı ilin ilçeleri
// hâlâ EKLENEBİLİYOR MU. İkincisi kritik: kural, ustayı tek ilçeye
// hapsetmemeli.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  const bursaOsmangazi = ServiceArea(province: 'Bursa', district: 'Osmangazi');
  const bursaNilufer = ServiceArea(province: 'Bursa', district: 'Nilüfer');
  const bursaYildirim = ServiceArea(province: 'Bursa', district: 'Yıldırım');
  const balikesirEdremit =
      ServiceArea(province: 'Balıkesir', district: 'Edremit');

  group('singleProvince — listenin ili', () {
    test('tek illi listede o ili döndürür', () {
      expect([bursaOsmangazi, bursaNilufer].singleProvince, 'Bursa');
    });

    test('boş listede null', () {
      expect(<ServiceArea>[].singleProvince, isNull);
    });

    test('çok illi ESKİ kayıtta İLK il döner', () {
      // Keyfi değil: kullanıcının ilk seçtiği ildir ve kaydederken
      // korunacak olan odur.
      expect([bursaOsmangazi, balikesirEdremit].singleProvince, 'Bursa');
    });
  });

  group('onlySingleProvince — kayıt anında normalleştirme', () {
    test('çok illi eski kayıt tek ile iner', () {
      final sonuc =
          [bursaOsmangazi, balikesirEdremit, bursaNilufer].onlySingleProvince;
      expect(sonuc, [bursaOsmangazi, bursaNilufer]);
    });

    test('tek illi listeye DOKUNMUYOR (kimlik)', () {
      // Boşuna kopya üretmemeli — sıcak yol bu.
      final liste = [bursaOsmangazi, bursaNilufer];
      expect(identical(liste.onlySingleProvince, liste), isTrue);
    });

    test('boş liste çökmüyor', () {
      expect(<ServiceArea>[].onlySingleProvince, isEmpty);
    });
  });

  group('Fazlasını yapmıyor — aynı ilin ilçeleri serbest', () {
    test('üç ilçe birden korunuyor', () {
      // Kural ustayı tek İLÇEYE hapsetmemeli; sınır İL düzeyinde.
      final liste = [bursaOsmangazi, bursaNilufer, bursaYildirim];
      expect(liste.onlySingleProvince.length, 3);
      expect(liste.hasMultipleProvinces, isFalse);
    });

    test('çok illi kayıt tespit ediliyor', () {
      expect([bursaOsmangazi, balikesirEdremit].hasMultipleProvinces, isTrue);
    });

    test('tek bölgeli listede çok il YOK', () {
      expect([bursaOsmangazi].hasMultipleProvinces, isFalse);
    });
  });

  group('Controller kapıyı uyguluyor', () {
    late String ctrl;
    setUpAll(() => ctrl = read(
        'lib/features/artisan/application/my_profile_controller.dart'));

    test('addServiceArea başka ili REDDEDİYOR', () {
      expect(ctrl.contains("if (il != null && area.province.trim() != il)"),
          isTrue,
          reason: 'Kapı yok — usta ikinci ili ekleyebilir.');
    });

    test('il değiştirme AYRI metot', () {
      // Ayrı olmasının sebebi yıkıcı olması: çağıran taraf önce
      // kullanıcıya onaylatmalı. addServiceArea bunu kendiliğinden yapmaz.
      expect(ctrl.contains('void changeProvince(ServiceArea yeni)'), isTrue);
    });

    test('kayıtta normalleştirme var (eski kayıt göçü)', () {
      expect(
          ctrl.contains(
              'serviceAreas: current.profile.serviceAreas.onlySingleProvince'),
          isTrue,
          reason: 'Eski çok illi kayıt kaydedilince tek ile inmeli.');
    });
  });

  group('Kullanıcı ONAYLAMADAN ilçeleri kaybetmiyor', () {
    test('usta profili önce soruyor', () {
      final ekran = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      expect(ekran.contains('Hizmet ilini değiştir'), isTrue,
          reason: 'Sessizce ilçe silmek veri kaybı gibi hissettirir.');
      expect(ekran.contains('_controller.changeProvince(yeni)'), isTrue);
    });

    test('mağaza kurulumu da soruyor', () {
      final ekran =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      expect(ekran.contains('Hizmet ilini değiştir'), isTrue,
          reason: 'İki ekran aynı davranmalı; biri sorup diğeri sormazsa '
              'kullanıcı kuralı öğrenemez.');
    });

    test('kural ÖNCEDEN söyleniyor', () {
      // Kullanıcı ikinci ili deneyip uyarıya çarpmasın; sınırı baştan bilsin.
      final usta = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      final magaza =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      expect(usta.contains('Tek ilde hizmet verebilirsiniz'), isTrue);
      expect(magaza.contains('tek ilde '), isTrue);
    });
  });

  group('Mağaza kaydı da normalleşiyor', () {
    late String ekran;
    setUpAll(() => ekran =
        read('lib/features/products/presentation/shop_setup_screen.dart'));

    test('kayıtta tek ile iniyor', () {
      expect(ekran.contains('List.of(_areas.onlySingleProvince)'), isTrue);
    });

    test('usta profilinden aktarım da tek ile iniyor', () {
      // Eski çok illi usta profili mağazaya olduğu gibi kopyalanırsa
      // kural mağaza tarafında delinirdi.
      expect(ekran.contains('areas.onlySingleProvince'), isTrue);
      expect(ekran.contains('user.shopServiceAreas.onlySingleProvince'), isTrue);
    });
  });
}

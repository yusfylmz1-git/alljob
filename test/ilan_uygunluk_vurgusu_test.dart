// Regresyon: ilan listesi ELEMEZ, uyanları VURGULAR (2026-08-23).
//
// Kapalı test geri bildirimi: "ilanda otomatik filtre kalkacak, şimdilik tüm
// ilanları görsün. Ama usta müsaitse kendi kategorisi ve bölgesindeki ilanlar
// başta görünse — ya da mesaj yazabileceği ilanlar yeşil çerçeveyle ayrılsa."
//
// Bir önceki tur (2026-08-20) ustanın ilini Keşfet filtresine VARSAYILAN
// olarak koymuştu. Ters etki verdi: usta piyasada ne olduğunu göremiyor,
// filtrenin kendiliğinden dolduğunu fark etmiyor ve "ilan yok" sanıyordu.
//
// Yeni davranış üç parçalı:
//   1. Otomatik il filtresi YOK — liste tüm ilanları gösterir.
//   2. Ustanın mesleğine + bölgesine uyanlar listenin BAŞINA alınır.
//   3. Uyanlar yeşil çerçeve + "Sana uygun" rozetiyle ayrışır.
//
// Çift test (kural 7): sıralama çalışıyor MU + fazlasını yapmıyor MU.
// "Fazlası" = uymayan ilanı listeden DÜŞÜRMEK. O bir kapı olurdu; burada
// yalnız görsel ayrım isteniyor.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/features/jobs/data/job_providers.dart';

Job _job({
  required String jobId,
  String category = 'painter',
  String province = 'Kocaeli',
}) {
  final now = DateTime(2026, 8, 23);
  return Job(
    jobId: jobId,
    customerId: 'baskasi',
    customerName: 'Müşteri',
    title: 'Başlık',
    description: 'Açıklama',
    category: category,
    province: province,
    district: 'İzmit',
    photos: const [],
    priceType: JobPriceType.fixed,
    status: JobStatus.open,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 7)),
  );
}

void main() {
  String read(String p) => File(p).readAsStringSync();

  // Boyacı, Kocaeli'de çalışıyor.
  bool boyaciKocaeli(Job j) => j.matchesArtisan(
        professionCodes: const ['painter'],
        serviceAreas: const [
          ServiceArea(province: 'Kocaeli', district: 'İzmit'),
        ],
      );

  group('Uygun ilanlar başa alınır', () {
    test('uyan ilan listenin başına geçer', () {
      final liste = [
        _job(jobId: 'bursa-elektrik', category: 'electrician',
            province: 'Bursa'),
        _job(jobId: 'kocaeli-boya'), // uyan
        _job(jobId: 'ankara-tesisat', category: 'plumber',
            province: 'Ankara'),
      ];

      final sirali = sortJobMatchesFirst(liste, boyaciKocaeli);

      expect(sirali.first.jobId, 'kocaeli-boya',
          reason: 'Ustanın kendi işi listenin başında olmalı.');
    });

    test('grup İÇİNDEKİ sıra korunur (kararlı sıralama)', () {
      // `List.sort` kararlı değildir; eşit gruptaki kartlar her çizimde yer
      // değiştirirse liste "zıplıyor" görünür.
      final liste = [
        _job(jobId: 'uymaz-1', category: 'electrician', province: 'Bursa'),
        _job(jobId: 'uyar-1'),
        _job(jobId: 'uymaz-2', category: 'plumber', province: 'Ankara'),
        _job(jobId: 'uyar-2'),
        _job(jobId: 'uymaz-3', category: 'plumber', province: 'İzmir'),
      ];

      final sirali = sortJobMatchesFirst(liste, boyaciKocaeli);

      expect(sirali.map((j) => j.jobId),
          ['uyar-1', 'uyar-2', 'uymaz-1', 'uymaz-2', 'uymaz-3'],
          reason: 'Her iki grup da kaynak sırasını (en yeni üstte) korumalı.');
    });

    test('aynı liste tekrar sıralanınca DEĞİŞMEZ', () {
      final liste = [
        _job(jobId: 'uymaz-1', category: 'plumber', province: 'Bursa'),
        _job(jobId: 'uyar-1'),
        _job(jobId: 'uymaz-2', category: 'plumber', province: 'Ankara'),
      ];

      final bir = sortJobMatchesFirst(liste, boyaciKocaeli);
      final iki = sortJobMatchesFirst(bir, boyaciKocaeli);

      expect(iki.map((j) => j.jobId), bir.map((j) => j.jobId),
          reason: 'Sıralama sabit noktada olmalı — kartlar zıplamamalı.');
    });
  });

  group('Fazlasını yapmıyor — hiçbir ilan ELENMİYOR', () {
    test('uymayan ilanlar listede KALIR', () {
      final liste = [
        _job(jobId: 'bursa-elektrik', category: 'electrician',
            province: 'Bursa'),
        _job(jobId: 'kocaeli-boya'),
        _job(jobId: 'ankara-tesisat', category: 'plumber',
            province: 'Ankara'),
      ];

      final sirali = sortJobMatchesFirst(liste, boyaciKocaeli);

      expect(sirali.length, liste.length,
          reason: 'Sıralama bir KAPI değil — hiçbir ilan düşmemeli. '
              '"Şimdilik tüm ilanları görsün" kararı budur.');
      expect(sirali.map((j) => j.jobId).toSet(),
          liste.map((j) => j.jobId).toSet());
    });

    test('hiç eşleşme yoksa liste OLDUĞU GİBİ döner', () {
      // Müşteri / misafir / profilsiz usta yolu — boşuna kopya üretilmemeli.
      final liste = [
        _job(jobId: 'a', category: 'electrician', province: 'Bursa'),
        _job(jobId: 'b', category: 'plumber', province: 'Ankara'),
      ];

      final sirali = sortJobMatchesFirst(liste, (_) => false);

      expect(identical(sirali, liste), isTrue,
          reason: 'Eşleşme yokken yeni liste üretmeye gerek yok.');
    });

    test('hepsi uyuyorsa sıra bozulmaz', () {
      final liste = [
        _job(jobId: 'a'),
        _job(jobId: 'b'),
        _job(jobId: 'c'),
      ];

      expect(sortJobMatchesFirst(liste, boyaciKocaeli).map((j) => j.jobId),
          ['a', 'b', 'c']);
    });

    test('boş liste çökmüyor', () {
      expect(sortJobMatchesFirst(const <Job>[], boyaciKocaeli), isEmpty);
    });
  });

  group('Uygunluk ölçütü push bildirimiyle AYNI', () {
    test('jobMatchesMeProvider Job.matchesArtisan kullanıyor', () {
      final providers = read('lib/features/jobs/data/job_providers.dart');
      expect(providers.contains('jobMatchesMeProvider'), isTrue);
      expect(providers.contains('job.matchesArtisan('), isTrue,
          reason: 'Vurgu ölçütü push bildiriminden ayrışırsa, usta '
              'bildirim aldığı ilanı listede yeşil göremez.');
    });

    test('ürün talebi hiçbir zaman uygun sayılmaz', () {
      // `matchesArtisan` ürün talebinde erken false döner; vurgu da
      // ondan beslendiği için talep asla yeşil çerçeve almaz.
      final talep = _job(jobId: 't', category: kProductRequestCategory);
      expect(boyaciKocaeli(talep), isFalse);
    });

    test('profilsiz kullanıcıda vurgu YOK', () {
      final providers = read('lib/features/jobs/data/job_providers.dart');
      expect(providers.contains('return (_) => false;'), isTrue,
          reason: 'Müşteri/misafir için ölçüt kapalı olmalı — herkesin '
              'kartı yeşil çerçeveli çıkmasın.');
    });
  });

  group('Kart vurgusu', () {
    late String kart;
    setUpAll(() =>
        kart = read('lib/features/jobs/presentation/widgets/job_widgets.dart'));

    test('yeşil çerçeve tema renginden geliyor', () {
      expect(kart.contains('accentBorder: matchesMe ? palette.success : null'),
          isTrue,
          reason: 'Sabit yeşil kullanılırsa karanlık modda okunmaz.');
      expect(kart.contains('accentWidth: matchesMe ? 2 : 1.2'), isTrue,
          reason: 'Uyan kartın çerçevesi belirgin olmalı.');
    });

    test('"Sana uygun" rozeti var ve "Yakınında" ile ÇAKIŞMIYOR', () {
      expect(kart.contains("isNearby ? 'Yakınında' : 'Sana uygun'"), isTrue,
          reason: 'İki rozet birden takılırsa başlığa yer kalmaz; '
              '"Yakınında" daha özeldir ve önceliklidir.');
    });
  });

  group('Ana sayfa şeridi Keşfet ile aynı sırayı gösterir', () {
    test('şerit de sortJobMatchesFirst kullanıyor', () {
      final home =
          read('lib/features/home/presentation/widgets/home_featured.dart');
      expect(home.contains('sortJobMatchesFirst'), isTrue,
          reason: 'Şerit yalnız 6 ilan gösterir; usta kendi işini ana '
              'sayfada göremezse vurgu işe yaramaz.');
      expect(home.contains('jobMatchesMeProvider'), isTrue);
    });
  });
}

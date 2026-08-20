// Regresyon: ilan feed'i süzme kuralları (2026-08-20 kapalı test bulguları).
//
// Testçi geri bildirimleri:
//  1. "Kocaeli'yi tanımlamadan önce başkasının ilanı bende gözüktü"
//  2. "Talep oluşturunca ilanlara da düşüyor"
//
// Kök neden: il/meslek/kendi-ilanı elemesi YALNIZ `nearbyJobsProvider` ve push
// bildiriminde (`onJobCreated`) vardı. Ana sayfa şeridi ile Keşfet > İlanlar
// paneli ham `openJobsProvider`'a bağlıydı ve HİÇBİR eleme yapmıyordu.
//
// Her düzeltme için ÇİFT test: hatanın gittiğini VE fazlasının elenmediğini
// doğrular (CLAUDE.md değişmez kural 7).

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/features/auth/application/auth_controller.dart';
import 'package:sepette_hizmet/features/jobs/data/job_providers.dart';

Job _job({
  required String jobId,
  String customerId = 'baskasi',
  String category = 'painter',
  String province = 'Kocaeli',
}) {
  final now = DateTime(2026, 8, 20);
  return Job(
    jobId: jobId,
    customerId: customerId,
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

AppUser _user(String uid) => AppUser(
      uid: uid,
      displayName: 'Test',
      email: 'test@example.com',
      createdAt: DateTime(2026, 1, 1),
    );

/// Verilen ilan listesi + oturumla dolu bir kap kurar.
///
/// StreamProvider ilk değerini MİKROTASK sonrası yayınlar; `read` hemen
/// çağrılırsa `valueOrNull` boştur. Bu yüzden kap kurulduktan sonra
/// `future` beklenmelidir.
Future<ProviderContainer> _kap(List<Job> jobs, {AppUser? user}) async {
  final container = ProviderContainer(
    overrides: [
      openJobsProvider.overrideWith((ref) => Stream.value(jobs)),
      authStateProvider.overrideWith((ref) => Stream.value(user)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(openJobsProvider.future);
  await container.read(authStateProvider.future);
  return container;
}

/// [visibleJobFeedProvider]'ı verilen ilan listesi ve oturumla çalıştırır.
Future<List<Job>> _feed(List<Job> jobs, {AppUser? user}) async {
  final container = await _kap(jobs, user: user);
  return container.read(visibleJobFeedProvider);
}

void main() {
  group('Ürün talebi iş ilanı feed’ine düşmez', () {
    test('talep elenir — testçi bulgusu "talep ilanlara düşüyor"', () async {
      final feed = await _feed([
        _job(jobId: 'is1'),
        _job(jobId: 'talep1', category: kProductRequestCategory),
      ]);

      expect(feed.map((j) => j.jobId), ['is1']);
    });

    test('normal iş ilanı ve Hemen Lazım ELENMEZ (fazlasını yapmadı)', () async {
      final feed = await _feed([
        _job(jobId: 'is1'),
        _job(jobId: 'hemen', category: kQuickSupportCategory),
        _job(jobId: 'talep1', category: kProductRequestCategory),
      ]);

      expect(feed.map((j) => j.jobId), ['is1', 'hemen']);
    });
  });

  group('Kendi ilanın feed’de görünmez', () {
    test('kendi ilanı elenir', () async {
      final feed = await _feed(
        [
          _job(jobId: 'benim', customerId: 'ben'),
          _job(jobId: 'baskasinin', customerId: 'baskasi'),
        ],
        user: _user('ben'),
      );

      expect(feed.map((j) => j.jobId), ['baskasinin']);
    });

    test('misafirde hiçbir ilan sahiplik yüzünden elenmez', () async {
      final feed = await _feed([
        _job(jobId: 'a', customerId: 'ben'),
        _job(jobId: 'b', customerId: 'baskasi'),
      ]);

      expect(feed.map((j) => j.jobId), ['a', 'b']);
    });
  });

  group('İl elemesi feed’de DEĞİL, filtrededir', () {
    // Bilinçli karar: il, Keşfet panelinde filtrenin VARSAYILAN değeridir.
    // Provider'da sabitlenseydi kullanıcı "hepsini gör" diyemez, komşu ilde
    // çalışan usta mağdur olurdu.
    test('feed farklı illerin ilanlarını taşımaya devam eder', () async {
      final feed = await _feed([
        _job(jobId: 'kocaeli', province: 'Kocaeli'),
        _job(jobId: 'bursa', province: 'Bursa'),
      ]);

      expect(feed.map((j) => j.jobId), ['kocaeli', 'bursa']);
    });
  });

  _myJobsTestleri();

  group('Keşfet paneli: varsayılan il', () {
    late String panel;
    setUpAll(() {
      panel = File(
        'lib/features/jobs/presentation/widgets/jobs_explore_panel.dart',
      ).readAsStringSync();
    });

    test('ustanın ili filtreye varsayılan olarak yerleşiyor', () {
      expect(panel.contains('myFeedProvinceProvider'), isTrue,
          reason: 'Varsayılan il tohumlaması kaldırılmış — usta yine tüm '
              'bütün illerin ilanlarını görür (2026-08-20 bulgusu).');
      expect(panel.contains('_seedProvince()'), isTrue);
    });

    test('tohumlama TEK SEFERLİK (kullanıcı seçimini ezmiyor)', () {
      // Bayrak olmasaydı, kullanıcı filtreyi temizlediği anda build kendi
      // ilini geri yazar ve "hepsini gör" hiç çalışmazdı.
      expect(panel.contains('_provinceSeeded'), isTrue,
          reason: 'Tek seferlik bayrak yok — filtre temizlenemez hale gelir.');
    });
  });

  group('quickSupportJobsProvider süzülmüş feed’den beslenir', () {
    test('kendi Hemen Lazım ilanın şeritte görünmez', () async {
      final container = await _kap(
        [
          _job(
            jobId: 'benim',
            customerId: 'ben',
            category: kQuickSupportCategory,
          ),
          _job(
            jobId: 'baskasinin',
            customerId: 'baskasi',
            category: kQuickSupportCategory,
          ),
        ],
        user: _user('ben'),
      );

      final quick = container.read(quickSupportJobsProvider);
      expect(quick.map((j) => j.jobId), ['baskasinin']);
    });
  });
}

/// "İlanlarım" ve "Taleplerim" AYNI ekrandır (`MyJobsScreen`), ayıran tek şey
/// `onlyProductRequests` bayrağıdır. Süzme İKİ YÖNLÜ olmalıdır.
///
/// 2026-08-20 bulgusu: yalnız `onlyProductRequests == true` yönü süzülüyordu.
/// Ters yön yazılmadığı için talep, "İlanlarım" listesinde görünüyordu —
/// testçinin "talep oluşturunca ilanlarda da gözüküyor" şikâyeti.
///
/// Ekranın kendi `_visible` metodu private olduğundan burada AYNI kural
/// bağımsız olarak doğrulanır; ekran kaynağı ayrıca sözleşmeyle bağlanır.
void _myJobsTestleri() {
  List<Job> visible(List<Job> jobs, {required bool onlyProductRequests}) {
    if (onlyProductRequests) {
      return jobs.where((j) => j.isProductRequest).toList(growable: false);
    }
    return jobs.where((j) => !j.isProductRequest).toList(growable: false);
  }

  group('İlanlarım / Taleplerim birbirini dışlar', () {
    final kayitlar = [
      _job(jobId: 'is1', customerId: 'ben'),
      _job(jobId: 'talep1', customerId: 'ben', category: kProductRequestCategory),
      _job(jobId: 'hemen', customerId: 'ben', category: kQuickSupportCategory),
    ];

    test('İlanlarım talebi GÖSTERMEZ', () {
      final liste = visible(kayitlar, onlyProductRequests: false);
      expect(liste.map((j) => j.jobId), ['is1', 'hemen']);
    });

    test('Taleplerim yalnız talepleri gösterir', () {
      final liste = visible(kayitlar, onlyProductRequests: true);
      expect(liste.map((j) => j.jobId), ['talep1']);
    });

    test('EKRAN gerçekten iki yönlü süzüyor (kural kopyası değil)', () {
      // Yukarıdaki testler kuralın KOPYASINI doğrular; ekran değişirse
      // yakalamazlar. Bu test asıl kaynağı bağlar.
      final ekran = File(
        'lib/features/jobs/presentation/my_jobs_screen.dart',
      ).readAsStringSync();

      expect(ekran.contains('j.isProductRequest'), isTrue);
      expect(ekran.contains('!j.isProductRequest'), isTrue,
          reason: 'İlanlarım tarafı talepleri elemiyor — talep yine '
              '"İlanlarım" listesinde görünür (2026-08-20 bulgusu).');
      expect(ekran.contains('if (!widget.onlyProductRequests) return jobs;'),
          isFalse,
          reason: 'Tek yönlü süzme geri gelmiş.');
    });

    test('iki liste birleşince HİÇBİR kayıt kaybolmaz', () {
      // Ayrım kayıp üretmemeli: kullanıcı her ilanına bir yerden ulaşabilmeli.
      final hepsi = [
        ...visible(kayitlar, onlyProductRequests: false),
        ...visible(kayitlar, onlyProductRequests: true),
      ];
      expect(hepsi.length, kayitlar.length);
      expect(
        hepsi.map((j) => j.jobId).toSet(),
        kayitlar.map((j) => j.jobId).toSet(),
      );
    });
  });
}

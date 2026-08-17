import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/data/models/chat.dart' show ChatLockReason;
import 'package:sepette_hizmet/data/models/favorite.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/data/models/review.dart'
    show Review, ReviewDirection;
import 'package:sepette_hizmet/features/favorites/data/mock_favorite_repository.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart'
    show MockChatRepository;
import 'package:sepette_hizmet/features/jobs/data/mock_job_repository.dart';
import 'package:sepette_hizmet/features/jobs/presentation/job_explore_filter.dart';

Job _sampleJob({
  String customerId = 'cust_1',
  String category = 'painter',
  String province = 'Bursa',
  String district = 'Osmangazi',
  JobDuration duration = JobDuration.day3,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.now();
  return Job(
    jobId: '',
    customerId: customerId,
    customerName: 'Test Müşteri',
    title: 'Duvar boyama',
    description: 'Salon duvarları boyanacak.',
    category: category,
    province: province,
    district: district,
    neighborhood: 'Dikkaldırım',
    photos: const [],
    priceType: JobPriceType.fixed,
    budget: 5000,
    status: JobStatus.open,
    createdAt: now,
    expiresAt: now.add(duration.duration),
  );
}

void main() {
  group('Model serileştirme (roundtrip)', () {
    test('durum ÜÇ değerdir; ilan bir duyurudur, iş takip aracı değil', () {
      // İş akışı (usta seçimi → tamamlama → puanlama) 2026-08-08'de kalktı.
      // Enum yeniden büyürse sadeleştirme sessizce geri alınmış demektir.
      expect(JobStatus.values, [
        JobStatus.open,
        JobStatus.cancelled,
        JobStatus.expired,
      ]);
      expect(JobStatus.open.simpleLabelTR, 'Yayında');
      expect(JobStatus.cancelled.simpleLabelTR, 'Kaldırıldı');
      expect(JobStatus.expired.simpleLabelTR, 'Süresi doldu');
    });

    test('eski kayıttaki kaldırılmış durum `open`a düşer (veri kaybı yok)', () {
      // Canlıda `workerSelected`/`completed` yazan doküman kalmış olabilir;
      // ilan görünmeye devam etmeli, çökmemeli.
      expect(JobStatus.fromString('workerSelected'), JobStatus.open);
      expect(JobStatus.fromString('completed'), JobStatus.open);
      expect(JobStatus.fromString('disputed'), JobStatus.open);
      expect(JobStatus.fromString(null), JobStatus.open);
      // Yaşayan değerler kendine çözülür.
      expect(JobStatus.fromString('cancelled'), JobStatus.cancelled);
      expect(JobStatus.fromString('expired'), JobStatus.expired);
    });

    test('Job toMap/fromMap tüm alanları korur', () {
      final job = _sampleJob().copyWith();
      final restored = Job.fromMap('job_x', job.toMap());
      expect(restored.customerId, job.customerId);
      expect(restored.category, job.category);
      expect(restored.province, job.province);
      expect(restored.district, job.district);
      expect(restored.neighborhood, job.neighborhood);
      expect(restored.priceType, JobPriceType.fixed);
      expect(restored.budget, 5000);
      expect(restored.status, JobStatus.open);
    });

    test('Favorite toMap/fromMap', () {
      final fav = Favorite(
        customerUid: 'c1',
        artisanUid: 'a1',
        artisanName: 'Ahmet',
        professionNameTR: 'Tesisatçı',
        rating: 4.9,
        totalReviews: 40,
        createdAt: DateTime.now(),
      );
      final restored = Favorite.fromMap(fav.id, fav.toMap());
      expect(restored.customerUid, 'c1');
      expect(restored.artisanUid, 'a1');
      expect(restored.rating, 4.9);
      expect(fav.id, 'c1__a1');
    });
  });

  group('Usta feed eşleştirme (#1)', () {
    test('yalnızca aynı meslek + eşleşen bölge + açık ilan gösterilir', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);

      await jobs.createJob(_sampleJob(category: 'painter', district: 'Osmangazi'));
      await jobs.createJob(_sampleJob(category: 'plumber', district: 'Osmangazi'));
      await jobs.createJob(_sampleJob(category: 'painter', district: 'Nilüfer'));

      final feed = await jobs.watchNearbyJobs(
        professionCode: 'painter',
        serviceAreas: const [
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
        ],
      ).first;

      // MESLEK eler: plumber listede olmamalı.
      expect(feed.every((j) => j.category == 'painter'), isTrue);
      // İLÇE ELEMEZ (2026-08-10): aynı ildeki Nilüfer ilanı da düşer.
      expect(
        feed.any((j) => j.district == 'Nilüfer'),
        isTrue,
        reason: 'İlçe şartı kalktı; aynı ilin diğer ilçeleri de görünmeli.',
      );
      expect(feed.every((j) => j.province == 'Bursa'), isTrue,
          reason: 'İl sınırı duruyor.');
      expect(feed.any((j) => j.jobId == 'job_seed_1'), isTrue);
    });

    test('en yeni ilan feed başında gelir', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final now = DateTime.now();
      await jobs.createJob(_sampleJob(
          category: 'welder',
          createdAt: now.subtract(const Duration(minutes: 1))));
      final newestId = await jobs.createJob(
          _sampleJob(category: 'welder', createdAt: now));

      final feed = await jobs.watchNearbyJobs(
        professionCode: 'welder',
        serviceAreas: const [
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
        ],
      ).first;
      expect(feed.first.jobId, newestId);
    });
  });

  group('Yaşam döngüsü (#4, #6, #10, #11)', () {
    test('müşteri iptali → cancelled + neden', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());
      await jobs.cancelJob(jobId: jobId, reason: JobCancelReason.solved);
      final job = await jobs.getJob(jobId);
      expect(job!.status, JobStatus.cancelled);
      expect(job.cancelReason, JobCancelReason.solved);
    });
  });

  group('Hemen Lazım', () {
    const areas = [
      ServiceArea(
          province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
    ];

    test('yalnız Hemen Lazım hizmeti açık ustalarla eşleşir', () {
      final job = _sampleJob(category: kQuickSupportCategory);
      // Boyacı Hemen Lazım ilanını almaz.
      expect(
          job.matchesArtisan(professionCode: 'painter', serviceAreas: areas),
          isFalse);
      expect(
          job.matchesArtisan(
              professionCode: kOtherProfession, serviceAreas: areas),
          isTrue);
    });

    test('İL geneline gider: farklı ilçedeki usta da alır', () {
      final job = _sampleJob(category: kQuickSupportCategory);
      // İlan Bursa/Osmangazi; usta Bursa/Nilüfer → İL eşleştiği için GELİR.
      expect(
        job.matchesArtisan(
          professionCode: kOtherProfession,
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
        ),
        isTrue,
      );
      // Başka il → gelmez (il sınırı korunur).
      expect(
        job.matchesArtisan(
          professionCode: kOtherProfession,
          serviceAreas: const [
            ServiceArea(province: 'Ankara', district: 'Çankaya'),
          ],
        ),
        isFalse,
      );
    });

    // 2026-08-10: klasik ilanda İLÇE ŞARTI KALKTI (kullanıcı kararı).
    // Önce yalnız Hemen Lazım il düzeyindeydi; klasik ilanlar ilçeye
    // kısıtlıydı ve çoğu ilçede alıcısız kalıyordu. Artık iki tip de il
    // düzeyinde eşleşir; ilçe yalnız SIRALAMA sinyalidir (isNearbyForAreas).
    test('klasik ilan farklı İLÇEDEKİ ustaya da düşer (aynı il)', () {
      final job = _sampleJob(category: 'painter');
      expect(
        job.matchesArtisan(
          professionCode: 'painter',
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
        ),
        isTrue,
        reason: 'Aynı il, farklı ilçe → artık eşleşmeli.',
      );
      expect(
        job.matchesArtisan(professionCode: 'painter', serviceAreas: areas),
        isTrue,
      );
    });

    test('klasik ilanda İL sınırı DURUYOR (fazlasını yapma)', () {
      // İlçe kalktı diye il de kalkmadı: başka ildeki usta ilanı görmemeli.
      final job = _sampleJob(category: 'painter');
      expect(
        job.matchesArtisan(
          professionCode: 'painter',
          serviceAreas: const [
            ServiceArea(province: 'İstanbul', district: 'Kadıköy'),
          ],
        ),
        isFalse,
        reason: 'Farklı il → eşleşmemeli.',
      );
    });

    test('ilçe farkı "Yakınında" rozetini etkiler ama ELEMEZ', () {
      final job = _sampleJob(category: 'painter');
      const uzak = [ServiceArea(province: 'Bursa', district: 'Nilüfer')];
      // Eşleşiyor ama yakın değil → listede var, üstte değil.
      expect(
        job.matchesArtisan(professionCode: 'painter', serviceAreas: uzak),
        isTrue,
      );
      expect(job.isNearbyForAreas(uzak), isFalse);
      expect(job.isNearbyForAreas(areas), isTrue);
    });

    test('isNearbyForAreas — aynı ilçe "Yakınında" sayılır', () {
      final job = _sampleJob(category: kQuickSupportCategory);
      expect(job.isNearbyForAreas(areas), isTrue);
      expect(
        job.isNearbyForAreas(const [
          ServiceArea(province: 'Bursa', district: 'Nilüfer'),
        ]),
        isFalse,
      );
    });

    test('feed sıralaması: Hemen Lazım üstte, kendi ilçesi önce', () {
      // Uzak ilçedeki Hemen Lazım ilanı listede ÖNCE duruyor; sıralama onu
      // yakın olanın ARKASINA almalı (yakınlık, giriş sırasından güçlü).
      final list = <Job>[
        _sampleJob(category: 'painter'),
        _sampleJob(category: kQuickSupportCategory)
            .copyWith(district: 'Nilüfer'),
        _sampleJob(category: kQuickSupportCategory),
      ];
      final sorted = sortJobsForArtisanFeed(list, areas);
      expect(sorted.first.category, kQuickSupportCategory);
      expect(sorted.first.district, 'Osmangazi'); // yakın olan önce
      expect(sorted[1].district, 'Nilüfer'); // uzak hemen-lazım ikinci
      expect(sorted.last.category, 'painter'); // klasik ilan en sonda
    });

    test('Hemen Lazım ustası YALNIZCA hemen lazım ilanlarını görür',
        () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final quickId =
          await jobs.createJob(_sampleJob(category: kQuickSupportCategory));
      await jobs.createJob(_sampleJob(category: 'painter'));

      final feed = await jobs
          .watchNearbyJobs(
              professionCode: kOtherProfession, serviceAreas: areas)
          .first;
      expect(feed.map((j) => j.jobId), contains(quickId));
      expect(feed.every((j) => j.category == kQuickSupportCategory), isTrue);
    });

    test('klasik usta yalnız kendi mesleğini görür (hızlı destek yok)',
        () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      await jobs.createJob(_sampleJob(category: kQuickSupportCategory));
      final paintId = await jobs.createJob(_sampleJob(category: 'painter'));
      await jobs.createJob(_sampleJob(category: 'plumber'));

      final feed = await jobs
          .watchNearbyJobs(professionCode: 'painter', serviceAreas: areas)
          .first;
      expect(feed.map((j) => j.jobId), contains(paintId));
      expect(feed.every((j) => j.category == 'painter'), isTrue);
    });

    test('meslek + Hızlı Destek birlikteyse her iki ilan da gelir', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final quickId =
          await jobs.createJob(_sampleJob(category: kQuickSupportCategory));
      final paintId = await jobs.createJob(_sampleJob(category: 'painter'));

      final feed = await jobs
          .watchNearbyJobs(
            professionCodes: [kOtherProfession, 'painter'],
            serviceAreas: areas,
          )
          .first;
      expect(feed.map((j) => j.jobId), containsAll([quickId, paintId]));
    });
  });

  group('Süre dolumu (#2)', () {
    test('süresi geçmiş açık ilan expired sayılır ve feed dışıdır', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final now = DateTime.now();
      final expired = Job.fromMap('job_old', _sampleJob().toMap()).copyWith(
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      db.jobs['job_old'] = expired;

      expect(expired.isExpiredAt(now), isTrue);
      expect(expired.effectiveStatusAt(now), JobStatus.expired);

      final feed = await jobs.watchNearbyJobs(
        professionCode: 'painter',
        serviceAreas: const [
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
        ],
      ).first;
      expect(feed.any((j) => j.jobId == 'job_old'), isFalse);
    });
  });

  group('Keşfet ilan paneli / watchOpenJobs', () {
    test('yalnızca açık + süresi dolmamış ilanlar, en yeni en üstte', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);

      final openId = await jobs.createJob(_sampleJob(category: 'plumber'));
      final cancelledId = await jobs.createJob(_sampleJob());
      await jobs.cancelJob(jobId: cancelledId, reason: JobCancelReason.solved);
      db.jobs['job_old'] = Job.fromMap('job_old', _sampleJob().toMap())
          .copyWith(expiresAt: DateTime.now().subtract(const Duration(hours: 1)));

      final feed = await jobs.watchOpenJobs().first;

      expect(feed.every((j) => j.status == JobStatus.open), isTrue);
      expect(feed.any((j) => j.jobId == openId), isTrue);
      expect(feed.any((j) => j.jobId == cancelledId), isFalse);
      expect(feed.any((j) => j.jobId == 'job_old'), isFalse);
      // Meslek/bölge filtresi YOK (herkese açık panel) + en yeni en üstte.
      expect(feed.first.jobId, openId);
      expect(feed.any((j) => j.jobId == 'job_seed_1'), isTrue);
    });

    test('limit uygulanır', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      for (var i = 0; i < 5; i++) {
        await jobs.createJob(_sampleJob());
      }
      final feed = await jobs.watchOpenJobs(limit: 3).first;
      expect(feed.length, 3);
    });
  });

  group('Favoriler (#14)', () {
    test('toggle ekler/çıkarır', () async {
      final db = MockDatabase();
      final favs = MockFavoriteRepository(db);
      final fav = Favorite(
        customerUid: 'c1',
        artisanUid: 'a1',
        artisanName: 'Ahmet',
        professionNameTR: 'Boyacı Ustası',
        rating: 4.8,
        totalReviews: 20,
        createdAt: DateTime.now(),
      );

      final added = await favs.toggle(fav);
      expect(added, isTrue);
      expect(await favs.isFavorite(customerUid: 'c1', artisanUid: 'a1'), isTrue);
      expect(
          await favs
              .watchIsFavorite(customerUid: 'c1', artisanUid: 'a1')
              .first,
          isTrue);
      expect((await favs.watchFavorites('c1').first).length, 1);

      final removed = await favs.toggle(fav);
      expect(removed, isFalse);
      expect(await favs.isFavorite(customerUid: 'c1', artisanUid: 'a1'), isFalse);
    });

    test('watchFollowers ustayı takip eden müşterileri döner', () async {
      final db = MockDatabase();
      final favs = MockFavoriteRepository(db);
      Favorite fav(String customer, String artisan) => Favorite(
            customerUid: customer,
            artisanUid: artisan,
            artisanName: 'Usta',
            professionNameTR: 'Boyacı Ustası',
            rating: 4.8,
            totalReviews: 20,
            customerName: 'Müşteri $customer',
            createdAt: DateTime.now(),
          );
      await favs.toggle(fav('c1', 'a1'));
      await favs.toggle(fav('c2', 'a1'));
      await favs.toggle(fav('c1', 'a2')); // başka ustanın takipçisi

      final followers = await favs.watchFollowers('a1').first;
      expect(followers.length, 2);
      expect(followers.map((f) => f.customerUid), containsAll(['c1', 'c2']));
      expect(followers.first.customerName, isNotEmpty);
    });
  });

  group('İlan düzenleme + silme', () {
    test('canEdit: yalnız açık ilan, yayından sonra 1 saat', () {
      final now = DateTime.now();
      final fresh = _sampleJob(createdAt: now);
      expect(fresh.canEditAt(now.add(const Duration(minutes: 59))), isTrue);
      expect(fresh.canEditAt(now.add(const Duration(minutes: 61))), isFalse);
      // Kapanmış ilan pencere içinde bile düzenlenemez.
      final closed = fresh.copyWith(status: JobStatus.cancelled);
      expect(closed.canEditAt(now.add(const Duration(minutes: 5))), isFalse);
    });

    test('updateJobContent açık ilanın içeriğini günceller', () async {
      final db = MockDatabase();
      final repo = MockJobRepository(db);
      final id = await repo.createJob(_sampleJob());

      await repo.updateJobContent(
        jobId: id,
        title: 'Yeni başlık',
        description: 'Yeni ve daha ayrıntılı açıklama.',
        budget: null, // bütçe beklentisi kaldırılabilir
      );
      final job = db.jobs[id]!;
      expect(job.title, 'Yeni başlık');
      expect(job.budget, isNull);
      expect(job.status, JobStatus.open); // yaşam döngüsü değişmez

      // Açık olmayan ilan düzenlenemez (kural paritesi).
      db.jobs[id] = job.copyWith(status: JobStatus.cancelled);
      expect(
        () => repo.updateJobContent(
            jobId: id, title: 'x', description: 'y'),
        throwsStateError,
      );
    });

  });

  group('JobExploreFilter (Keşfet İlanlar)', () {
    test('il / ilçe ve metin sorgusu daraltır', () {
      final jobs = <Job>[
        _sampleJob(
          category: 'painter',
          province: 'Bursa',
          district: 'Osmangazi',
        ).copyWith(title: 'Salon boya'),
        _sampleJob(
          category: 'plumber',
          province: 'İstanbul',
          district: 'Kadıköy',
        ).copyWith(title: 'Mutfak tıkanıklık'),
        _sampleJob(
          category: 'painter',
          province: 'Bursa',
          district: 'Nilüfer',
        ).copyWith(title: 'Balkon boyama'),
      ];

      expect(
        const JobExploreFilter(province: 'Bursa')
            .apply(jobs)
            .map((j) => j.title)
            .toList(),
        ['Salon boya', 'Balkon boyama'],
      );
      expect(
        const JobExploreFilter(province: 'Bursa', district: 'Nilüfer')
            .apply(jobs)
            .map((j) => j.title)
            .toList(),
        ['Balkon boyama'],
      );
      expect(
        const JobExploreFilter(query: 'tıkan')
            .apply(jobs)
            .map((j) => j.title)
            .toList(),
        ['Mutfak tıkanıklık'],
      );
    });

    // 2026-08-15: filtre sayfasına Kategori seçeneği eklendi. Daha önce
    // meslek yalnızca metin aramasında geçiyordu ("Meslek dropdown yok").
    test('kategori tek başına daraltır', () {
      final jobs = <Job>[
        _sampleJob(category: 'painter', province: 'Bursa')
            .copyWith(title: 'Salon boya'),
        _sampleJob(category: 'plumber', province: 'Bursa')
            .copyWith(title: 'Mutfak tıkanıklık'),
        _sampleJob(category: 'painter', province: 'İzmir')
            .copyWith(title: 'Cephe boya'),
      ];

      expect(
        const JobExploreFilter(category: 'painter')
            .apply(jobs)
            .map((j) => j.title)
            .toList(),
        ['Salon boya', 'Cephe boya'],
      );
    });

    test('kategori il ile birlikte kesişim verir', () {
      final jobs = <Job>[
        _sampleJob(category: 'painter', province: 'Bursa')
            .copyWith(title: 'Salon boya'),
        _sampleJob(category: 'painter', province: 'İzmir')
            .copyWith(title: 'Cephe boya'),
        _sampleJob(category: 'plumber', province: 'Bursa')
            .copyWith(title: 'Mutfak tıkanıklık'),
      ];

      expect(
        const JobExploreFilter(category: 'painter', province: 'Bursa')
            .apply(jobs)
            .map((j) => j.title)
            .toList(),
        ['Salon boya'],
      );
    });

    // Fazlasını yapmama kontrolü: kategori BOŞ bırakılırsa hiçbir ilan
    // elenmemeli (filtre alanları isteğe bağlıdır).
    test('kategori boşken liste daralmaz', () {
      final jobs = <Job>[
        _sampleJob(category: 'painter').copyWith(title: 'Salon boya'),
        _sampleJob(category: 'plumber').copyWith(title: 'Mutfak tıkanıklık'),
      ];

      expect(const JobExploreFilter().apply(jobs).length, 2);
      expect(const JobExploreFilter(category: '').apply(jobs).length, 2);
    });

    test('kategori sayacı ve rozet durumu', () {
      const bos = JobExploreFilter();
      expect(bos.hasDetailFilters, isFalse);
      expect(bos.activeDetailCount, 0);

      const kategorili = JobExploreFilter(category: 'painter');
      expect(kategorili.hasDetailFilters, isTrue);
      expect(kategorili.activeDetailCount, 1);

      const ucu = JobExploreFilter(
        category: 'painter',
        province: 'Bursa',
        district: 'Nilüfer',
      );
      expect(ucu.activeDetailCount, 3);
    });

    test('copyWith kategoriyi taşır ve clearCategory temizler', () {
      const f = JobExploreFilter(category: 'painter', province: 'Bursa');

      expect(f.copyWith(province: 'İzmir').category, 'painter');
      expect(f.copyWith(clearCategory: true).category, isNull);
      // Kategoriyi temizlemek ili düşürmemeli.
      expect(f.copyWith(clearCategory: true).province, 'Bursa');
    });
  });

  // Sohbet artık İLAN BAZLI: `chat_{müşteri}__{usta}__{jobId}`. Aynı çift her
  // ilanda ayrı odada konuşur; eski iki parçalı kimlikler (ürün/eleman ve
  // geçiş öncesi kayıtlar) çalışmaya devam eder.
  group('Kişi bazlı sohbet kimliği (tek kutu)', () {
    test('aynı çift, iki ilan → TEK sohbet', () async {
      final chats = MockChatRepository();
      final a = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
        jobTitle: 'Banyo musluk',
      );
      final b = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_b',
        jobTitle: 'Mutfak dolabı',
      );

      // Kimlik ilandan TÜREMEZ: ikinci ilan yeni oda açmaz.
      expect(a, b);
      // Kimlik SIRALI (2026-08-10): uid'ler alfabetik → 'art_1' < 'cust_1'.
      expect(a, 'chat_art_1__cust_1');
      expect(chats.getThread(a)!.jobTitle, 'Banyo musluk');
    });

    test('jobId olsun olmasın kimlik AYNI', () async {
      final chats = MockChatRepository();
      final withJob = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
        jobTitle: 'Banyo musluk',
      );
      final withoutJob = MockChatRepository.chatIdFor('cust_1', 'art_1');

      expect(withJob, withoutJob);
      expect(withJob, 'chat_art_1__cust_1');
    });

    // 2026-08-10 (madde 4/6): kimlik ROL SIRASINDAN bağımsız.
    // Rol giriş noktasına göre değişiyordu — ilan detayında "ilanı veren =
    // müşteri", profil ekranında "ben = müşteri" — ve aynı çift iki ayrı
    // kutu açıyordu. Sıralı kimlik bunu imkânsız kılar.
    test('taraflar ters verilse bile TEK kutu', () async {
      final ileri = MockChatRepository.chatIdFor('cust_1', 'art_1');
      final geri = MockChatRepository.chatIdFor('art_1', 'cust_1');
      expect(ileri, geri,
          reason: 'Aynı çift için kimlik her yönden aynı olmalı.');
    });

    test('ters yönden girilince roller DEĞİŞMEZ', () async {
      final chats = MockChatRepository();
      // İlan detayı yolu: ilanı veren müşteri.
      final ilk = await chats.startChat(
        customerUid: 'ilan_sahibi',
        customerName: 'İlan Sahibi',
        artisanUid: 'yazan',
        artisanName: 'Yazan',
      );
      // Profil yolu: aynı iki kişi, roller TERS verildi.
      final ikinci = await chats.startChat(
        customerUid: 'yazan',
        customerName: 'Yazan',
        artisanUid: 'ilan_sahibi',
        artisanName: 'İlan Sahibi',
      );

      expect(ikinci, ilk, reason: 'İkinci giriş yeni kutu açmamalı.');
      final t = chats.getThread(ilk)!;
      expect(t.customerUid, 'ilan_sahibi',
          reason: 'Roller İLK açılışta donar; sonradan yer değiştiremez.');
      expect(t.artisanUid, 'yazan');
    });

    test('canSend: SERBEST — iki taraf da yazar; kilitli sohbette kimse '
        'yazamaz', () async {
      final chats = MockChatRepository();
      final id = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
      );
      final fresh = chats.getThread(id)!;
      // Serbest pazaryeri (2026-08-08): usta da ilk mesajı atabilir.
      // Eskiden `customerStarted` bayrağı beklenirdi (spam koruması).
      expect(fresh.canSend('cust_1'), isTrue);
      expect(fresh.canSend('art_1'), isTrue);

      final locked = fresh.copyWith(
        lockedAt: DateTime.now(),
        lockReason: ChatLockReason.otherArtisanSelected,
      );
      expect(locked.canSend('cust_1'), isFalse);
      expect(locked.canSend('art_1'), isFalse);
    });

    test('effectiveStatus: süresi dolmuş ilan `open` alanına rağmen expired',
        () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);

      final openId = await jobs.createJob(_sampleJob());
      expect((await jobs.getJob(openId))!.effectiveStatus, JobStatus.open);

      // Süresi dolmuş ilan: status alanı hâlâ `open` ama süre kapısı eler.
      // Usta seçim akışı kalktıktan sonra da bu kapı duruyor — ilan feed'de
      // görünmemeli ve mesaj kabul etmemeli.
      final staleId = await jobs.createJob(_sampleJob(
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ));
      expect((await jobs.getJob(staleId))!.effectiveStatus, JobStatus.expired);
    });

    test('customerStarted bayrağı korunur (yazma iznini artık ETKİLEMEZ)',
        () async {
      final chats = MockChatRepository();
      final id = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
      );
      // Bayrak hâlâ "müşteri konuşmaya başladı mı" bilgisini taşır (UI/liste
      // kullanır) ama YAZMA İZNİNİ belirlemez — usta baştan yazabilir.
      expect(chats.getThread(id)!.canSend('art_1'), isTrue);

      await chats.sendMessage(
          chatId: id, senderUid: 'art_1', text: 'merhaba');
      expect(chats.getThread(id)!.customerStarted, isFalse,
          reason: 'Usta mesajı bayrağı açmamalı.');

      await chats.sendMessage(
          chatId: id, senderUid: 'cust_1', text: 'merhaba usta');
      expect(chats.getThread(id)!.customerStarted, isTrue);
    });

    test('markCustomerStarted: işi vermek bayrağı açar (yazma zaten serbest)',
        () async {
      final chats = MockChatRepository();
      final id = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
      );
      // Müşteri sohbete TEK MESAJ yazmadan doğrudan "Bu Ustayı Seç" diyor.
      // Serbest mesajlaşmada usta zaten yazabiliyor; bayrak yine de
      // işaretlenmeli (liste/UI "konuşma başladı" bilgisini kullanır).
      await chats.markCustomerStarted(id);

      expect(chats.getThread(id)!.customerStarted, isTrue);
      expect(chats.getThread(id)!.canSend('art_1'), isTrue);
    });

    test('markCustomerStarted kilidi AÇMAZ: kilitli sohbette kimse yazamaz',
        () async {
      final chats = MockChatRepository();
      final id = await chats.startChat(
        customerUid: 'cust_1',
        customerName: 'Müşteri',
        artisanUid: 'art_1',
        artisanName: 'Usta',
        jobId: 'job_a',
      );
      await chats.markCustomerStarted(id);
      final locked = chats.getThread(id)!.copyWith(
            lockedAt: DateTime.now(),
            lockReason: ChatLockReason.otherArtisanSelected,
          );
      expect(locked.canSend('art_1'), isFalse);
      expect(locked.canSend('cust_1'), isFalse);
    });
  });

  group('Çift taraflı değerlendirme', () {
    test('doküman kimliği yöne göre ayrışır; c2a geriye uyumlu', () {
      const chatId = 'chat_cust_1__art_1__job_a';
      expect(
        ReviewDirection.docIdFor(chatId, ReviewDirection.customerToArtisan),
        chatId, // eski kayıtlarla aynı kimlik
      );
      expect(
        ReviewDirection.docIdFor(chatId, ReviewDirection.artisanToCustomer),
        '${chatId}__a2c',
      );
    });

    test('yön alanı yoksa ESKİ kayıt sayılır (müşteri→usta)', () {
      final r = Review.fromMap('chat_c__a', const {
        'artisanUID': 'a',
        'customerUID': 'c',
        'rating': 5,
      });
      expect(r.direction, ReviewDirection.customerToArtisan);
      expect(r.targetUid, 'a');
      expect(r.authorUid, 'c');
    });

    test('a2c: hedef müşteri, yazan usta', () {
      final r = Review.fromMap('chat_c__a__a2c', const {
        'artisanUID': 'a',
        'customerUID': 'c',
        'rating': 4,
        'direction': 'a2c',
      });
      expect(r.direction, ReviewDirection.artisanToCustomer);
      expect(r.targetUid, 'c');
      expect(r.authorUid, 'a');
    });
  });
}

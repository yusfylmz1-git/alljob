import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/local/mock_database.dart';
import 'package:usta_cepte/data/models/favorite.dart';
import 'package:usta_cepte/data/models/geo_models.dart';
import 'package:usta_cepte/data/models/job.dart';
import 'package:usta_cepte/data/models/offer.dart';
import 'package:usta_cepte/features/favorites/data/mock_favorite_repository.dart';
import 'package:usta_cepte/features/jobs/data/mock_job_repository.dart';
import 'package:usta_cepte/features/jobs/data/mock_offer_repository.dart';

Job _sampleJob({
  String customerId = 'cust_1',
  String category = 'painter',
  String province = 'Bursa',
  String district = 'Osmangazi',
  JobDuration duration = JobDuration.day3,
  bool urgent = false,
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
    isUrgent: urgent,
    priceType: JobPriceType.fixed,
    budget: 5000,
    status: JobStatus.open,
    offerCount: 0,
    customerConfirmedDone: false,
    artisanConfirmedDone: false,
    createdAt: now,
    expiresAt: now.add(duration.duration),
  );
}

Offer _sampleOffer({
  required String jobId,
  required String artisanId,
  String customerId = 'cust_1',
  double? price = 4500,
  JobPriceType priceType = JobPriceType.fixed,
}) {
  final now = DateTime.now();
  return Offer(
    offerId: Offer.idFor(jobId, artisanId),
    jobId: jobId,
    artisanId: artisanId,
    customerId: customerId,
    artisanName: 'Usta $artisanId',
    professionNameTR: 'Boyacı Ustası',
    experienceYears: 5,
    rating: 4.7,
    totalReviews: 12,
    isVerified: true,
    isPremium: false,
    priceType: priceType,
    price: price,
    note: 'Malzeme dahildir.',
    status: OfferStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Model serileştirme (roundtrip)', () {
    test('Job toMap/fromMap tüm alanları korur', () {
      final job = _sampleJob(urgent: true).copyWith();
      final restored = Job.fromMap('job_x', job.toMap());
      expect(restored.customerId, job.customerId);
      expect(restored.category, job.category);
      expect(restored.province, job.province);
      expect(restored.district, job.district);
      expect(restored.neighborhood, job.neighborhood);
      expect(restored.isUrgent, isTrue);
      expect(restored.priceType, JobPriceType.fixed);
      expect(restored.budget, 5000);
      expect(restored.status, JobStatus.open);
    });

    test('Offer toMap/fromMap ve Keşif Gerekli fiyat tipi', () {
      final offer = _sampleOffer(
        jobId: 'job_x',
        artisanId: 'art_1',
        priceType: JobPriceType.inspection,
        price: null,
      );
      final restored = Offer.fromMap(offer.offerId, offer.toMap());
      expect(restored.priceType, JobPriceType.inspection);
      expect(restored.price, isNull);
      expect(restored.artisanId, 'art_1');
      expect(restored.rating, 4.7);
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

  group('Teklif tekilliği ve offerCount (#1, #3)', () {
    test('aynı usta aynı ilana 2. kez teklif verince tek teklif + sayaç 1', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final offers = MockOfferRepository(db);

      final jobId = await jobs.createJob(_sampleJob());
      await offers.submitOffer(_sampleOffer(jobId: jobId, artisanId: 'art_1'));
      await offers.submitOffer(_sampleOffer(
          jobId: jobId, artisanId: 'art_1', price: 4200)); // güncelleme

      final forJob = await offers
          .watchOffersForJob(jobId: jobId, customerId: 'cust_1')
          .first;
      expect(forJob.length, 1);
      expect(forJob.first.price, 4200);

      final job = await jobs.getJob(jobId);
      expect(job!.offerCount, 1);
    });

    test('farklı ustalar → sayaç artar; geri çekilince azalır (#7)', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final offers = MockOfferRepository(db);

      final jobId = await jobs.createJob(_sampleJob());
      await offers.submitOffer(_sampleOffer(jobId: jobId, artisanId: 'art_1'));
      await offers.submitOffer(_sampleOffer(jobId: jobId, artisanId: 'art_2'));
      expect((await jobs.getJob(jobId))!.offerCount, 2);

      await offers.withdrawOffer(jobId: jobId, artisanUid: 'art_1');
      expect((await jobs.getJob(jobId))!.offerCount, 1);
      final visible = await offers
          .watchOffersForJob(jobId: jobId, customerId: 'cust_1')
          .first;
      expect(visible.length, 1);
      expect(visible.first.artisanId, 'art_2');
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

      // Osmangazi/painter'lar: yeni eklenen + seed (job_seed_1). Nilüfer ve
      // plumber elenmeli.
      expect(feed.every((j) => j.category == 'painter'), isTrue);
      expect(feed.every((j) => j.district == 'Osmangazi'), isTrue);
      expect(feed.any((j) => j.jobId == 'job_seed_1'), isTrue);
    });

    test('acil ilan feed başında gelir', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      // createdAt aynı milisaniyeye denk gelirse sıralama belirsizleşir —
      // deterministik olması için acil (en yeni) ilana açık zaman verilir.
      final now = DateTime.now();
      await jobs.createJob(_sampleJob(
          category: 'welder',
          urgent: false,
          createdAt: now.subtract(const Duration(minutes: 1))));
      await jobs.createJob(
          _sampleJob(category: 'welder', urgent: true, createdAt: now));

      final feed = await jobs.watchNearbyJobs(
        professionCode: 'welder',
        serviceAreas: const [
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
        ],
      ).first;
      expect(feed.first.isUrgent, isTrue);
    });
  });

  group('Yaşam döngüsü (#4, #6, #10, #11)', () {
    test('seçim → workerSelected + accepted/rejected + chatId', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final offers = MockOfferRepository(db);

      final jobId = await jobs.createJob(_sampleJob());
      await offers.submitOffer(_sampleOffer(jobId: jobId, artisanId: 'art_1'));
      await offers.submitOffer(_sampleOffer(jobId: jobId, artisanId: 'art_2'));

      await jobs.selectOffer(
        jobId: jobId,
        offerId: Offer.idFor(jobId, 'art_1'),
        artisanId: 'art_1',
        customerId: 'cust_1',
        chatId: 'chat_abc',
      );

      final job = await jobs.getJob(jobId);
      expect(job!.status, JobStatus.workerSelected);
      expect(job.selectedArtisanId, 'art_1');
      expect(job.chatId, 'chat_abc');

      final all = db.offers.values.where((o) => o.jobId == jobId).toList();
      final accepted = all.firstWhere((o) => o.artisanId == 'art_1');
      final rejected = all.firstWhere((o) => o.artisanId == 'art_2');
      expect(accepted.status, OfferStatus.accepted);
      expect(rejected.status, OfferStatus.rejected);
    });

    test('iki taraflı tamamlama → completed', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());
      await jobs.markStarted(jobId);
      expect((await jobs.getJob(jobId))!.status, JobStatus.inProgress);

      await jobs.confirmDone(jobId: jobId, byCustomer: false);
      final oneSided = (await jobs.getJob(jobId))!;
      expect(oneSided.status, JobStatus.inProgress); // tek taraf
      // Tek taraflı onay otomatik tamamlama süresini başlatır (CF paritesi).
      expect(oneSided.autoCompleteAt, isNotNull);

      await jobs.confirmDone(jobId: jobId, byCustomer: true);
      expect((await jobs.getJob(jobId))!.status, JobStatus.completed);

      await jobs.markRated(jobId);
      expect((await jobs.getJob(jobId))!.status, JobStatus.rated);
    });

    test('iş tamamlanınca seçili ustanın completedJobs sayacı artar', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());
      await jobs.selectOffer(
        jobId: jobId,
        offerId: Offer.idFor(jobId, 'artisan_0'),
        artisanId: 'artisan_0', // seed'de var olan usta
        customerId: 'cust_1',
        chatId: 'chat_x',
      );
      final before = db.artisans['artisan_0']!.profile.completedJobs;

      await jobs.confirmDone(jobId: jobId, byCustomer: true);
      // Tek taraf: sayaç henüz artmaz.
      expect(db.artisans['artisan_0']!.profile.completedJobs, before);

      await jobs.confirmDone(jobId: jobId, byCustomer: false);
      expect((await jobs.getJob(jobId))!.status, JobStatus.completed);
      expect(db.artisans['artisan_0']!.profile.completedJobs, before + 1);

      // rated'a geçiş sayacı İKİNCİ kez artırmaz.
      await jobs.markRated(jobId);
      expect(db.artisans['artisan_0']!.profile.completedJobs, before + 1);
    });

    test('sorun bildir → disputed; geri çek → önceki duruma dönüş', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());
      await jobs.markStarted(jobId);

      await jobs.reportDispute(
        jobId: jobId,
        byCustomer: true,
        reason: JobDisputeReason.qualityIssue,
        note: '  Boya akmış.  ',
      );
      final disputed = (await jobs.getJob(jobId))!;
      expect(disputed.status, JobStatus.disputed);
      expect(disputed.disputedBy, JobDisputeParty.customer);
      expect(disputed.disputeReason, JobDisputeReason.qualityIssue);
      expect(disputed.disputeNote, 'Boya akmış.'); // trim'lenir
      expect(disputed.disputedAt, isNotNull);
      expect(disputed.statusBeforeDispute, JobStatus.inProgress);

      await jobs.withdrawDispute(jobId);
      final restored = (await jobs.getJob(jobId))!;
      expect(restored.status, JobStatus.inProgress);
      expect(restored.disputedBy, isNull);
      expect(restored.disputeReason, isNull);
      expect(restored.disputeNote, isNull);
      expect(restored.statusBeforeDispute, isNull);
    });

    test('açık ilanda veya ikinci kez sorun bildirilemez', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());

      // open: karşı taraf yok → bildirilemez.
      expect(
        () => jobs.reportDispute(
            jobId: jobId,
            byCustomer: true,
            reason: JobDisputeReason.other),
        throwsStateError,
      );

      await jobs.markStarted(jobId);
      await jobs.reportDispute(
          jobId: jobId,
          byCustomer: false,
          reason: JobDisputeReason.paymentIssue);
      // disputed'dayken tekrar bildirilemez.
      expect(
        () => jobs.reportDispute(
            jobId: jobId,
            byCustomer: true,
            reason: JobDisputeReason.other),
        throwsStateError,
      );
      // Şikayet yokken geri çekilemez.
      await jobs.withdrawDispute(jobId);
      expect(() => jobs.withdrawDispute(jobId), throwsStateError);
    });

    test('dispute alanları toMap ile yazılmaz (yalnız repo metodları yazar)',
        () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final jobId = await jobs.createJob(_sampleJob());
      await jobs.markStarted(jobId);
      await jobs.reportDispute(
          jobId: jobId,
          byCustomer: true,
          reason: JobDisputeReason.notCompleted);

      final disputed = (await jobs.getJob(jobId))!;
      final map = disputed.toMap();
      expect(map.containsKey('disputedBy'), isFalse);
      expect(map.containsKey('disputeReason'), isFalse);
      expect(map.containsKey('statusBeforeDispute'), isFalse);

      // fromMap ham Firestore verisinden alanları okuyabilir.
      final parsed = Job.fromMap('j', {
        ...map,
        'status': 'disputed',
        'disputedBy': 'artisan',
        'disputeReason': 'paymentIssue',
        'disputedAt': DateTime.now().toIso8601String(),
        'statusBeforeDispute': 'completed',
      });
      expect(parsed.status, JobStatus.disputed);
      expect(parsed.disputedBy, JobDisputeParty.artisan);
      expect(parsed.disputeReason, JobDisputeReason.paymentIssue);
      expect(parsed.statusBeforeDispute, JobStatus.completed);
    });

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

  group('Hızlı Destek (ayak işleri)', () {
    const areas = [
      ServiceArea(
          province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
    ];

    test('hızlı destek ilanı ilçedeki HER meslekten ustayla eşleşir', () {
      final job = _sampleJob(category: kQuickSupportCategory);
      // Meslek fark etmez: boyacı da, "Diğer" de eşleşir.
      expect(
          job.matchesArtisan(professionCode: 'painter', serviceAreas: areas),
          isTrue);
      expect(
          job.matchesArtisan(
              professionCode: kOtherProfession, serviceAreas: areas),
          isTrue);
      // Ama ilçe eşleşmesi ŞART.
      expect(
        job.matchesArtisan(
          professionCode: 'painter',
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
        ),
        isFalse,
      );
    });

    test('"Diğer" ustası YALNIZCA hızlı destek ilanlarını görür', () async {
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

    test('normal usta feed\'inde kendi mesleği + hızlı destek birlikte görünür',
        () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final quickId =
          await jobs.createJob(_sampleJob(category: kQuickSupportCategory));
      final paintId = await jobs.createJob(_sampleJob(category: 'painter'));
      await jobs.createJob(_sampleJob(category: 'plumber')); // başka meslek

      final feed = await jobs
          .watchNearbyJobs(professionCode: 'painter', serviceAreas: areas)
          .first;
      expect(feed.map((j) => j.jobId), containsAll([quickId, paintId]));
      expect(
          feed.every((j) =>
              j.category == 'painter' ||
              j.category == kQuickSupportCategory),
          isTrue);
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

  group('Keşfet ilan paneli (watchOpenJobs)', () {
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
      // Ustaya bağlanmış ilan pencere içinde bile düzenlenemez.
      final assigned = fresh.copyWith(status: JobStatus.workerSelected);
      expect(assigned.canEditAt(now.add(const Duration(minutes: 5))), isFalse);
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
      db.jobs[id] = job.copyWith(status: JobStatus.workerSelected);
      expect(
        () => repo.updateJobContent(
            jobId: id, title: 'x', description: 'y'),
        throwsStateError,
      );
    });

    test('deleteJob: bağlanmamış ilanı ve tekliflerini siler', () async {
      final db = MockDatabase();
      final jobs = MockJobRepository(db);
      final offers = MockOfferRepository(db);
      final id = await jobs.createJob(_sampleJob());
      await offers.submitOffer(_sampleOffer(jobId: id, artisanId: 'a1'));

      await jobs.deleteJob(id);
      expect(db.jobs.containsKey(id), isFalse);
      // CF paritesi: bağlı teklifler de temizlenir.
      expect(db.offers.values.where((o) => o.jobId == id), isEmpty);
    });

    test('deleteJob: ustaya bağlanmış ilan silinemez', () async {
      final db = MockDatabase();
      final repo = MockJobRepository(db);
      final id = await repo.createJob(_sampleJob());
      db.jobs[id] = db.jobs[id]!.copyWith(status: JobStatus.inProgress);

      expect(() => repo.deleteJob(id), throwsStateError);
      expect(db.jobs.containsKey(id), isTrue);

      // İptal edilen ilan silinebilir.
      db.jobs[id] = db.jobs[id]!.copyWith(status: JobStatus.cancelled);
      await repo.deleteJob(id);
      expect(db.jobs.containsKey(id), isFalse);
    });
  });
}

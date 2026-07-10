import 'dart:async';
import 'dart:math';

import '../models/artisan_profile.dart';
import '../models/availability.dart';
import '../models/favorite.dart';
import '../models/geo_models.dart';
import '../models/job.dart';
import '../models/offer.dart';
import '../models/review.dart';

/// Meslek/kategori kodu → Türkçe ad. Meslekler professions.json ile aynı;
/// `quick_support` yalnızca İLAN kategorisidir (usta mesleği değildir,
/// görüntüleme için burada).
const kProfessionNames = <String, String>{
  'painter': 'Boyacı Ustası',
  'plumber': 'Tesisatçı',
  'electrician': 'Elektrikçi',
  'carpenter': 'Marangoz',
  'tiler': 'Fayansçı',
  'welder': 'Kaynakçı',
  'ac_technician': 'Klima Servisi',
  'locksmith': 'Çilingir',
  'white_goods': 'Beyaz Eşya Tamiri',
  'mover': 'Nakliyat / Evden Eve',
  'gardener': 'Bahçıvan',
  'cleaner': 'Temizlik',
  'other': 'Diğer / Hızlı Destek',
  'quick_support': 'Hızlı Destek',
};

/// Bir ustanın bellek içi kaydı (users + artisanProfiles + reviews birleşimi).
class ArtisanRecord {
  ArtisanRecord({
    required this.uid,
    required this.displayName,
    required this.profile,
    required this.reviews,
    this.profilePhotoUrl,
  });

  String uid;
  String displayName;
  String? profilePhotoUrl;
  ArtisanProfile profile;
  List<Review> reviews;
}

/// Uygulama boyunca yaşayan tek bellek içi "veritabanı". Hem müşteri araması
/// (`MockArtisanRepository`) hem de ustanın kendi profili (`MockMyProfileRepository`)
/// AYNI bu örneği kullanır. Böylece bir usta profilini kaydedince müşteri
/// aramasında da görünür. Firebase gelince bu sınıf Firestore ile değişecek.
class MockDatabase {
  MockDatabase() {
    _seed();
    _seedJobs();
  }

  final Map<String, ArtisanRecord> artisans = {};

  // Çift taraflı pazaryeri koleksiyonları (bellek içi).
  final Map<String, Job> jobs = {};
  final Map<String, Offer> offers = {};
  final Map<String, Favorite> favorites = {};

  /// jobs/offers/favorites değiştiğinde tetiklenir → mock repo'lar akışlarını
  /// yeniden yayar (Firestore snapshot dinleyicisinin bellek içi taklidi).
  final StreamController<void> _tick = StreamController<void>.broadcast();
  Stream<void> get changes => _tick.stream;
  void notify() => _tick.add(null);

  List<ArtisanRecord> get all => artisans.values.toList();

  /// İş sonu değerlendirmesi ekler; aynı müşteri aynı ustayı ikinci kez
  /// değerlendirirse MEVCUT kaydı günceller (Firestore kural paritesi:
  /// müşteri başına usta başına tek döküman). Ortalama puanı CF
  /// `onReviewWritten` gibi delta ile işler. Döner: true = yeni eklendi,
  /// false = mevcut kayıt güncellendi.
  bool addReview({
    required String artisanUid,
    required String customerUid,
    required String customerName,
    required int rating,
    required List<String> tags,
  }) {
    final rec = artisans[artisanUid];
    if (rec == null) throw StateError('artisan-not-found');
    final p = rec.profile;
    final old =
        rec.reviews.where((r) => r.customerUid == customerUid).firstOrNull;
    final review = Review(
      id: old?.id ?? 'rev_${DateTime.now().millisecondsSinceEpoch}',
      artisanUid: artisanUid,
      customerUid: customerUid,
      customerDisplayName: customerName,
      chatId: '',
      rating: rating,
      tags: tags,
      createdAt: DateTime.now(),
    );

    if (old != null) {
      // Güncelleme: sayaç sabit, toplam eski−yeni farkı kadar oynar;
      // güncellenen kayıt listenin başına çıkar (en yeni önce).
      rec.reviews = [review, ...rec.reviews.where((r) => r != old)];
      final totalRatingSum = p.totalRatingSum - old.rating + rating;
      rec.profile = p.copyWithRating(
        averageRating:
            p.totalReviews > 0 ? totalRatingSum / p.totalReviews : 0,
        totalReviews: p.totalReviews,
        totalRatingSum: totalRatingSum,
      );
      return false;
    }

    rec.reviews = [review, ...rec.reviews];
    final totalReviews = p.totalReviews + 1;
    final totalRatingSum = p.totalRatingSum + rating;
    rec.profile = p.copyWithRating(
      averageRating: totalRatingSum / totalReviews,
      totalReviews: totalReviews,
      totalRatingSum: totalRatingSum,
    );
    return true;
  }

  /// İş `completed` olduğunda usta sayacını artırır (CF `onJobWritten` paritesi).
  void incrementCompletedJobs(String artisanUid) {
    final rec = artisans[artisanUid];
    if (rec == null) return;
    final p = rec.profile;
    rec.profile = p.copyWithRating(
      averageRating: p.averageRating,
      totalReviews: p.totalReviews,
      totalRatingSum: p.totalRatingSum,
      completedJobs: p.completedJobs + 1,
    );
  }

  /// Ustanın kendi profilini kaydeder/günceller (upsert). Puanlama alanları
  /// profilde korunur; displayName/foto users tarafından gelir.
  void upsertArtisan({
    required String uid,
    required String displayName,
    String? profilePhotoUrl,
    required ArtisanProfile profile,
  }) {
    final existing = artisans[uid];
    artisans[uid] = ArtisanRecord(
      uid: uid,
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      profile: profile,
      reviews: existing?.reviews ?? const [],
    );
  }

  // ---- Demo tohumu ----

  static const _firstNames = [
    'Ahmet', 'Mehmet', 'Mustafa', 'Hasan', 'Hüseyin', 'İbrahim', 'Ali',
    'Osman', 'Yusuf', 'Murat', 'Kemal', 'Recep', 'Salih', 'Fatih', 'Kadir',
  ];
  static const _lastNames = [
    'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldız', 'Aydın', 'Öztürk',
    'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç',
  ];

  // Genel demo verisi bölge havuzu (JSON'daki gerçek il/ilçe adları).
  static const _generalAreas = <ServiceArea>[
    ServiceArea(province: 'Bursa', district: 'Nilüfer', neighborhood: 'Beşevler'),
    ServiceArea(province: 'Bursa', district: 'Yıldırım', neighborhood: 'Mevlana'),
    ServiceArea(province: 'Bursa', district: 'Osmangazi', neighborhood: 'Çekirge'),
    ServiceArea(province: 'İstanbul', district: 'Kadıköy', neighborhood: 'Caferağa'),
    ServiceArea(province: 'Ankara', district: 'Çankaya', neighborhood: 'Kızılay'),
    ServiceArea(province: 'İzmir', district: 'Konak', neighborhood: 'Alsancak'),
  ];

  void _seed() {
    final rnd = Random(42); // sabit tohum → tekrarlanabilir demo verisi

    // 25 boyacı: Bursa > Osmangazi > Dikkaldırım (sayfalama + sıralama demosu).
    for (int i = 0; i < 25; i++) {
      _add(
        rnd: rnd,
        index: i,
        professionCode: 'painter',
        areas: const [
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
          ServiceArea(
              province: 'Bursa', district: 'Osmangazi', neighborhood: 'Çekirge'),
        ],
        rating: double.parse((3.0 + rnd.nextDouble() * 2.0).toStringAsFixed(1)),
        reviewCount: 3 + rnd.nextInt(40),
        isPremium: i < 4,
        // Yeni temel kural: müşteri yalnızca müsait ustaları görür → demo
        // ustaları müsait tohumlanır.
        available: true,
        isNew: i >= 23,
      );
    }

    _add(
      rnd: rnd, index: 100, professionCode: 'plumber',
      areas: const [
        ServiceArea(province: 'Bursa', district: 'Nilüfer', neighborhood: 'Beşevler'),
      ],
      rating: 4.8, reviewCount: 56, isPremium: true, available: true, isNew: false,
    );
    _add(
      rnd: rnd, index: 101, professionCode: 'electrician',
      areas: const [
        ServiceArea(province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım'),
      ],
      rating: 4.2, reviewCount: 18, isPremium: false, available: true, isNew: false,
    );

    // Genel veri: HER meslekten, birden fazla il/ilçede ustalar. Böylece
    // kullanıcı hangi meslek/bölgeyi seçerse seçsin sonuç bulur.
    // `quick_support` ilan kategorisidir, usta mesleği DEĞİL → seed'e girmez.
    var idx = 200;
    for (final prof in kProfessionNames.keys) {
      if (prof == kQuickSupportCategory) continue;
      for (var j = 0; j < 6; j++) {
        final area = _generalAreas[idx % _generalAreas.length];
        _add(
          rnd: rnd,
          index: idx,
          professionCode: prof,
          areas: [area],
          rating: double.parse((3.2 + rnd.nextDouble() * 1.8).toStringAsFixed(1)),
          reviewCount: 2 + rnd.nextInt(60),
          isPremium: j < 2,
          available: true,
          isNew: j == 5,
        );
        idx++;
      }
    }
  }

  void _add({
    required Random rnd,
    required int index,
    required String professionCode,
    required List<ServiceArea> areas,
    required double rating,
    required int reviewCount,
    required bool isPremium,
    required bool available,
    required bool isNew,
  }) {
    final uid = 'artisan_$index';
    final name =
        '${_firstNames[index % _firstNames.length]} ${_lastNames[(index * 3) % _lastNames.length]}';
    final experience = 2 + rnd.nextInt(25);

    final profile = ArtisanProfile(
      uid: uid,
      profession: professionCode,
      experienceYears: experience,
      aboutText:
          '$experience yıldır ${kProfessionNames[professionCode]} olarak '
          'çalışıyorum. Temiz, hızlı ve garantili iş yaparım.',
      serviceAreas: areas,
      certificates: const [],
      workPhotos: const [],
      isVerified: isPremium || rnd.nextBool(),
      averageRating: rating,
      totalReviews: reviewCount,
      totalRatingSum: (rating * reviewCount).round(),
      isPremium: isPremium,
      premiumExpiresAt:
          isPremium ? DateTime.now().add(const Duration(days: 20)) : null,
      alwaysAvailable: available,
      manualPause: !available,
      weeklySchedule: WeeklySchedule.empty(),
      createdAt: DateTime.now().subtract(Duration(days: isNew ? 5 : 200)),
    );

    artisans[uid] = ArtisanRecord(
      uid: uid,
      displayName: name,
      profile: profile,
      reviews: _buildReviews(uid, min(reviewCount, 5), rnd),
    );
  }

  /// Usta feed'i boş görünmesin diye birkaç örnek açık ilan. Demo müşterisi
  /// `seed_customer`. Bölgeler `_generalAreas` + Dikkaldırım ile örtüşür ki
  /// tohumlanan ustaların feed'ine düşsün.
  void _seedJobs() {
    final now = DateTime.now();
    final samples = <Job>[
      _seedJob(
        id: 'job_seed_1',
        title: 'Salon duvarları boyanacak',
        description:
            'Yaklaşık 120 m² salon ve koridor duvarlarının boyanması gerekiyor. '
            'Boya bize ait olabilir, işçilik teklifinizi bekliyorum.',
        category: 'painter',
        province: 'Bursa',
        district: 'Osmangazi',
        neighborhood: 'Dikkaldırım',
        createdAgo: const Duration(hours: 3),
        duration: JobDuration.day3,
        isUrgent: false,
        priceType: JobPriceType.fixed,
        budget: 5000,
        offerCount: 0,
      ),
      _seedJob(
        id: 'job_seed_2',
        title: 'Mutfak bataryası su sızdırıyor',
        description:
            'Mutfak evyesinin bataryası damlatıyor. Aynı gün gelinebilirse çok iyi olur.',
        category: 'plumber',
        province: 'Bursa',
        district: 'Osmangazi',
        neighborhood: 'Dikkaldırım',
        createdAgo: const Duration(minutes: 20),
        duration: JobDuration.day1,
        isUrgent: true,
        priceType: JobPriceType.inspection,
        budget: null,
        offerCount: 0,
      ),
      _seedJob(
        id: 'job_seed_3',
        title: 'Klima bakımı ve gaz kontrolü',
        description: 'Salon tipi klimanın periyodik bakımı ve gaz kontrolü.',
        category: 'ac_technician',
        province: 'İstanbul',
        district: 'Kadıköy',
        neighborhood: 'Caferağa',
        createdAgo: const Duration(days: 1),
        duration: JobDuration.day7,
        isUrgent: false,
        priceType: JobPriceType.fixed,
        budget: 1200,
        offerCount: 0,
      ),
    ];
    for (final j in samples) {
      jobs[j.jobId] = j;
    }
    // now referansı kullanılıyor (analyzer memnuniyeti için gereksiz değil).
    assert(samples.every((j) => j.expiresAt.isAfter(now.subtract(
        const Duration(days: 30)))));
  }

  Job _seedJob({
    required String id,
    required String title,
    required String description,
    required String category,
    required String province,
    required String district,
    required String? neighborhood,
    required Duration createdAgo,
    required JobDuration duration,
    required bool isUrgent,
    required JobPriceType priceType,
    required double? budget,
    required int offerCount,
  }) {
    final createdAt = DateTime.now().subtract(createdAgo);
    return Job(
      jobId: id,
      customerId: 'seed_customer',
      customerName: 'Demo Müşteri',
      title: title,
      description: description,
      category: category,
      province: province,
      district: district,
      neighborhood: neighborhood,
      photos: const [],
      isUrgent: isUrgent,
      priceType: priceType,
      budget: budget,
      status: JobStatus.open,
      offerCount: offerCount,
      customerConfirmedDone: false,
      artisanConfirmedDone: false,
      createdAt: createdAt,
      expiresAt: createdAt.add(duration.duration),
    );
  }

  List<Review> _buildReviews(String artisanUid, int count, Random rnd) {
    return List.generate(count, (i) {
      final t1 = ReviewTags.positive[i % ReviewTags.positive.length];
      final t2 = ReviewTags.positive[(i + 3) % ReviewTags.positive.length];
      return Review(
        id: '${artisanUid}_rev_$i',
        artisanUid: artisanUid,
        customerUid: 'cust_$i',
        customerDisplayName: _firstNames[(i + 2) % _firstNames.length],
        chatId: 'chat_$i',
        rating: 4 + (rnd.nextBool() ? 1 : 0),
        tags: rnd.nextBool() ? [t1, t2] : [t1],
        createdAt: DateTime.now().subtract(Duration(days: i * 7 + 1)),
      );
    });
  }
}

import 'dart:async';
import 'dart:math';

import '../models/app_user.dart';
import '../models/artisan_profile.dart';
import '../models/availability.dart';
import '../models/favorite.dart';
import '../models/geo_models.dart';
import '../models/job.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../models/user_role.dart';

/// Meslek/kategori kodu → Türkçe ad. professions.json ile senkron tut.
/// `quick_support` ilan kategorisi; usta tarafında `other` kodu = Hemen Lazım.
const kProfessionNames = <String, String>{
  'painter': 'Boyacı',
  'plumber': 'Tesisatçı / Su Tesisatı',
  'electrician': 'Elektrikçi',
  'carpenter': 'Marangoz / Mobilyacı',
  'tiler': 'Fayans / Seramik Ustası',
  'welder': 'Kaynakçı',
  'ac_technician': 'Klima / Soğutma',
  'locksmith': 'Çilingir',
  'white_goods': 'Beyaz Eşya Servisi',
  'mover': 'Nakliyat / Evden Eve',
  'gardener': 'Bahçıvan / Peyzaj',
  'cleaner': 'Temizlik',
  'roofer': 'Çatı / Oluk Ustası',
  'plasterer': 'Sıvacı / Alçıpan',
  'mason': 'Duvarcı / Kaba İnşaat',
  'reinforcement': 'Demirci / İnşaat Demiri',
  'formwork': 'Kalıpçı',
  'concrete': 'Betoncu',
  'insulation': 'Yalıtım / İzolasyon',
  'waterproofing': 'Su Yalıtımı',
  'painter_deco': 'Dekoratif Boya / Kartonpiyer',
  'epoxy': 'Epoksi / Zemin Kaplama',
  'parquet': 'Parke / Laminat',
  'glass': 'Camcı / Duşakabin',
  'aluminum': 'Alüminyum Doğrama',
  'pvc_window': 'PVC Pencere / Kapı',
  'steel_door': 'Çelik Kapı',
  'shutter': 'Panjur / Kepenk',
  'awning': 'Tente / Pergola',
  'curtain': 'Perde / Stor',
  'upholstery': 'Döşemeci',
  'furniture_assembly': 'Mobilya Montaj',
  'kitchen_cabinet': 'Mutfak Dolabı',
  'wardrobe': 'Giyinme Odası / Ray Dolap',
  'ironwork': 'Demir Doğrama / Korkuluk',
  'auto_mechanic': 'Oto Tamir / Mekanik',
  'auto_electric': 'Oto Elektrik',
  'auto_body': 'Kaporta / Boya',
  'auto_glass': 'Oto Cam',
  'tire': 'Lastikçi',
  'auto_detail': 'Oto Kuaför / Detay',
  'boiler': 'Kombi / Kalorifer',
  'natural_gas': 'Doğalgaz Tesisatı',
  'solar': 'Güneş Enerjisi / Panel',
  'generator': 'Jeneratör',
  'elevator': 'Asansör Bakım',
  'security_cam': 'Güvenlik Kamerası',
  'satellite': 'Uydu / Anten',
  'network': 'Network / Kablolama',
  'smart_home': 'Akıllı Ev Sistemleri',
  'phone_repair': 'Telefon / Tablet Tamiri',
  'computer': 'Bilgisayar Teknik Servis',
  'tv_repair': 'TV / Elektronik Tamir',
  'printer': 'Yazıcı / Fotokopi Servisi',
  'sewing': 'Terzi / Dikiş',
  'shoe_repair': 'Ayakkabı Tamiri',
  'key_copy': 'Anahtar Kopyalama',
  'pest_control': 'İlaçlama / Haşere',
  'pool': 'Havuz Bakım',
  'sauna': 'Sauna / Hamam Tesisatı',
  'marble': 'Mermer / Granit',
  'stone': 'Taş / Traverten',
  'excavation': 'Hafriyat / Kepçe',
  'demolition': 'Yıkım / Kırım',
  'scaffolding': 'İskele Kurulum',
  'crane': 'Vinç / Kaldırma',
  'welding_tig': 'Argon / TIG Kaynak',
  'cnc': 'CNC / Torna',
  'lathe': 'Tornacı',
  'blacksmith': 'Nalbant / Nalbur İşleri',
  'signage': 'Tabela / Reklam',
  'printing': 'Matbaa / Baskı',
  'photographer': 'Fotoğrafçı',
  'videographer': 'Video / Düğün Çekimi',
  'dj': 'DJ / Ses Sistemi',
  'event': 'Organizasyon / Etkinlik',
  'catering': 'Catering / Yemek',
  'waiter_event': 'Garson / Etkinlik Personeli',
  'babysitter': 'Bebek Bakımı',
  'elder_care': 'Yaşlı Bakımı',
  'nurse_home': 'Hemşire (Evde Sağlık)',
  'tutor': 'Özel Ders / Öğretmen',
  'language': 'Dil Eğitmeni',
  'music_teacher': 'Müzik Dersi',
  'driving': 'Sürücü / Şoför',
  'courier': 'Kurye / Paket',
  'pet_grooming': 'Pet Kuaför',
  'vet_visit': 'Evde Veteriner Desteği',
  'dog_walker': 'Köpek Gezdirme',
  'barber': 'Berber (Ev / Mobil)',
  'hairdresser': 'Kuaför (Ev / Mobil)',
  'makeup': 'Makyaj / Güzellik',
  'nail': 'Nail Art / Manikür',
  'massage': 'Masaj / Spa',
  'physiotherapy': 'Fizyoterapi (Ev)',
  'lawyer_consult': 'Avukat / Hukuki Danışmanlık',
  'accountant': 'Muhasebeci / Mali Müşavir',
  'real_estate': 'Emlak Danışmanı',
  'insurance': 'Sigorta Danışmanı',
  'translation': 'Tercüman',
  'notary_assist': 'Noter / Evrak Takibi',
  // Profesyonel hizmetler + sağlık/eğitim genişlemesi (2026-08-10).
  'architect': 'Mimar',
  'interior_arch': 'İç Mimar / Dekorasyon',
  'surveyor': 'Bilirkişi / Ekspertiz',
  'web_dev': 'Web / Yazılım',
  'graphic': 'Grafik Tasarım',
  'social_media': 'Sosyal Medya Yönetimi',
  'psychologist': 'Psikolog / Terapist',
  'dietitian': 'Diyetisyen',
  'personal_trainer': 'Kişisel Antrenör',
  'speech_therapy': 'Dil ve Konuşma Terapisti',
  'exam_prep': 'Sınav Hazırlık',
  'coding_course': 'Kodlama Eğitmeni',
  'appliance_install': 'Beyaz Eşya Montaj',
  'chandelier': 'Avize / Aydınlatma Montaj',
  'curtain_rail': 'Korniş / Perde Rayı',
  'wallpaper': 'Duvar Kağıdı',
  'blind': 'Jaluzi / Zebra Perde',
  'carpet_wash': 'Halı / Koltuk Yıkama',
  'chimney': 'Baca Temizliği',
  'septic': 'Foseptik / Kanalizasyon',
  'well': 'Su Kuyusu / Sondaj',
  'irrigation': 'Sulama Sistemi',
  'fence_wood': 'Ahşap Çit / Kamelya',
  'paving': 'Parke Taşı / Bordür',
  'asphalt': 'Asfalt / Yol',
  'welding_mobile': 'Seyyar Kaynak',
  'battery': 'Akü / Yol Yardım',
  'towing': 'Çekici',
  'motorcycle': 'Motosiklet Tamir',
  'bike': 'Bisiklet Tamir',
  'boat': 'Tekne / Deniz Motoru',
  'agricultural': 'Tarım Makinesi',
  'sewing_machine': 'Dikiş Makinesi Servisi',
  'water_heater': 'Şofben / Termosifon',
  'water_softener': 'Su Arıtma / Softener',
  'fire_safety': 'Yangın Güvenliği',
  'lightning': 'Paratoner',
  'drain': 'Lavabo / Gider Açma',
  'leak_detect': 'Su Kaçağı Tespiti',
  'power_line': 'Elektrik Tesisatı (Bina)',
  'generator_install': 'Jeneratör Montaj',
  'ups': 'UPS / Kesintisiz Güç',
  'other': 'Kolay İş',
  'quick_support': 'Kolay İş',
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
  /// [withDemoPersonas]: mağaza ekran görüntüsü seti (10 persona + ilan + ürün
  /// + favori). Varsayılan `false` — normal mock davranışı ve mevcut testlerin
  /// gördüğü tohum BİREBİR korunur. Yalnız demo akışı `true` geçer.
  /// Ayrıntı: `vault/06-Test/Demo-Veri-Seti.md`.
  MockDatabase({bool withDemoPersonas = false}) {
    _seed();
    _seedJobs();
    if (withDemoPersonas) {
      _seedDemoPersonas();
      _seedDemoJobs();
      _seedDemoProducts();
      _seedDemoFavorites();
    }
  }

  final Map<String, ArtisanRecord> artisans = {};

  // Çift taraflı pazaryeri koleksiyonları (bellek içi).
  final Map<String, Job> jobs = {};
  final Map<String, Favorite> favorites = {};

  /// Mağaza ürün vitrini. Ürün modülü 2026-08-08'de kaldırılmış, 2026-08-10'da
  /// Mağaza olarak geri getirilmiştir — bkz. `vault/06-Test/PLAN-Magaza.md`.
  final Map<String, Product> products = {};

  /// Demo personaların herkese açık kullanıcı kayıtları (`users/{uid}`
  /// karşılığı). Yalnız `withDemoPersonas: true` ile dolar.
  /// [publicUser] üzerinden `MockAuthRepository`'ye beslenir.
  final Map<String, AppUser> demoUsers = {};

  /// uid → herkese açık kullanıcı. Firestore'da `users/{uid}` HERKESE AÇIK
  /// okunur (CLAUDE.md kural 5); mock bunu taklit etmediği için "başkasının
  /// profili" akışları bellek içi çalışmıyordu. Bu yardımcı o pariteyi kurar:
  /// önce demo kayıtlarına, sonra usta kayıtlarına bakar.
  AppUser? publicUser(String uid) {
    final u = demoUsers[uid];
    if (u != null) return u;
    final rec = artisans[uid];
    if (rec == null) return null;
    return AppUser(
      uid: uid,
      displayName: rec.displayName,
      email: '',
      createdAt: rec.profile.createdAt,
      profilePhotoUrl: rec.profilePhotoUrl,
      hasArtisanProfile: true,
      activeMode: UserRole.artisan,
      aboutText: rec.profile.aboutText,
      available: rec.profile.alwaysAvailable && !rec.profile.manualPause,
    );
  }

  /// jobs/favorites değiştiğinde tetiklenir → mock repo'lar akışlarını
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
        topTags: _computeTopTags(rec.reviews),
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
      topTags: _computeTopTags(rec.reviews),
    );
    return true;
  }

  /// Bir ustanın tüm değerlendirmelerinden en sık 3 OLUMLU etiketi türetir
  /// (CF `onReviewWritten` → topTags paritesi). Olumsuz etiketler sayılmaz.
  List<String> _computeTopTags(Iterable<Review> reviews) {
    final counts = <String, int>{};
    for (final r in reviews) {
      for (final t in r.tags) {
        if (ReviewTags.isNegative(t)) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(3)) e.key];
  }

  /// İş `completed` olduğunda usta sayacını artırır (CF `onJobWritten` paritesi).
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
    // ---- Demo persona genişlemesi (ekran görüntüsü seti) ----
    // Hepsi opsiyonel; verilmezse yukarıdaki üretilmiş değerler kullanılır,
    // yani mevcut çağrıların davranışı değişmez.
    String? uidOverride,
    String? nameOverride,
    String? aboutOverride,
    String? photoHandle,
    List<String> workPhotos = const [],
    int? experienceOverride,
    List<String>? topTagsOverride,
  }) {
    final uid = uidOverride ?? 'artisan_$index';
    final name = nameOverride ??
        '${_firstNames[index % _firstNames.length]} ${_lastNames[(index * 3) % _lastNames.length]}';
    final experience = experienceOverride ?? (2 + rnd.nextInt(25));

    final profile = ArtisanProfile(
      uid: uid,
      profession: professionCode,
      experienceYears: experience,
      // Hemen Lazım bir meslek değil ("... Hemen Lazım olarak çalışıyorum"
      // anlamsız olurdu) → ona ayrı bir tanıtım metni.
      aboutText: aboutOverride ??
          (professionCode == kOtherProfession
              ? 'Market, taşıma, kısa gidiş gibi işlerde yardımcı oluyorum. '
                  'Hızlı dönüş yaparım.'
              : '$experience yıldır ${kProfessionNames[professionCode]} olarak '
                  'çalışıyorum. Temiz, hızlı ve garantili iş yaparım.'),
      serviceAreas: areas,
      certificates: const [],
      workPhotos: workPhotos,
      isVerified: isPremium || rnd.nextBool(),
      // Demo: bir kısmında e-posta da doğrulu → çift doğrulama tooltip'i.
      emailVerified: isPremium || rnd.nextBool(),
      averageRating: rating,
      totalReviews: reviewCount,
      totalRatingSum: (rating * reviewCount).round(),
      // Demo: puanı iyi + yorumu olan ustalarda kart rozetleri dolu görünsün.
      // Gerçekte CF (onReviewWritten) besler; burada deterministik üretilir.
      topTags: topTagsOverride ??
          ((reviewCount > 0 && rating >= 3.8)
              ? _demoTopTags(index)
              : const []),
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
      profilePhotoUrl: photoHandle,
      profile: profile,
      reviews: _buildReviews(uid, min(reviewCount, 5), rnd),
    );
  }

  /// Demo için deterministik "en sık etiketler" (2-3 olumlu). Gerçekte CF
  /// tagCounts'tan türetir; burada [index]'e göre sabit bir seçim yapılır ki
  /// her açılışta aynı usta aynı rozetleri göstersin.
  List<String> _demoTopTags(int index) {
    const pos = ReviewTags.positive;
    final count = 2 + (index % 2); // 2 veya 3 etiket
    final start = index % pos.length;
    return [
      for (var i = 0; i < count; i++) pos[(start + i) % pos.length],
    ];
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
        priceType: JobPriceType.fixed,
        budget: 5000,
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
        priceType: JobPriceType.inspection,
        budget: null,
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
        priceType: JobPriceType.fixed,
        budget: 1200,
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
    required JobPriceType priceType,
    required double? budget,
    String customerId = 'seed_customer',
    String customerName = 'Demo Müşteri',
  }) {
    final createdAt = DateTime.now().subtract(createdAgo);
    return Job(
      jobId: id,
      customerId: customerId,
      customerName: customerName,
      title: title,
      description: description,
      category: category,
      province: province,
      district: district,
      neighborhood: neighborhood,
      photos: const [],
      priceType: priceType,
      budget: budget,
      status: JobStatus.open,
      createdAt: createdAt,
      expiresAt: createdAt.add(duration.duration),
    );
  }

  // ==========================================================================
  // DEMO PERSONA SETİ — mağaza ekran görüntüleri için
  //
  // Yalnız `MockDatabase(withDemoPersonas: true)` ile üretilir; varsayılan
  // kurucu bu bloğa hiç girmez → mevcut testlerin gördüğü tohum değişmez.
  //
  // Bölge seçimi kasıtlı: hiçbir persona Bursa/Osmangazi/Dikkaldırım'a veya
  // `_generalAreas` kombinasyonlarına konmadı, çünkü `artisan_search_test`
  // o bölgelerde TAM sayı bekliyor (ilk sayfa 20, yeni usta 2).
  // Ayrıntı: `vault/06-Test/Demo-Veri-Seti.md`.
  // ==========================================================================

  /// Demo görselinin bellek içi depo handle'ı. `AppImage` `local://` dalını
  /// zaten destekler (app_image.dart:52) → UI kodu değişmeden fotoğraf çıkar.
  /// Görsel yoksa handle boşa düşer ve baş harf rozeti görünür.
  static String demoPhoto(String kind, String name) =>
      'local://demo/$kind/$name';

  /// Ekran görüntüsü setindeki 10 persona. Usta olanlar [artisans]'a,
  /// hepsi (yalnız müşteri olanlar dahil) [demoUsers]'a yazılır.
  void _seedDemoPersonas() {
    final rnd = Random(7); // demo seti için ayrı sabit tohum

    void persona({
      required int index,
      required String uid,
      required String name,
      required String profession,
      required List<ServiceArea> areas,
      required double rating,
      required int reviewCount,
      required int experience,
      required String about,
      required bool premium,
      List<String> workPhotos = const [],
      List<String>? topTags,
    }) {
      _add(
        rnd: rnd,
        index: index,
        professionCode: profession,
        areas: areas,
        rating: rating,
        reviewCount: reviewCount,
        isPremium: premium,
        available: true,
        isNew: false,
        uidOverride: uid,
        nameOverride: name,
        aboutOverride: about,
        photoHandle: demoPhoto('avatar', uid),
        workPhotos: workPhotos,
        experienceOverride: experience,
        topTagsOverride: topTags,
      );
    }

    persona(
      index: 900,
      uid: 'demo_kerem',
      name: 'Kerem Alptekin',
      profession: 'painter',
      areas: const [
        ServiceArea(province: 'Bursa', district: 'Nilüfer', neighborhood: 'Ertuğrul'),
        ServiceArea(province: 'Bursa', district: 'Nilüfer', neighborhood: 'Görükle'),
      ],
      rating: 4.9,
      reviewCount: 87,
      experience: 14,
      about: '14 yıldır iç ve dış cephe boya işi yapıyorum. Silinebilir boya, '
          'dekoratif uygulama ve alçı tamiri dahil. İşe başlamadan mobilyanızı '
          'örtüyor, çıkarken temiz teslim ediyorum. Bursa geneli aynı gün keşif.',
      premium: true,
      workPhotos: [
        demoPhoto('work', 'work_painter_1'),
        demoPhoto('work', 'work_painter_2'),
        demoPhoto('work', 'work_painter_3'),
      ],
      topTags: const ['Temiz işçilik', 'Zamanında geldi', 'Güler yüzlü'],
    );

    persona(
      index: 901,
      uid: 'demo_sevil',
      name: 'Sevil Karaduman',
      profession: 'interior_arch',
      areas: const [
        ServiceArea(province: 'İstanbul', district: 'Beşiktaş', neighborhood: 'Levent'),
        ServiceArea(province: 'İstanbul', district: 'Şişli', neighborhood: 'Mecidiyeköy'),
      ],
      rating: 5.0,
      reviewCount: 42,
      experience: 9,
      about: 'İç mimarım. Anahtar teslim daire ve ofis projeleri, mutfak-banyo '
          'yenileme, mobilya seçimi yapıyorum. Önce 3D görselini gösteriyorum, '
          'onayınızı almadan işe başlamıyorum. Kendi tasarladığım aksesuarları '
          'da mağazamdan satıyorum.',
      premium: true,
      workPhotos: [
        demoPhoto('work', 'work_interior_1'),
        demoPhoto('work', 'work_interior_2'),
      ],
      topTags: const ['Profesyonel', 'Kaliteli işçilik', 'Net anlattı'],
    );

    persona(
      index: 902,
      uid: 'demo_okan',
      name: 'Okan Beyazıt',
      profession: 'plumber',
      areas: const [
        ServiceArea(province: 'Ankara', district: 'Keçiören', neighborhood: 'Kalaba'),
      ],
      rating: 4.7,
      reviewCount: 63,
      experience: 21,
      about: '21 yıllık tesisatçıyım. Kırmadan su kaçağı tespiti, kombi '
          'bağlantısı, gider açma ve komple tesisat yenileme yapıyorum. '
          'Acil çağrılara gece gündüz çıkıyorum. Malzemeyi mağazamdan uygun veriyorum.',
      premium: false,
      topTags: const ['Hızlı çözüm', 'Güvenilir', 'Uygun fiyat'],
    );

    persona(
      index: 903,
      uid: 'demo_tolga',
      name: 'Tolga Şenyurt',
      profession: 'electrician',
      areas: const [
        ServiceArea(province: 'İstanbul', district: 'Ümraniye', neighborhood: 'Atakent'),
      ],
      rating: 4.6,
      reviewCount: 38,
      experience: 11,
      about: 'Elektrik tesisatı, priz-anahtar, avize montajı ve sigorta panosu '
          'yenileme yapıyorum. Elektrik mühendisliği mezunuyum, iş güvenliği '
          'sertifikam var. Ümraniye ve çevresine hizmet veriyorum.',
      premium: true,
      topTags: const ['Profesyonel', 'Güvenilir'],
    );

    persona(
      index: 904,
      uid: 'demo_ayse',
      name: 'Ayşe Nur Tunç',
      profession: 'cleaner',
      areas: const [
        ServiceArea(province: 'Ankara', district: 'Çankaya', neighborhood: 'Bahçelievler'),
      ],
      rating: 4.8,
      reviewCount: 124,
      experience: 7,
      about: 'Ev, ofis ve inşaat sonrası detaylı temizlik yapıyorum. Kendi '
          'ekipmanım ve hipoalerjenik ürünlerimle geliyorum. Haftalık veya '
          'aylık düzenli anlaşma da yapıyorum.',
      premium: false,
      topTags: const ['Temiz işçilik', 'Güler yüzlü', 'Zamanında geldi'],
    );

    persona(
      index: 905,
      uid: 'demo_burak',
      name: 'Burak Yalçınkaya',
      profession: 'ac_technician',
      areas: const [
        ServiceArea(province: 'İzmir', district: 'Bornova', neighborhood: 'Kazımdirik'),
      ],
      rating: 4.4,
      reviewCount: 19,
      experience: 5,
      about: 'Klima montajı, bakımı, gaz dolumu ve arıza tespiti yapıyorum. '
          'Tüm markalarda çalışıyorum. Bornova ve çevresine 2 saat içinde '
          'ulaşıyorum, montajda 2 yıl garanti veriyorum.',
      premium: false,
      topTags: const ['Hızlı çözüm', 'Uygun fiyat'],
    );

    persona(
      index: 906,
      uid: 'demo_hatice',
      name: 'Hatice Gülbahar',
      profession: 'photographer',
      areas: const [
        ServiceArea(province: 'Antalya', district: 'Muratpaşa', neighborhood: 'Lara'),
      ],
      rating: 5.0,
      reviewCount: 31,
      experience: 6,
      about: 'Düğün, nişan, doğum günü ve ürün fotoğrafçılığı yapıyorum. '
          'Antalya ve çevresinde çekim yapıyor, tüm kareleri rötuşlu teslim '
          'ediyorum. Aynı gün önizleme gönderirim.',
      premium: true,
      topTags: const ['Profesyonel', 'Güler yüzlü', 'Kaliteli işçilik'],
    );

    persona(
      index: 907,
      uid: 'demo_serkan',
      name: 'Serkan Doğanay',
      profession: 'carpenter',
      areas: const [
        ServiceArea(province: 'Bursa', district: 'Gemlik', neighborhood: 'Osmaniye'),
      ],
      rating: 4.5,
      reviewCount: 52,
      experience: 17,
      about: 'Marangozum. Ölçüye özel mutfak dolabı, gardırop, TV ünitesi ve '
          'ahşap masa yapıyorum. Atölyem Gemlik\'te, montajı kendim yapıyorum. '
          'Hazır ürünlerimi de mağazamdan satıyorum.',
      premium: false,
      workPhotos: [
        demoPhoto('work', 'work_carpenter_1'),
        demoPhoto('work', 'work_carpenter_2'),
      ],
      topTags: const ['Kaliteli işçilik', 'Temiz işçilik'],
    );

    persona(
      index: 908,
      uid: 'demo_elif',
      name: 'Elif Sarıkaya',
      profession: 'tiler',
      areas: const [
        ServiceArea(province: 'Kocaeli', district: 'İzmit', neighborhood: 'Yahyakaptan'),
      ],
      rating: 4.9,
      reviewCount: 71,
      experience: 12,
      about: 'Fayans, seramik, mermer ve doğal taş uygulaması yapıyorum. '
          'Banyo ve mutfak komple yenileme işlerinde su yalıtımını da dahil '
          'ediyorum, sonradan sorun çıkmıyor. Kocaeli geneli çalışıyorum.',
      premium: true,
      workPhotos: [
        demoPhoto('work', 'work_tiler_1'),
        demoPhoto('work', 'work_tiler_2'),
      ],
      topTags: const ['Temiz işçilik', 'Güvenilir', 'Zamanında geldi'],
    );

    // Ustaların herkese açık kullanıcı kayıtları (users/{uid} karşılığı).
    for (final rec in artisans.values) {
      if (!rec.uid.startsWith('demo_')) continue;
      final shop = _demoShopCategories[rec.uid];
      demoUsers[rec.uid] = AppUser(
        uid: rec.uid,
        displayName: rec.displayName,
        email: '',
        createdAt: rec.profile.createdAt,
        profilePhotoUrl: rec.profilePhotoUrl,
        hasArtisanProfile: true,
        activeMode: UserRole.artisan,
        phoneVerified: true,
        aboutText: rec.profile.aboutText,
        available: true,
        hasShopProfile: shop != null,
        shopCategories: shop ?? const [],
      );
    }

    // Zeynep YALNIZ müşteri — usta profili yok, bu yüzden `artisans`'a girmez.
    // "Rol ayrımı yok" ilkesinin karşı örneği: ilan veren, mesajlaşan kullanıcı.
    demoUsers['demo_zeynep'] = AppUser(
      uid: 'demo_zeynep',
      displayName: 'Zeynep Uçar',
      email: '',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      profilePhotoUrl: demoPhoto('avatar', 'demo_zeynep'),
      hasArtisanProfile: false,
      activeMode: UserRole.customer,
      phoneVerified: true,
      aboutText: 'Karşıyaka\'da oturuyorum. Ev yenileme işleri için usta arıyorum.',
      available: true,
    );
  }

  /// Mağaza profili olan personalar → `users.hasShopProfile` + kategoriler.
  static const _demoShopCategories = <String, List<String>>{
    'demo_sevil': ['mobilya', 'ev_tekstil'],
    'demo_okan': ['tesisat_malzeme', 'hirdavat'],
    'demo_burak': ['isitma_sogutma'],
    'demo_serkan': ['mobilya', 'yapi_malzeme'],
    'demo_hatice': ['hediyelik_sus'],
  };

  /// Demo ilanları. Sahipleri demo personalar → sohbetlerle örtüşür.
  void _seedDemoJobs() {
    final samples = <Job>[
      _seedJob(
        id: 'job_demo_1',
        title: 'Banyo fayansları yenilenecek',
        description:
            'Yaklaşık 6 m² banyonun eski fayansları sökülüp yenisi döşenecek. '
            'Zemin de dahil. Su yalıtımı yapılmasını istiyorum.',
        category: 'tiler',
        province: 'Kocaeli',
        district: 'İzmit',
        neighborhood: 'Yahyakaptan',
        createdAgo: const Duration(hours: 6),
        duration: JobDuration.day7,
        priceType: JobPriceType.fixed,
        budget: 18000,
        customerId: 'demo_zeynep',
        customerName: 'Zeynep Uçar',
      ),
      _seedJob(
        id: 'job_demo_2',
        title: 'Salon tipi klima montajı',
        description:
            'Yeni aldığım 12000 BTU klimanın montajı yapılacak. Dış ünite '
            'balkona gelecek, tesisat çekilmesi gerekiyor.',
        category: 'ac_technician',
        province: 'İzmir',
        district: 'Bornova',
        neighborhood: 'Kazımdirik',
        createdAgo: const Duration(hours: 2),
        duration: JobDuration.day3,
        priceType: JobPriceType.inspection,
        budget: null,
        customerId: 'demo_zeynep',
        customerName: 'Zeynep Uçar',
      ),
      _seedJob(
        id: 'job_demo_3',
        title: 'Ofis taşınacak, 2 kat merdiven var',
        description:
            '8 kişilik ofisin masaları, dolapları ve bilgisayarları taşınacak. '
            'Yeni adreste asansör yok, 2 kat merdiven çıkılacak.',
        category: 'mover',
        province: 'İstanbul',
        district: 'Beşiktaş',
        neighborhood: 'Levent',
        createdAgo: const Duration(days: 1),
        duration: JobDuration.day5,
        priceType: JobPriceType.fixed,
        budget: 9500,
        customerId: 'demo_tolga',
        customerName: 'Tolga Şenyurt',
      ),
      _seedJob(
        id: 'job_demo_4',
        title: 'Mutfak dolabı ölçüye yaptırılacak',
        description:
            'L şeklinde mutfak için ölçüye özel dolap istiyorum. Tezgah altı ve '
            'üst dolaplar dahil. Malzeme önerisi bekliyorum.',
        category: 'carpenter',
        province: 'Bursa',
        district: 'Gemlik',
        neighborhood: 'Osmaniye',
        createdAgo: const Duration(hours: 20),
        duration: JobDuration.day7,
        priceType: JobPriceType.inspection,
        budget: null,
        customerId: 'demo_zeynep',
        customerName: 'Zeynep Uçar',
      ),
    ];
    for (final j in samples) {
      jobs[j.jobId] = j;
    }
  }

  /// Mağaza vitrini. `status: active` + `moderationHidden: false` olmadan
  /// Keşfet'te GÖRÜNMEZ (`Product.isLiveInDiscover`) → ikisi de şart.
  void _seedDemoProducts() {
    final now = DateTime.now();

    void add({
      required String id,
      required String ownerUid,
      required String title,
      required String description,
      required String categoryCode,
      required String photo,
      required ProductPriceType priceType,
      double? price,
      required ProductCondition condition,
      required String province,
      String? district,
      required Duration ago,
      bool featured = false,
      List<String> tags = const [],
    }) {
      final created = now.subtract(ago);
      products[id] = Product(
        id: id,
        ownerUid: ownerUid,
        ownerName: demoUsers[ownerUid]?.displayName ?? '',
        ownerPhotoUrl: demoPhoto('avatar', ownerUid),
        title: title,
        description: description,
        categoryCode: categoryCode,
        tags: tags,
        photos: [demoPhoto('product', photo)],
        priceType: priceType,
        priceAmount: price,
        condition: condition,
        quantity: 1,
        province: province,
        district: district,
        status: ProductStatus.active,
        moderationHidden: false,
        featured: featured,
        createdAt: created,
        updatedAt: created,
        publishedAt: created,
      );
    }

    add(
      id: 'prod_demo_1',
      ownerUid: 'demo_okan',
      title: 'Grohe Mutfak Bataryası — sıfır, kutusunda',
      description:
          'Grohe Eurosmart mutfak bataryası. Hiç kullanılmadı, kutusu ve '
          'garanti belgesi duruyor. Müşterim vazgeçtiği için elimde kaldı.',
      categoryCode: 'tesisat_malzeme',
      photo: 'prod_1',
      priceType: ProductPriceType.fixed,
      price: 2450,
      condition: ProductCondition.brandNew,
      province: 'Ankara',
      district: 'Keçiören',
      ago: const Duration(hours: 5),
      featured: true,
      tags: const ['batarya', 'mutfak', 'grohe'],
    );

    add(
      id: 'prod_demo_2',
      ownerUid: 'demo_okan',
      title: 'Bosch Kombi Sirkülasyon Pompası',
      description:
          'Sökülmüş ama sağlam çalışan sirkülasyon pompası. Test edildi, '
          'sorunsuz. Kombi tamiri yapanlar için uygun.',
      categoryCode: 'isitma_sogutma',
      photo: 'prod_2',
      priceType: ProductPriceType.from,
      price: 1180,
      condition: ProductCondition.likeNew,
      province: 'Ankara',
      district: 'Keçiören',
      ago: const Duration(days: 2),
      tags: const ['kombi', 'pompa', 'bosch'],
    );

    add(
      id: 'prod_demo_3',
      ownerUid: 'demo_serkan',
      title: 'Ölçüye Özel Meşe TV Ünitesi',
      description:
          'Masif meşeden, istediğiniz ölçüde yapıyorum. Fotoğraftaki 180 cm. '
          'Kablo geçişleri ve yumuşak kapanır menteşe dahil. Montaj bana ait.',
      categoryCode: 'mobilya',
      photo: 'prod_3',
      priceType: ProductPriceType.negotiable,
      condition: ProductCondition.handmade,
      province: 'Bursa',
      district: 'Gemlik',
      ago: const Duration(days: 3),
      featured: true,
      tags: const ['tv ünitesi', 'meşe', 'masif'],
    );

    add(
      id: 'prod_demo_4',
      ownerUid: 'demo_serkan',
      title: 'Masif Ahşap Yemek Masası — 6 kişilik',
      description:
          'Kendi atölyemde ürettim. 160x90 cm, masif ahşap, doğal yağ ile '
          'cilalandı. Sandalyeler dahil değildir.',
      categoryCode: 'mobilya',
      photo: 'prod_4',
      priceType: ProductPriceType.fixed,
      price: 14900,
      condition: ProductCondition.handmade,
      province: 'Bursa',
      district: 'Gemlik',
      ago: const Duration(days: 6),
      tags: const ['masa', 'ahşap', 'el yapımı'],
    );

    add(
      id: 'prod_demo_5',
      ownerUid: 'demo_sevil',
      title: 'El Dokuma Kilim — 160x230 cm',
      description:
          'Doğal yün, bitkisel boya ile dokunmuş kilim. Projelerimde '
          'kullandığım atölyeden geliyor. Rengi fotoğraftakiyle aynıdır.',
      categoryCode: 'ev_tekstil',
      photo: 'prod_5',
      priceType: ProductPriceType.fixed,
      price: 6750,
      condition: ProductCondition.brandNew,
      province: 'İstanbul',
      district: 'Beşiktaş',
      ago: const Duration(days: 1),
      tags: const ['kilim', 'halı', 'el dokuma'],
    );

    add(
      id: 'prod_demo_6',
      ownerUid: 'demo_sevil',
      title: 'Pirinç Sarkıt Aydınlatma — 3\'lü set',
      description:
          'Mutfak adası veya yemek masası üstü için tasarladığım pirinç sarkıt. '
          'Kablo boyu ayarlanabilir. Ampul dahil değildir.',
      categoryCode: 'aydinlatma',
      photo: 'prod_6',
      priceType: ProductPriceType.fixed,
      price: 3200,
      condition: ProductCondition.brandNew,
      province: 'İstanbul',
      district: 'Beşiktaş',
      ago: const Duration(days: 4),
      tags: const ['sarkıt', 'aydınlatma', 'pirinç'],
    );

    add(
      id: 'prod_demo_7',
      ownerUid: 'demo_burak',
      title: 'Arçelik 12000 BTU Klima — az kullanılmış',
      description:
          'Müşterimin taşınırken bıraktığı klima. 1 sezon çalıştı, gazı dolu, '
          'temizliği yapıldı. Montajını ben yaparım, ücreti ayrıdır.',
      categoryCode: 'isitma_sogutma',
      photo: 'prod_7',
      priceType: ProductPriceType.negotiable,
      condition: ProductCondition.likeNew,
      province: 'İzmir',
      district: 'Bornova',
      ago: const Duration(hours: 9),
      tags: const ['klima', 'arçelik', 'ikinci el'],
    );

    add(
      id: 'prod_demo_8',
      ownerUid: 'demo_hatice',
      title: 'Ahşap Fotoğraf Çerçevesi Seti',
      description:
          'Çekimlerimde kullandığım el yapımı çerçevelerden. 3 farklı boy, '
          'ceviz renginde. Baskı siparişi verirseniz çerçeveli teslim ederim.',
      categoryCode: 'hediyelik_sus',
      photo: 'prod_8',
      priceType: ProductPriceType.fixed,
      price: 890,
      condition: ProductCondition.handmade,
      province: 'Antalya',
      district: 'Muratpaşa',
      ago: const Duration(days: 5),
      tags: const ['çerçeve', 'ahşap', 'hediyelik'],
    );
  }

  /// Zeynep'in takip ettiği ustalar → "Takip" ekranı dolu görünür.
  void _seedDemoFavorites() {
    for (final uid in const ['demo_kerem', 'demo_ayse', 'demo_elif']) {
      final rec = artisans[uid];
      if (rec == null) continue;
      final fav = Favorite(
        customerUid: 'demo_zeynep',
        artisanUid: uid,
        artisanName: rec.displayName,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        professionNameTR: kProfessionNames[rec.profile.profession] ?? '',
        rating: rec.profile.averageRating,
        totalReviews: rec.profile.totalReviews,
        photoUrl: rec.profilePhotoUrl,
        customerName: 'Zeynep Uçar',
        customerPhotoUrl: demoPhoto('avatar', 'demo_zeynep'),
      );
      favorites[fav.id] = fav;
    }
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

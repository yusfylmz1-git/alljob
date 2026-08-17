import 'geo_models.dart';

/// "Hemen Lazım" ilan kategorisi — market, taşıma, kısa gidiş gibi uzmanlık
/// gerektirmeyen kısa işler. Yalnız Hemen Lazım hizmeti AÇIK olan ustalara
/// düşer (bkz. [isQuickSupportProviderCodes]).
///
/// Depolama kodu (`quick_support`) geriye uyum için DEĞİŞMEZ — yalnız
/// kullanıcıya görünen ad değişir ([kQuickSupportName]).
/// CF paritesi: functions/index.js QUICK_SUPPORT_CATEGORY.
const kQuickSupportCategory = 'quick_support';

/// Kullanıcıya görünen ad. Metinlerde bu sabit kullanılır ki tek noktadan
/// değiştirilebilsin.
///
/// "Hemen Lazım" → "Kolay İş" (2026-08-08): eski ad aciliyet vaat ediyordu,
/// oysa bu akış "acil" değil "kısa ve basit iş" demek. Depolama kodu ve
/// `kOtherProfession` DEĞİŞMEDİ.
const kQuickSupportName = 'Kolay İş';

/// "Ürün Talebi" kategorisi — Mağaza'nın ikinci bölümü (2026-08-10).
///
/// Kullanıcı "şu ürüne ihtiyacım var" der; talep aynı ildeki ilgili
/// satıcılara **günlük özet** bildirimiyle ulaşır (anlık push YOK — bkz.
/// `vault/06-Test/PLAN-Magaza.md` §Aşama 3).
///
/// Neden `jobs` içinde bir kategori (ayrı koleksiyon değil): limit, süre
/// dolumu, moderasyon, şikayet ve admin paneli `jobs` için yazılmış ve
/// canlıda test edilmiş durumda. Kolay İş de tam olarak böyle kurulmuştur.
///
/// ⚠️ Bu kategorideki ilan USTALARA DÜŞMEZ — alıcı kitlesi satıcılardır
/// (aynı il + `productCategoryCode`: yayında ürün veya mağaza kategorisi).
/// `onJobCreated` ustalara gitmez; `notifyProductRequestSellers` anlık
/// yollar. Akşam `sendProductRequestDigest` anlık kaçıranları tamamlar.
const kProductRequestCategory = 'product_request';

/// Kullanıcıya görünen ad.
const kProductRequestName = 'Ürün Talebi';

/// Usta profilinde Hemen Lazım hizmetini işaretleyen meslek kodu
/// (JSON code: `other`, geriye uyum). Meslek listesinden AYRILMIŞTIR:
/// profilde ayrı bir anahtar (switch) ile açılıp kapatılır.
///
/// Bu kod `professions` dizisinde tutulmaya devam eder — böylece mevcut
/// eşleşme (istemci + CF + rules) ve eski profiller olduğu gibi çalışır.
const kOtherProfession = 'other';

/// Bu meslek kodları Hemen Lazım ilanlarını alabilir.
bool isQuickSupportProviderCodes(Iterable<String> codes) {
  for (final c in codes) {
    if (c == kOtherProfession || c == kQuickSupportCategory) return true;
  }
  return false;
}

/// İş ilanı fiyat tipi (#8): sabit fiyat beklentisi veya "keşif gerekli".
enum JobPriceType {
  fixed,
  inspection;

  String get apiValue => name;

  static JobPriceType fromString(String? v) => JobPriceType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobPriceType.fixed,
      );
}

/// İlan yayında kalma süresi (#2). Varsayılan 3 gün.
///
/// Normal ilan: 3 / 5 / 7 gün ([selectable]).
/// Kolay İş: HER ZAMAN [day1] — seçim sunulmaz, kısa iş kısa yaşar.
///
/// > [!warning] `day1` SİLİNMEZ
/// > `apiValue` = enum adı = Firestore değeri (CLAUDE.md kural 6). `day1`
/// > artık normal ilanda seçilemez ama Kolay İş onu kullanır ve eski
/// > kayıtlarda da yazılıdır; sabiti kaldırmak veri göçüdür.
enum JobDuration {
  day1,
  day3,
  day5,
  day7;

  Duration get duration => switch (this) {
        JobDuration.day1 => const Duration(days: 1),
        JobDuration.day3 => const Duration(days: 3),
        JobDuration.day5 => const Duration(days: 5),
        JobDuration.day7 => const Duration(days: 7),
      };

  String get labelTR => switch (this) {
        JobDuration.day1 => '1 gün',
        JobDuration.day3 => '3 gün',
        JobDuration.day5 => '5 gün',
        JobDuration.day7 => '7 gün',
      };

  /// Normal ilan formunda SEÇİLEBİLEN süreler.
  ///
  /// `day1` listede yoktur: 24 saat normal ilan için fazla kısaydı, ilan
  /// görülmeden düşüyordu. Kısa işler zaten Kolay İş akışına ait.
  static const List<JobDuration> selectable = [day3, day5, day7];

  String get apiValue => name;

  static JobDuration fromString(String? v) => JobDuration.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobDuration.day3,
      );
}

/// İlan yaşam döngüsü. **Üç durum** — ilan bir duyurudur, iş takip aracı
/// değil.
///
/// `open` doğar → süresi dolunca `expired`, sahibi kaldırırsa `cancelled`.
///
/// Eskiden 8 durum vardı (`workerSelected`, `inProgress`, `completed`,
/// `rated`, `disputed`): usta seçimi → tamamlama onayı → puanlama zinciri.
/// O akış 2026-08-08'de kaldırıldı — usta ilan sahibine doğrudan mesaj atar,
/// anlaşma taraflar arasındadır. Silinen değerler hiç üretilmiyordu.
/// → `vault/02-Ozellikler/Is-Akisi-Durum-Makinesi.md`
enum JobStatus {
  open, // yayında, mesaj alabilir
  cancelled, // sahibi kaldırdı
  expired; // süresi doldu

  String get apiValue => name;

  /// Tanınmayan değer `open` sayılır. Eski kayıtlardaki `workerSelected` gibi
  /// değerler de buraya düşer: ilan görünür kalır, veri kaybı olmaz.
  static JobStatus fromString(String? v) => JobStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobStatus.open,
      );

  /// Ustaların feed'inde görünüyor ve mesaj alabiliyor mu?
  bool get isActiveForOffers => this == JobStatus.open;

  /// Teknik / admin / debug için ayrıntılı etiket.
  String get labelTR => switch (this) {
        JobStatus.open => 'Açık',
        JobStatus.cancelled => 'İptal Edildi',
        JobStatus.expired => 'Süresi Doldu',
      };

  /// Kullanıcıya görünen sade dil.
  String get simpleLabelTR => switch (this) {
        JobStatus.open => 'Yayında',
        JobStatus.cancelled => 'Kaldırıldı',
        JobStatus.expired => 'Süresi doldu',
      };
}

/// İptal nedeni (#11).
enum JobCancelReason {
  changedMind,
  solved,
  wrongPost,

  /// Günlük ilan hakkı dolduğu için sunucu iptal etti (yalnız CF yazar —
  /// istemci bu sebeple ilan iptal edemez).
  rateLimited;

  String get apiValue => name;

  static JobCancelReason? fromString(String? v) {
    if (v == null) return null;
    for (final e in JobCancelReason.values) {
      if (e.name == v) return e;
    }
    return null;
  }

  String get labelTR => switch (this) {
        JobCancelReason.changedMind => 'Vazgeçtim',
        JobCancelReason.solved => 'Sorun çözüldü',
        JobCancelReason.wrongPost => 'Yanlış ilan',
        JobCancelReason.rateLimited => 'Günlük ilan hakkı doldu',
      };
}

/// `jobs` koleksiyonundaki iş ilanı (müşterinin açtığı talep).
class Job {
  const Job({
    required this.jobId,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.description,
    required this.category,
    required this.province,
    required this.district,
    required this.photos,
    required this.priceType,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.customerPhotoUrl,
    this.neighborhood,
    this.budget,
    this.cancelReason,
    this.moderationHidden = false,
    this.productCategoryCode,
  });

  final String jobId;
  final String customerId;
  final String customerName;
  final String? customerPhotoUrl;

  final String title;
  final String description;
  final String category; // meslek kodu (kProfessionNames)

  /// Ürün talebinde seçilen satış kategorisi (`ProductCategory` kodu).
  /// Normal iş ilanında null. `category` yine `product_request` kalır
  /// (CF özet + feed süzümü buna bakar).
  final String? productCategoryCode;

  final String province;
  final String district;
  final String? neighborhood;

  final List<String> photos; // image handle (max AppConstants.maxJobPhotos)

  final JobPriceType priceType;
  final double? budget; // müşteri fiyat beklentisi (opsiyonel, #8)

  final JobStatus status;

  final JobCancelReason? cancelReason; // (#11)

  final DateTime createdAt;
  final DateTime expiresAt;

  /// Yönetici tarafından gizlendi mi? Yalnız CF yazar; eksik alan = görünür.
  final bool moderationHidden;

  /// Yayından sonra ilan içeriğinin (başlık/açıklama/bütçe) düzenlenebildiği
  /// pencere. Kural tarafında yalnız `open` durumu doğrulanır (createdAt ISO
  /// string olduğundan kural zaman aritmetiği yapamaz); süre istemcide kesilir.
  static const editWindow = Duration(hours: 1);

  /// İlan içeriği ŞU AN düzenlenebilir mi? Yalnız açık (süresi dolmamış) ilan,
  /// yayınlandıktan sonra [editWindow] içinde.
  bool canEditAt(DateTime now) =>
      status == JobStatus.open &&
      !isExpiredAt(now) &&
      now.difference(createdAt) < editWindow;

  bool get canEditNow => canEditAt(DateTime.now());

  /// İlan silinebilir mi? İlan artık bir duyuru olduğundan (usta ataması,
  /// tamamlama zinciri yok) sahibi her zaman kaldırabilir. Sohbetler ilandan
  /// bağımsız yaşar — silme mesaj geçmişini götürmez.
  bool get canDelete => true;

  /// Açık ilan süresi dolmuş mu? (okuma anında `expired` gibi gösterilir).
  bool isExpiredAt(DateTime now) =>
      status == JobStatus.open && now.isAfter(expiresAt);

  bool get isExpired => isExpiredAt(DateTime.now());

  /// Ekranda gösterilecek etkin durum (süre dolumu okuma anında hesaplanır).
  JobStatus effectiveStatusAt(DateTime now) =>
      isExpiredAt(now) ? JobStatus.expired : status;

  JobStatus get effectiveStatus => effectiveStatusAt(DateTime.now());

  Job copyWith({
    String? title,
    String? description,
    String? category,
    String? province,
    String? district,
    String? neighborhood,
    List<String>? photos,
    JobPriceType? priceType,
    double? budget,
    JobStatus? status,
    JobCancelReason? cancelReason,
    DateTime? expiresAt,
    String? productCategoryCode,
  }) {
    return Job(
      jobId: jobId,
      customerId: customerId,
      customerName: customerName,
      customerPhotoUrl: customerPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      province: province ?? this.province,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      photos: photos ?? this.photos,
      priceType: priceType ?? this.priceType,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      moderationHidden: moderationHidden,
      productCategoryCode: productCategoryCode ?? this.productCategoryCode,
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhotoURL': customerPhotoUrl,
        'title': title,
        'description': description,
        'category': category,
        if (productCategoryCode != null && productCategoryCode!.isNotEmpty)
          'productCategoryCode': productCategoryCode,
        'province': province,
        'district': district,
        'neighborhood': neighborhood,
        'photos': photos,
        'priceType': priceType.apiValue,
        'budget': budget,
        'status': status.apiValue,
        'cancelReason': cancelReason?.apiValue,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        // H4: rules süre kontrolü (ISO string rules'ta zor; ms karşılaştırılır).
        'expiresAtMs': expiresAt.millisecondsSinceEpoch,
        // Yeni ilanlar her zaman görünür; gizleme yalnız CF.
        'moderationHidden': false,
      };

  factory Job.fromMap(String jobId, Map<String, dynamic> map) {
    return Job(
      jobId: jobId,
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerPhotoUrl: map['customerPhotoURL'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      productCategoryCode: map['productCategoryCode'] as String?,
      province: (map['province'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      neighborhood: map['neighborhood'] as String?,
      photos: ((map['photos'] as List?) ?? []).map((e) => e.toString()).toList(),
      priceType: JobPriceType.fromString(map['priceType'] as String?),
      budget: (map['budget'] as num?)?.toDouble(),
      // Eski kayıtlardaki iş akışı alanları (offerCount, selectedArtisanId,
      // dispute*, *ConfirmedDone…) bilerek OKUNMUYOR — akış kalktı, alanlar
      // anlamsız. Firestore'da durabilirler, modele girmezler.
      status: JobStatus.fromString(map['status'] as String?),
      cancelReason: JobCancelReason.fromString(map['cancelReason'] as String?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(JobDuration.day3.duration),
      moderationHidden: map['moderationHidden'] == true,
    );
  }

  /// Bir ustanın (meslek + hizmet bölgeleri) bu ilana teklif verebilir mi? (#1)
  /// Meslek eşleşmeli; ilan konumu ustanın hizmet bölgelerinden biriyle
  /// **İL** düzeyinde örtüşmeli.
  ///
  /// Bölge eşleşmesi HER İLAN TİPİNDE il düzeyindedir (2026-08-10). Önce
  /// yalnız Hemen Lazım böyleydi; klasik ilanlar il + ilçe istiyordu ve bu
  /// ilanları çoğu ilçede alıcısız bırakıyordu — arz ilçe ölçeğinde yeterince
  /// yoğun değil. Aynı ilçedeki ustalar elenmez, UI'da "Yakınında" rozetiyle
  /// ÖNE ALINIR (bkz. [isNearbyForAreas]) — eleme değil, sıralama tercihi.
  ///
  /// Hemen Lazım ([kQuickSupportCategory]) farkı yalnız MESLEK tarafında:
  ///  - Yalnız Hemen Lazım hizmeti açık olan ustalara düşer.
  ///  - Yalnız Hemen Lazım açık olup mesleği olmayan usta klasik meslek
  ///    ilanlarını almaz.
  ///
  /// [professionCodes] çoklu meslek; [professionCode] tekil (geriye uyum).
  bool matchesArtisan({
    String? professionCode,
    List<String>? professionCodes,
    required List<ServiceArea> serviceAreas,
  }) {
    final codes = (professionCodes ??
            (professionCode != null && professionCode.isNotEmpty
                ? [professionCode]
                : const <String>[]))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    // ÜRÜN TALEBİ ustaya DÜŞMEZ — alıcı kitlesi satıcılar (Mağaza modülü).
    // Aşağıdaki meslek eşleşmesi zaten tutmazdı ('product_request' bir
    // meslek kodu değil), ama bu sessiz bir kazaydı: biri kategoriyi
    // meslek listesine eklerse talepler usta feed'ine sızardı. Açık kapı.
    if (category == kProductRequestCategory) return false;
    // İL düzeyi: ustanın hizmet bölgelerinden herhangi biri ilanın ilinde.
    final areaMatch = serviceAreas.any((a) => a.province == province);
    if (category == kQuickSupportCategory) {
      return areaMatch && isQuickSupportProviderCodes(codes);
    }
    final matchable = codes
        .where((c) => c != kOtherProfession && c != kQuickSupportCategory)
        .toList(growable: false);
    if (matchable.isEmpty) return false;
    return matchable.contains(category) && areaMatch;
  }

  /// Bu ilan Hemen Lazım ilanı mı?
  bool get isQuickSupport => category == kQuickSupportCategory;

  /// Bu ilan bir ürün talebi mi? (Mağaza > İlan Ver)
  bool get isProductRequest => category == kProductRequestCategory;

  /// Kullanıcıya görünen kategori. `product_request` meslek listesinde
  /// yoktur — ham kod ekrana sızmasın diye burada çözülür.
  static String labelForCategory(String category) {
    if (category == kProductRequestCategory) return kProductRequestName;
    if (category == kQuickSupportCategory) return kQuickSupportName;
    return category;
  }

  String get categoryLabelTR => labelForCategory(category);

  /// Usta ilanın İLÇESİNDE de hizmet veriyor mu? Hemen Lazım ilanları il
  /// geneline gittiğinden, aynı ilçedekiler listede öne alınır ve "Yakınında"
  /// rozeti gösterilir. ELEME DEĞİLDİR — yalnız sıralama/gösterim sinyali.
  bool isNearbyForAreas(List<ServiceArea> serviceAreas) => serviceAreas.any(
        (a) => a.province == province && a.district == district,
      );
}

/// Usta feed'i sıralaması: Hemen Lazım ilanları en üstte (kısa işler çabuk
/// bayatlar), her grupta ustanın kendi ilçesindekiler önce, sonra en yeni.
///
/// Listeyi YERİNDE sıralar ve aynı listeyi döndürür.
List<Job> sortJobsForArtisanFeed(
  List<Job> jobs,
  List<ServiceArea> serviceAreas,
) {
  // Sıralama anahtarları önden hesaplanır: comparator içinde her
  // karşılaştırmada serviceAreas taranırsa O(n log n × alan) olurdu.
  //
  // Anahtar olarak jobId DEĞİL nesne kimliği kullanılır: kaydedilmemiş
  // ilanlarda (ve testlerde) jobId boş olabilir ve aynı anahtara düşen
  // ilanlar birbirinin yakınlık değerini ezerdi.
  final nearby = Map<Job, bool>.identity();
  for (final j in jobs) {
    nearby[j] = j.isNearbyForAreas(serviceAreas);
  }
  jobs.sort((a, b) {
    if (a.isQuickSupport != b.isQuickSupport) {
      return a.isQuickSupport ? -1 : 1;
    }
    final an = nearby[a] ?? false;
    final bn = nearby[b] ?? false;
    if (an != bn) return an ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return jobs;
}

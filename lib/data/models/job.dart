import 'geo_models.dart';

/// "Hızlı Destek" ilan kategorisi — ayak işleri (market, taşıma, kısa yardım).
/// Yalnız [kOtherProfession] ("Hızlı Destek") mesleğini seçen ustalara düşer.
/// CF paritesi: functions/index.js QUICK_SUPPORT_CATEGORY.
const kQuickSupportCategory = 'quick_support';

/// Usta profilindeki "Hızlı Destek" mesleği (JSON code: `other`, geriye uyum).
/// Yalnız bunu seçen usta klasik meslek ilanlarını almaz; Hızlı Destek ilanlarını alır.
/// Klasik meslek + Hızlı Destek birlikte seçilebilir.
const kOtherProfession = 'other';

/// Bu meslek kodları Hızlı Destek (ayak işi) ilanlarını alabilir.
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
enum JobDuration {
  day1,
  day3,
  day7;

  Duration get duration => switch (this) {
        JobDuration.day1 => const Duration(hours: 24),
        JobDuration.day3 => const Duration(days: 3),
        JobDuration.day7 => const Duration(days: 7),
      };

  String get labelTR => switch (this) {
        JobDuration.day1 => '24 saat',
        JobDuration.day3 => '3 gün',
        JobDuration.day7 => '7 gün',
      };

  String get apiValue => name;

  static JobDuration fromString(String? v) => JobDuration.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobDuration.day3,
      );
}

/// İlan yaşam döngüsü (#4): Open → (Teklif geldi) → Worker Selected →
/// In Progress → Completed → Rated. Ayrıca iptal, süre dolumu ve anlaşmazlık.
enum JobStatus {
  open, // teklif topluyor
  workerSelected, // usta seçildi, sohbet açıldı, iş henüz başlamadı
  inProgress, // iş sürüyor
  completed, // iki taraf da onayladı
  rated, // müşteri puanladı
  disputed, // taraflardan biri sorun bildirdi (yaşam döngüsü donar)
  cancelled, // müşteri iptal etti
  expired; // süresi doldu

  String get apiValue => name;

  static JobStatus fromString(String? v) => JobStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => JobStatus.open,
      );

  /// Ustaların feed'inde görünmeye ve teklif almaya açık mı?
  bool get isActiveForOffers => this == JobStatus.open;

  /// İş bir ustaya bağlanmış (seçim yapılmış) durumlardan biri mi?
  bool get isAssigned =>
      this == JobStatus.workerSelected ||
      this == JobStatus.inProgress ||
      this == JobStatus.completed ||
      this == JobStatus.rated ||
      this == JobStatus.disputed;

  /// Bu durumda taraflardan biri sorun bildirebilir mi? (rated/cancelled
  /// sonrası bildirilemez; open'da henüz karşı taraf yok.)
  bool get canDispute =>
      this == JobStatus.workerSelected ||
      this == JobStatus.inProgress ||
      this == JobStatus.completed;

  String get labelTR => switch (this) {
        JobStatus.open => 'Açık',
        JobStatus.workerSelected => 'Usta Seçildi',
        JobStatus.inProgress => 'İş Sürüyor',
        JobStatus.completed => 'Tamamlandı',
        JobStatus.rated => 'Değerlendirildi',
        JobStatus.disputed => 'Sorun Bildirildi',
        JobStatus.cancelled => 'İptal Edildi',
        JobStatus.expired => 'Süresi Doldu',
      };
}

/// Sorunu bildiren taraf.
enum JobDisputeParty {
  customer,
  artisan;

  String get apiValue => name;

  static JobDisputeParty? fromString(String? v) {
    for (final e in JobDisputeParty.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// Sorun bildirme nedeni (iki taraf için de anlamlı genel başlıklar).
enum JobDisputeReason {
  notCompleted,
  qualityIssue,
  paymentIssue,
  communicationIssue,
  other;

  String get apiValue => name;

  static JobDisputeReason? fromString(String? v) {
    for (final e in JobDisputeReason.values) {
      if (e.name == v) return e;
    }
    return null;
  }

  String get labelTR => switch (this) {
        JobDisputeReason.notCompleted => 'İş yapılmadı / yarım bırakıldı',
        JobDisputeReason.qualityIssue => 'İş kötü veya özensiz yapıldı',
        JobDisputeReason.paymentIssue => 'Ücret / ödeme anlaşmazlığı',
        JobDisputeReason.communicationIssue => 'Ulaşılamıyor / iletişim sorunu',
        JobDisputeReason.other => 'Diğer',
      };
}

/// İptal nedeni (#11).
enum JobCancelReason {
  changedMind,
  solved,
  wrongPost;

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
    required this.isUrgent,
    required this.priceType,
    required this.status,
    required this.offerCount,
    required this.customerConfirmedDone,
    required this.artisanConfirmedDone,
    required this.createdAt,
    required this.expiresAt,
    this.customerPhotoUrl,
    this.neighborhood,
    this.budget,
    this.selectedOfferId,
    this.selectedArtisanId,
    this.chatId,
    this.cancelReason,
    this.autoCompleteAt,
    this.disputedBy,
    this.disputeReason,
    this.disputeNote,
    this.disputedAt,
    this.statusBeforeDispute,
    this.moderationHidden = false,
  });

  final String jobId;
  final String customerId;
  final String customerName;
  final String? customerPhotoUrl;

  final String title;
  final String description;
  final String category; // meslek kodu (kProfessionNames)

  final String province;
  final String district;
  final String? neighborhood;

  final List<String> photos; // image handle (max AppConstants.maxJobPhotos)
  final bool isUrgent; // 🚨 acil (#urgent)

  final JobPriceType priceType;
  final double? budget; // müşteri fiyat beklentisi (opsiyonel, #8)

  final JobStatus status;
  final int offerCount; // denormalize sayaç (#3)

  final String? selectedOfferId;
  final String? selectedArtisanId;
  final String? chatId; // seçim yapılınca üretilir (#6)

  // İki taraflı tamamlama (#10).
  final bool customerConfirmedDone;
  final bool artisanConfirmedDone;

  final JobCancelReason? cancelReason; // (#11)

  /// Tek taraf "işi tamamladım" dediğinde CF (`onJobWritten`) tarafından
  /// yazılan son tarih: karşı taraf bu tarihe kadar yanıt vermezse zamanlanmış
  /// CF (`autoCompleteJobs`) işi otomatik `completed` yapar. İstemci YAZMAZ
  /// (toMap'e girmez), yalnızca gösterir.
  final DateTime? autoCompleteAt;

  // Anlaşmazlık (şikayet) alanları: yalnızca `reportDispute`/`withdrawDispute`
  // repo metodları yazar (toMap'e girmez — ilan oluştururken set edilemez).
  // `statusBeforeDispute` şikayet geri çekilince dönülecek durumu saklar.
  final JobDisputeParty? disputedBy;
  final JobDisputeReason? disputeReason;
  final String? disputeNote;
  final DateTime? disputedAt;
  final JobStatus? statusBeforeDispute;

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

  /// İlan silinebilir mi? Bir ustaya bağlanmamış (open/expired/cancelled)
  /// ilanlar silinebilir; aktif/tamamlanmış işler kayıt olarak kalır.
  bool get canDelete => !status.isAssigned;

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
    bool? isUrgent,
    JobPriceType? priceType,
    double? budget,
    JobStatus? status,
    int? offerCount,
    String? selectedOfferId,
    String? selectedArtisanId,
    String? chatId,
    bool? customerConfirmedDone,
    bool? artisanConfirmedDone,
    JobCancelReason? cancelReason,
    DateTime? expiresAt,
    DateTime? autoCompleteAt,
    JobDisputeParty? disputedBy,
    JobDisputeReason? disputeReason,
    String? disputeNote,
    DateTime? disputedAt,
    JobStatus? statusBeforeDispute,
    bool clearDispute = false, // withdraw: null=koru kalıbı silmeye yetmez
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
      isUrgent: isUrgent ?? this.isUrgent,
      priceType: priceType ?? this.priceType,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      offerCount: offerCount ?? this.offerCount,
      selectedOfferId: selectedOfferId ?? this.selectedOfferId,
      selectedArtisanId: selectedArtisanId ?? this.selectedArtisanId,
      chatId: chatId ?? this.chatId,
      customerConfirmedDone:
          customerConfirmedDone ?? this.customerConfirmedDone,
      artisanConfirmedDone: artisanConfirmedDone ?? this.artisanConfirmedDone,
      cancelReason: cancelReason ?? this.cancelReason,
      autoCompleteAt: autoCompleteAt ?? this.autoCompleteAt,
      disputedBy: clearDispute ? null : (disputedBy ?? this.disputedBy),
      disputeReason:
          clearDispute ? null : (disputeReason ?? this.disputeReason),
      disputeNote: clearDispute ? null : (disputeNote ?? this.disputeNote),
      disputedAt: clearDispute ? null : (disputedAt ?? this.disputedAt),
      statusBeforeDispute: clearDispute
          ? null
          : (statusBeforeDispute ?? this.statusBeforeDispute),
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      moderationHidden: moderationHidden,
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhotoURL': customerPhotoUrl,
        'title': title,
        'description': description,
        'category': category,
        'province': province,
        'district': district,
        'neighborhood': neighborhood,
        'photos': photos,
        'isUrgent': isUrgent,
        'priceType': priceType.apiValue,
        'budget': budget,
        'status': status.apiValue,
        'offerCount': offerCount,
        'selectedOfferId': selectedOfferId,
        'selectedArtisanId': selectedArtisanId,
        'chatId': chatId,
        'customerConfirmedDone': customerConfirmedDone,
        'artisanConfirmedDone': artisanConfirmedDone,
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
      province: (map['province'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      neighborhood: map['neighborhood'] as String?,
      photos: ((map['photos'] as List?) ?? []).map((e) => e.toString()).toList(),
      isUrgent: (map['isUrgent'] as bool?) ?? false,
      priceType: JobPriceType.fromString(map['priceType'] as String?),
      budget: (map['budget'] as num?)?.toDouble(),
      status: JobStatus.fromString(map['status'] as String?),
      offerCount: (map['offerCount'] as num?)?.toInt() ?? 0,
      selectedOfferId: map['selectedOfferId'] as String?,
      selectedArtisanId: map['selectedArtisanId'] as String?,
      chatId: map['chatId'] as String?,
      customerConfirmedDone: (map['customerConfirmedDone'] as bool?) ?? false,
      artisanConfirmedDone: (map['artisanConfirmedDone'] as bool?) ?? false,
      cancelReason: JobCancelReason.fromString(map['cancelReason'] as String?),
      autoCompleteAt: map['autoCompleteAt'] != null
          ? DateTime.tryParse(map['autoCompleteAt'].toString())
          : null,
      disputedBy: JobDisputeParty.fromString(map['disputedBy'] as String?),
      disputeReason:
          JobDisputeReason.fromString(map['disputeReason'] as String?),
      disputeNote: map['disputeNote'] as String?,
      disputedAt: map['disputedAt'] != null
          ? DateTime.tryParse(map['disputedAt'].toString())
          : null,
      statusBeforeDispute: map['statusBeforeDispute'] != null
          ? JobStatus.fromString(map['statusBeforeDispute'] as String?)
          : null,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(JobDuration.day3.duration),
      moderationHidden: map['moderationHidden'] == true,
    );
  }

  /// Bir ustanın (meslek + hizmet bölgeleri) bu ilana teklif verebilir mi? (#1)
  /// Meslek eşleşmeli; ilan konumu ustanın hizmet bölgelerinden biriyle
  /// örtüşmeli (il+ilçe; mahalle verilmişse ve usta o mahalleyi de seçmişse
  /// daha spesifik eşleşir, ama ilçe düzeyi eşleşmesi yeterlidir).
  ///
  /// Hızlı Destek:
  ///  - İlan [kQuickSupportCategory] → yalnız Hızlı Destek mesleği + aynı ilçe.
  ///  - Yalnız Hızlı Destek seçen usta klasik meslek ilanlarını almaz.
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
    final areaMatch = serviceAreas.any(
      (a) => a.province == province && a.district == district,
    );
    if (category == kQuickSupportCategory) {
      return areaMatch && isQuickSupportProviderCodes(codes);
    }
    final matchable = codes
        .where((c) => c != kOtherProfession && c != kQuickSupportCategory)
        .toList(growable: false);
    if (matchable.isEmpty) return false;
    return matchable.contains(category) && areaMatch;
  }
}

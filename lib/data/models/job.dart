import 'geo_models.dart';

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
/// In Progress → Completed → Rated. Ayrıca iptal ve süre dolumu.
enum JobStatus {
  open, // teklif topluyor
  workerSelected, // usta seçildi, sohbet açıldı, iş henüz başlamadı
  inProgress, // iş sürüyor
  completed, // iki taraf da onayladı
  rated, // müşteri puanladı
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
      this == JobStatus.rated;

  String get labelTR => switch (this) {
        JobStatus.open => 'Açık',
        JobStatus.workerSelected => 'Usta Seçildi',
        JobStatus.inProgress => 'İş Sürüyor',
        JobStatus.completed => 'Tamamlandı',
        JobStatus.rated => 'Değerlendirildi',
        JobStatus.cancelled => 'İptal Edildi',
        JobStatus.expired => 'Süresi Doldu',
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

  final DateTime createdAt;
  final DateTime expiresAt;

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
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? '') ??
          DateTime.now().add(JobDuration.day3.duration),
    );
  }

  /// Bir ustanın (meslek + hizmet bölgeleri) bu ilana teklif verebilir mi? (#1)
  /// Meslek eşleşmeli; ilan konumu ustanın hizmet bölgelerinden biriyle
  /// örtüşmeli (il+ilçe; mahalle verilmişse ve usta o mahalleyi de seçmişse
  /// daha spesifik eşleşir, ama ilçe düzeyi eşleşmesi yeterlidir).
  bool matchesArtisan({
    required String professionCode,
    required List<ServiceArea> serviceAreas,
  }) {
    if (professionCode != category) return false;
    return serviceAreas.any(
      (a) => a.province == province && a.district == district,
    );
  }
}

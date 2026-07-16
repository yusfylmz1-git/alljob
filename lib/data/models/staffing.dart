// Eleman istihdam — ters model: eleman başvurmaz; işveren arar / sohbet açar.
// Tek profil tipi; "gündelik" yalnızca bir bayrak (isDaily).

enum StaffRateType {
  daily,
  monthly,
  negotiable;

  String get apiValue => name;

  static StaffRateType fromString(String? v) => StaffRateType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => StaffRateType.negotiable,
      );

  String get labelTR => switch (this) {
        StaffRateType.daily => 'Günlük',
        StaffRateType.monthly => 'Aylık',
        StaffRateType.negotiable => 'Görüşülür',
      };
}

/// Elemanın "iş arıyorum" kartı. Döküman ID: `worker_{uid}`.
class StaffWorkerListing {
  const StaffWorkerListing({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.title,
    required this.about,
    required this.professionLabel,
    required this.province,
    required this.district,
    required this.rateType,
    required this.openToWork,
    required this.isDaily,
    required this.updatedAt,
    this.photoUrl,
    this.rate,
    this.createdAt,
  });

  final String id;
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String title;
  final String about;
  final String professionLabel;
  final String province;
  final String district;
  final StaffRateType rateType;
  final double? rate;
  final bool openToWork;
  /// true = gündelik işlere de açık (arama filtresinde "Gündelik eleman").
  final bool isDaily;
  final DateTime updatedAt;
  final DateTime? createdAt;

  static String idFor(String uid) => 'worker_$uid';

  String get rateLabel {
    if (rateType == StaffRateType.negotiable || rate == null) {
      return 'Ücret görüşülür';
    }
    final n = rate!.round();
    return rateType == StaffRateType.daily ? '$n ₺/gün' : '$n ₺/ay';
  }

  String get placeLabel => '$province / $district';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'photoURL': photoUrl,
        'title': title,
        'about': about,
        'professionLabel': professionLabel,
        'province': province,
        'district': district,
        'rateType': rateType.apiValue,
        'rate': rate,
        'openToWork': openToWork,
        'isDaily': isDaily,
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': (createdAt ?? updatedAt).toIso8601String(),
      };

  factory StaffWorkerListing.fromMap(String id, Map<String, dynamic> map) {
    // Eski kind=dayLabor kayıtları isDaily sayılır.
    final legacyDaily = map['kind'] == 'dayLabor' || map['kind'] == 'crew';
    return StaffWorkerListing(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      photoUrl: map['photoURL'] as String?,
      title: (map['title'] as String?) ?? '',
      about: (map['about'] as String?) ?? '',
      professionLabel: (map['professionLabel'] as String?) ?? '',
      province: (map['province'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      rateType: StaffRateType.fromString(map['rateType'] as String?),
      rate: (map['rate'] as num?)?.toDouble(),
      openToWork: map['openToWork'] != false,
      isDaily: map['isDaily'] == true || legacyDaily,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  StaffWorkerListing copyWith({
    bool? openToWork,
    bool? isDaily,
    String? title,
    String? about,
    double? rate,
    StaffRateType? rateType,
    DateTime? updatedAt,
  }) {
    return StaffWorkerListing(
      id: id,
      uid: uid,
      displayName: displayName,
      photoUrl: photoUrl,
      title: title ?? this.title,
      about: about ?? this.about,
      professionLabel: professionLabel,
      province: province,
      district: district,
      rateType: rateType ?? this.rateType,
      rate: rate ?? this.rate,
      openToWork: openToWork ?? this.openToWork,
      isDaily: isDaily ?? this.isDaily,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }
}

/// İşverenin "eleman arıyorum" ilanı.
class StaffNeed {
  const StaffNeed({
    required this.id,
    required this.employerUid,
    required this.employerName,
    required this.title,
    required this.detail,
    required this.province,
    required this.district,
    required this.neededCount,
    required this.isDaily,
    required this.status,
    required this.createdAt,
    this.employerPhotoUrl,
    this.dailyRate,
    this.workDate,
  });

  final String id;
  final String employerUid;
  final String employerName;
  final String? employerPhotoUrl;
  final String title;
  final String detail;
  final String province;
  final String district;
  final int neededCount;
  final bool isDaily;
  final double? dailyRate;
  final DateTime? workDate;
  /// open | closed
  final String status;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  String get placeLabel => '$province / $district';

  String get rateLabel =>
      dailyRate == null ? 'Ücret görüşülür' : '${dailyRate!.round()} ₺/gün';

  Map<String, dynamic> toMap() => {
        'employerUid': employerUid,
        'employerName': employerName,
        'employerPhotoURL': employerPhotoUrl,
        'title': title,
        'detail': detail,
        'province': province,
        'district': district,
        'neededCount': neededCount,
        'isDaily': isDaily,
        'dailyRate': dailyRate,
        'workDate': workDate?.toIso8601String(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StaffNeed.fromMap(String id, Map<String, dynamic> map) {
    final legacyDaily = map['kind'] == 'dayLabor';
    return StaffNeed(
      id: id,
      employerUid: (map['employerUid'] as String?) ?? '',
      employerName: (map['employerName'] as String?) ?? '',
      employerPhotoUrl: map['employerPhotoURL'] as String?,
      title: (map['title'] as String?) ?? '',
      detail: (map['detail'] as String?) ?? '',
      province: (map['province'] as String?) ?? '',
      district: (map['district'] as String?) ?? '',
      neededCount: (map['neededCount'] as num?)?.toInt() ?? 1,
      isDaily: map['isDaily'] == true || legacyDaily,
      dailyRate: (map['dailyRate'] as num?)?.toDouble(),
      workDate: map['workDate'] != null
          ? DateTime.tryParse(map['workDate'].toString())
          : null,
      status: (map['status'] as String?) ?? 'open',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

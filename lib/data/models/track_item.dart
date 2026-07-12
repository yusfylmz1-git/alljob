import 'dart:math';

/// Takip Merkezi kaydı. Kişisel veya iş hayatındaki her türlü takibi
/// (randevu, hatırlatma, görev, müşteri takibi…) temsil eder. Belirli bir
/// mesleğe bağlı değildir — usta, doktor, berber, öğretmen herkes kullanır.
///
/// TASARIM: zorunlu olan yalnızca [title]; gerisi opsiyonel. Alanların TAMAMI
/// modelde hazırdır (bilgi mimarisi tam brief'e hazır) ama arayüzde ihtiyaca
/// göre "akıllı" açılır (progressive disclosure) — hepsi aynı anda gösterilmez.
///
/// DEPOLAMA: yerel-öncelikli (sqflite). [toMap]/[fromMap] JSON uyumludur;
/// tarihler `millisecondsSinceEpoch` (int) olarak taşınır — hem sqflite hem de
/// ileride bulut yedeği (Firestore) için aynı biçim çalışır.

/// Tamamlanma durumu. (Brief: "Durum" + "Tamamlanma durumu".)
enum TrackStatus {
  active, // sürüyor / bekliyor
  done; // tamamlandı

  String get apiValue => name;

  String get labelTR => switch (this) {
        TrackStatus.active => 'Aktif',
        TrackStatus.done => 'Tamamlandı',
      };

  static TrackStatus fromString(String? v) => TrackStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TrackStatus.active,
      );
}

/// Öncelik. (Brief: "Öncelik".)
enum TrackPriority {
  low,
  normal,
  high;

  String get apiValue => name;

  String get labelTR => switch (this) {
        TrackPriority.low => 'Düşük',
        TrackPriority.normal => 'Normal',
        TrackPriority.high => 'Yüksek',
      };

  static TrackPriority fromString(String? v) =>
      TrackPriority.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TrackPriority.normal,
      );
}

/// Tekrarlama kuralı. (Brief: "Tekrarlama".) Motoru Faz 2'de eklenir; model
/// şimdiden hazır durur.
enum TrackRecurrence {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get apiValue => name;

  String get labelTR => switch (this) {
        TrackRecurrence.none => 'Tekrar yok',
        TrackRecurrence.daily => 'Her gün',
        TrackRecurrence.weekly => 'Her hafta',
        TrackRecurrence.monthly => 'Her ay',
        TrackRecurrence.yearly => 'Her yıl',
      };

  static TrackRecurrence fromString(String? v) =>
      TrackRecurrence.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TrackRecurrence.none,
      );

  /// [from]'dan sonraki bir sonraki tekrar zamanı. Saat/dakika korunur.
  /// [none] için null döner. Ay/yıl eklemede ayın gün sayısı taşarsa ayın
  /// SON gününe kırpılır (31 Ocak + 1 ay → 28/29 Şubat; 29 Şubat + 1 yıl →
  /// 28 Şubat). Böylece geçersiz tarih (ör. 31 Şubat → 3 Mart) oluşmaz.
  DateTime? nextAfter(DateTime from) {
    switch (this) {
      case TrackRecurrence.none:
        return null;
      case TrackRecurrence.daily:
        return from.add(const Duration(days: 1));
      case TrackRecurrence.weekly:
        return from.add(const Duration(days: 7));
      case TrackRecurrence.monthly:
        return _addMonths(from, 1);
      case TrackRecurrence.yearly:
        return _addMonths(from, 12);
    }
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    // Hedef ayın gün sayısı (bir sonraki ayın 0. günü = bu ayın son günü).
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(year, month, day, d.hour, d.minute, d.second);
  }
}

/// Ek türü. (Brief: "Fotoğraf" / "Dosya" / "Ses Notu".)
enum TrackAttachmentType {
  photo,
  file,
  audio;

  String get apiValue => name;

  static TrackAttachmentType fromString(String? v) =>
      TrackAttachmentType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TrackAttachmentType.file,
      );
}

/// İlgili kişi. (Brief: "İlgili kişi" + "Telefon".)
class TrackPerson {
  const TrackPerson({required this.name, this.phone});

  final String name;
  final String? phone;

  Map<String, dynamic> toMap() => {'name': name, if (phone != null) 'phone': phone};

  static TrackPerson fromMap(Map<String, dynamic> m) => TrackPerson(
        name: (m['name'] ?? '') as String,
        phone: m['phone'] as String?,
      );
}

/// Konum. (Brief: "Konum".) Serbest metin etiket + opsiyonel koordinat.
class TrackLocation {
  const TrackLocation({required this.label, this.lat, this.lng});

  final String label;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toMap() => {
        'label': label,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  static TrackLocation fromMap(Map<String, dynamic> m) => TrackLocation(
        label: (m['label'] ?? '') as String,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

/// Ek (foto/dosya/ses). [path] yerel dosya yolu; bulut yedeğinde uzak URL ile
/// değiştirilebilir.
class TrackAttachment {
  const TrackAttachment({
    required this.type,
    required this.path,
    this.name,
    this.sizeBytes,
    this.durationMs,
  });

  final TrackAttachmentType type;
  final String path;
  final String? name;
  final int? sizeBytes;

  /// Yalnız ses notları için: kayıt uzunluğu (ms).
  final int? durationMs;

  Map<String, dynamic> toMap() => {
        'type': type.apiValue,
        'path': path,
        if (name != null) 'name': name,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (durationMs != null) 'durationMs': durationMs,
      };

  static TrackAttachment fromMap(Map<String, dynamic> m) => TrackAttachment(
        type: TrackAttachmentType.fromString(m['type'] as String?),
        path: (m['path'] ?? '') as String,
        name: m['name'] as String?,
        sizeBytes: (m['sizeBytes'] as num?)?.toInt(),
        durationMs: (m['durationMs'] as num?)?.toInt(),
      );
}

class TrackItem {
  TrackItem({
    required this.id,
    required this.title,
    this.note,
    this.status = TrackStatus.active,
    this.priority = TrackPriority.normal,
    this.tags = const [],
    this.reminderAt,
    this.recurrence = TrackRecurrence.none,
    this.person,
    this.location,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;

  /// Zorunlu tek alan.
  final String title;
  final String? note;

  final TrackStatus status;
  final TrackPriority priority;
  final List<String> tags;

  /// Hatırlatma zamanı (Faz 2'de yerel bildirim buradan kurulur).
  final DateTime? reminderAt;
  final TrackRecurrence recurrence;

  final TrackPerson? person;
  final TrackLocation? location;
  final List<TrackAttachment> attachments;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Çöp kutusu: null değilse kayıt "silinmiş" sayılır (kalıcı silinmez).
  final DateTime? deletedAt;

  bool get isDone => status == TrackStatus.done;
  bool get isTrashed => deletedAt != null;
  bool get hasReminder => reminderAt != null;

  /// Yeni kayıt için çakışmayan kimlik (zaman damgası + rastgele son ek).
  static String newId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rnd = Random().nextInt(1 << 32).toRadixString(36);
    return 't_${ts}_$rnd';
  }

  TrackItem copyWith({
    String? title,
    String? note,
    TrackStatus? status,
    TrackPriority? priority,
    List<String>? tags,
    DateTime? reminderAt,
    TrackRecurrence? recurrence,
    TrackPerson? person,
    TrackLocation? location,
    List<TrackAttachment>? attachments,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TrackItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      reminderAt: reminderAt ?? this.reminderAt,
      recurrence: recurrence ?? this.recurrence,
      person: person ?? this.person,
      location: location ?? this.location,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;
  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (note != null) 'note': note,
        'status': status.apiValue,
        'priority': priority.apiValue,
        'tags': tags,
        if (reminderAt != null) 'reminderAt': _ms(reminderAt),
        'recurrence': recurrence.apiValue,
        if (person != null) 'person': person!.toMap(),
        if (location != null) 'location': location!.toMap(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toMap()).toList(),
        'createdAt': _ms(createdAt),
        'updatedAt': _ms(updatedAt),
        if (deletedAt != null) 'deletedAt': _ms(deletedAt),
      };

  static TrackItem fromMap(Map<String, dynamic> m) => TrackItem(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        note: m['note'] as String?,
        status: TrackStatus.fromString(m['status'] as String?),
        priority: TrackPriority.fromString(m['priority'] as String?),
        tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        reminderAt: _dt(m['reminderAt']),
        recurrence: TrackRecurrence.fromString(m['recurrence'] as String?),
        person: m['person'] == null
            ? null
            : TrackPerson.fromMap(
                (m['person'] as Map).cast<String, dynamic>()),
        location: m['location'] == null
            ? null
            : TrackLocation.fromMap(
                (m['location'] as Map).cast<String, dynamic>()),
        attachments: (m['attachments'] as List?)
                ?.map((e) =>
                    TrackAttachment.fromMap((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        createdAt: _dt(m['createdAt']) ?? DateTime.now(),
        updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
        deletedAt: _dt(m['deletedAt']),
      );
}

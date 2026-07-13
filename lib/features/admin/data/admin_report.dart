import '../../../data/models/report.dart';

/// Şikayet kaydının yaşam döngüsü durumu (admin kuyruğu).
enum ReportStatus {
  open('open', 'Açık'),
  reviewing('reviewing', 'İnceleniyor'),
  resolved('resolved', 'Çözüldü'),
  dismissed('dismissed', 'Reddedildi');

  const ReportStatus(this.apiValue, this.labelTR);
  final String apiValue;
  final String labelTR;

  /// Kapanmış (kuyruktan düşmüş) durum mu?
  bool get isClosed =>
      this == ReportStatus.resolved || this == ReportStatus.dismissed;

  static ReportStatus fromString(String? v) => values.firstWhere(
        (e) => e.apiValue == v,
        orElse: () => ReportStatus.open,
      );
}

/// Bir şikayet kaydının admin tarafındaki TAM görünümü (`reports/{id}`).
/// İstemci (şikayetçi) bu kaydı okuyamaz; yalnızca `admin:true` claim'i olan
/// yönetici kuyruğu okur (Firestore kuralı). Alanlar [ReportRepository]'nin
/// yazdığı şemayla eşleşir; admin ek olarak durum/çözüm alanlarını yazar.
class Report {
  const Report({
    required this.id,
    required this.reporterUid,
    required this.reportedUid,
    required this.target,
    required this.targetId,
    this.chatId,
    required this.reason,
    this.note,
    required this.status,
    required this.createdAt,
    this.adminNote,
    this.resolvedBy,
    this.resolvedAt,
    this.assignedTo,
  });

  final String id;
  final String reporterUid;
  final String reportedUid;
  final ReportTarget target;
  final String targetId;
  final String? chatId;
  final ReportReason reason;
  final String? note;
  final ReportStatus status;
  final DateTime createdAt;

  /// Admin çözümü sırasında eklenen not + kimin/ne zaman kapattığı.
  final String? adminNote;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  /// Şikayeti ÜSTLENEN yöneticinin uid'i (çoklu-moderatör koordinasyonu; iki
  /// kişi aynı kaydı işlemesin). Yalnız `adminAssignReport` CF yazar; karara
  /// bağlanınca temizlenir. Null = kimse üstlenmemiş.
  final String? assignedTo;

  static ReportTarget _target(String? v) => ReportTarget.values.firstWhere(
        (e) => e.apiValue == v,
        orElse: () => ReportTarget.user,
      );

  static ReportReason _reason(String? v) => ReportReason.values.firstWhere(
        (e) => e.apiValue == v,
        orElse: () => ReportReason.other,
      );

  static DateTime _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory Report.fromMap(String id, Map<String, dynamic> m) => Report(
        id: id,
        reporterUid: (m['reporterUid'] ?? '') as String,
        reportedUid: (m['reportedUid'] ?? '') as String,
        target: _target(m['targetType'] as String?),
        targetId: (m['targetId'] ?? '') as String,
        chatId: m['chatId'] as String?,
        reason: _reason(m['reason'] as String?),
        note: m['note'] as String?,
        status: ReportStatus.fromString(m['status'] as String?),
        createdAt: _date(m['createdAt']),
        adminNote: m['adminNote'] as String?,
        resolvedBy: m['resolvedBy'] as String?,
        resolvedAt: m['resolvedAt'] == null ? null : _date(m['resolvedAt']),
        assignedTo: m['assignedTo'] as String?,
      );
}

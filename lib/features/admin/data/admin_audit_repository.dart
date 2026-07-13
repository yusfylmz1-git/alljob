import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// `adminAuditLogs/{id}` denetim kaydı satırı: kim, ne, hangi hedef, öncesi/
/// sonrası, ne zaman. Yalnız CF (Admin SDK) yazar; yalnız yönetici okur (kural).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorUid,
    required this.action,
    required this.createdAt,
    this.targetType,
    this.targetId,
    this.before,
    this.after,
  });

  final String id;
  final String actorUid;
  final String action;
  final DateTime createdAt;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  /// Eylem kodunun Türkçe karşılığı (bilinmeyen kod olduğu gibi gösterilir).
  String get actionLabelTR => switch (action) {
        'grant_admin' => 'Yönetici yetkisi verildi',
        'set_role' => 'Rol atandı',
        'revoke_admin' => 'Yönetici yetkisi kaldırıldı',
        'suspend_user' => 'Kullanıcı askıya alındı',
        'unsuspend_user' => 'Askı kaldırıldı',
        'resolve_report' => 'Şikayet karara bağlandı',
        'claim_report' => 'Şikayet üstlenildi',
        'release_report' => 'Şikayet bırakıldı',
        'resolve_dispute' => 'Anlaşmazlık çözüldü',
        _ => action,
      };

  static DateTime _date(dynamic v) {
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  factory AuditEntry.fromMap(String id, Map<String, dynamic> m) => AuditEntry(
        id: id,
        actorUid: (m['actorUid'] ?? '') as String,
        action: (m['action'] ?? '') as String,
        createdAt: _date(m['createdAt']),
        targetType: m['targetType'] as String?,
        targetId: m['targetId'] as String?,
        before: _map(m['before']),
        after: _map(m['after']),
      );
}

/// Yönetici denetim kaydı soyutlaması (yalnız okuma — kayıtları CF yazar).
abstract interface class AdminAuditRepository {
  /// En yeni denetim kayıtları (en yeni üstte).
  Stream<List<AuditEntry>> watchAuditLog();
}

/// Firestore `adminAuditLogs` ile çalışan repo. `createdAt` ISO-8601 metin
/// olduğundan tek alan sözlüksel `orderBy` doğru (zamanla artan) çalışır →
/// bileşik indeks gerekmez. Pencere [_pageLimit] ile sınırlı (ölçek).
class FirebaseAdminAuditRepository implements AdminAuditRepository {
  FirebaseAdminAuditRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const int _pageLimit = 200;

  @override
  Stream<List<AuditEntry>> watchAuditLog() {
    return _db
        .collection('adminAuditLogs')
        .orderBy('createdAt', descending: true)
        .limit(_pageLimit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AuditEntry.fromMap(d.id, d.data())).toList());
  }
}

/// Bellek-içi repo (testler ve Firebase'siz geliştirme). Denetim kayıtlarını
/// mock repo'lar yazmadığından liste [seed] ile verilir.
class MockAdminAuditRepository implements AdminAuditRepository {
  MockAdminAuditRepository([List<AuditEntry>? seed])
      : _items = [...?seed]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final List<AuditEntry> _items;

  @override
  Stream<List<AuditEntry>> watchAuditLog() => Stream.value(_items);
}

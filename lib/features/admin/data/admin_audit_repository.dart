import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// `adminAuditLogs/{id}` denetim kaydı satırı: kim, ne, hangi hedef, öncesi/
/// sonrası, ne zaman. Yalnız CF (Admin SDK) yazar; yalnız yönetici okur (kural).
class AuditEntry {
  AuditEntry({
    required this.id,
    required this.actorUid,
    required this.action,
    required this.createdAt,
    String? cursor,
    this.targetType,
    this.targetId,
    this.before,
    this.after,
  }) : cursor = cursor ?? createdAt.toUtc().toIso8601String();

  final String id;
  final String actorUid;
  final String action;
  final DateTime createdAt;

  /// Sayfalama imleci: kaydın DEPO'daki ham `createdAt` metni (sözlüksel sıra
  /// = zaman sırası). Bir sonraki (daha eski) sayfa `createdAt < cursor` ile
  /// çekilir. Firebase için ham metin birebir korunur (sınır kayması olmaz);
  /// elle üretilen kayıtlarda [createdAt]'ten türetilir.
  final String cursor;

  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  /// Eylem kodunun Türkçe karşılığı (bilinmeyen kod olduğu gibi gösterilir).
  String get actionLabelTR => switch (action) {
    'grant_admin' => 'Yönetici yetkisi verildi',
    'set_role' => 'Rol atandı',
    'revoke_admin' => 'Yönetici yetkisi kaldırıldı',
    'set_capabilities' => 'Yetkiler güncellendi',
    'invite_create' => 'Moderatör daveti oluşturuldu',
    'invite_accept' => 'Davet kabul edildi',
    'invite_revoke' => 'Davet iptal edildi',
    'stats_rebuild' => 'İstatistikler yeniden kuruldu',
    'moderate_job' => 'İlan moderasyonu',
    'set_artisan_flags' => 'Usta vitrin ayarı',
    'hide_review' => 'Değerlendirme gizlendi',
    'get_chat_transcript' => 'Sohbet kanıtı okundu',
    'hide_message' => 'Mesaj kaldırıldı',
    'unhide_message' => 'Mesaj geri getirildi',
    'suspend_user' => 'Hesap askıya alındı',
    'unsuspend_user' => 'Hesap askısı kaldırıldı',
    'resolve_report' => 'Şikayet karara bağlandı',
    'claim_report' => 'Şikayet üstlenildi',
    'release_report' => 'Şikayet bırakıldı',
    'moderate_product' => 'Ürün moderasyonu',
    'update_config' => 'Sistem ayarı güncellendi',
    'grant_premium' => 'Premium tanımlandı / iptal',
    'review_certificates' => 'Belge incelemesi',
    'add_user_note' => 'Dahili not eklendi',
    'bulk_plan_update' => 'Toplu plan güncellemesi',
    'bulk_suspend' => 'Toplu askı',
    'export' => 'Dışa aktarım',
    'broadcast' => 'Duyuru gönderildi',
    // Artık üretilmiyor (hakemlik kalktı); ESKİ kayıtlar okunabilsin diye durur.
    'resolve_dispute' => 'Anlaşmazlık çözüldü',
    _ => action,
  };

  /// Hedef türünün Türkçe etiketi.
  String get targetTypeLabelTR {
    final t = (targetType ?? '').toLowerCase();
    return switch (t) {
      'user' || 'users' => 'Kullanıcı',
      'job' || 'jobs' => 'İlan',
      'product' || 'products' => 'Ürün',
      'report' || 'reports' => 'Şikayet',
      'review' || 'reviews' => 'Değerlendirme',
      'artisan' || 'artisanprofile' || 'artisan_profile' => 'Usta profili',
      'message' || 'messages' => 'Mesaj',
      'chat' || 'chats' => 'Sohbet',
      'config' || 'adminconfig' => 'Sistem ayarı',
      'invite' => 'Davet',
      '' => 'Hedef',
      _ => targetType!,
    };
  }

  /// Operatörün okuyabileceği tek satırlık özet (UID yığını değil).
  String get summaryLine {
    final parts = <String>[actionLabelTR];
    final detail = detailSummary;
    if (detail != null && detail.isNotEmpty) parts.add(detail);
    return parts.join(' · ');
  }

  /// `after` / `before` haritasından insan dilinde kısa özet.
  String? get detailSummary {
    final a = after;
    if (a == null || a.isEmpty) return null;
    final parts = <String>[];

    void add(String label, dynamic v) {
      if (v == null) return;
      final s = '$v'.trim();
      if (s.isEmpty) return;
      parts.add('$label: $s');
    }

    if (a['role'] != null) {
      final r = '${a['role']}';
      parts.add(r == 'null' || r.isEmpty ? 'rol kaldırıldı' : 'rol → $r');
    }
    if (a['status'] != null) {
      final st = '${a['status']}';
      parts.add(switch (st) {
        'resolved' => 'sonuç: çözüldü',
        'dismissed' => 'sonuç: reddedildi',
        'open' => 'durum: açık',
        'reviewing' => 'durum: inceleniyor',
        'active' => 'yayında',
        'pending_review' => 'incelemede',
        'rejected' => 'reddedildi',
        'hidden' => 'gizlendi',
        _ => 'durum: $st',
      });
    }
    if (a['decision'] != null) add('karar', a['decision']);
    if (a['suspended'] != null) {
      parts.add(a['suspended'] == true ? 'askıya alındı' : 'askı kaldırıldı');
    }
    if (a['reason'] != null && '${a['reason']}'.trim().isNotEmpty) {
      parts.add('neden: ${a['reason']}');
    }
    if (a['note'] != null && '${a['note']}'.trim().isNotEmpty) {
      parts.add('not: ${a['note']}');
    }
    if (a['adminNote'] != null && '${a['adminNote']}'.trim().isNotEmpty) {
      parts.add('yönetici notu: ${a['adminNote']}');
    }
    if (a['assignedTo'] != null) add('üstlenen', a['assignedTo']);
    if (a['adminVerified'] != null) {
      parts.add(
        a['adminVerified'] == true
            ? 'platform onayı verildi'
            : 'platform onayı kaldırıldı',
      );
    }
    if (a['featured'] != null) {
      parts.add(a['featured'] == true ? 'öne çıkarıldı' : 'öne çıkarma kalktı');
    }
    if (a['moderationHidden'] != null) {
      parts.add(
        a['moderationHidden'] == true ? 'vitrin gizlendi' : 'vitrin gösterildi',
      );
    }
    if (a['days'] != null) add('gün', a['days']);
    if (a['revoke'] == true) parts.add('premium iptal');
    if (a['expiresAt'] != null) add('bitiş', a['expiresAt']);
    if (a['kind'] != null) add('tür', a['kind']);
    if (a['rowCount'] != null) add('satır', a['rowCount']);
    if (a['mode'] != null) add('mod', a['mode']);
    if (a['approve'] != null) {
      parts.add(a['approve'] == true ? 'belgeler onaylandı' : 'belgeler reddedildi');
    }
    if (a['moderationHidden'] == null &&
        a['hidden'] != null) {
      parts.add(a['hidden'] == true ? 'gizlendi' : 'gösterildi');
    }
    // Bilinen anahtar yoksa ham anahtar=değer (max 3).
    if (parts.isEmpty) {
      for (final e in a.entries.take(3)) {
        if (e.value == null) continue;
        parts.add('${e.key}: ${e.value}');
      }
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

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
    // İmleç = ham depo metni (varsa); böylece sınır kayması olmaz.
    cursor: m['createdAt'] is String ? m['createdAt'] as String : null,
    targetType: m['targetType'] as String?,
    targetId: m['targetId'] as String?,
    before: _map(m['before']),
    after: _map(m['after']),
  );
}

/// Denetim kaydı eylem kategorileri (istemci-tarafı filtre için). Her kategori
/// bir grup eylem kodunu kapsar; [AuditCategory.all] hepsini geçirir.
enum AuditCategory {
  all('Tümü'),
  users('Kullanıcı'),
  content('İçerik'),
  reports('Şikayet'),
  roles('Kadro'),
  system('Sistem');

  const AuditCategory(this.labelTR);
  final String labelTR;

  bool matches(AuditEntry e) => switch (this) {
    AuditCategory.all => true,
    AuditCategory.users => const {
      'suspend_user',
      'unsuspend_user',
      'bulk_suspend',
      'set_artisan_flags',
      'grant_premium',
      'review_certificates',
      'add_user_note',
    }.contains(e.action),
    AuditCategory.content => const {
      'moderate_job',
      'moderate_product',
      'hide_review',
      'hide_message',
      'unhide_message',
      'get_chat_transcript',
      'bulk_plan_update',
    }.contains(e.action),
    AuditCategory.reports => const {
      'resolve_report',
      'claim_report',
      'release_report',
    }.contains(e.action),
    AuditCategory.roles => const {
      'grant_admin',
      'set_role',
      'revoke_admin',
      'set_capabilities',
      'invite_create',
      'invite_accept',
      'invite_revoke',
    }.contains(e.action),
    AuditCategory.system => const {
      'stats_rebuild',
      'update_config',
      'export',
      'broadcast',
    }.contains(e.action),
  };
}

/// Denetim kayıtlarını kategori + serbest metin (aktör/hedef uid) ile süzer.
List<AuditEntry> filterAudit(
  List<AuditEntry> entries, {
  AuditCategory category = AuditCategory.all,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return entries.where((e) {
    if (!category.matches(e)) return false;
    if (q.isEmpty) return true;
    return e.actorUid.toLowerCase().contains(q) ||
        (e.targetId ?? '').toLowerCase().contains(q);
  }).toList();
}

/// Yönetici denetim kaydı soyutlaması (yalnız okuma — kayıtları CF yazar).
abstract interface class AdminAuditRepository {
  /// Bir sayfa denetim kaydı döndürür (en yeni üstte). [beforeCursor] verilirse
  /// yalnız ondan ESKİ kayıtlar gelir (cursor sayfalama; bkz. [AuditEntry.cursor]).
  /// Dönen liste [limit]'e eşitse muhtemelen daha eski kayıt vardır.
  Future<List<AuditEntry>> fetchPage({String? beforeCursor, int limit});
}

/// Firestore `adminAuditLogs` ile çalışan repo. `createdAt` ISO-8601 metin
/// olduğundan tek alan sözlüksel `orderBy`/`isLessThan` doğru (zamanla artan)
/// çalışır → bileşik indeks gerekmez. Cursor = son kaydın ham `createdAt`
/// metni; bir sonraki sayfa `createdAt < cursor` ile çekilir (sınır kayması yok).
class FirebaseAdminAuditRepository implements AdminAuditRepository {
  FirebaseAdminAuditRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<AuditEntry>> fetchPage({
    String? beforeCursor,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('adminAuditLogs')
        .orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => AuditEntry.fromMap(d.id, d.data())).toList();
  }
}

/// Bellek-içi repo (testler ve Firebase'siz geliştirme). Denetim kayıtlarını
/// mock repo'lar yazmadığından liste [seed] ile verilir.
class MockAdminAuditRepository implements AdminAuditRepository {
  MockAdminAuditRepository([List<AuditEntry>? seed])
    : _items = [...?seed]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final List<AuditEntry> _items;

  @override
  Future<List<AuditEntry>> fetchPage({
    String? beforeCursor,
    int limit = 50,
  }) async {
    final before = (beforeCursor == null || beforeCursor.isEmpty)
        ? null
        : DateTime.tryParse(beforeCursor);
    final list = before == null
        ? _items
        : _items.where((e) => e.createdAt.isBefore(before)).toList();
    return list.take(limit).toList();
  }
}

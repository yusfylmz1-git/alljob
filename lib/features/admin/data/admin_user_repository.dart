import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/app_user.dart';

/// Kullanıcı dizin filtreleri (tek equality + `createdAt` — bileşik indeks PR0).
enum AdminUserListFilter {
  all,
  suspended,
  artisans,
  nonArtisans,
}

/// Yönetici kadrosu (`adminRoles/{uid}`) satırı: kimin hangi rolde olduğu.
class AdminRosterEntry {
  const AdminRosterEntry({
    required this.uid,
    required this.role,
    this.updatedAt,
    this.email,
    this.capabilities,
    this.capabilitiesFieldPresent = false,
  });

  final String uid;
  final String role; // 'moderator' | 'superadmin'
  final DateTime? updatedAt;
  final String? email;

  /// Explicit capabilities listesi; alan yoksa null ([capabilitiesFieldPresent]
  /// false). Explicit boş dizi = kilitli moderatör.
  final List<String>? capabilities;

  /// Firestore'da `capabilities` anahtarı var mı?
  final bool capabilitiesFieldPresent;

  bool get isSuperAdmin => role == 'superadmin';
}

/// Yönetici kullanıcı yönetimi soyutlaması: bir kullanıcıyı bulup askıya alma /
/// geri açma. Askıya alma zorlaması SUNUCUDADIR (`suspended` custom claim →
/// Firestore kuralları içerik oluşturmayı reddeder); bu repo yalnız arama +
/// `adminSetUserSuspended` CF çağrısıdır (istemci `users`'a doğrudan yazmaz).
///
/// Görünüm modeli olarak [AppUser] yeniden kullanılır (herkese açık `users`
/// dökümanından okunur; `suspended` alanı oradaki bool aynadır).
abstract interface class AdminUserRepository {
  /// UID ile bulur (yoksa null).
  Future<AppUser?> findByUid(String uid);

  /// E-posta ile bulur (yoksa null). Eşitlik sorgusu — e-posta tek alan
  /// otomatik indekslidir.
  Future<AppUser?> findByEmail(String email);

  /// Kullanıcıyı askıya alır / geri açar. Opsiyonel [reason] yalnız denetim
  /// kaydına yazılır (herkese açık dökümana değil).
  Future<void> setSuspended(
    String uid, {
    required bool suspended,
    String? reason,
  });

  /// Kullanıcının mevcut yönetici rolünü döndürür ('moderator'|'superadmin')
  /// ya da yönetici değilse null. Kaynak `adminRoles/{uid}` roster dökümanı
  /// (başka kullanıcının Auth claim'i istemciden okunamaz).
  Future<String?> findRole(String uid);

  /// Bir kullanıcının yönetici rolünü atar/kaldırır (YALNIZ superadmin). [role]
  /// 'moderator' | 'superadmin' | null (yetkiyi kaldır). CF üzerinden yürür.
  Future<void> setRole(String uid, {required String? role});

  /// Yönetici kadrosu (tüm rol sahipleri) — superadmin'ler üstte. Kaynak
  /// `adminRoles` koleksiyonu (kural: yalnız yönetici okur).
  Stream<List<AdminRosterEntry>> watchRoster();

  /// Sayfalı kullanıcı dizini (`createdAt` desc). [beforeCursor] = son satırın
  /// ham ISO `createdAt` metni. [filter] tek equality (indeks READY gerekir).
  Future<List<AppUser>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminUserListFilter filter = AdminUserListFilter.all,
  });

  /// Moderatör yetki listesini günceller (YALNIZ superadmin). CF merge.
  Future<void> setCapabilities(String uid, List<String> capabilities);

  /// Toplu askıya alma / açma (max 25). Sonuçlar uid bazında.
  Future<List<BulkSuspendResult>> bulkSuspend(
    List<String> uids, {
    required bool suspended,
    String? reason,
  });

  /// CSV dışa aktarım denetim kaydı (satır verisi sunucuya gitmez).
  Future<void> logExport({required String kind, required int rowCount});
}

/// [AdminUserRepository.bulkSuspend] tek satır sonucu.
class BulkSuspendResult {
  const BulkSuspendResult({
    required this.uid,
    required this.ok,
    this.suspended,
    this.error,
  });

  final String uid;
  final bool ok;
  final bool? suspended;
  final String? error;
}

int _rosterSort(AdminRosterEntry a, AdminRosterEntry b) {
  // Süper yöneticiler üstte; sonra en son güncellenen üstte.
  if (a.isSuperAdmin != b.isSuperAdmin) return a.isSuperAdmin ? -1 : 1;
  final ad = a.updatedAt ?? DateTime(0);
  final bd = b.updatedAt ?? DateTime(0);
  return bd.compareTo(ad);
}

/// Firestore `users` + `adminSetUserSuspended` CF ile çalışan repo.
class FirebaseAdminUserRepository implements AdminUserRepository {
  FirebaseAdminUserRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<AppUser?> findByUid(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    // H2: e-posta public users'ta yok → Auth Admin (CF) + public profil.
    try {
      final res = await _functions
          .httpsCallable('adminLookupUser')
          .call<Object?>({'uid': id});
      return _userFromLookup(res.data);
    } catch (_) {
      final snap = await _db.collection('users').doc(id).get();
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.id, snap.data()!);
    }
  }

  @override
  Future<AppUser?> findByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    // H2: e-posta sorgusu Auth üzerinden (public users'ta email yok).
    try {
      final res = await _functions
          .httpsCallable('adminLookupUser')
          .call<Object?>({'email': e});
      return _userFromLookup(res.data);
    } catch (_) {
      // Legacy: eski dökümanlarda email hâlâ public olabilir.
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: e)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return AppUser.fromMap(d.id, d.data());
    }
  }

  AppUser? _userFromLookup(Object? data) {
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final uid = m['uid']?.toString();
    if (uid == null || uid.isEmpty) return null;
    final created = DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return AppUser(
      uid: uid,
      displayName: (m['displayName'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      createdAt: created,
      hasArtisanProfile: m['hasArtisanProfile'] == true,
      phoneVerified: false,
      emailVerified: m['emailVerified'] == true,
      suspended: m['suspended'] == true,
      profilePhotoUrl: m['profilePhotoURL'] as String?,
    );
  }

  @override
  Future<void> setSuspended(
    String uid, {
    required bool suspended,
    String? reason,
  }) async {
    await _functions.httpsCallable('adminSetUserSuspended').call<Object?>({
      'uid': uid,
      'suspended': suspended,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  @override
  Future<String?> findRole(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    final snap = await _db.collection('adminRoles').doc(id).get();
    if (!snap.exists) return null;
    return snap.data()?['role'] as String?;
  }

  @override
  Future<void> setRole(String uid, {required String? role}) async {
    await _functions.httpsCallable('adminSetRole').call<Object?>({
      'uid': uid,
      'role': role ?? 'none',
    });
  }

  @override
  Stream<List<AdminRosterEntry>> watchRoster() {
    return _db.collection('adminRoles').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        final hasCaps = m.containsKey('capabilities');
        final raw = m['capabilities'];
        return AdminRosterEntry(
          uid: d.id,
          role: (m['role'] as String?) ?? 'moderator',
          updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? ''),
          email: m['email'] as String?,
          capabilitiesFieldPresent: hasCaps,
          capabilities: hasCaps && raw is List
              ? raw.map((e) => e.toString()).toList()
              : null,
        );
      }).toList()
        ..sort(_rosterSort);
      return list;
    });
  }

  @override
  Future<List<AppUser>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminUserListFilter filter = AdminUserListFilter.all,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('users');
    switch (filter) {
      case AdminUserListFilter.all:
        break;
      case AdminUserListFilter.suspended:
        q = q.where('suspended', isEqualTo: true);
      case AdminUserListFilter.artisans:
        q = q.where('hasArtisanProfile', isEqualTo: true);
      case AdminUserListFilter.nonArtisans:
        q = q.where('hasArtisanProfile', isEqualTo: false);
    }
    q = q.orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<void> setCapabilities(String uid, List<String> capabilities) async {
    await _functions.httpsCallable('adminSetCapabilities').call<Object?>({
      'uid': uid,
      'capabilities': capabilities,
    });
  }

  @override
  Future<List<BulkSuspendResult>> bulkSuspend(
    List<String> uids, {
    required bool suspended,
    String? reason,
  }) async {
    final res = await _functions
        .httpsCallable('adminBulkSuspend')
        .call<Object?>({
      'uids': uids,
      'suspended': suspended,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    final data = res.data;
    if (data is! Map) return const [];
    final raw = data['results'];
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return BulkSuspendResult(
        uid: m['uid']?.toString() ?? '',
        ok: m['ok'] == true,
        suspended: m['suspended'] is bool ? m['suspended'] as bool : null,
        error: m['error']?.toString(),
      );
    }).toList();
  }

  @override
  Future<void> logExport({
    required String kind,
    required int rowCount,
  }) async {
    await _functions.httpsCallable('adminLogExport').call<Object?>({
      'kind': kind,
      'rowCount': rowCount,
    });
  }
}

/// Bellek-içi repo (testler ve Firebase'siz geliştirme). CF etkisini taklit
/// eder: setSuspended kaydın `suspended` alanını çevirir.
class MockAdminUserRepository implements AdminUserRepository {
  MockAdminUserRepository([List<AppUser>? seed]) {
    if (seed != null) {
      for (final u in seed) {
        _users[u.uid] = u;
      }
    }
  }

  final Map<String, AppUser> _users = {};
  final Map<String, String> _roles = {}; // uid → 'moderator'|'superadmin'
  final Map<String, DateTime> _roleUpdatedAt = {};
  final Map<String, List<String>?> _caps = {}; // null = field missing
  final _changes = StreamController<void>.broadcast();

  @override
  Future<AppUser?> findByUid(String uid) async => _users[uid.trim()];

  @override
  Future<AppUser?> findByEmail(String email) async {
    final e = email.trim().toLowerCase();
    for (final u in _users.values) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  @override
  Future<void> setSuspended(
    String uid, {
    required bool suspended,
    String? reason,
  }) async {
    final u = _users[uid.trim()];
    if (u == null) return;
    _users[uid.trim()] = u.copyWith(suspended: suspended);
  }

  @override
  Future<String?> findRole(String uid) async => _roles[uid.trim()];

  @override
  Future<void> setRole(String uid, {required String? role}) async {
    final id = uid.trim();
    if (role == null || role == 'none') {
      _roles.remove(id);
      _roleUpdatedAt.remove(id);
      _caps.remove(id);
    } else {
      _roles[id] = role;
      _roleUpdatedAt[id] = DateTime.now();
      if (role == 'moderator' && !_caps.containsKey(id)) {
        _caps[id] = null; // missing until setCapabilities
      }
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> setCapabilities(String uid, List<String> capabilities) async {
    final id = uid.trim();
    if (!_roles.containsKey(id)) return;
    _caps[id] = List<String>.from(capabilities);
    _roleUpdatedAt[id] = DateTime.now();
    if (!_changes.isClosed) _changes.add(null);
  }

  List<AdminRosterEntry> _roster() => _roles.entries
      .map((e) {
        final hasKey = _caps.containsKey(e.key);
        final c = _caps[e.key];
        return AdminRosterEntry(
          uid: e.key,
          role: e.value,
          updatedAt: _roleUpdatedAt[e.key],
          capabilitiesFieldPresent: hasKey && c != null,
          capabilities: c,
        );
      })
      .toList()
    ..sort(_rosterSort);

  @override
  Stream<List<AdminRosterEntry>> watchRoster() async* {
    yield _roster();
    await for (final _ in _changes.stream) {
      yield _roster();
    }
  }

  @override
  Future<List<AppUser>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminUserListFilter filter = AdminUserListFilter.all,
  }) async {
    var list = _users.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    switch (filter) {
      case AdminUserListFilter.all:
        break;
      case AdminUserListFilter.suspended:
        list = list.where((u) => u.suspended).toList();
      case AdminUserListFilter.artisans:
        list = list.where((u) => u.hasArtisanProfile).toList();
      case AdminUserListFilter.nonArtisans:
        list = list.where((u) => !u.hasArtisanProfile).toList();
    }
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      final cut = DateTime.tryParse(beforeCursor);
      if (cut != null) {
        list = list.where((u) => u.createdAt.isBefore(cut)).toList();
      }
    }
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  @override
  Future<List<BulkSuspendResult>> bulkSuspend(
    List<String> uids, {
    required bool suspended,
    String? reason,
  }) async {
    if (uids.isEmpty || uids.length > 25) {
      throw StateError('uids 1–25');
    }
    final out = <BulkSuspendResult>[];
    for (final raw in uids) {
      final id = raw.trim();
      final u = _users[id];
      if (u == null) {
        out.add(BulkSuspendResult(uid: id, ok: false, error: 'not-found'));
        continue;
      }
      if (_roles.containsKey(id)) {
        out.add(BulkSuspendResult(uid: id, ok: false, error: 'is-admin'));
        continue;
      }
      _users[id] = u.copyWith(suspended: suspended);
      out.add(BulkSuspendResult(uid: id, ok: true, suspended: suspended));
    }
    return out;
  }

  final List<({String kind, int rowCount})> exportLogs = [];

  @override
  Future<void> logExport({
    required String kind,
    required int rowCount,
  }) async {
    exportLogs.add((kind: kind, rowCount: rowCount));
  }

  /// Test seed: kullanıcı ekler/günceller.
  void put(AppUser user) => _users[user.uid] = user;

  void dispose() => _changes.close();
}

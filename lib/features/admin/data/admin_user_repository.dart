import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/app_user.dart';

/// Yönetici kadrosu (`adminRoles/{uid}`) satırı: kimin hangi rolde olduğu.
class AdminRosterEntry {
  const AdminRosterEntry({
    required this.uid,
    required this.role,
    this.updatedAt,
  });

  final String uid;
  final String role; // 'moderator' | 'superadmin'
  final DateTime? updatedAt;

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
    final snap = await _db.collection('users').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromMap(snap.id, snap.data()!);
  }

  @override
  Future<AppUser?> findByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: e)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return AppUser.fromMap(d.id, d.data());
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
        return AdminRosterEntry(
          uid: d.id,
          role: (m['role'] as String?) ?? 'moderator',
          updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? ''),
        );
      }).toList()
        ..sort(_rosterSort);
      return list;
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
    } else {
      _roles[id] = role;
      _roleUpdatedAt[id] = DateTime.now();
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  List<AdminRosterEntry> _roster() => _roles.entries
      .map((e) => AdminRosterEntry(
            uid: e.key,
            role: e.value,
            updatedAt: _roleUpdatedAt[e.key],
          ))
      .toList()
    ..sort(_rosterSort);

  @override
  Stream<List<AdminRosterEntry>> watchRoster() async* {
    yield _roster();
    await for (final _ in _changes.stream) {
      yield _roster();
    }
  }

  void dispose() => _changes.close();
}

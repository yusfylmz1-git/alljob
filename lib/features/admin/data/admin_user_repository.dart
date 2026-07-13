import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/app_user.dart';

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
}

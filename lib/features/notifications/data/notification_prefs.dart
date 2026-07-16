import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../auth/application/auth_controller.dart';

/// Push bildirim tercihleri (YOL_HARITASI P1).
///
/// Uygulama **içi** bildirim merkezi her zaman dolar; bu bayraklar yalnız
/// cihaz **push** (FCM) gönderimini keser. Varsayılan: hepsi açık.
///
/// Depo: `users/{uid}/private/push.prefs` (token'larla aynı gizli döküman).
class NotificationPrefs {
  const NotificationPrefs({
    this.chat = true,
    this.jobUpdates = true,
    this.nearbyJobs = true,
  });

  /// Sohbet mesajı push'u.
  final bool chat;

  /// İş durumu (seçilme, tamamlanma, anlaşmazlık, iptal…).
  final bool jobUpdates;

  /// Yeni ilan eşleşmesi (usta — bölge/meslek).
  final bool nearbyJobs;

  static const defaults = NotificationPrefs();

  NotificationPrefs copyWith({
    bool? chat,
    bool? jobUpdates,
    bool? nearbyJobs,
  }) {
    return NotificationPrefs(
      chat: chat ?? this.chat,
      jobUpdates: jobUpdates ?? this.jobUpdates,
      nearbyJobs: nearbyJobs ?? this.nearbyJobs,
    );
  }

  Map<String, dynamic> toMap() => {
        'chat': chat,
        'jobUpdates': jobUpdates,
        'nearbyJobs': nearbyJobs,
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    // Eksik / null alan = açık (geriye dönük; eski hesaplar bozulmasın).
    return NotificationPrefs(
      chat: map['chat'] != false,
      jobUpdates: map['jobUpdates'] != false,
      nearbyJobs: map['nearbyJobs'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPrefs &&
          chat == other.chat &&
          jobUpdates == other.jobUpdates &&
          nearbyJobs == other.nearbyJobs;

  @override
  int get hashCode => Object.hash(chat, jobUpdates, nearbyJobs);
}

/// Tercih okuma/yazma.
abstract class NotificationPrefsRepository {
  Stream<NotificationPrefs> watch(String uid);
  Future<void> save(String uid, NotificationPrefs prefs);
}

class FirebaseNotificationPrefsRepository implements NotificationPrefsRepository {
  FirebaseNotificationPrefsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _pushRef(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('push');

  @override
  Stream<NotificationPrefs> watch(String uid) {
    return _pushRef(uid).snapshots().map((snap) {
      final data = snap.data();
      final raw = data?['prefs'];
      if (raw is Map<String, dynamic>) {
        return NotificationPrefs.fromMap(raw);
      }
      if (raw is Map) {
        return NotificationPrefs.fromMap(Map<String, dynamic>.from(raw));
      }
      return NotificationPrefs.defaults;
    });
  }

  @override
  Future<void> save(String uid, NotificationPrefs prefs) async {
    await _pushRef(uid).set({
      'prefs': prefs.toMap(),
      'prefsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Bellek içi (mock / test).
class MockNotificationPrefsRepository implements NotificationPrefsRepository {
  final Map<String, NotificationPrefs> _byUid = {};

  @override
  Stream<NotificationPrefs> watch(String uid) async* {
    yield _byUid[uid] ?? NotificationPrefs.defaults;
  }

  @override
  Future<void> save(String uid, NotificationPrefs prefs) async {
    _byUid[uid] = prefs;
  }
}

final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>((ref) {
  if (useFirebaseBackend) return FirebaseNotificationPrefsRepository();
  return MockNotificationPrefsRepository();
});

/// Oturum açmış kullanıcının tercihleri (yoksa varsayılan).
final notificationPrefsProvider =
    StreamProvider<NotificationPrefs>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(NotificationPrefs.defaults);
  return ref.watch(notificationPrefsRepositoryProvider).watch(uid);
});

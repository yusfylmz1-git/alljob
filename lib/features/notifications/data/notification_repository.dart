import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/app_notification.dart';

/// Uygulama içi bildirim merkezi soyutlaması. Kayıtları sunucu (Cloud
/// Functions) yazar; istemci okur ve okundu işaretler.
abstract interface class NotificationRepository {
  /// Kullanıcının bildirimleri — canlı akış, en yeni en üstte.
  Stream<List<AppNotification>> watchMyNotifications(String uid);

  /// Verilen bildirimleri okundu işaretler (rozet sayacı sıfırlansın).
  Future<void> markRead(String uid, List<String> notificationIds);
}

/// Firestore `users/{uid}/notifications` ile çalışan gerçek depo.
class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  @override
  Stream<List<AppNotification>> watchMyNotifications(String uid) {
    // Tek alan sıralaması → otomatik indeks yeterli, composite gerekmez.
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> markRead(String uid, List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in notificationIds) {
      batch.update(_col(uid).doc(id), {'read': true});
    }
    await batch.commit();
  }
}

/// Bellek içi bildirim deposu (mock mod + testler). Görsel geliştirme
/// kolaylığı için ilk izlemede birkaç örnek bildirim tohumlar.
class MockNotificationRepository implements NotificationRepository {
  final Map<String, List<AppNotification>> _byUser = {};
  final _ctrl = StreamController<void>.broadcast();

  List<AppNotification> _seed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'job_demo1',
        type: 'job',
        title: 'Bursa bölgesinde yeni iş ilanı',
        body: 'Mutfak dolabı montajı · Osmangazi',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 12)),
        jobId: 'job_demo1',
      ),
      AppNotification(
        id: 'chat_demo',
        type: 'chat',
        title: 'Ahmet Yılmaz',
        body: 'Merhaba, yarın müsait misiniz?',
        read: false,
        createdAt: now.subtract(const Duration(hours: 3)),
        chatId: 'chat_demo',
      ),
      AppNotification(
        id: 'job_demo2',
        type: 'job',
        title: '🎉 Bir iş için seçildiniz',
        body: '"Banyo tadilatı" için müşteri sizi seçti.',
        read: true,
        createdAt: now.subtract(const Duration(days: 2)),
        jobId: 'job_demo2',
      ),
    ];
  }

  List<AppNotification> _list(String uid) =>
      _byUser.putIfAbsent(uid, _seed);

  @override
  Stream<List<AppNotification>> watchMyNotifications(String uid) async* {
    yield _list(uid);
    yield* _ctrl.stream.map((_) => _list(uid));
  }

  @override
  Future<void> markRead(String uid, List<String> notificationIds) async {
    final list = _list(uid);
    for (var i = 0; i < list.length; i++) {
      if (notificationIds.contains(list[i].id)) {
        list[i] = list[i].copyWith(read: true);
      }
    }
    _ctrl.add(null);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (useFirebaseBackend) return FirebaseNotificationRepository();
  return MockNotificationRepository();
});

/// Kullanıcının bildirim akışı (en yeni üstte, ilk 50).
final myNotificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, uid) {
  return ref.watch(notificationRepositoryProvider).watchMyNotifications(uid);
});

/// Zil rozetindeki okunmamış sayısı.
final unreadNotificationCountProvider =
    Provider.family<int, String>((ref, uid) {
  final list = ref.watch(myNotificationsProvider(uid)).valueOrNull;
  if (list == null) return 0;
  return list.where((n) => !n.read).length;
});

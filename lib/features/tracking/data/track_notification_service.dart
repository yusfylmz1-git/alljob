import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/router/app_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../data/models/track_item.dart';

/// Takip Merkezi hatırlatmalarını yöneten servis (Faz 2). TAMAMEN yerel:
/// buluta/FCM'e gerek yok, cihazda `flutter_local_notifications` ile planlanır.
///
/// Kalıp [PushService] ile aynı: arayüz + gerçek impl + no-op (web/test). Mobil
/// olmayan ortamlarda ([kIsWeb]) ve testlerde no-op kullanılır.
///
/// TEKRARLAMA MODELİ (ürün kararı): tekrarlı takip TAMAMLANINCA aynı kayıt
/// bir sonraki tarihe kayar (bkz. [TrackingController]); bu servis her zaman
/// TEK atışlık bildirim planlar (OS-tekrarı kullanılmaz). Böylece günlük/
/// haftalık/aylık/yıllık aynı yolla, tutarlı yürür.
abstract interface class TrackNotificationService {
  /// Eklenti + saat dilimi veritabanını hazırlar (idempotent).
  Future<void> init();

  /// Bildirim iznini ister (Android 13+, iOS). İzin verildiyse true.
  Future<bool> ensurePermission();

  /// Kaydın durumuna göre hatırlatmayı planlar ya da iptal eder:
  /// aktif + çöpte değil + gelecekte bir [TrackItem.reminderAt] varsa planlar,
  /// aksi halde (tamamlandı/çöpte/geçmiş/boş) iptal eder. Idempotent.
  Future<void> sync(TrackItem item);

  /// Verilen kaydın planlı bildirimini iptal eder.
  Future<void> cancel(String trackId);
}

/// Kayıt kimliğinden (String) kararlı 31-bit bildirim id'si üretir.
/// Aynı kayıt her zaman aynı id'yi alır → güncelle/iptal doğru hedefler.
int trackNotificationId(String trackId) {
  var hash = 0;
  for (final code in trackId.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return hash;
}

/// Cihaz üstünde gerçek bildirim planlayan uygulama.
class LocalTrackNotificationService implements TrackNotificationService {
  LocalTrackNotificationService(this._ref);
  final Ref _ref;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const _channelId = 'track_reminders';
  static const _channelName = 'Takip Hatırlatmaları';
  static const _channelDesc = 'Takip Merkezi randevu/görev hatırlatmaları';

  @override
  Future<void> init() async {
    if (_inited) return;
    try {
      tzdata.initializeTimeZones();
      // TR pazarı: kalıcı UTC+3 (DST yok). Uluslararasılaşınca cihazın gerçek
      // saat dilimini almak için flutter_timezone eklenmeli.
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap,
      );
      _inited = true;
    } catch (e) {
      debugPrint('TrackNotification init hatası: $e');
    }
  }

  void _onTap(NotificationResponse response) {
    final id = response.payload;
    if (id == null || id.isEmpty) return;
    try {
      _ref.read(routerProvider).push(RoutePaths.trackDetail(id));
    } catch (e) {
      debugPrint('TrackNotification gezinme hatası: $e');
    }
  }

  @override
  Future<bool> ensurePermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('TrackNotification izin hatası: $e');
      return false;
    }
  }

  @override
  Future<void> sync(TrackItem item) async {
    await init();
    await cancel(item.id);
    final at = item.reminderAt;
    if (item.isTrashed || item.isDone || at == null) return;
    if (!at.isAfter(DateTime.now())) return; // geçmiş → planlama yok
    try {
      await _plugin.zonedSchedule(
        id: trackNotificationId(item.id),
        title: item.title,
        body: _body(item),
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Kesin alarm istemiyoruz (Play kısıtı yok); birkaç dk sapabilir.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.id,
      );
    } catch (e) {
      debugPrint('TrackNotification planlama hatası: $e');
    }
  }

  /// Bildirim gövdesi: not varsa ilk satırı, yoksa nazik bir varsayılan.
  String? _body(TrackItem item) {
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) {
      final firstLine = note.split('\n').first;
      return firstLine.length > 120 ? '${firstLine.substring(0, 117)}…' : firstLine;
    }
    return 'Hatırlatma zamanı geldi.';
  }

  @override
  Future<void> cancel(String trackId) async {
    await init();
    try {
      await _plugin.cancel(id: trackNotificationId(trackId));
    } catch (e) {
      debugPrint('TrackNotification iptal hatası: $e');
    }
  }
}

/// Bildirim yeteneği olmayan ortamlar (web/test) için no-op.
class NoopTrackNotificationService implements TrackNotificationService {
  const NoopTrackNotificationService();

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> sync(TrackItem item) async {}

  @override
  Future<void> cancel(String trackId) async {}
}

/// Uygulama ömrü boyunca yaşayan tekil bildirim servisi. Web'de no-op.
final trackNotificationServiceProvider =
    Provider<TrackNotificationService>((ref) {
  if (kIsWeb) return const NoopTrackNotificationService();
  return LocalTrackNotificationService(ref);
});

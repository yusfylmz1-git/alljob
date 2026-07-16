import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/snackbar_helper.dart';

/// Web push için VAPID (Voluntary Application Server Identification) anahtarı.
///
/// ⚠️ KULLANICI AKSİYONU (yalnız Web için): Firebase Console → Proje Ayarları →
/// Cloud Messaging → "Web Push certificates" → anahtar çiftini oluştur/kopyala
/// ve buraya yapıştır. Boş kalırsa web'de push token alınmaz (Android/iOS
/// etkilenmez). Bu anahtar gizli değildir, istemciye gömülür.
const String kWebVapidKey = '';

/// FCM push bildirimlerini yöneten servis.
///
/// Sorumluluklar:
///  - İzin iste (Android 13+/iOS runtime izni).
///  - Cihaz token'ını al ve `users/{uid}/private/push.fcmTokens` dizisine
///    kaydet (`arrayUnion`); public `users` dökümanına YAZILMAZ (H2).
///  - Çıkışta token'ı diziden çıkar + geçersiz kıl (`deleteToken`).
///  - Ön planda gelen bildirimi in-app SnackBar ile göster.
///  - Bildirime dokununca (arka plan/kapalıdan açılış dahil) ilgili sohbete git.
///
/// Yalnızca [useFirebaseBackend] açıkken çalışır; mock modda tüm metotlar no-op.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  // Lazy: Firebase örnekleri yalnızca ilk kullanımda (registerFor içindeki
  // try/catch bloğunda) oluşturulur. Böylece Firebase başlatılmamış ortamlarda
  // (ör. widget testleri) servisin kurulması hata vermez.
  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _uid;
  bool _handlersWired = false;
  bool _initialMessageChecked = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Kullanıcı giriş yaptığında çağrılır: izin + token kaydı + dinleyiciler.
  Future<void> registerFor(String uid) async {
    if (!useFirebaseBackend) return;
    // Web'de VAPID anahtarı olmadan getToken hata verir → sessizce atla.
    if (kIsWeb && kWebVapidKey.isEmpty) {
      _wireHandlers(); // yine de tıklama/ön plan işleyicileri bağlansın
      return;
    }
    _uid = uid;
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // kullanıcı reddetti
      }

      _wireHandlers();

      final token = await _getToken();
      if (token != null) await _saveToken(uid, token);

      _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((t) {
        final u = _uid;
        if (u != null) _saveToken(u, t);
      });
    } catch (e) {
      debugPrint('PushService.registerFor hatası: $e');
    }
  }

  /// Çıkışta çağrılır: bu cihazın token'ını kullanıcının dizisinden çıkarır
  /// ve token'ı geçersiz kılar (başka hesap bu cihaza bildirim almasın).
  Future<void> unregisterFor(String uid) async {
    if (!useFirebaseBackend) return;
    try {
      final token = await _getToken();
      if (token != null) {
        await _pushRef(uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
        // Legacy public alandan da düş (eski kurulumlar).
        await _stripPublicToken(uid, token);
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('PushService.unregisterFor hatası: $e');
    } finally {
      _uid = null;
    }
  }

  Future<String?> _getToken() {
    if (kIsWeb) return _messaging.getToken(vapidKey: kWebVapidKey);
    return _messaging.getToken();
  }

  DocumentReference<Map<String, dynamic>> _pushRef(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('push');

  Future<void> _saveToken(String uid, String token) async {
    await _pushRef(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Public dökümandaki eski fcmTokens/email sızıntısını temizle (H2).
    await _stripPublicPii(uid, token);
  }

  Future<void> _stripPublicToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (_) {
      /* kural veya alan yok — yok say */
    }
  }

  Future<void> _stripPublicPii(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'email': FieldValue.delete(),
        'fcmTokens': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Eski kurallar / yok alan — private push yine yazıldı.
      await _stripPublicToken(uid, token);
    }
  }

  void _wireHandlers() {
    if (_handlersWired) return;
    _handlersWired = true;

    // Ön plandayken sistem bildirimi gösterilmez → in-app SnackBar göster.
    _onMessageSub = FirebaseMessaging.onMessage.listen(_showForeground);

    // Bildirime dokunup uygulama arka plandan geldi.
    _onOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);

    // Uygulama tamamen kapalıyken bildirime dokunulup açıldıysa (ilk mesaj).
    if (!_initialMessageChecked) {
      _initialMessageChecked = true;
      _messaging.getInitialMessage().then((m) {
        if (m != null) _handleNavigation(m);
      });
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    final route = _routeFor(message);
    // Üstten inen bildirim kartı (sistem bildirimi görünümü); dokununca
    // ilgili ekrana gider. Overlay için router'ın navigator bağlamı kullanılır.
    final ctx = _ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx == null) return;
    TopToast.show(
      ctx,
      title: n?.title ?? 'Yeni bildirim',
      message: n?.body ?? '',
      icon: Icons.notifications_active_outlined,
      onTap: route == null ? null : () => _go(route),
    );
  }

  void _handleNavigation(RemoteMessage message) {
    final route = _routeFor(message);
    if (route != null) _go(route);
  }

  /// Bildirim verisinden hedef rota: `chat` → sohbet, `job` → ilan detayı.
  String? _routeFor(RemoteMessage message) {
    switch (message.data['type']) {
      case 'chat':
        final chatId = message.data['chatId'] as String?;
        return chatId == null ? null : RoutePaths.chatThread(chatId);
      case 'job':
        final jobId = message.data['jobId'] as String?;
        return jobId == null ? null : RoutePaths.jobDetail(jobId);
      default:
        return null;
    }
  }

  void _go(String route) {
    try {
      _ref.read(routerProvider).push(route);
    } catch (e) {
      debugPrint('PushService gezinme hatası: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
  }
}

/// Uygulama ömrü boyunca yaşayan tekil push servisi.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});

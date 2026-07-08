import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/globals.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/route_paths.dart';

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
///  - Cihaz token'ını al ve `users/{uid}.fcmTokens` dizisine kaydet
///    (`arrayUnion`); token yenilenince güncelle.
///  - Çıkışta token'ı diziden çıkar + geçersiz kıl (`deleteToken`).
///  - Ön planda gelen bildirimi in-app SnackBar ile göster.
///  - Bildirime dokununca (arka plan/kapalıdan açılış dahil) ilgili sohbete git.
///
/// Yalnızca [useFirebaseBackend] açıkken çalışır; mock modda tüm metotlar no-op.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
        await _db.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
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

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
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
    final chatId = message.data['chatId'] as String?;
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            n?.title != null ? '${n!.title}: ${n.body ?? ''}' : (n?.body ?? 'Yeni mesaj'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: chatId == null
              ? null
              : SnackBarAction(
                  label: 'Gör',
                  onPressed: () => _goToChat(chatId),
                ),
        ),
      );
  }

  void _handleNavigation(RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      final chatId = message.data['chatId'] as String?;
      if (chatId != null) _goToChat(chatId);
    }
  }

  void _goToChat(String chatId) {
    try {
      _ref.read(routerProvider).push(RoutePaths.chatThread(chatId));
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

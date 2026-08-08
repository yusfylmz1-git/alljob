import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
      _lastStatus = settings.authorizationStatus;
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Android 13+/iOS: izin reddedilirse token HİÇ yazılmaz ve sistem
        // bildirimi hiç düşmez. Durum burada saklanır; kullanıcı Ayarlar'dan
        // izni açtığında `retry()` ile yeniden denenebilir.
        _lastError = 'İzin reddedildi (${settings.authorizationStatus.name})';
        debugPrint('Push: izin reddedildi — token yazılmadı.');
        return;
      }

      // Android 8+: FCM kanalı önceden tanımlı olmalı (manifest channel_id).
      if (!kIsWeb) {
        await _ensureAndroidPushChannel();
      }

      _wireHandlers();

      final token = await _getToken();
      if (token == null) {
        _lastError = 'FCM token alınamadı (getToken null döndü)';
        debugPrint('Push: token alınamadı.');
        return;
      }
      await _saveToken(uid, token);
      _lastToken = token;
      _lastError = null;
      debugPrint('Push: token kaydedildi (${token.substring(0, 12)}…).');

      _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((t) {
        final u = _uid;
        if (u != null) _saveToken(u, t);
      });
    } catch (e) {
      // ÖNEMLİ: burası eskiden hatayı SESSİZCE yutuyordu. Token yazımı App
      // Check reddi / kural hatası / ağ yüzünden düşerse uygulama "çalışıyor"
      // görünür ama `fcmTokens` boş kalır ve sistem push'u HİÇ gelmez —
      // in-app bildirimler Admin SDK ile yazıldığı için çalışmaya devam eder,
      // bu da sorunu görünmez kılar. Artık durum saklanıyor (Ayarlar'da
      // "Bildirim tanılama" ile görülebilir).
      _lastError = e.toString();
      debugPrint('PushService.registerFor hatası: $e');
    }
  }

  /// Son kayıt denemesinin sonucu — Ayarlar'daki tanılama satırı okur.
  AuthorizationStatus? _lastStatus;
  String? _lastError;
  String? _lastToken;

  /// Push kaydı başarılı mı? (token yazıldıysa true)
  bool get isRegistered => _lastToken != null && _lastError == null;

  /// Tanılama özeti — kullanıcıya/loga gösterilecek tek satır.
  String get diagnosticsTR {
    if (_lastToken != null && _lastError == null) {
      return 'Bildirimler açık (cihaz kayıtlı).';
    }
    if (_lastStatus == AuthorizationStatus.denied) {
      return 'Bildirim izni kapalı. Ayarlar → Uygulamalar → Sepette Hizmet → '
          'Bildirimler bölümünden açın, sonra "Yeniden dene"ye basın.';
    }
    if (_lastError != null) {
      return 'Cihaz bildirimlere kaydedilemedi: $_lastError';
    }
    return 'Bildirim durumu bilinmiyor.';
  }

  /// İzin sonradan açıldıysa kaydı yeniden dener.
  Future<void> retry() async {
    final u = _uid;
    if (u == null) return;
    _lastError = null;
    await registerFor(u);
  }

  /// Çıkışta çağrılır: bu cihazın token'ını kullanıcının dizisinden çıkarır
  /// ve token'ı geçersiz kılar (başka hesap bu cihaza bildirim almasın).
  ///
  /// TAMAMI SÜRE SINIRLI: `signOut` bunu `await` eder (`auth_controller.dart`).
  /// Süre sınırı olmazsa yavaş/kopuk ağda çıkış ekranı kilitlenir ve Android
  /// "yanıt vermiyor" (ANR) uyarısı verir. Token temizliği **en iyi çaba**dır —
  /// başarısız olsa da çıkış tamamlanmalıdır (sunucu geçersiz token'ı zaten
  /// ilk gönderimde eler).
  static const _unregisterTimeout = Duration(seconds: 4);

  Future<void> unregisterFor(String uid) async {
    if (!useFirebaseBackend) return;
    try {
      await _unregisterBody(uid).timeout(_unregisterTimeout);
    } on TimeoutException {
      debugPrint('PushService.unregisterFor: süre aşıldı, çıkışa devam.');
    } catch (e) {
      debugPrint('PushService.unregisterFor hatası: $e');
    } finally {
      _uid = null;
    }
  }

  Future<void> _unregisterBody(String uid) async {
    final token = await _getToken();
    if (token != null) {
      await _pushRef(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
      // Legacy public alandan da düş (eski kurulumlar).
      await _stripPublicToken(uid);
    }
    await _messaging.deleteToken();
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
    await _stripPublicPii(uid);
  }

  /// Public dökümandaki legacy `fcmTokens` alanını TAMAMEN kaldırır.
  ///
  /// DİKKAT — `arrayRemove` KULLANILAMAZ: kural (H2, `notSettingPublicPii`)
  /// bu alan için yalnız SİLMEYE izin verir; yazım sonrası anahtar hiç
  /// kalmamalıdır. `arrayRemove` alanı boş diziye indirir ama anahtar durur
  /// (`'fcmTokens' in request.resource.data` hâlâ true) → permission-denied.
  /// Zaten amaç tek token'ı çıkarmak değil, alanı public dökümandan silmek.
  Future<void> _stripPublicToken(String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      /* kural veya alan yok — yok say */
    }
  }

  /// H2 temizliği: public dökümandan `email` + `fcmTokens` sızıntısını siler.
  ///
  /// Başarısız olursa yalnız `fcmTokens` ile bir kez daha denenir (eski
  /// kurallarda `email` silme reddedilebiliyordu); private push yazımı bu
  /// temizlikten bağımsız olarak zaten tamamlanmıştır.
  Future<void> _stripPublicPii(String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'email': FieldValue.delete(),
        'fcmTokens': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Eski kurallar / yok alan — private push yine yazıldı.
      await _stripPublicToken(uid);
    }
  }

  /// FCM `high_importance_channel` + monokrom varsayılan ikon (Manifest).
  Future<void> _ensureAndroidPushChannel() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'Önemli bildirimler',
          description: 'Sohbet, iş güncellemeleri ve duyurular',
          importance: Importance.high,
        ),
      );
    } catch (e) {
      debugPrint('Push kanal oluşturma: $e');
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
      case 'follow':
        // Yeni takipçi → takip edenin profili.
        final actorUid = message.data['actorUid'] as String?;
        return actorUid == null ? null : RoutePaths.userProfile(actorUid);
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

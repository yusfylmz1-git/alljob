import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/backend_config.dart';
import 'core/widgets/app_error_fallback.dart';
import 'core/theme/accent_state.dart';
import 'core/theme/theme_mode_state.dart';
import 'features/membership/membership_package.dart';
import 'features/onboarding/onboarding_state.dart';
import 'firebase_options.dart';

/// Uygulama arka planda/kapalıyken gelen push mesajlarını işler. Ayrı bir
/// isolate'te çalışır → Firebase'i burada yeniden başlatmak gerekir. Bildirim
/// yükü (`notification`) sistem tepsisinde otomatik gösterildiğinden ek işlem
/// yapmaya gerek yok; işleyicinin varlığı FCM tarafından zorunludur.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release'te widget derleme hatası: Flutter'ın boz gri kutusu yerine sakin
  // markalı yedek (hata yine Crashlytics'e gider). Debug'da kırmızı ekran
  // kalır — geliştirici teşhisi için.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const AppErrorFallback();
  }

  // Türkçe tarih biçimlendirme verisini yükle (yorum tarihleri için).
  await initializeDateFormatting('tr_TR', null);

  // Firebase yalnızca backend açıkken başlatılır (bkz. backend_config.dart).
  // Mock modda (varsayılan) hiçbir Firebase kurulumu gerekmez.
  if (useFirebaseBackend) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // App Check: isteklerin GERÇEK uygulamadan geldiğini kanıtlar.
    // Debug: Debug sağlayıcı — logcat'teki token Console'a eklenmeli
    // (paket adı değişince ESKİ token geçmez: com.ustasindan.app).
    // "Too many attempts": token reddi/throttle — 30–60 dk bekle + debug
    // token kaydet; sürekli hot restart throttle'ı kötüleştirir.
    // SKIP_APP_CHECK=true (yalnız debug): activate atlanır (acil geliştirme).
    // Ayrıntı: docs/OPS_BILLING_APPCHECK.md
    const skipAppCheck = bool.fromEnvironment('SKIP_APP_CHECK');
    if (skipAppCheck && kDebugMode) {
      debugPrint('App Check: SKIP_APP_CHECK=true — activate atlandı (debug).');
    } else if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
        );
        if (kDebugMode) {
          // Token'ı bir kez ısıt; hata loglanır ama uygulama ÇÖKMEZ.
          // "Too many attempts" → otomatik yenilemeyi kes (log/spam + throttle).
          try {
            await FirebaseAppCheck.instance.getToken(true);
          } on FirebaseException catch (e) {
            final msg = e.message ?? e.code;
            debugPrint('App Check getToken: $msg');
            if (msg.toLowerCase().contains('too many attempts') ||
                e.code == 'too-many-requests') {
              await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
              debugPrint(
                'App Check: throttle — auto-refresh KAPALI. '
                '1) 30–60 dk bekle  2) logcat: DebugAppCheckProvider token '
                '3) Console → App Check → Manage debug tokens → ekle '
                '4) uygulamayı tamamen kapatıp aç. '
                'Acil: flutter run --dart-define=SKIP_APP_CHECK=true',
              );
            }
          } catch (e) {
            debugPrint('App Check getToken (diğer): $e');
          }
        }
      } catch (e) {
        // Activate başarısız olsa da uygulama açılsın (monitor modunda
        // Firestore çalışır; enforce'ta veri istekleri permission-denied olur).
        debugPrint('App Check activate atlandı/hata: $e');
      }
    } else if (kAppCheckWebRecaptchaKey.isNotEmpty) {
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(kAppCheckWebRecaptchaKey),
        );
      } catch (e) {
        debugPrint('App Check web activate hata: $e');
      }
    }

    // Arka plan mesaj işleyicisi runApp'ten ÖNCE kaydedilmelidir.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Merkezi hata raporlama (Crashlytics). Web'de desteklenmez → yalnız mobil.
    // Kullanıcıya "beyaz ekran"/sessiz çökme yerine, hatalar arka planda
    // kaydedilip geliştiriciye raporlanır.
    if (!kIsWeb) {
      final crashlytics = FirebaseCrashlytics.instance;
      // Yakalanmayan Flutter (widget/derleme/sync) hatalarını raporla.
      FlutterError.onError = crashlytics.recordFlutterFatalError;
      // Yakalanmayan async / platform (isolate) hatalarını raporla.
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }

  // Onboarding yalnızca ilk açılışta gösterilir; "görüldü" bilgisi cihazdan
  // okunup provider'a override ile verilir (testler override'sız çalıştığı
  // için varsayılan "görüldü" kalır ve akışa hiç girmez).
  final seenOnboarding = await readOnboardingSeen();
  final packageSeen = await readPackageSelectionSeen();
  final selectedPackage = await readSelectedMembershipPackage();

  // Tema tercihi (Sistem/Açık/Koyu) cihazdan okunur; kayıt yoksa Sistem.
  final themeMode = await readThemeMode();

  // Mod başına seçilen vurgu rengi (Görünüm ayarı) cihazdan okunur.
  final customerAccentId = await readCustomerAccentId();
  final artisanAccentId = await readArtisanAccentId();

  runApp(
    ProviderScope(
      overrides: [
        onboardingSeenProvider.overrideWith((ref) => seenOnboarding),
        packageSelectionSeenProvider.overrideWith((ref) => packageSeen),
        selectedMembershipPackageProvider.overrideWith(
          (ref) => selectedPackage,
        ),
        themeModeProvider.overrideWith((ref) => themeMode),
        customerAccentIdProvider.overrideWith((ref) => customerAccentId),
        artisanAccentIdProvider.overrideWith((ref) => artisanAccentId),
      ],
      child: const UstaCepteApp(),
    ),
  );
}

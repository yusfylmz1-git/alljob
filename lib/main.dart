import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/backend_config.dart';
import 'firebase_options.dart';

/// Uygulama arka planda/kapalıyken gelen push mesajlarını işler. Ayrı bir
/// isolate'te çalışır → Firebase'i burada yeniden başlatmak gerekir. Bildirim
/// yükü (`notification`) sistem tepsisinde otomatik gösterildiğinden ek işlem
/// yapmaya gerek yok; işleyicinin varlığı FCM tarafından zorunludur.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih biçimlendirme verisini yükle (yorum tarihleri için).
  await initializeDateFormatting('tr_TR', null);

  // Firebase yalnızca backend açıkken başlatılır (bkz. backend_config.dart).
  // Mock modda (varsayılan) hiçbir Firebase kurulumu gerekmez.
  if (useFirebaseBackend) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

  runApp(const ProviderScope(child: UstaCepteApp()));
}

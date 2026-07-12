import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/backend_config.dart';
import 'features/admin/presentation/admin_app.dart';
import 'firebase_options.dart';

/// AYRI yönetim uygulamasının giriş noktası. Tüketici `main.dart`'tan bağımsız
/// derlenir: `flutter build web -t lib/main_admin.dart` → ayrı, erişimi kısıtlı
/// Firebase Hosting sitesine yayınlanır. Admin kodu tüketici binary'sine girmez.
///
/// Aynı Firebase projesi/kuralları/CF'leri kullanılır; yalnız UI ve giriş
/// noktası ayrıdır. Push/Crashlytics gibi tüketici-özgü kurulumlar YOK.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  if (useFirebaseBackend) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Web'de App Check yalnız reCAPTCHA anahtarı doluysa etkinleşir (tüketici
    // uygulamasıyla aynı politika).
    if (kIsWeb && kAppCheckWebRecaptchaKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(kAppCheckWebRecaptchaKey),
      );
    }
  }

  runApp(const ProviderScope(child: AdminApp()));
}

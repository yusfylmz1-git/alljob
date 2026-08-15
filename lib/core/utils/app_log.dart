import 'package:flutter/foundation.dart';

/// Tanılama günlüğü — **yalnız hata ayıklama derlemesinde** yazar.
///
/// ## Neden gerekli
///
/// Flutter'ın `debugPrint` fonksiyonu adına rağmen **release derlemede de
/// çalışır**; yalnız profil modunda susturulur. Yani doğrudan çağrıldığında
/// satırlar kullanıcının cihazında `logcat`'e düşer ve `adb logcat` ile
/// okunabilir. Bu iki sebeple istenmez:
///
/// 1. **Gizlilik.** Satırlar uid, sohbet kimliği, ilan kimliği taşıyor. Tek
///    başına parola değildir ama cihaza fiziksel erişimi olan biri için
///    gereksiz bir bilgi sızıntısıdır.
/// 2. **Başarım.** Günlük yazımı ucuz değildir; sohbet akışı gibi sık tetiklenen
///    yollarda ana iş parçacığını meşgul eder.
///
/// ## Kullanım
///
/// ```dart
/// AppLog.d('[chat] thread listesi kapandı ($uid): $e');
/// ```
///
/// Release'te çağrı gövdesi boştur; dize birleştirme maliyeti kalır ama
/// çıktı üretilmez. Sıcak döngülerde bunu da atlamak için [AppLog.lazy]
/// kullanılabilir — dize yalnız debug'da kurulur.
///
/// ## Ne ZAMAN kullanılmaz
///
/// Kullanıcının görmesi gereken bir arıza günlüğe yazılmaz — ona
/// `context.showError(...)` ile söylenir. Geliştiricinin canlıda görmesi
/// gereken bir arıza da buraya yazılmaz; Crashlytics'e gider
/// (`FirebaseCrashlytics.instance.recordError`).
class AppLog {
  const AppLog._();

  /// Tanılama satırı — release'te hiçbir şey yapmaz.
  static void d(String mesaj) {
    if (kDebugMode) debugPrint(mesaj);
  }

  /// Maliyetli dize kurulumunu da release'te atlar.
  ///
  /// Sık tetiklenen yollarda (mesaj akışı, kaydırma) tercih edilir:
  /// ```dart
  /// AppLog.lazy(() => '[chat] ${threads.length} sohbet çözümlendi');
  /// ```
  static void lazy(String Function() olustur) {
    if (kDebugMode) debugPrint(olustur());
  }
}

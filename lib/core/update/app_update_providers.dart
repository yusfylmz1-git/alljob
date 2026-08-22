import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/backend_config.dart';
import '../constants/app_constants.dart';
import '../../data/models/app_version_info.dart';

/// Sunucudaki sürüm bilgisi (`config/app`) — güncelleme rozetinin kaynağı.
///
/// TASARIM KARARLARI (2026-08-23):
///
///  * **Firestore, Remote Config DEĞİL.** Remote Config ayrı bir eklenti +
///    ayrı bir konsol yüzeyi demekti; sürüm bildirimi için mevcut desene
///    (repo + provider + kural) bağlanmak daha ucuz ve test edilebilir.
///  * **Tek seferlik okuma, canlı dinleyici değil.** Sürüm günde bir kez
///    değişir; her oturumda açık bir dinleyici tutmak boşuna maliyettir.
///  * **Hata YUTULUR.** Doküman yoksa, kural reddederse veya ağ yoksa
///    `null` döner ve HİÇBİR uyarı çıkmaz. Güncelleme bildirimi yardımcı bir
///    özelliktir; çalışmaması uygulamayı engellememelidir.
final appVersionInfoProvider = FutureProvider<AppVersionInfo?>((ref) async {
  if (!useFirebaseBackend) return null; // mock: sunucu yok, uyarı da yok
  try {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.configCollection)
        .doc(AppConstants.configAppDoc)
        .get();
    final data = snap.data();
    if (data == null) return null;
    return AppVersionInfo.fromMap(data);
  } catch (_) {
    // Kural reddi / ağ / bozuk veri — sessizce geç.
    return null;
  }
});

/// Çalışan sürüme göre güncelleme durumu. Sunucu bilgisi yoksa [
/// UpdateStatus.upToDate] — yani hiçbir şey gösterilmez.
final updateStatusProvider = Provider<UpdateStatus>((ref) {
  final info = ref.watch(appVersionInfoProvider).valueOrNull;
  if (info == null) return UpdateStatus.upToDate;
  return info.statusFor(currentAppVersion);
});

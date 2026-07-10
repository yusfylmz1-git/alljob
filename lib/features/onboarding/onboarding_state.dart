import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSeenKey = 'onboarding_seen_v1';

/// Onboarding görüldü mü? Varsayılan TRUE (görüldü): testler ve override'sız
/// beklenmedik durumlar asla onboarding'e hapsolmasın. Gerçek değer
/// `main.dart`'ta cihaz kayıtlarından okunup ProviderScope override'ı ile verilir.
final onboardingSeenProvider = StateProvider<bool>((_) => true);

/// Cihazdan "onboarding görüldü" bilgisini okur. Hata durumunda TRUE döner
/// (yanlışlıkla tekrar göstermek, kullanıcıyı akışa hapsetmekten iyidir).
Future<bool> readOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

/// Onboarding'i kalıcı olarak "görüldü" işaretler.
Future<void> markOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  } catch (_) {/* kalıcı yazım başarısızsa bir dahaki açılışta tekrar görünür */}
}

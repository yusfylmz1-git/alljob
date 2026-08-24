import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';
import '../utils/app_log.dart';

/// Çalışan uygulamanın sürümü — **`pubspec.yaml`'dan okunur** (2026-08-23).
///
/// ── NEDEN VAR ──
///
/// Sürüm eskiden `AppConstants.appVersion` sabitinde elle yazılıydı ve
/// `pubspec.yaml` ile senkron tutmak kullanıcıya kalıyordu. Unutulduğunda:
///
///  * güncelleme bildirimi yanlış hesaplıyor ("güncelsiniz" derken değil),
///  * zorunlu güncelleme kapısı GÜNCEL sürümdekiler dâhil **herkesi
///    kilitleyebiliyordu** (`kClientVersion` `1.0.0`'da unutulmuştu).
///
/// Artık tek kaynak `pubspec.yaml`. Sürüm yükseltirken **tek bir yeri**
/// değiştiriyorsun.
///
/// ── NASIL KULLANILIR ──
///
/// `main()` içinde bir kez [load] çağrılır; sonrasında [value] senkron
/// okunabilir. Yükleme başarısız olursa [AppConstants.appVersionFallback]
/// kullanılır — uygulama sürüm yüzünden açılmamazlık etmez.
class AppVersion {
  AppVersion._();

  static String _value = AppConstants.appVersionFallback;
  static bool _loaded = false;

  /// Çalışan sürüm adı (`1.2.0`). Build numarası (`+6`) DAHİL DEĞİL —
  /// karşılaştırmalar sürüm adı üzerinden yapılır ve `+build` Play'de artan
  /// ama kullanıcıya görünmeyen bir sayıdır.
  static String get value => _value;

  /// [load] çağrıldı mı? (Test/tanı amaçlı.)
  static bool get isLoaded => _loaded;

  /// Sürümü platformdan okur. `main()` içinde Firebase kurulumundan ÖNCE
  /// çağrılabilir — ağ gerektirmez.
  ///
  /// İki kez çağrılırsa ikincisi işlem yapmaz.
  ///
  /// HATA YUTULUR: eklenti cevap veremezse (platform kanalı hazır değil,
  /// masaüstü/test ortamı) yedek değerle devam edilir. Sürüm okunamadı diye
  /// uygulamayı açmamak, çözdüğünden büyük bir sorun yaratırdı.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (v.isNotEmpty) _value = v;
    } catch (e) {
      AppLog.d('[version] okunamadı, yedek kullanılıyor: $e');
    } finally {
      _loaded = true;
    }
  }

  /// Testlerde sürümü sabitlemek için. Üretimde KULLANILMAZ.
  static void debugSet(String v) {
    _value = v;
    _loaded = true;
  }
}

import '../../data/models/app_version_info.dart' show compareVersions;
import 'app_version_runtime.dart';

export '../../data/models/app_version_info.dart' show compareVersions;

/// İstemci sürümü — **tek kaynak `pubspec.yaml`** (2026-08-23).
///
/// Değer çalışma anında `package_info_plus` ile okunur
/// ([AppVersion.load], `main()` içinde bir kez).
///
/// ── NEDEN SABİT DEĞİL ──
///
/// 2026-08-23'e kadar burada elle yazılmış bir sabit duruyordu (`'1.0.0'`)
/// ve gerçek sürüm `1.2.0` iken güncellenmemişti. Zorunlu güncelleme kapısı
/// bu değeri okuduğu için ciddi bir tuzaktı:
/// `adminConfig/runtime.minAppVersion` alanına `1.1.0` yazan bir yönetici,
/// uygulama kendini `1.0.0` sandığından **GÜNCEL sürümdekiler dâhil herkesi
/// kilitlerdi**.
///
/// Sonra `AppConstants.appVersion`'a bağlandı — ama o da elle yazılıyordu,
/// yani sorun bir adım öteye taşınmıştı. Artık hiçbir yerde elle yazılan
/// sürüm yok: `pubspec.yaml` değişir, gerisi kendiliğinden gelir.
String get kClientVersion => AppVersion.value;

/// [minAppVersion] dolu ve istemci daha düşükse true.
///
/// Karşılaştırma [compareVersions] ile yapılır — o fonksiyon
/// `app_version_info.dart` içinde yaşar ve buradan yeniden dışa aktarılır.
/// İkinci bir kopya tutmak, iki farklı "sürüm karşılaştırma" davranışı
/// demekti: güncelleme rozeti bir şey, zorunlu güncelleme kapısı başka bir
/// şey söyleyebilirdi.
bool isClientBelowMinVersion({
  required String clientVersion,
  String? minAppVersion,
}) {
  final min = minAppVersion?.trim();
  if (min == null || min.isEmpty) return false;
  return compareVersions(clientVersion, min) < 0;
}

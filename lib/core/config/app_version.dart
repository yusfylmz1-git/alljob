import '../../data/models/app_version_info.dart' show compareVersions;
import '../constants/app_constants.dart';

export '../../data/models/app_version_info.dart' show compareVersions;

/// İstemci sürümü — **tek kaynak** [AppConstants.appVersion]'dır.
///
/// 2026-08-23'e kadar burada elle yazılmış ayrı bir sabit duruyordu
/// (`'1.0.0'`) ve gerçek sürüm `1.2.0` iken güncellenmemişti. Zorunlu
/// güncelleme kapısı bu değeri okuduğu için ciddi bir tuzaktı:
/// `adminConfig/runtime.minAppVersion` alanına `1.1.0` yazan bir yönetici,
/// uygulama kendini `1.0.0` sandığından **herkesin uygulamasını
/// kilitlerdi** — güncel sürümdekiler dâhil.
///
/// Artık `AppConstants.appVersion`'a bağlı; o sabit de
/// `test/guncelleme_bildirimi_test.dart` ile `pubspec.yaml`'a bağlanmış
/// durumda. Yani zincir tek: **pubspec → AppConstants → buradan okuyan
/// herkes.**
const String kClientVersion = AppConstants.appVersion;

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

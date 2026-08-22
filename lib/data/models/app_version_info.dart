import '../../core/constants/app_constants.dart';

/// Sunucudaki sürüm bilgisi (`config/app`) ve ondan çıkan güncelleme durumu.
///
/// 2026-08-23 kapalı test bulgusu: "güncelleme bildirimi yok — yeni sürüm
/// varsa menüde görünmesi lazım." Testçiler eski APK ile devam ediyor ve
/// düzeltilmiş hataları yeniden bildiriyordu.
///
/// Doküman herkese açık okunur, yalnız admin/CF yazar (`firestore.rules`).
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    this.minSupportedVersion,
    this.updateUrl,
    this.updateNote,
  });

  /// Mağazadaki en yeni sürüm adı (`1.3.0`). Boşsa kontrol yapılmaz.
  final String latestVersion;

  /// Bunun ALTINDAKİ sürümler artık desteklenmez → zorunlu güncelleme.
  /// Boş bırakılırsa hiçbir sürüm zorlanmaz (güvenli varsayılan).
  final String? minSupportedVersion;

  /// Mağaza bağlantısı. Boşsa uygulama sitesine düşülür.
  final String? updateUrl;

  /// "Neler değişti" için kısa not (isteğe bağlı, tek satır).
  final String? updateNote;

  factory AppVersionInfo.fromMap(Map<String, dynamic> map) => AppVersionInfo(
        latestVersion: (map['latestVersion'] as String?)?.trim() ?? '',
        minSupportedVersion:
            (map['minSupportedVersion'] as String?)?.trim().nullIfEmpty,
        updateUrl: (map['updateUrl'] as String?)?.trim().nullIfEmpty,
        updateNote: (map['updateNote'] as String?)?.trim().nullIfEmpty,
      );

  Map<String, dynamic> toMap() => {
        'latestVersion': latestVersion,
        if (minSupportedVersion != null)
          'minSupportedVersion': minSupportedVersion,
        if (updateUrl != null) 'updateUrl': updateUrl,
        if (updateNote != null) 'updateNote': updateNote,
      };

  /// Çalışan sürüme göre güncelleme durumu.
  UpdateStatus statusFor(String currentVersion) {
    // Sunucu boş/bozuk değer yazmışsa HİÇBİR ŞEY GÖSTERME. Yanlış bir
    // "güncelle" uyarısı, kullanıcıyı olmayan bir sürümü aramaya yollar.
    if (compareVersions(latestVersion, '0.0.0') <= 0) {
      return UpdateStatus.upToDate;
    }
    final min = minSupportedVersion;
    if (min != null && compareVersions(currentVersion, min) < 0) {
      return UpdateStatus.zorunlu;
    }
    if (compareVersions(currentVersion, latestVersion) < 0) {
      return UpdateStatus.available;
    }
    return UpdateStatus.upToDate;
  }
}

/// Güncelleme durumu — menü rozetini ve kapıyı belirler.
enum UpdateStatus {
  /// Güncel (ya da sunucudan geçerli bilgi gelmedi). Hiçbir şey gösterilmez.
  upToDate,

  /// Yeni sürüm var; kullanıcı isterse günceller. Menüde rozet çıkar.
  available,

  /// Çalışan sürüm artık desteklenmiyor — engelleyici uyarı.
  zorunlu;

  bool get hasUpdate => this != UpdateStatus.upToDate;
  bool get isRequired => this == UpdateStatus.zorunlu;
}

/// İki sürüm adını sayısal olarak karşılaştırır: `a<b` → negatif, eşit → 0.
///
/// Neden dize karşılaştırması YETMEZ: `'1.10.0' < '1.9.0'` alfabetik olarak
/// DOĞRUDUR ama sürüm olarak yanlıştır — kullanıcı 1.10.0'dayken "güncelleme
/// var" uyarısı alırdı.
///
/// Biçim toleranslıdır: `1.2`, `1.2.0`, `1.2.0+6` ve baştaki `v` kabul edilir
/// (`+buildNumber` yok sayılır — Play'de artan ama kullanıcıya görünmeyen
/// sayıdır). Sayıya çevrilemeyen parça 0 sayılır; bozuk sunucu değeri
/// yüzünden uygulama çökmez.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va < vb ? -1 : 1;
  }
  return 0;
}

List<int> _parts(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  if (s.isEmpty) return const [0];
  return s
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList(growable: false);
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Çalışan sürüm — `pubspec.yaml` ile senkron tutulan sabit.
String get currentAppVersion => AppConstants.appVersion;

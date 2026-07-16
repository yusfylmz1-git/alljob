/// İstemci sürümü — `pubspec.yaml` içindeki `version:` alanının
/// **build numarasından önceki** kısmı ile senkron tutulmalı
/// (ör. `1.0.0+12` → `1.0.0`).
///
/// Admin `adminConfig/runtime.minAppVersion` bu değerden yüksekse
/// zorunlu güncelleme kapısı açılır (bkz. [isClientBelowMinVersion]).
const String kClientVersion = '1.0.0';

/// `a` ile `b` semver-benzeri karşılaştırma: negatif = a < b, 0 = eşit,
/// pozitif = a > b. Yalnız nokta ile ayrılmış sayısal parçalar (1.2.3);
/// `+build` / `-pre` soneki yok sayılır. Boş / geçersiz → 0 parçalı.
int compareVersions(String a, String b) {
  List<int> parts(String raw) {
    final core = raw.trim().split(RegExp(r'[+\-]')).first;
    if (core.isEmpty) return const [];
    return core.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// [minAppVersion] dolu ve istemci daha düşükse true.
bool isClientBelowMinVersion({
  required String clientVersion,
  String? minAppVersion,
}) {
  final min = minAppVersion?.trim();
  if (min == null || min.isEmpty) return false;
  return compareVersions(clientVersion, min) < 0;
}

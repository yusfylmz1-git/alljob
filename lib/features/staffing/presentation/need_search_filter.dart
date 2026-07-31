import '../../../core/utils/search_fold.dart';
import '../../../data/models/staffing.dart';

/// Eleman ilanı (ihtiyaç) arama filtresi.
class NeedSearchFilter {
  const NeedSearchFilter({
    this.province,
    this.district,
    this.dailyOnly = false,
    this.query = '',
  });

  final String? province;
  final String? district;
  final bool dailyOnly;
  final String query;

  bool get hasDetailFilters =>
      (province != null && province!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      dailyOnly;

  int get activeDetailCount {
    var n = 0;
    if (province != null && province!.isNotEmpty) n++;
    if (district != null && district!.isNotEmpty) n++;
    if (dailyOnly) n++;
    return n;
  }

  NeedSearchFilter copyWith({
    String? province,
    String? district,
    bool? dailyOnly,
    String? query,
    bool clearProvince = false,
    bool clearDistrict = false,
  }) {
    return NeedSearchFilter(
      province: clearProvince ? null : (province ?? this.province),
      district: clearDistrict ? null : (district ?? this.district),
      dailyOnly: dailyOnly ?? this.dailyOnly,
      query: query ?? this.query,
    );
  }

  // foldTrSearch: Türkçe harf sadeleştirme (İ/ı→i, ş→s…) — düz toLowerCase
  // 'İ'yi birleşik noktalı 'i̇' yaptığından "İnşaat" kaydı "insaat" hatta
  // "inşaat" sorgusuyla eşleşmiyordu.
  static bool matchesQuery(StaffNeed n, String rawQuery) {
    final q = foldTrSearch(rawQuery.trim());
    if (q.isEmpty) return true;
    final hay = foldTrSearch([
      n.title,
      n.detail,
      n.employerName,
      n.province,
      n.district,
      n.rateLabel,
      '${n.neededCount}',
      if (n.isDaily) 'gündelik günlük',
    ].join(' '));
    final parts = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    for (final p in parts) {
      if (!hay.contains(p)) return false;
    }
    return true;
  }

  List<StaffNeed> applyClientFilters(List<StaffNeed> list) {
    return list.where((n) {
      if (district != null &&
          district!.isNotEmpty &&
          foldTrSearch(n.district) != foldTrSearch(district!)) {
        return false;
      }
      if (dailyOnly && !n.isDaily) return false;
      if (!matchesQuery(n, query)) return false;
      return true;
    }).toList();
  }
}

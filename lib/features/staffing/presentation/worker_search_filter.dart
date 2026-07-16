import '../../../data/models/staffing.dart';

/// Eleman arama filtresi.
class WorkerSearchFilter {
  const WorkerSearchFilter({
    this.province,
    this.district,
    this.rateType,
    this.dailyOnly = false,
    this.query = '',
  });

  final String? province;
  final String? district;
  final StaffRateType? rateType;
  /// true = yalnız gündelik işe açık elemanlar.
  final bool dailyOnly;
  final String query;

  bool get hasDetailFilters =>
      (province != null && province!.isNotEmpty) ||
      (district != null && district!.isNotEmpty) ||
      rateType != null ||
      dailyOnly;

  int get activeDetailCount {
    var n = 0;
    if (province != null && province!.isNotEmpty) n++;
    if (district != null && district!.isNotEmpty) n++;
    if (rateType != null) n++;
    if (dailyOnly) n++;
    return n;
  }

  WorkerSearchFilter copyWith({
    String? province,
    String? district,
    StaffRateType? rateType,
    bool? dailyOnly,
    String? query,
    bool clearProvince = false,
    bool clearDistrict = false,
    bool clearRateType = false,
  }) {
    return WorkerSearchFilter(
      province: clearProvince ? null : (province ?? this.province),
      district: clearDistrict ? null : (district ?? this.district),
      rateType: clearRateType ? null : (rateType ?? this.rateType),
      dailyOnly: dailyOnly ?? this.dailyOnly,
      query: query ?? this.query,
    );
  }

  static bool matchesQuery(StaffWorkerListing w, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      w.title,
      w.professionLabel,
      w.about,
      w.displayName,
      w.province,
      w.district,
      w.rateLabel,
      if (w.isDaily) 'gündelik günlük',
    ].join(' ').toLowerCase();
    final parts = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    for (final p in parts) {
      if (!hay.contains(p)) return false;
    }
    return true;
  }

  List<StaffWorkerListing> applyClientFilters(List<StaffWorkerListing> list) {
    return list.where((w) {
      if (district != null &&
          district!.isNotEmpty &&
          w.district.toLowerCase() != district!.toLowerCase()) {
        return false;
      }
      if (rateType != null && w.rateType != rateType) return false;
      if (dailyOnly && !w.isDaily) return false;
      if (!matchesQuery(w, query)) return false;
      return true;
    }).toList();
  }
}

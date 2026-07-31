import '../../../core/utils/search_fold.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';

/// Keşfet → İlanlar: istemci tarafı filtre (sunucu zaten açık ilanları verir).
/// Detay: il / ilçe. Meslek dropdown yok (metin aramada kalır).
class JobExploreFilter {
  const JobExploreFilter({
    this.query = '',
    this.province,
    this.district,
  });

  final String query;
  final String? province;
  final String? district;

  bool get hasDetailFilters =>
      (province != null && province!.isNotEmpty) ||
      (district != null && district!.isNotEmpty);

  int get activeDetailCount {
    var n = 0;
    if (province != null && province!.isNotEmpty) n++;
    if (district != null && district!.isNotEmpty) n++;
    return n;
  }

  bool get hasAnyFilter => query.trim().isNotEmpty || hasDetailFilters;

  JobExploreFilter copyWith({
    String? query,
    String? province,
    String? district,
    bool clearProvince = false,
    bool clearDistrict = false,
  }) {
    return JobExploreFilter(
      query: query ?? this.query,
      province: clearProvince ? null : (province ?? this.province),
      district: clearDistrict ? null : (district ?? this.district),
    );
  }

  static bool matchesQuery(Job job, String rawQuery) {
    final q = foldTrSearch(rawQuery.trim());
    if (q.isEmpty) return true;
    final catLabel = kProfessionNames[job.category] ?? job.category;
    final hay = foldTrSearch([
      job.title,
      job.description,
      job.province,
      job.district,
      job.neighborhood ?? '',
      job.customerName,
      catLabel,
      job.category,
    ].join(' '));
    final parts = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    for (final p in parts) {
      if (!hay.contains(p)) return false;
    }
    return true;
  }

  List<Job> apply(List<Job> jobs) {
    return jobs.where((j) {
      if (province != null &&
          province!.isNotEmpty &&
          foldTrSearch(j.province) != foldTrSearch(province!)) {
        return false;
      }
      if (district != null &&
          district!.isNotEmpty &&
          foldTrSearch(j.district) != foldTrSearch(district!)) {
        return false;
      }
      if (!matchesQuery(j, query)) return false;
      return true;
    }).toList();
  }
}

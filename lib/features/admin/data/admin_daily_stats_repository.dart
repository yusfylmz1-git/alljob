import 'package:cloud_firestore/cloud_firestore.dart';

/// Tek bir günün sayaçları — `adminStats/daily/days/{YYYY-MM-DD}`.
///
/// Bu dokümanları Cloud Functions `bumpDaily()` yazar (olay bazlı, her
/// oluşumda +1). Gün anahtarı **İstanbul saatine** göredir; sunucu UTC'de
/// çalıştığı için `istanbulDayKey()` kullanılır — aksi hâlde gece yarısı
/// civarındaki kayıtlar yanlış güne düşerdi.
class AdminDailyStat {
  const AdminDailyStat({
    required this.day,
    this.usersCreated = 0,
    this.jobsCreated = 0,
    this.artisansCreated = 0,
    this.productsActivated = 0,
    this.reportsCreated = 0,
    this.productRequestsCreated = 0,
  });

  /// `YYYY-MM-DD` (İstanbul).
  final String day;

  final int usersCreated;
  final int jobsCreated;
  final int artisansCreated;
  final int productsActivated;
  final int reportsCreated;

  /// Ürün talebi (`category == 'product_request'`) — normal ilandan ayrı.
  final int productRequestsCreated;

  /// Hizmet ilanı = toplam ilan − ürün talebi.
  ///
  /// `jobsCreated` HER ikisini de sayar (ürün talebi de `jobs` koleksiyonunda
  /// yaşar). Ayrı gösterilmezse "ilan sayısı" mağaza talepleriyle şişer.
  int get serviceJobsCreated {
    final n = jobsCreated - productRequestsCreated;
    return n < 0 ? 0 : n; // eski günlerde talep sayacı yoktu
  }

  DateTime? get date => DateTime.tryParse(day);

  factory AdminDailyStat.fromMap(String id, Map<String, dynamic>? m) {
    int i(String k) => ((m ?? const {})[k] as num?)?.toInt() ?? 0;
    return AdminDailyStat(
      day: (m?['day'] as String?) ?? id,
      usersCreated: i('usersCreated'),
      jobsCreated: i('jobsCreated'),
      artisansCreated: i('artisansCreated'),
      productsActivated: i('productsActivated'),
      reportsCreated: i('reportsCreated'),
      productRequestsCreated: i('productRequestsCreated'),
    );
  }
}

/// Bir metriğin gün gün serisi + özetleri.
class DailySeries {
  const DailySeries({
    required this.label,
    required this.values,
    required this.days,
  });

  final String label;

  /// Gün başına değer; [days] ile aynı sırada ve uzunlukta (eski → yeni).
  final List<int> values;
  final List<String> days;

  int get total => values.fold(0, (a, b) => a + b);
  int get max => values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

  /// Son [n] günün toplamı (varsayılan 7).
  int lastDays(int n) {
    if (values.isEmpty) return 0;
    final start = values.length - n;
    return values.sublist(start < 0 ? 0 : start).fold(0, (a, b) => a + b);
  }

  /// Son 7 gün ile önceki 7 günün karşılaştırması (yüzde).
  ///
  /// `null` = önceki dönem sıfır; oran hesaplanamaz (sıfıra bölme değil,
  /// "artış yüzdesi" ifadesi anlamsız olurdu — UI bunu "yeni" diye gösterir).
  double? get weekOverWeekPercent {
    if (values.length < 14) return null;
    final son = values.sublist(values.length - 7).fold(0, (a, b) => a + b);
    final onceki = values
        .sublist(values.length - 14, values.length - 7)
        .fold(0, (a, b) => a + b);
    if (onceki == 0) return null;
    return (son - onceki) / onceki * 100;
  }
}

/// Gün dizisini boşluksuz hâle getirir.
///
/// Firestore yalnız **olay olan** günlerde doküman yazar; hiç ilan açılmayan
/// gün eksiktir. Grafik bunu bilmezse iki nokta arasını düz çizgiyle bağlar ve
/// "o gün de aktivite vardı" izlenimi verir. Eksik günler 0 ile doldurulur.
List<AdminDailyStat> fillMissingDays(
  List<AdminDailyStat> rows, {
  required DateTime endDay,
  required int dayCount,
}) {
  final byDay = {for (final r in rows) r.day: r};
  final out = <AdminDailyStat>[];
  for (var i = dayCount - 1; i >= 0; i--) {
    final d = DateTime.utc(endDay.year, endDay.month, endDay.day)
        .subtract(Duration(days: i));
    final key = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    out.add(byDay[key] ?? AdminDailyStat(day: key));
  }
  return out;
}

/// Satırlardan tek bir metriğin serisini çıkarır.
DailySeries seriesOf(
  List<AdminDailyStat> rows,
  int Function(AdminDailyStat) pick, {
  required String label,
}) {
  return DailySeries(
    label: label,
    values: [for (final r in rows) pick(r)],
    days: [for (final r in rows) r.day],
  );
}

abstract interface class AdminDailyStatsRepository {
  /// Son [dayCount] günün sayaçları (eski → yeni, boşluklar 0 ile dolu).
  Future<List<AdminDailyStat>> fetchRecent({int dayCount = 30});
}

class FirebaseAdminDailyStatsRepository implements AdminDailyStatsRepository {
  FirebaseAdminDailyStatsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<AdminDailyStat>> fetchRecent({int dayCount = 30}) async {
    final n = dayCount.clamp(7, 180);
    // Doküman kimliği `YYYY-MM-DD` olduğu için sözlük sırası = tarih sırası;
    // ayrı bir indeks veya `orderBy('day')` gerekmez.
    final snap = await _db
        .collection('adminStats')
        .doc('daily')
        .collection('days')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(n)
        .get();
    final rows = [
      for (final d in snap.docs) AdminDailyStat.fromMap(d.id, d.data()),
    ];
    return fillMissingDays(rows, endDay: DateTime.now().toUtc(), dayCount: n);
  }
}

class MockAdminDailyStatsRepository implements AdminDailyStatsRepository {
  MockAdminDailyStatsRepository([this.rows = const []]);

  List<AdminDailyStat> rows;

  @override
  Future<List<AdminDailyStat>> fetchRecent({int dayCount = 30}) async {
    return fillMissingDays(
      rows,
      endDay: DateTime.now().toUtc(),
      dayCount: dayCount.clamp(7, 180),
    );
  }
}

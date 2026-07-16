import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// `adminStats/global` anlık görüntüsü (CF increment / rebuild).
class AdminStatsSnapshot {
  const AdminStatsSnapshot({
    this.usersTotal = 0,
    this.usersSuspended = 0,
    this.artisansTotal = 0,
    this.jobsOpen = 0,
    this.jobsInProgress = 0,
    this.jobsCompleted = 0,
    this.jobsDisputed = 0,
    this.jobsCancelled = 0,
    this.jobsOther = 0,
    this.openReports = 0,
    this.openDisputes = 0,
    this.updatedAt,
    this.rebuiltAt,
  });

  final int usersTotal;
  final int usersSuspended;
  final int artisansTotal;
  final int jobsOpen;
  final int jobsInProgress;
  final int jobsCompleted;
  final int jobsDisputed;
  final int jobsCancelled;
  final int jobsOther;
  final int openReports;
  final int openDisputes;
  final DateTime? updatedAt;
  final DateTime? rebuiltAt;

  int get jobsTotal =>
      jobsOpen +
      jobsInProgress +
      jobsCompleted +
      jobsDisputed +
      jobsCancelled +
      jobsOther;

  /// 24 saatten eski veya hiç güncellenmemiş.
  bool get isStale {
    if (updatedAt == null) return true;
    return DateTime.now().toUtc().difference(updatedAt!.toUtc()) >
        const Duration(hours: 24);
  }

  factory AdminStatsSnapshot.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AdminStatsSnapshot();
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    DateTime? t(String k) =>
        m[k] != null ? DateTime.tryParse(m[k].toString()) : null;
    return AdminStatsSnapshot(
      usersTotal: i('usersTotal'),
      usersSuspended: i('usersSuspended'),
      artisansTotal: i('artisansTotal'),
      jobsOpen: i('jobsOpen'),
      jobsInProgress: i('jobsInProgress'),
      jobsCompleted: i('jobsCompleted'),
      jobsDisputed: i('jobsDisputed'),
      jobsCancelled: i('jobsCancelled'),
      jobsOther: i('jobsOther'),
      openReports: i('openReports'),
      openDisputes: i('openDisputes'),
      updatedAt: t('updatedAt'),
      rebuiltAt: t('rebuiltAt'),
    );
  }
}

/// Pure job status → stats field (CF `jobStatsBucket` paritesi).
String? jobStatsBucket(String? status) {
  switch (status) {
    case 'open':
      return 'jobsOpen';
    case 'workerSelected':
    case 'inProgress':
      return 'jobsInProgress';
    case 'completed':
    case 'rated':
      return 'jobsCompleted';
    case 'disputed':
      return 'jobsDisputed';
    case 'cancelled':
    case 'expired':
      return 'jobsCancelled';
    case null:
    case '':
      return null;
    default:
      return 'jobsOther';
  }
}

/// Pure: job before/after → delta map (CF `jobStatsDelta` paritesi).
Map<String, int> jobStatsDelta(
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  final d = <String, int>{};
  void bump(String? k, int n) {
    if (k == null || n == 0) return;
    d[k] = (d[k] ?? 0) + n;
  }

  if (before == null && after != null) {
    bump(jobStatsBucket(after['status'] as String?), 1);
    if (after['status'] == 'disputed') bump('openDisputes', 1);
  } else if (before != null && after == null) {
    bump(jobStatsBucket(before['status'] as String?), -1);
    if (before['status'] == 'disputed') bump('openDisputes', -1);
  } else if (before != null && after != null) {
    final b = jobStatsBucket(before['status'] as String?);
    final a = jobStatsBucket(after['status'] as String?);
    if (b != a) {
      bump(b, -1);
      bump(a, 1);
    }
    final wasD = before['status'] == 'disputed';
    final isD = after['status'] == 'disputed';
    if (!wasD && isD) bump('openDisputes', 1);
    if (wasD && !isD) bump('openDisputes', -1);
  }
  return d;
}

/// Pure: report open/reviewing transitions.
Map<String, int> reportStatsDelta(
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  bool open(Map<String, dynamic>? m) {
    final s = m?['status'];
    return s == 'open' || s == 'reviewing';
  }

  final openB = open(before);
  final openA = open(after);
  if (!openB && openA) return {'openReports': 1};
  if (openB && !openA) return {'openReports': -1};
  return {};
}

abstract interface class AdminStatsRepository {
  Stream<AdminStatsSnapshot> watchGlobal();
  Future<AdminStatsSnapshot> rebuild();
}

class FirebaseAdminStatsRepository implements AdminStatsRepository {
  FirebaseAdminStatsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<AdminStatsSnapshot> watchGlobal() {
    return _db.collection('adminStats').doc('global').snapshots().map(
          (s) => AdminStatsSnapshot.fromMap(s.data()),
        );
  }

  @override
  Future<AdminStatsSnapshot> rebuild() async {
    final res =
        await _functions.httpsCallable('adminRebuildStats').call<Object?>({});
    final data = res.data;
    if (data is Map && data['counts'] is Map) {
      return AdminStatsSnapshot.fromMap(
          Map<String, dynamic>.from(data['counts'] as Map));
    }
    return const AdminStatsSnapshot();
  }
}

class MockAdminStatsRepository implements AdminStatsRepository {
  MockAdminStatsRepository([this._snap = const AdminStatsSnapshot()]);

  AdminStatsSnapshot _snap;

  void set(AdminStatsSnapshot s) => _snap = s;

  @override
  Stream<AdminStatsSnapshot> watchGlobal() => Stream.value(_snap);

  @override
  Future<AdminStatsSnapshot> rebuild() async => _snap;
}

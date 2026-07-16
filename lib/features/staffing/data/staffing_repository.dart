import '../../../data/models/staffing.dart';

/// Eleman istihdam deposu.
abstract interface class StaffingRepository {
  /// Açık "iş arıyorum" kartları. [dailyOnly]=true ise yalnız isDaily.
  Stream<List<StaffWorkerListing>> watchOpenWorkers({
    String? province,
    bool? dailyOnly,
  });

  Stream<StaffWorkerListing?> watchMyWorkerListing(String uid);

  Future<void> saveWorkerListing(StaffWorkerListing listing);

  Future<void> setWorkerOpen({required String uid, required bool open});

  Future<StaffWorkerListing?> getWorkerListing(String id);

  Stream<List<StaffNeed>> watchOpenNeeds({
    String? province,
    bool? dailyOnly,
  });

  Stream<List<StaffNeed>> watchMyNeeds(String employerUid);

  Future<String> createNeed(StaffNeed need);

  Future<void> closeNeed(String needId);
}

class MockStaffingRepository implements StaffingRepository {
  final Map<String, StaffWorkerListing> _workers = {};
  final Map<String, StaffNeed> _needs = {};
  int _needSeq = 0;

  @override
  Stream<List<StaffWorkerListing>> watchOpenWorkers({
    String? province,
    bool? dailyOnly,
  }) async* {
    List<StaffWorkerListing> snap() {
      var list = _workers.values.where((w) => w.openToWork).toList();
      if (province != null && province.isNotEmpty) {
        list = list.where((w) => w.province == province).toList();
      }
      if (dailyOnly == true) {
        list = list.where((w) => w.isDaily).toList();
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }

    yield snap();
    yield* Stream.periodic(const Duration(milliseconds: 400), (_) => snap())
        .distinct((a, b) => a.length == b.length);
  }

  @override
  Stream<StaffWorkerListing?> watchMyWorkerListing(String uid) async* {
    yield _workers[StaffWorkerListing.idFor(uid)];
    yield* Stream.periodic(const Duration(milliseconds: 400), (_) {
      return _workers[StaffWorkerListing.idFor(uid)];
    });
  }

  @override
  Future<void> saveWorkerListing(StaffWorkerListing listing) async {
    _workers[listing.id] = listing;
  }

  @override
  Future<void> setWorkerOpen({required String uid, required bool open}) async {
    final id = StaffWorkerListing.idFor(uid);
    final w = _workers[id];
    if (w == null) return;
    _workers[id] = w.copyWith(openToWork: open, updatedAt: DateTime.now());
  }

  @override
  Future<StaffWorkerListing?> getWorkerListing(String id) async =>
      _workers[id];

  @override
  Stream<List<StaffNeed>> watchOpenNeeds({
    String? province,
    bool? dailyOnly,
  }) async* {
    List<StaffNeed> snap() {
      var list = _needs.values.where((n) => n.isOpen).toList();
      if (province != null && province.isNotEmpty) {
        list = list.where((n) => n.province == province).toList();
      }
      if (dailyOnly == true) {
        list = list.where((n) => n.isDaily).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield snap();
    yield* Stream.periodic(const Duration(milliseconds: 400), (_) => snap());
  }

  @override
  Stream<List<StaffNeed>> watchMyNeeds(String employerUid) async* {
    List<StaffNeed> snap() {
      return _needs.values.where((n) => n.employerUid == employerUid).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    yield snap();
    yield* Stream.periodic(const Duration(milliseconds: 400), (_) => snap());
  }

  @override
  Future<String> createNeed(StaffNeed need) async {
    final id = need.id.isNotEmpty ? need.id : 'need_${_needSeq++}';
    _needs[id] = StaffNeed(
      id: id,
      employerUid: need.employerUid,
      employerName: need.employerName,
      employerPhotoUrl: need.employerPhotoUrl,
      title: need.title,
      detail: need.detail,
      province: need.province,
      district: need.district,
      neededCount: need.neededCount,
      isDaily: need.isDaily,
      dailyRate: need.dailyRate,
      workDate: need.workDate,
      status: need.status,
      createdAt: need.createdAt,
    );
    return id;
  }

  @override
  Future<void> closeNeed(String needId) async {
    final n = _needs[needId];
    if (n == null) return;
    _needs[needId] = StaffNeed(
      id: n.id,
      employerUid: n.employerUid,
      employerName: n.employerName,
      employerPhotoUrl: n.employerPhotoUrl,
      title: n.title,
      detail: n.detail,
      province: n.province,
      district: n.district,
      neededCount: n.neededCount,
      isDaily: n.isDaily,
      dailyRate: n.dailyRate,
      workDate: n.workDate,
      status: 'closed',
      createdAt: n.createdAt,
    );
  }
}

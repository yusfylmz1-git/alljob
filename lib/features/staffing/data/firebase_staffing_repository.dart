import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/staffing.dart';
import 'staffing_repository.dart';

class FirebaseStaffingRepository implements StaffingRepository {
  FirebaseStaffingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _workers =>
      _db.collection('staffWorkers');
  CollectionReference<Map<String, dynamic>> get _needs =>
      _db.collection('staffNeeds');

  @override
  Stream<List<StaffWorkerListing>> watchOpenWorkers({
    String? province,
    bool? dailyOnly,
  }) {
    Query<Map<String, dynamic>> q =
        _workers.where('openToWork', isEqualTo: true);
    if (province != null && province.isNotEmpty) {
      q = q.where('province', isEqualTo: province);
    }
    // isDaily sunucu filtresi composite index ister; istemcide süzülür.
    return q.limit(100).snapshots().map((s) {
      var list = s.docs
          .map((d) => StaffWorkerListing.fromMap(d.id, d.data()))
          .toList();
      if (dailyOnly == true) {
        list = list.where((w) => w.isDaily).toList();
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Stream<StaffWorkerListing?> watchMyWorkerListing(String uid) {
    return _workers.doc(StaffWorkerListing.idFor(uid)).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      return StaffWorkerListing.fromMap(d.id, d.data()!);
    });
  }

  @override
  Future<void> saveWorkerListing(StaffWorkerListing listing) async {
    await _workers.doc(listing.id).set(listing.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> setWorkerOpen({required String uid, required bool open}) async {
    await _workers.doc(StaffWorkerListing.idFor(uid)).set({
      'openToWork': open,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<StaffWorkerListing?> getWorkerListing(String id) async {
    final snap = await _workers.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return StaffWorkerListing.fromMap(snap.id, snap.data()!);
  }

  @override
  Stream<List<StaffNeed>> watchOpenNeeds({
    String? province,
    bool? dailyOnly,
  }) {
    Query<Map<String, dynamic>> q = _needs.where('status', isEqualTo: 'open');
    if (province != null && province.isNotEmpty) {
      q = q.where('province', isEqualTo: province);
    }
    return q.limit(100).snapshots().map((s) {
      var list = s.docs.map((d) => StaffNeed.fromMap(d.id, d.data())).toList();
      if (dailyOnly == true) {
        list = list.where((n) => n.isDaily).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<StaffNeed>> watchMyNeeds(String employerUid) {
    return _needs
        .where('employerUid', isEqualTo: employerUid)
        .limit(50)
        .snapshots()
        .map((s) {
      return s.docs.map((d) => StaffNeed.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<String> createNeed(StaffNeed need) async {
    final ref = _needs.doc();
    await ref.set({
      ...need.toMap(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'open',
    });
    return ref.id;
  }

  @override
  Future<void> closeNeed(String needId) async {
    await _needs.doc(needId).update({'status': 'closed'});
  }
}

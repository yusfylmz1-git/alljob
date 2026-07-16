import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/review.dart';

/// Admin review row (+ hide flag).
class AdminReview {
  const AdminReview({
    required this.review,
    this.hiddenByAdmin = false,
  });

  final Review review;
  final bool hiddenByAdmin;
}

abstract interface class AdminReviewRepository {
  Future<List<AdminReview>> fetchPage({String? beforeCursor, int limit = 30});
  Future<void> setHidden(String reviewId, {required bool hidden});
}

class FirebaseAdminReviewRepository implements AdminReviewRepository {
  FirebaseAdminReviewRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<List<AdminReview>> fetchPage(
      {String? beforeCursor, int limit = 30}) async {
    Query<Map<String, dynamic>> q =
        _db.collection('reviews').orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs.map((d) {
      final m = d.data();
      return AdminReview(
        review: Review.fromMap(d.id, m),
        hiddenByAdmin: m['hiddenByAdmin'] == true,
      );
    }).toList();
  }

  @override
  Future<void> setHidden(String reviewId, {required bool hidden}) async {
    await _functions.httpsCallable('adminHideReview').call<Object?>({
      'reviewId': reviewId,
      'hidden': hidden,
    });
  }
}

class MockAdminReviewRepository implements AdminReviewRepository {
  final List<AdminReview> _items = [];

  void put(AdminReview r) => _items.add(r);

  @override
  Future<List<AdminReview>> fetchPage(
      {String? beforeCursor, int limit = 30}) async {
    var list = List<AdminReview>.from(_items)
      ..sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
    if (beforeCursor != null) {
      final cut = DateTime.tryParse(beforeCursor);
      if (cut != null) {
        list = list.where((r) => r.review.createdAt.isBefore(cut)).toList();
      }
    }
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  @override
  Future<void> setHidden(String reviewId, {required bool hidden}) async {
    final i = _items.indexWhere((r) => r.review.id == reviewId);
    if (i < 0) return;
    final cur = _items[i];
    _items[i] = AdminReview(review: cur.review, hiddenByAdmin: hidden);
  }
}

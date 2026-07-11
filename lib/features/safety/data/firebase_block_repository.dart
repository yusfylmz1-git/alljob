import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/blocked_user.dart';
import 'block_repository.dart';

/// Firestore `users/{uid}/blocked/{otherUid}` ile çalışan [BlockRepository].
/// Kural: yalnızca sahibi okur/yazar; mesaj kuralı bu koleksiyona `exists`
/// ile bakarak engellenenin mesaj yazmasını sunucuda reddeder.
class FirebaseBlockRepository implements BlockRepository {
  FirebaseBlockRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('blocked');

  @override
  Stream<List<BlockedUser>> watchBlocked(String uid) {
    return _col(uid)
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BlockedUser.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> block({required String uid, required BlockedUser other}) =>
      _col(uid).doc(other.uid).set(other.toMap());

  @override
  Future<void> unblock({required String uid, required String otherUid}) =>
      _col(uid).doc(otherUid).delete();
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/favorite.dart';
import 'favorite_repository.dart';

/// Firestore `favorites` ile çalışan [FavoriteRepository].
class FirebaseFavoriteRepository implements FavoriteRepository {
  FirebaseFavoriteRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _favorites =>
      _db.collection('favorites');

  @override
  Future<bool> toggle(Favorite favorite) async {
    final ref = _favorites.doc(favorite.id);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set(favorite.toMap());
    return true;
  }

  @override
  Stream<List<Favorite>> watchFavorites(String customerUid) {
    return _favorites
        .where('customerUid', isEqualTo: customerUid)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Favorite.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<bool> isFavorite({
    required String customerUid,
    required String artisanUid,
  }) async {
    final snap =
        await _favorites.doc(Favorite.idFor(customerUid, artisanUid)).get();
    return snap.exists;
  }
}

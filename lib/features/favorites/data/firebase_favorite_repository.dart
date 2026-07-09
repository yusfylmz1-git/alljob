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
  Stream<List<Favorite>> watchFollowers(String artisanUid) {
    // `artisanUid` eşitlik filtresi kural ispatı için zorunlu (kural: usta
    // yalnızca KENDİ takipçilerini okuyabilir).
    return _favorites
        .where('artisanUid', isEqualTo: artisanUid)
        .snapshots()
        .asyncMap((s) async {
      final list = s.docs.map((d) => Favorite.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Eski kayıtlar müşteri snapshot'ı taşımaz → adı/fotoyu herkese açık
      // `users` dökümanından tamamla (önbellekli; kayıt sayısı sınırlı).
      return Future.wait(list.map((f) async {
        if (f.customerName.isNotEmpty) return f;
        final cached = _customerCache[f.customerUid];
        if (cached != null) {
          return f.copyWith(
              customerName: cached.$1, customerPhotoUrl: cached.$2);
        }
        try {
          final u =
              await _db.collection('users').doc(f.customerUid).get();
          final name = (u.data()?['displayName'] as String?) ?? 'Kullanıcı';
          final photo = u.data()?['profilePhotoURL'] as String?;
          _customerCache[f.customerUid] = (name, photo);
          return f.copyWith(customerName: name, customerPhotoUrl: photo);
        } catch (_) {
          return f.copyWith(customerName: 'Kullanıcı');
        }
      }));
    });
  }

  /// customerUid → (ad, foto) — takipçi listesi her snapshot'ta users'ı
  /// yeniden okumasın diye.
  final Map<String, (String, String?)> _customerCache = {};

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

import '../../../data/local/mock_database.dart';
import '../../../data/models/favorite.dart';
import 'favorite_repository.dart';

/// Bellek içi [FavoriteRepository].
class MockFavoriteRepository implements FavoriteRepository {
  MockFavoriteRepository(this._db);

  final MockDatabase _db;

  @override
  Future<bool> toggle(Favorite favorite) async {
    final id = favorite.id;
    final exists = _db.favorites.containsKey(id);
    if (exists) {
      _db.favorites.remove(id);
    } else {
      _db.favorites[id] = favorite;
    }
    _db.notify();
    return !exists;
  }

  @override
  Stream<List<Favorite>> watchFavorites(String customerUid) async* {
    yield _mine(customerUid);
    yield* _db.changes.map((_) => _mine(customerUid));
  }

  List<Favorite> _mine(String customerUid) {
    final list = _db.favorites.values
        .where((f) => f.customerUid == customerUid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Stream<List<Favorite>> watchFollowers(String artisanUid) async* {
    yield _followers(artisanUid);
    yield* _db.changes.map((_) => _followers(artisanUid));
  }

  List<Favorite> _followers(String artisanUid) {
    final list = _db.favorites.values
        .where((f) => f.artisanUid == artisanUid)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<bool> isFavorite({
    required String customerUid,
    required String artisanUid,
  }) async {
    return _db.favorites.containsKey(Favorite.idFor(customerUid, artisanUid));
  }
}

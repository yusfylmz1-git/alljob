import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/favorite.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import 'favorite_repository.dart';
import 'firebase_favorite_repository.dart';
import 'mock_favorite_repository.dart';

/// Aktif favori repo'su. Backend seçimi [useFirebaseBackend] ile.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  if (useFirebaseBackend) return FirebaseFavoriteRepository();
  return MockFavoriteRepository(ref.watch(mockDatabaseProvider));
});

/// Müşterinin takip ettiği ustalar (Takip Ettiklerim).
final favoritesProvider = StreamProvider.family<List<Favorite>, String>(
  (ref, customerUid) =>
      ref.watch(favoriteRepositoryProvider).watchFavorites(customerUid),
);

/// Ustayı takip eden müşteriler — bildirim ekranı "Sizi Takip Edenler".
final followersProvider = StreamProvider.family<List<Favorite>, String>(
  (ref, artisanUid) =>
      ref.watch(favoriteRepositoryProvider).watchFollowers(artisanUid),
);

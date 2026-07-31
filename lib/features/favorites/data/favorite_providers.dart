import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/favorite.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import '../../auth/application/auth_controller.dart';
import 'favorite_repository.dart';
import 'firebase_favorite_repository.dart';
import 'mock_favorite_repository.dart';

/// Aktif favori repo'su. Backend seçimi [useFirebaseBackend] ile.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  if (useFirebaseBackend) return FirebaseFavoriteRepository();
  return MockFavoriteRepository(ref.watch(mockDatabaseProvider));
});

/// Müşterinin takip ettiği ustalar (Takip Ettiklerim).
/// autoDispose: yalnız favoriler ekranı açıkken tam liste.
final favoritesProvider =
    StreamProvider.autoDispose.family<List<Favorite>, String>(
  (ref, customerUid) =>
      ref.watch(favoriteRepositoryProvider).watchFavorites(customerUid),
);

/// Ustayı takip eden müşteriler — bildirim ekranı "Sizi Takip Edenler".
final followersProvider =
    StreamProvider.autoDispose.family<List<Favorite>, String>(
  (ref, artisanUid) =>
      ref.watch(favoriteRepositoryProvider).watchFollowers(artisanUid),
);

/// Tek usta için favori mi? (kalp butonu — tek döküman snapshot).
/// [artisanUid] family anahtarı; müşteri oturumdan alınır.
final isFavoriteProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, artisanUid) {
    final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (uid == null) return Stream.value(false);
    return ref.watch(favoriteRepositoryProvider).watchIsFavorite(
          customerUid: uid,
          artisanUid: artisanUid,
        );
  },
);

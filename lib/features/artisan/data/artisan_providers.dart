import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/local/mock_database.dart';
import 'artisan_repository.dart';
import 'firebase_artisan_repository.dart';
import 'mock_artisan_repository.dart';

/// Uygulama boyunca yaşayan ortak bellek içi veritabanı. Müşteri araması ve
/// ustanın kendi profili aynı örneği paylaşır (Firebase gelince Firestore olur).
final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());

/// Aktif usta verisi sağlayıcısı. Backend seçimi [useFirebaseBackend] ile.
final artisanRepositoryProvider = Provider<ArtisanRepository>((ref) {
  if (useFirebaseBackend) return FirebaseArtisanRepository();
  return MockArtisanRepository(ref.watch(mockDatabaseProvider));
});

/// Tek bir ustanın tam profil detayını (profil + yorumlar) getirir.
final artisanDetailProvider =
    FutureProvider.family<ArtisanDetail?, String>((ref, uid) {
  return ref.watch(artisanRepositoryProvider).getArtisanDetail(uid);
});

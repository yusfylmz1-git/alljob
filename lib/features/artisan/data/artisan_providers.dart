import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/config/backend_config.dart';
import '../../../data/local/mock_database.dart';
import '../../auth/application/auth_controller.dart';
import '../application/my_profile_controller.dart';
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

// ─────────── ŞEHİR BAZLI PREMIUM KAPISI (2026-08-23) ───────────

/// Oturum açmış kullanıcının hizmet İLLERİ.
///
/// Kaynak sırası: usta profili (`serviceAreas`) → mağaza bölgeleri
/// (`users.shopServiceAreas`). Tek il kuralı geldiği için en fazla bir
/// tane döner; eski çok illi kayıtlarda hepsi listelenir.
///
/// İkisi de boşsa BOŞ liste: kullanıcı hiçbir ilin kapsamına girmez ve
/// ücretli döneme alınmaz. Bölgesiz profili ücretliye almak yanlış olurdu —
/// hangi ile ait olduğu bilinmiyor.
final myProvincesProvider = Provider<List<String>>((ref) {
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  final usta = draft?.profile.serviceAreas ?? const [];
  if (usta.isNotEmpty) {
    return usta
        .map((a) => a.province.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
  }
  final magaza = ref.watch(currentUserProvider)?.shopServiceAreas ?? const [];
  return magaza
      .map((a) => a.province.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
});

/// Bu kullanıcı için premium ÜCRETSİZ mi?
///
/// Şehir bazlı geçişin TEK okuma noktası: beta bayrağı + kullanıcının ili +
/// ücretli il listesi. Ayrı ayrı hesaplayan her ekran zamanla ayrışırdı.
///
/// Liste boşken davranış bugünküyle BİREBİR aynı — yalnız beta bayrağı
/// karar verir.
final premiumFreeForMeProvider = Provider<bool>((ref) {
  final cfg = ref.watch(appRuntimeConfigProvider).valueOrNull;
  return premiumFreeForUser(
    userProvinces: ref.watch(myProvincesProvider),
    premiumFreeDuringBeta: cfg?.premiumFreeDuringBeta,
    paidProvinces: cfg?.paidProvinces ?? const [],
  );
});

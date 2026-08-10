import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/product.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import 'firebase_product_repository.dart';
import 'mock_product_repository.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  if (useFirebaseBackend) return FirebaseProductRepository();
  return MockProductRepository(ref.watch(mockDatabaseProvider));
});

/// Mağaza ürün vitrini açık mı? Yerel hard-off + remote `productsEnabled`.
///
/// Config henüz yüklenmediyse yerel sabite düşer (varsayılan: açık).
final productsLiveProvider = Provider<bool>((ref) {
  final remote = ref.watch(appRuntimeConfigProvider).valueOrNull;
  if (remote != null) return remote.isProductsLive;
  return AppConstants.kProductsEnabled;
});

final discoverProductsProvider = StreamProvider<List<Product>>((ref) {
  if (!ref.watch(productsLiveProvider)) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(productRepositoryProvider).watchDiscoverProducts(
        limit: AppConstants.productDiscoverFetchCap,
      );
});

/// Sahibin KENDİ ürünleri — taslak, duraklatılmış, satılmış dâhil.
/// Yalnızca "Ürünlerim" ekranında kullanılır.
final myProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, ownerUid) {
  return ref.watch(productRepositoryProvider).watchMyProducts(ownerUid);
});

/// Bir kullanıcının BAŞKASINA görünen vitrini — yalnız yayındakiler.
///
/// `myProductsProvider` durum filtresi uygulamaz; başkasının profilinde
/// onu kullanmak taslak ve satılmış ürünleri sızdırırdı. Moderasyonla
/// gizlenmişler de elenir.
/// Ölçüt `Product.isLiveInDiscover` — Keşfet feed'iyle AYNI kural
/// (`active` && `!moderationHidden`). İkisi ayrışırsa profilde görünüp
/// Keşfet'te görünmeyen (veya tersi) ürünler doğar.
final publicProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, ownerUid) {
  return ref
      .watch(productRepositoryProvider)
      .watchMyProducts(ownerUid)
      .map((list) => list.where((p) => p.isLiveInDiscover).toList());
});

final productProvider =
    StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});

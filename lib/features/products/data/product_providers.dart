import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final discoverProductsProvider = StreamProvider<List<Product>>((ref) {
  if (!AppConstants.kProductsEnabled) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(productRepositoryProvider).watchDiscoverProducts(
        limit: AppConstants.productDiscoverFetchCap,
      );
});

final myProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, ownerUid) {
  return ref.watch(productRepositoryProvider).watchMyProducts(ownerUid);
});

final productProvider =
    StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});

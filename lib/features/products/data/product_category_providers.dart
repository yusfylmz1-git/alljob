import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/product_category.dart';

/// Canlı ürün kategorisi kataloğu.
///
/// Kaynak: `adminConfig/productCategories` (public read, yalnız CF yazar).
/// Boşsa / mock backend: gömülü [ProductCategoryCatalog.defaults].
final productCategoryCatalogProvider =
    StreamProvider<ProductCategoryCatalog>((ref) {
  if (!useFirebaseBackend) {
    return Stream.value(ProductCategoryCatalog.defaults);
  }
  return FirebaseFirestore.instance
      .collection('adminConfig')
      .doc('productCategories')
      .snapshots()
      .map((s) => ProductCategoryCatalog.fromRemote(s.data()));
});

/// Senkron erişim: stream henüz dolmadıysa yedek varsayılanlar.
ProductCategoryCatalog catalogOf(WidgetRef ref) {
  return ref.watch(productCategoryCatalogProvider).valueOrNull ??
      ProductCategoryCatalog.defaults;
}

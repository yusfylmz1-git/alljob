import '../../../data/models/product.dart';

/// Keşfet Ürünler repository sözleşmesi.
abstract class ProductRepository {
  /// Keşfet: active ∧ !moderationHidden, publishedAt desc.
  Stream<List<Product>> watchDiscoverProducts({
    String? province,
    String? categoryCode,
    int limit = 30,
  });

  Stream<List<Product>> watchMyProducts(String ownerUid);

  Stream<Product?> watchProduct(String productId);

  Future<Product?> getProduct(String productId);

  /// Draft oluştur; dönen id ile foto yükle.
  Future<String> createDraft(Product draft);

  /// Draft content + safe alanlar (status draft kalır).
  Future<void> updateDraft(Product product);

  /// Safe + lifecycle client transitions (PRD allowlist).
  Future<void> setLifecycle({
    required String productId,
    required ProductStatus to,
    String? removedReason,
  });

  /// CF publishProduct.
  Future<void> publishProduct(String productId);

  /// CF updateProductContent (requeue pending_review).
  Future<void> updateProductContent({
    required String productId,
    required String title,
    required String description,
    required String categoryCode,
    required List<String> photos,
  });

  /// Safe fields only (price/tags/condition/location/denorm) — status unchanged.
  Future<void> updateSafeFields({
    required String productId,
    required ProductPriceType priceType,
    required double? priceAmount,
    required ProductCondition condition,
    required int quantity,
    required List<String> tags,
    required String province,
    String? district,
    String? ownerName,
    String? ownerPhotoUrl,
  });
}

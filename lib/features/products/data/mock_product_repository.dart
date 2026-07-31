import '../../../core/constants/app_constants.dart';
import '../../../core/utils/search_fold.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/product.dart';
import 'product_repository.dart';

class MockProductRepository implements ProductRepository {
  MockProductRepository(this._db);

  final MockDatabase _db;
  int _seq = 0;

  @override
  Stream<List<Product>> watchDiscoverProducts({
    String? province,
    String? categoryCode,
    int limit = 30,
  }) async* {
    yield _discover(province, categoryCode, limit);
    yield* _db.changes
        .map((_) => _discover(province, categoryCode, limit));
  }

  List<Product> _discover(String? province, String? categoryCode, int limit) {
    var list = _db.products.values.where((p) => p.isLiveInDiscover).toList();
    if (province != null && province.isNotEmpty) {
      list = list.where((p) => p.province == province).toList();
    }
    if (categoryCode != null && categoryCode.isNotEmpty) {
      list = list.where((p) => p.categoryCode == categoryCode).toList();
    }
    list.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      final ap = a.publishedAt ?? a.createdAt;
      final bp = b.publishedAt ?? b.createdAt;
      return bp.compareTo(ap);
    });
    return list.take(limit).toList();
  }

  @override
  Stream<List<Product>> watchMyProducts(String ownerUid) async* {
    yield _mine(ownerUid);
    yield* _db.changes.map((_) => _mine(ownerUid));
  }

  List<Product> _mine(String ownerUid) {
    return _db.products.values.where((p) => p.ownerUid == ownerUid).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Stream<Product?> watchProduct(String productId) async* {
    yield _db.products[productId];
    yield* _db.changes.map((_) => _db.products[productId]);
  }

  @override
  Future<Product?> getProduct(String productId) async =>
      _db.products[productId];

  @override
  Future<String> createDraft(Product draft) async {
    final id = draft.id.isNotEmpty
        ? draft.id
        : 'prod_${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
    final p = Product.fromMap(id, {
      ...draft.toMap(),
      'status': ProductStatus.draft.apiValue,
      'moderationHidden': false,
    });
    _db.products[id] = p;
    _db.notify();
    return id;
  }

  @override
  Future<void> updateDraft(Product product) async {
    final prev = _db.products[product.id];
    if (prev == null || prev.status != ProductStatus.draft) {
      throw StateError('not-draft');
    }
    _db.products[product.id] = product.copyWith(
      status: ProductStatus.draft,
      updatedAt: DateTime.now(),
    );
    _db.notify();
  }

  @override
  Future<void> setLifecycle({
    required String productId,
    required ProductStatus to,
    String? removedReason,
  }) async {
    final current = _db.products[productId];
    if (current == null) throw StateError('product-not-found');
    if (!canOwnerTransition(current.status, to)) {
      throw StateError('invalid-transition');
    }
    if (to == ProductStatus.draft &&
        current.status == ProductStatus.removed &&
        !current.isOwnerRestorable) {
      throw StateError('admin-removed-not-restorable');
    }
    final now = DateTime.now();
    var next = current.copyWith(status: to, updatedAt: now);
    if (to == ProductStatus.sold) {
      next = next.copyWith(soldAt: now);
    }
    if (to == ProductStatus.removed) {
      next = next.copyWith(
        removedAt: now,
        removedBy: 'owner',
        removedReason: removedReason,
      );
    }
    if (to == ProductStatus.draft && current.status == ProductStatus.removed) {
      next = Product(
        id: current.id,
        ownerUid: current.ownerUid,
        ownerName: current.ownerName,
        ownerPhotoUrl: current.ownerPhotoUrl,
        title: current.title,
        description: current.description,
        categoryCode: current.categoryCode,
        tags: current.tags,
        photos: current.photos,
        priceType: current.priceType,
        priceAmount: current.priceAmount,
        currency: current.currency,
        condition: current.condition,
        quantity: current.quantity,
        province: current.province,
        district: current.district,
        status: ProductStatus.draft,
        moderationHidden: current.moderationHidden,
        hiddenByModeration: current.hiddenByModeration,
        hiddenByUserSuspend: current.hiddenByUserSuspend,
        hiddenByArtisanHide: current.hiddenByArtisanHide,
        featured: current.featured,
        createdAt: current.createdAt,
        updatedAt: now,
        publishedAt: current.publishedAt,
        reportCount: current.reportCount,
        viewCount: current.viewCount,
        schemaVersion: current.schemaVersion,
      );
    }
    _db.products[productId] = next;
    _db.notify();
  }

  @override
  Future<void> publishProduct(String productId) async {
    final p = _db.products[productId];
    if (p == null) throw StateError('product-not-found');
    if (p.status != ProductStatus.draft &&
        p.status != ProductStatus.pendingReview) {
      // allow re-publish from draft after reject
      if (p.status != ProductStatus.draft) {
        throw StateError('not-publishable');
      }
    }
    if (!productFieldsComplete(
      title: p.title,
      description: p.description,
      categoryCode: p.categoryCode,
      photos: p.photos,
      priceType: p.priceType,
      priceAmount: p.priceAmount,
      province: p.province,
      condition: p.condition,
    )) {
      throw StateError('fields-incomplete');
    }
    final activeCount = _db.products.values
        .where((x) =>
            x.ownerUid == p.ownerUid &&
            (x.status == ProductStatus.active ||
                x.status == ProductStatus.paused ||
                x.status == ProductStatus.outOfStock))
        .length;
    if (activeCount >= AppConstants.maxActiveProductsPerOwner &&
        p.status == ProductStatus.draft) {
      throw StateError('active-cap');
    }
    final now = DateTime.now();
    final hidden = p.hiddenByModeration ||
        p.hiddenByUserSuspend ||
        p.hiddenByArtisanHide;
    _db.products[productId] = Product(
      id: p.id,
      ownerUid: p.ownerUid,
      ownerName: p.ownerName,
      ownerPhotoUrl: p.ownerPhotoUrl,
      title: p.title,
      description: p.description,
      categoryCode: p.categoryCode,
      tags: p.tags,
      photos: p.photos,
      priceType: p.priceType,
      priceAmount: p.priceAmount,
      currency: p.currency,
      condition: p.condition,
      quantity: p.quantity,
      province: p.province,
      district: p.district,
      status: ProductStatus.active,
      moderationHidden: hidden,
      hiddenByModeration: p.hiddenByModeration,
      hiddenByUserSuspend: p.hiddenByUserSuspend,
      hiddenByArtisanHide: p.hiddenByArtisanHide,
      featured: p.featured,
      createdAt: p.createdAt,
      updatedAt: now,
      publishedAt: p.publishedAt ?? now,
      soldAt: p.soldAt,
      removedAt: p.removedAt,
      removedBy: p.removedBy,
      removedReason: p.removedReason,
      reportCount: p.reportCount,
      viewCount: p.viewCount,
      moderationNote: p.moderationNote,
      schemaVersion: p.schemaVersion,
    );
    _db.notify();
  }

  @override
  Future<void> updateProductContent({
    required String productId,
    required String title,
    required String description,
    required String categoryCode,
    required List<String> photos,
  }) async {
    final p = _db.products[productId];
    if (p == null) throw StateError('product-not-found');
    if (p.status == ProductStatus.draft ||
        p.status == ProductStatus.removed) {
      throw StateError('use-draft-or-forbidden');
    }
    final now = DateTime.now();
    final hidden = p.hiddenByModeration ||
        p.hiddenByUserSuspend ||
        p.hiddenByArtisanHide;
    _db.products[productId] = Product.fromMap(productId, {
      ...p.toMap(),
      'title': title.trim(),
      'titleFold': foldTrSearch(title),
      'description': description.trim(),
      'categoryCode': categoryCode,
      'photos': photos,
      'status': ProductStatus.pendingReview.apiValue,
      'moderationHidden': hidden,
      'hiddenByModeration': p.hiddenByModeration,
      'hiddenByUserSuspend': p.hiddenByUserSuspend,
      'hiddenByArtisanHide': p.hiddenByArtisanHide,
      'updatedAt': now.toIso8601String(),
    });
    _db.notify();
  }

  @override
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
  }) async {
    final p = _db.products[productId];
    if (p == null) throw StateError('product-not-found');
    if (p.status == ProductStatus.pendingReview ||
        p.status == ProductStatus.removed) {
      throw StateError('safe-edit-locked');
    }
    final now = DateTime.now();
    _db.products[productId] = p.copyWith(
      priceType: priceType,
      priceAmount: priceAmount,
      clearPriceAmount: priceType == ProductPriceType.negotiable,
      condition: condition,
      quantity: quantity,
      tags: tags,
      province: province,
      district: district,
      ownerName: ownerName,
      ownerPhotoUrl: ownerPhotoUrl,
      updatedAt: now,
    );
    _db.notify();
  }
}

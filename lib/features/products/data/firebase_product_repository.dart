import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/search_fold.dart';
import '../../../data/models/product.dart';
import 'product_repository.dart';

class FirebaseProductRepository implements ProductRepository {
  FirebaseProductRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  /// Create/update allowlist ile birebir; null alanlar OMIT (rules hasOnly +
  /// gereksiz null yazımı yok).
  Map<String, dynamic> _draftWriteMap(Product p, {required bool isCreate}) {
    final map = <String, dynamic>{
      'schemaVersion': 1,
      'ownerUid': p.ownerUid,
      'ownerName': p.ownerName.trim().isEmpty ? 'Usta' : p.ownerName.trim(),
      'title': p.title.trim(),
      'titleFold': foldTrSearch(p.title),
      'description': p.description.trim(),
      'categoryCode': p.categoryCode.trim(),
      'tags': p.tags,
      'tagsFold': p.tags.map(foldTrSearch).toList(),
      'photos': p.photos,
      'priceType': p.priceType.apiValue,
      'currency': p.currency,
      'condition': p.condition.apiValue,
      'quantity': p.quantity < 1 ? 1 : p.quantity,
      'province': p.province.trim(),
      'status': ProductStatus.draft.apiValue,
      'updatedAt': p.updatedAt.toIso8601String(),
    };
    if (p.ownerPhotoUrl != null && p.ownerPhotoUrl!.trim().isNotEmpty) {
      map['ownerPhotoURL'] = p.ownerPhotoUrl!.trim();
    }
    if (p.priceAmount != null) {
      map['priceAmount'] = p.priceAmount;
    }
    if (p.district != null && p.district!.trim().isNotEmpty) {
      map['district'] = p.district!.trim();
    }
    if (isCreate) {
      map['moderationHidden'] = false;
      map['createdAt'] = p.createdAt.toIso8601String();
    }
    return map;
  }

  @override
  Stream<List<Product>> watchDiscoverProducts({
    String? province,
    String? categoryCode,
    int limit = 30,
  }) {
    final cap = limit > AppConstants.productDiscoverFetchCap
        ? limit
        : AppConstants.productDiscoverFetchCap;
    return _col
        .where('status', isEqualTo: ProductStatus.active.apiValue)
        .limit(cap)
        .snapshots()
        .map((s) {
      try {
        var list = s.docs
            .map((d) {
              try {
                return Product.fromMap(d.id, d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Product>()
            .where((p) => p.isLiveInDiscover)
            .toList();
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
        return list.take(limit).toList(growable: false);
      } catch (_) {
        return const <Product>[];
      }
    });
  }

  @override
  Stream<List<Product>> watchMyProducts(String ownerUid) {
    return _col
        .where('ownerUid', isEqualTo: ownerUid)
        .limit(100)
        .snapshots()
        .map((s) {
      try {
        return s.docs
            .map((d) {
              try {
                return Product.fromMap(d.id, d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Product>()
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } catch (_) {
        return const <Product>[];
      }
    });
  }

  @override
  Stream<Product?> watchProduct(String productId) {
    return _col.doc(productId).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      return Product.fromMap(d.id, d.data()!);
    });
  }

  @override
  Future<Product?> getProduct(String productId) async {
    final d = await _col.doc(productId).get();
    if (!d.exists || d.data() == null) return null;
    return Product.fromMap(d.id, d.data()!);
  }

  @override
  Future<String> createDraft(Product draft) async {
    final ref = draft.id.isNotEmpty ? _col.doc(draft.id) : _col.doc();
    final now = DateTime.now();
    final p = draft.copyWith(updatedAt: now);
    await ref.set(_draftWriteMap(
      Product(
        id: ref.id,
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
        condition: p.condition,
        quantity: p.quantity,
        province: p.province,
        district: p.district,
        status: ProductStatus.draft,
        createdAt: p.createdAt,
        updatedAt: now,
      ),
      isCreate: true,
    ));
    return ref.id;
  }

  @override
  Future<void> updateDraft(Product product) async {
    final prev = await getProduct(product.id);
    if (prev == null) throw StateError('product-not-found');
    if (prev.status != ProductStatus.draft) {
      throw StateError('not-draft');
    }
    final now = DateTime.now();
    // Draft update: content + safe alanlar; server alanlarına dokunma
    // (moderationHidden / publishedAt vb. merge'de kalır).
    final map = _draftWriteMap(
      product.copyWith(updatedAt: now),
      isCreate: false,
    );
    // Update'te schemaVersion / createdAt / moderationHidden yazma —
    // productServerFieldsLocked bunları değiştirmeyi engeller.
    map.remove('schemaVersion');
    await _col.doc(product.id).set(map, SetOptions(merge: true));
  }

  @override
  Future<void> setLifecycle({
    required String productId,
    required ProductStatus to,
    String? removedReason,
  }) async {
    final current = await getProduct(productId);
    if (current == null) throw StateError('product-not-found');
    if (!canOwnerTransition(current.status, to)) {
      throw StateError('invalid-transition');
    }
    if (!ownerNeverPublishesViaStatus(current.status, to)) {
      throw StateError('publish-via-status-forbidden');
    }
    if (to == ProductStatus.draft && current.status == ProductStatus.removed) {
      if (!current.isOwnerRestorable) {
        throw StateError('admin-removed-not-restorable');
      }
    }
    final now = DateTime.now();
    final patch = <String, dynamic>{
      'status': to.apiValue,
      'updatedAt': now.toIso8601String(),
    };
    if (to == ProductStatus.sold) {
      patch['soldAt'] = now.toIso8601String();
    }
    if (to == ProductStatus.removed) {
      patch['removedAt'] = now.toIso8601String();
      patch['removedBy'] = 'owner';
      if (removedReason != null) patch['removedReason'] = removedReason;
    }
    if (to == ProductStatus.draft &&
        current.status == ProductStatus.removed) {
      patch['removedAt'] = FieldValue.delete();
      patch['removedBy'] = FieldValue.delete();
      patch['removedReason'] = FieldValue.delete();
    }
    await _col.doc(productId).set(patch, SetOptions(merge: true));
  }

  @override
  Future<void> publishProduct(String productId) async {
    try {
      await _functions.httpsCallable('publishProduct').call<Object?>({
        'productId': productId,
      });
    } on FirebaseFunctionsException catch (e) {
      // ignore: avoid_print
      print('publishProduct CF hatası → code=${e.code} '
          'message=${e.message} details=${e.details}');
      // CF henüz deploy edilmemiş olabilir.
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw StateError('publish-cf-missing');
      }
      rethrow;
    }
  }

  @override
  Future<void> updateProductContent({
    required String productId,
    required String title,
    required String description,
    required String categoryCode,
    required List<String> photos,
  }) async {
    try {
      await _functions.httpsCallable('updateProductContent').call<Object?>({
        'productId': productId,
        'title': title,
        'description': description,
        'categoryCode': categoryCode,
        'photos': photos,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw StateError('content-cf-missing');
      }
      rethrow;
    }
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
    final patch = <String, dynamic>{
      'priceType': priceType.apiValue,
      'condition': condition.apiValue,
      'quantity': quantity < 1 ? 1 : quantity,
      'tags': tags,
      'tagsFold': tags.map(foldTrSearch).toList(),
      'province': province.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (priceAmount != null) {
      patch['priceAmount'] = priceAmount;
    } else {
      patch['priceAmount'] = FieldValue.delete();
    }
    if (district != null && district.trim().isNotEmpty) {
      patch['district'] = district.trim();
    } else {
      patch['district'] = FieldValue.delete();
    }
    if (ownerName != null && ownerName.trim().isNotEmpty) {
      patch['ownerName'] = ownerName.trim();
    }
    if (ownerPhotoUrl != null && ownerPhotoUrl.trim().isNotEmpty) {
      patch['ownerPhotoURL'] = ownerPhotoUrl.trim();
    }
    await _col.doc(productId).set(patch, SetOptions(merge: true));
  }
}

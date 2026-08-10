import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/product.dart';

/// Admin ürün dizini filtresi.
///
/// Tek equality (jobs deseni): status VEYA gizli bayrağı — ikisi birden değil.
enum AdminProductListFilter {
  /// Varsayılan kuyruk: inceleme bekleyenler.
  pendingReview,
  all,
  active,
  draft,
  paused,
  sold,
  removed,
  /// `moderationHidden == true` (durum filtresi yok).
  hidden,
}

extension AdminProductListFilterX on AdminProductListFilter {
  String get labelTR => switch (this) {
        AdminProductListFilter.pendingReview => 'İncelemede',
        AdminProductListFilter.all => 'Tümü',
        AdminProductListFilter.active => 'Yayında',
        AdminProductListFilter.draft => 'Taslak',
        AdminProductListFilter.paused => 'Duraklatıldı',
        AdminProductListFilter.sold => 'Satıldı',
        AdminProductListFilter.removed => 'Kaldırıldı',
        AdminProductListFilter.hidden => 'Gizli',
      };
}

/// Yönetici ürün tarayıcısı + moderasyon (`adminModerateProduct`).
abstract interface class AdminProductRepository {
  Future<List<Product>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminProductListFilter filter = AdminProductListFilter.pendingReview,
  });

  /// Tam ürün kimliği ile bul (yoksa null).
  Future<Product?> findById(String productId);

  /// hide | unhide | approve | reject | force_remove | hard_purge
  Future<void> moderate(
    String productId, {
    required String decision,
    String? note,
  });
}

class FirebaseAdminProductRepository implements AdminProductRepository {
  FirebaseAdminProductRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<List<Product>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminProductListFilter filter = AdminProductListFilter.pendingReview,
  }) async {
    try {
      return await _fetchPageRaw(
        beforeCursor: beforeCursor,
        limit: limit,
        filter: filter,
      );
    } catch (e) {
      // Bileşik indeks henüz READY değilse: tek alan orderBy + istemci süzme.
      // Admin paneli indekssiz de açılsın (boş kuyruk "hata" sanılmasın).
      final s = e.toString().toLowerCase();
      final indexMissing = s.contains('failed-precondition') ||
          s.contains('requires an index') ||
          s.contains('the query requires an index');
      if (!indexMissing || filter == AdminProductListFilter.all) rethrow;
      return _fetchPageClientFilter(
        beforeCursor: beforeCursor,
        limit: limit,
        filter: filter,
      );
    }
  }

  Future<List<Product>> _fetchPageRaw({
    String? beforeCursor,
    int limit = 30,
    required AdminProductListFilter filter,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('products');

    if (filter == AdminProductListFilter.hidden) {
      q = q.where('moderationHidden', isEqualTo: true);
    } else if (filter != AdminProductListFilter.all) {
      final status = switch (filter) {
        AdminProductListFilter.pendingReview => ProductStatus.pendingReview,
        AdminProductListFilter.active => ProductStatus.active,
        AdminProductListFilter.draft => ProductStatus.draft,
        AdminProductListFilter.paused => ProductStatus.paused,
        AdminProductListFilter.sold => ProductStatus.sold,
        AdminProductListFilter.removed => ProductStatus.removed,
        _ => null,
      };
      if (status != null) {
        q = q.where('status', isEqualTo: status.apiValue);
      }
    }

    q = q.orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return _mapDocs(snap.docs);
  }

  /// İndeks yokken: son N ürünü çek, filtreyi istemcide uygula.
  Future<List<Product>> _fetchPageClientFilter({
    String? beforeCursor,
    int limit = 30,
    required AdminProductListFilter filter,
  }) async {
    Query<Map<String, dynamic>> q =
        _db.collection('products').orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    // Filtre daraltırken daha geniş pencere oku, sonra kes.
    final snap = await q.limit(limit * 4).get();
    final all = _mapDocs(snap.docs);
    final filtered = all.where((p) => _matchesFilter(p, filter)).toList();
    if (filtered.length > limit) return filtered.sublist(0, limit);
    return filtered;
  }

  static bool _matchesFilter(Product p, AdminProductListFilter filter) {
    return switch (filter) {
      AdminProductListFilter.all => true,
      AdminProductListFilter.hidden => p.moderationHidden,
      AdminProductListFilter.pendingReview =>
        p.status == ProductStatus.pendingReview,
      AdminProductListFilter.active => p.status == ProductStatus.active,
      AdminProductListFilter.draft => p.status == ProductStatus.draft,
      AdminProductListFilter.paused => p.status == ProductStatus.paused,
      AdminProductListFilter.sold => p.status == ProductStatus.sold,
      AdminProductListFilter.removed => p.status == ProductStatus.removed,
    };
  }

  static List<Product> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <Product>[];
    for (final d in docs) {
      try {
        out.add(Product.fromMap(d.id, d.data()));
      } catch (_) {
        // Bozuk tek döküman tüm kuyruğu düşürmesin.
      }
    }
    return out;
  }

  @override
  Future<Product?> findById(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return null;
    final snap = await _db.collection('products').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return Product.fromMap(snap.id, snap.data()!);
  }

  @override
  Future<void> moderate(
    String productId, {
    required String decision,
    String? note,
  }) async {
    await _functions.httpsCallable('adminModerateProduct').call<Object?>({
      'productId': productId,
      'decision': decision,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}

class MockAdminProductRepository implements AdminProductRepository {
  MockAdminProductRepository([List<Product>? seed]) {
    if (seed != null) {
      for (final p in seed) {
        _items[p.id] = p;
      }
    }
  }

  final Map<String, Product> _items = {};

  void put(Product p) => _items[p.id] = p;

  @override
  Future<List<Product>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    AdminProductListFilter filter = AdminProductListFilter.pendingReview,
  }) async {
    var list = _items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    list = switch (filter) {
      AdminProductListFilter.all => list,
      AdminProductListFilter.hidden =>
        list.where((p) => p.moderationHidden).toList(),
      AdminProductListFilter.pendingReview =>
        list.where((p) => p.status == ProductStatus.pendingReview).toList(),
      AdminProductListFilter.active =>
        list.where((p) => p.status == ProductStatus.active).toList(),
      AdminProductListFilter.draft =>
        list.where((p) => p.status == ProductStatus.draft).toList(),
      AdminProductListFilter.paused =>
        list.where((p) => p.status == ProductStatus.paused).toList(),
      AdminProductListFilter.sold =>
        list.where((p) => p.status == ProductStatus.sold).toList(),
      AdminProductListFilter.removed =>
        list.where((p) => p.status == ProductStatus.removed).toList(),
    };

    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      final cut = DateTime.tryParse(beforeCursor);
      if (cut != null) {
        list = list.where((p) => p.createdAt.isBefore(cut)).toList();
      }
    }
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  @override
  Future<Product?> findById(String productId) async => _items[productId.trim()];

  @override
  Future<void> moderate(
    String productId, {
    required String decision,
    String? note,
  }) async {
    final p = _items[productId];
    if (p == null) return;
    final now = DateTime.now();
    if (decision == 'hard_purge') {
      _items.remove(productId);
      return;
    }
    // copyWith moderasyon bayraklarını taşımıyor; tam kayıt kur.
    Product rebuilt({
      ProductStatus? status,
      bool? moderationHidden,
      bool? hiddenByModeration,
      DateTime? publishedAt,
      DateTime? removedAt,
      String? removedBy,
      String? removedReason,
      String? moderationNote,
    }) {
      return Product(
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
        status: status ?? p.status,
        moderationHidden: moderationHidden ?? p.moderationHidden,
        hiddenByModeration: hiddenByModeration ?? p.hiddenByModeration,
        hiddenByUserSuspend: p.hiddenByUserSuspend,
        hiddenByArtisanHide: p.hiddenByArtisanHide,
        featured: p.featured,
        createdAt: p.createdAt,
        updatedAt: now,
        publishedAt: publishedAt ?? p.publishedAt,
        soldAt: p.soldAt,
        removedAt: removedAt ?? p.removedAt,
        removedBy: removedBy ?? p.removedBy,
        removedReason: removedReason ?? p.removedReason,
        reportCount: p.reportCount,
        viewCount: p.viewCount,
        moderationNote: moderationNote ?? p.moderationNote,
      );
    }

    _items[productId] = switch (decision) {
      'approve' => rebuilt(
          status: ProductStatus.active,
          moderationHidden: false,
          hiddenByModeration: false,
          publishedAt: p.publishedAt ?? now,
        ),
      'reject' => rebuilt(
          status: ProductStatus.draft,
          moderationNote: note,
        ),
      'hide' => rebuilt(
          moderationHidden: true,
          hiddenByModeration: true,
        ),
      'unhide' => rebuilt(
          hiddenByModeration: false,
          moderationHidden: p.hiddenByUserSuspend || p.hiddenByArtisanHide,
        ),
      'force_remove' => rebuilt(
          status: ProductStatus.removed,
          moderationHidden: true,
          hiddenByModeration: true,
          removedAt: now,
          removedBy: 'admin',
          removedReason: note,
        ),
      _ => p,
    };
  }
}

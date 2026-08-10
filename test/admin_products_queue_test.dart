import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/product.dart';
import 'package:sepette_hizmet/features/admin/data/admin_product_repository.dart';

Product _p({
  required String id,
  ProductStatus status = ProductStatus.active,
  bool hidden = false,
}) {
  final now = DateTime.utc(2026, 8, 10);
  return Product(
    id: id,
    ownerUid: 'u1',
    ownerName: 'Satıcı',
    title: 'Ürün $id',
    description: 'Açıklama en az on karakter',
    categoryCode: 'hirdavat',
    photos: const ['https://example.com/a.jpg'],
    priceType: ProductPriceType.negotiable,
    condition: ProductCondition.used,
    province: 'Bursa',
    status: status,
    moderationHidden: hidden,
    hiddenByModeration: hidden,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('MockAdminProductRepository', () {
    test('varsayılan kuyruk yalnız pending_review', () async {
      final repo = MockAdminProductRepository([
        _p(id: 'a', status: ProductStatus.pendingReview),
        _p(id: 'b', status: ProductStatus.active),
        _p(id: 'c', status: ProductStatus.draft),
      ]);
      final page = await repo.fetchPage();
      expect(page.map((p) => p.id), ['a']);
    });

    test('approve: pending → active', () async {
      final repo = MockAdminProductRepository([
        _p(id: 'a', status: ProductStatus.pendingReview),
      ]);
      await repo.moderate('a', decision: 'approve');
      final page = await repo.fetchPage(filter: AdminProductListFilter.active);
      expect(page.single.id, 'a');
      expect(page.single.status, ProductStatus.active);
    });

    test('reject: pending → draft', () async {
      final repo = MockAdminProductRepository([
        _p(id: 'a', status: ProductStatus.pendingReview),
      ]);
      await repo.moderate('a', decision: 'reject', note: 'eksik foto');
      final page = await repo.fetchPage(filter: AdminProductListFilter.draft);
      expect(page.single.status, ProductStatus.draft);
      expect(page.single.moderationNote, 'eksik foto');
    });

    test('hard_purge kaydı siler', () async {
      final repo = MockAdminProductRepository([_p(id: 'a')]);
      await repo.moderate('a', decision: 'hard_purge');
      final page = await repo.fetchPage(filter: AdminProductListFilter.all);
      expect(page, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/utils/validators.dart';
import 'package:sepette_hizmet/data/models/product.dart';

void main() {
  group('parseTrAmount (ürün fiyatı TR yazımı)', () {
    test('binlik nokta: "1.500" → 1500 (1.5 DEĞİL)', () {
      expect(Validators.parseTrAmount('1.500'), 1500);
      expect(Validators.parseTrAmount('12.500'), 12500);
      expect(Validators.parseTrAmount('1.250.000'), 1250000);
    });

    test('ondalık virgül ve karışık yazım', () {
      expect(Validators.parseTrAmount('1.500,50'), 1500.5);
      expect(Validators.parseTrAmount('99,90'), 99.9);
      expect(Validators.parseTrAmount('1,500.50'), 1500.5);
    });

    test('düz yazımlar ve semboller', () {
      expect(Validators.parseTrAmount('1500'), 1500);
      expect(Validators.parseTrAmount('10.5'), 10.5);
      expect(Validators.parseTrAmount('₺ 2.000'), 2000);
      expect(Validators.parseTrAmount('  750 TL '), 750);
    });

    test('geçersiz girişler null', () {
      expect(Validators.parseTrAmount(''), isNull);
      expect(Validators.parseTrAmount(null), isNull);
      expect(Validators.parseTrAmount('abc'), isNull);
      expect(Validators.parseTrAmount('.,'), isNull);
    });
  });

  group('ProductStatus transitions', () {
    test('owner cannot publish draft→active via client', () {
      expect(
        ownerNeverPublishesViaStatus(
            ProductStatus.draft, ProductStatus.active),
        isFalse,
      );
      expect(
        ownerNeverPublishesViaStatus(
            ProductStatus.pendingReview, ProductStatus.active),
        isFalse,
      );
      expect(
        ownerNeverPublishesViaStatus(
            ProductStatus.paused, ProductStatus.active),
        isTrue,
      );
    });

    test('allowlist: pause resume sold remove restore', () {
      expect(
        canOwnerTransition(ProductStatus.active, ProductStatus.paused),
        isTrue,
      );
      expect(
        canOwnerTransition(ProductStatus.paused, ProductStatus.active),
        isTrue,
      );
      expect(
        canOwnerTransition(ProductStatus.active, ProductStatus.sold),
        isTrue,
      );
      expect(
        canOwnerTransition(ProductStatus.sold, ProductStatus.active),
        isFalse,
      );
      expect(
        canOwnerTransition(ProductStatus.removed, ProductStatus.draft),
        isTrue,
      );
      expect(
        canOwnerTransition(ProductStatus.draft, ProductStatus.active),
        isFalse,
      );
      expect(
        canOwnerTransition(
            ProductStatus.pendingReview, ProductStatus.pendingReview),
        isFalse,
      );
    });

    test('content writable only draft', () {
      expect(contentWritableForStatus(ProductStatus.draft), isTrue);
      expect(contentWritableForStatus(ProductStatus.active), isFalse);
      expect(contentWritableForStatus(ProductStatus.paused), isFalse);
    });
  });

  group('Product model', () {
    test('toMap excludes moderation hide bits', () {
      final p = Product(
        id: 'x',
        ownerUid: 'u1',
        ownerName: 'Ali',
        title: 'Test ürün başlığı',
        description: 'Açıklama metni yeterince uzun olmalı',
        categoryCode: 'carpenter',
        photos: const ['https://example.com/a.jpg'],
        priceType: ProductPriceType.negotiable,
        condition: ProductCondition.handmade,
        province: 'Bursa',
        status: ProductStatus.draft,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        moderationHidden: true,
        hiddenByModeration: true,
      );
      final map = p.toMap();
      expect(map.containsKey('hiddenByModeration'), isFalse);
      expect(map.containsKey('featured'), isFalse);
      expect(map['moderationHidden'], isFalse); // create default only
      expect(map['titleFold'], isNotEmpty);
    });

    test('fromMap recompute-style hide flags', () {
      final p = Product.fromMap('id1', {
        'ownerUid': 'u',
        'ownerName': 'A',
        'title': 'T',
        'description': 'D',
        'categoryCode': 'plumber',
        'photos': <String>[],
        'priceType': 'fixed',
        'priceAmount': 100,
        'condition': 'used',
        'province': 'İstanbul',
        'status': 'active',
        'moderationHidden': true,
        'hiddenByModeration': true,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      expect(p.isLiveInDiscover, isFalse);
      expect(p.hiddenByModeration, isTrue);
    });

    test('fields complete helper', () {
      expect(
        productFieldsComplete(
          title: 'Ahşap raf',
          description: 'El yapımı ahşap raf, 80 cm',
          categoryCode: 'carpenter',
          photos: const ['https://x'],
          priceType: ProductPriceType.negotiable,
          priceAmount: null,
          province: 'Bursa',
          condition: ProductCondition.handmade,
        ),
        isTrue,
      );
      expect(
        productFieldsComplete(
          title: 'x',
          description: 'short',
          categoryCode: '',
          photos: const [],
          priceType: ProductPriceType.fixed,
          priceAmount: null,
          province: '',
          condition: ProductCondition.used,
        ),
        isFalse,
      );
    });

    test('canPublishProduct requires photo and jobs match', () {
      expect(
        canPublishProduct(
          canMatchJobs: true,
          photoOk: false,
          artisanExists: true,
          artisanModerationHidden: false,
          userSuspended: false,
          fieldsComplete: true,
        ),
        isFalse,
      );
      expect(
        canPublishProduct(
          canMatchJobs: true,
          photoOk: true,
          artisanExists: true,
          artisanModerationHidden: false,
          userSuspended: false,
          fieldsComplete: true,
        ),
        isTrue,
      );
    });
  });
}

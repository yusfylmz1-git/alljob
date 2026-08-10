import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/config/app_runtime_config.dart';
import 'package:sepette_hizmet/features/admin/data/admin_runtime_config_repository.dart';

/// Mağaza bayrakları — admin runtime config (2026-08-10).
///
/// `productsForceReview` CF'de okunuyordu ama admin UI / model alanları
/// yoktu; `productsEnabled` ise yalnız derleme sabitiydi. Bu testler
/// varsayılanları ve yaz-oku döngüsünü çiviler.
void main() {
  group('AppRuntimeConfig — Mağaza bayrakları', () {
    test('alan yoksa vitrin AÇIK, zorunlu inceleme KAPALI', () {
      final c = AppRuntimeConfig.fromMap(const {});
      expect(c.productsEnabled, isTrue);
      expect(c.productsForceReview, isFalse);
      expect(c.isProductsLive, isTrue);
    });

    test('productsEnabled: false vitrini kapatır', () {
      final c = AppRuntimeConfig.fromMap(const {
        'productsEnabled': false,
      });
      expect(c.productsEnabled, isFalse);
      expect(c.isProductsLive, isFalse);
    });

    test('productsForceReview: true zorunlu incelemeyi açar', () {
      final c = AppRuntimeConfig.fromMap(const {
        'productsForceReview': true,
      });
      expect(c.productsForceReview, isTrue);
      // İnceleme bayrağı vitrini KAPATMAZ.
      expect(c.isProductsLive, isTrue);
    });
  });

  group('AdminRuntimeConfig — Mağaza bayrakları', () {
    test('fromMap varsayılanları AppRuntime ile aynı semantik', () {
      final a = AdminRuntimeConfig.fromMap(const {});
      expect(a.productsEnabled, isTrue);
      expect(a.productsForceReview, isFalse);

      final b = AdminRuntimeConfig.fromMap(const {
        'productsEnabled': false,
        'productsForceReview': true,
      });
      expect(b.productsEnabled, isFalse);
      expect(b.productsForceReview, isTrue);
    });

    test('mock update products bayraklarını yazar', () async {
      final repo = MockAdminRuntimeConfigRepository();
      await repo.update({
        'productsEnabled': false,
        'productsForceReview': true,
      });
      final next = await repo.watchRuntime().first;
      expect(next.productsEnabled, isFalse);
      expect(next.productsForceReview, isTrue);
    });
  });
}

// Regresyon: Keşfet → Ürünler'de "Ürün paylaş" kısayolu (2026-08-23).
//
// Kapalı test geri bildirimi: "keşfet - mağaza - ürünler kısmına (mağaza
// varsa) Ürün paylaş butonu koymalıyız. Ürün paylaş bir tek profilde var,
// ulaşmak zor gibi geldi."
//
// Satıcı ürün eklemek için Keşfet'ten çıkıp Profil → Mağaza kartına inmek
// zorundaydı — kendi vitrinine bakarken ürün ekleyemiyordu.
//
// Çift test (kural 7): kısayol var MI + yanlış kişiye gösterilmiyor MU.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String panel;

  setUpAll(() {
    panel = File(
      'lib/features/products/presentation/widgets/products_explore_panel.dart',
    ).readAsStringSync();
  });

  group('Kısayol Keşfet > Ürünler başlığında', () {
    test('"Ürün paylaş" düğmesi var', () {
      expect(panel.contains("label: const Text('Ürün paylaş')"), isTrue,
          reason: 'Kısayol kaldırılmış — satıcı yine Profil → Mağaza '
              'yoluna mahkûm kalır.');
    });

    test('ürün ekleme rotasına gidiyor', () {
      expect(panel.contains('RoutePaths.productNew'), isTrue);
    });
  });

  group('Fazlasını yapmıyor — yalnız mağaza sahibine', () {
    test('düğme hasShopProfile kapısının ardında', () {
      // Mağazası olmayana "Ürün paylaş" göstermek onu kurulum ekranına
      // çarptırır; Keşfet başlığı da gereksiz kalabalıklaşır.
      expect(
          panel.contains(
              "ref.watch(currentUserProvider)?.hasShopProfile ?? false"),
          isTrue,
          reason: 'Kapı yok — düğme herkese görünüyor.');
    });

    test('boş vitrinde davet de role göre ayrışıyor', () {
      // Mağazası olana doğrudan eylem, olmayana yol tarifi.
      expect(panel.contains("retryLabel: 'Ürün paylaş'"), isTrue,
          reason: 'Boş vitrinde satıcıya doğrudan eylem verilmiyor.');
      expect(panel.contains('Profil → Mağaza’dan ürün ekleyin'), isTrue,
          reason: 'Mağazası olmayan için yol tarifi kaybolmuş.');
    });
  });
}

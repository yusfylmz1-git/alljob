import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/core/constants/app_constants.dart';
import 'package:sepette_hizmet/data/models/product.dart';
import 'package:sepette_hizmet/features/products/presentation/widgets/product_card.dart';

/// Ürün kartı TAŞMA (overflow) regresyonu — 2026-08-14 cihaz bulgusu:
/// Keşfet → Ürünler ızgarasında fotoğrafın altında sarı-siyah şerit.
///
/// SEBEP: görsel `AspectRatio` ile SABİT yer kaplıyor, metin bloğu ise
/// sınırsızdı; ikisinin toplamı ızgara hücresini aşınca taşıyordu.
/// Ayrıca `photoCardAspectRatio` 0.62 idi — 4:5 görsel + metin şeridi için
/// gereken paydan (≈0.60) dar.
///
/// Bu test KAYNAK TARAMASI DEĞİL: kartı gerçekten çizip taşma olup
/// olmadığını ölçer.
void main() {
  Product urun({required String baslik, bool oneCikan = false}) => Product(
        id: 'p1',
        ownerUid: 'u1',
        ownerName: 'Test Satıcı',
        title: baslik,
        description: 'açıklama',
        categoryCode: 'hirdavat',
        photos: const [],
        priceType: ProductPriceType.fixed,
        priceAmount: 1500,
        condition: ProductCondition.brandNew,
        province: 'İstanbul',
        district: 'Kadıköy',
        status: ProductStatus.active,
        createdAt: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
        featured: oneCikan,
      );

  /// Kartı gerçek ızgara ölçüsünde çizer.
  Future<void> ciz(
    WidgetTester tester, {
    required Product p,
    required double genislik,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: genislik,
                  // Izgara hücresinin yüksekliği: genişlik / oran.
                  height: genislik / AppConstants.photoCardAspectRatio,
                  child: ProductCard(product: p, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Ürün kartı hiçbir ölçüde taşmıyor', () {
    // Izgara `maxCrossAxisExtent` 200–220 kullanıyor; dar telefonda hücre
    // 160 px'e kadar iner.
    for (final g in [160.0, 190.0, 220.0]) {
      testWidgets('hücre ${g.toInt()}px', (tester) async {
        await ciz(tester, p: urun(baslik: 'Matkap ucu seti 12 parça'), genislik: g);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"ÖNE ÇIKAN" rozeti fazladan satır ekliyor', (tester) async {
      // Rozet bir satır daha ekler — taşmanın en olası hâli.
      await ciz(
        tester,
        p: urun(baslik: 'Profesyonel darbeli matkap seti', oneCikan: true),
        genislik: 160,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uzun başlık (2 satır + ellipsis)', (tester) async {
      await ciz(
        tester,
        p: urun(
          baslik: 'Çok uzun bir ürün başlığı buraya yazıldı ve iki satırı '
              'kesinlikle aşıyor böylece kırpılması gerekiyor',
          oneCikan: true,
        ),
        genislik: 160,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('büyük yazı tipi ölçeği (erişilebilirlik 1.3x)',
        (tester) async {
      // Kullanıcı sistem yazı boyutunu büyütünce metin şeridi uzar.
      await ciz(
        tester,
        p: urun(baslik: 'Matkap ucu seti', oneCikan: true),
        genislik: 160,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Oran sabiti güvenli payda', () {
    test('photoCardAspectRatio metin şeridine yer bırakıyor', () {
      // 4:5 görsel → yükseklik = genişlik * 1.25. Metin ~92 px.
      // Gereken oran = g / (g*1.25 + 92); 220 px'te ≈ 0.599.
      const g = 220.0;
      final gereken = g /
          (g *
                  (AppConstants.photoAspectHeight /
                      AppConstants.photoAspectWidth) +
              92);
      expect(AppConstants.photoCardAspectRatio, lessThan(gereken),
          reason: 'Oran çok dar — kart taşar (0.62 bu yüzden overflow verdi).');
    });
  });
}

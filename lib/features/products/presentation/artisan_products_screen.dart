import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/status_views.dart';
import '../data/product_providers.dart';
import 'widgets/product_card.dart';

/// Bir ustanın/satıcının herkese açık ürünlerini listeleyen ekran. Usta profil
/// sayfasındaki "Dükkan → Tümünü Gör" buradan açılır. Salt görüntüleme.
class ArtisanProductsScreen extends ConsumerWidget {
  const ArtisanProductsScreen({
    super.key,
    required this.uid,
    this.sellerName,
  });

  final String uid;

  /// Başlıkta gösterilecek satıcı adı (opsiyonel — yoksa genel başlık).
  final String? sellerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GİZLİLİK: `myProductsProvider` sahibin HER ürününü verir (taslak,
    // duraklatılmış, satılmış). Burası BAŞKASININ vitrini — yalnız
    // yayındakiler görünmeli. Aynı hata Dükkân bölümünde de vardı.
    final async = ref.watch(publicProductsProvider(uid));

    // Geri tuşu: yığın yoksa Ana Sayfa'ya (Mağaza Keşfet'in sekmesi).
    return MainTabScope(
      tab: MainTab.explore,
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          (sellerName != null && sellerName!.trim().isNotEmpty)
              ? '${sellerName!.trim()} · Ürünler'
              : 'Ürünler',
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
            message: 'Ürünler yüklenemedi. Bağlantınızı kontrol edip '
                'tekrar deneyin.'),
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('Bu satıcının yayında ürünü yok.'),
                  ],
                ),
              ),
            );
          }
          return ResponsiveCenter(
            maxWidth: 900,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Görsel 4:5 dikeye geçti (2026-08-14) → hücre de uzadı;
                // eski oranda kart içeriği taşıyordu.
                childAspectRatio: AppConstants.photoCardAspectRatio,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return ProductCard(
                  product: p,
                  onTap: () => context.push(RoutePaths.productDetail(p.id)),
                );
              },
            ),
          );
        },
        ),
      ),
    );
  }
}

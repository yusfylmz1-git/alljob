import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../data/models/product.dart';
import '../../data/product_providers.dart';

/// Profil ekranlarındaki "Dükkân" bölümü — bu kişinin satılık ürünleri.
///
/// İKİ profil ekranı da kullanır: usta profili (`artisan_profile_screen`) ve
/// genel kullanıcı profili (`public_user_screen`). Ortak dosyada durmasının
/// sebebi "herkes satabilir" kararı: satıcı olmak usta olmayı gerektirmiyor,
/// dolayısıyla dükkân yalnız usta profiline ait bir bölüm değil.
///
/// Yalnızca YAYINDAKİ ürünler gösterilir (`publicProductsProvider`); ürünü
/// olmayan kişide bölüm tamamen gizlenir — boş kart göstermez.
class DukkanBolumu extends ConsumerWidget {
  const DukkanBolumu({
    super.key,
    required this.saticiUid,
    required this.saticiAdi,
    required this.bolumKurucu,
  });

  final String saticiUid;
  final String saticiAdi;

  /// Ekranın kendi `_Section` sarmalayıcısı. İki profil ekranının kart
  /// görünümü aynı değil; bölümü kendi kabuğuyla sarsınlar diye dışarıdan
  /// alınır (widget'ı kopyalamak yerine).
  final Widget Function({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) bolumKurucu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin "Mağaza kapalı" ise profilde dükkân göstermeyiz (ölü link olmasın).
    if (!ref.watch(productsLiveProvider)) return const SizedBox.shrink();

    final urunler =
        ref.watch(publicProductsProvider(saticiUid)).valueOrNull ?? const [];
    if (urunler.isEmpty) return const SizedBox.shrink();

    final onizleme = urunler.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: bolumKurucu(
        icon: Icons.storefront_outlined,
        title: 'Dükkân (${urunler.length})',
        trailing: TextButton(
          onPressed: () => context.push(
            '${RoutePaths.artisanProducts(saticiUid)}'
            '?ad=${Uri.encodeComponent(saticiAdi)}',
          ),
          child: const Text('Tümünü Gör →'),
        ),
        child: SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: onizleme.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _DukkanKucukResim(urun: onizleme[i]),
          ),
        ),
      ),
    );
  }
}

/// Dükkân önizlemesindeki tek küçük ürün: kapak resmi + ad + fiyat.
class _DukkanKucukResim extends StatelessWidget {
  const _DukkanKucukResim({required this.urun});
  final Product urun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SizedBox(
      width: 104,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(RoutePaths.productDetail(urun.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 80,
                width: double.infinity,
                child: urun.coverPhoto != null
                    ? AppImage(
                        handle: urun.coverPhoto,
                        fit: BoxFit.cover,
                        memCacheWidth: 208,
                      )
                    : Container(
                        color: palette.surfaceMuted,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: palette.primary,
                          size: 24,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urun.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      urun.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

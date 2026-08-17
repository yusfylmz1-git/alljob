import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../data/models/product.dart';
import '../../data/product_category_providers.dart';

/// Keşfet / liste ürün kartı.
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final cat = catalogOf(ref).label(product.categoryCode);

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              // 4:5 dikey — KIRPMA ORANIYLA AYNI olmalı (PhotoPicker).
              // Eskiden 1.15 (yatay) idi: kullanıcı dikey fotoğraf yükleyince
              // `BoxFit.cover` altını/üstünü kesiyordu ("yarım çıkıyor").
              aspectRatio: AppConstants.photoAspectWidth /
                  AppConstants.photoAspectHeight,
              child: product.coverPhoto == null
                  ? ColoredBox(
                      color: palette.surfaceMuted,
                      child: Icon(Icons.inventory_2_outlined,
                          color: palette.inkMuted, size: 36),
                    )
                  : AppImage(
                      handle: product.coverPhoto,
                      fit: BoxFit.cover,
                    ),
            ),
            // TAŞMA KORUMASI (2026-08-14 cihaz bulgusu: fotoğrafın altında
            // sarı-siyah "overflow" şeridi).
            //
            // Görsel `AspectRatio` ile SABİT yer kaplıyor; metin bloğu ise
            // sınırsızdı. Izgara hücresi dar geldiğinde (küçük ekran, büyük
            // yazı tipi ölçeği veya "ÖNE ÇIKAN" rozetinin eklediği satır)
            // ikisinin toplamı hücreyi aşıyordu.
            //
            // `Flexible` + `MainAxisSize.min`: metin bloğu kalan alana
            // sığar, sığmazsa satırlar ellipsis'e düşer — taşma olmaz.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.featured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'ÖNE ÇIKAN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.priceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        '$cat · ${product.placeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

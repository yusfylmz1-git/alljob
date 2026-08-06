import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../../data/models/product.dart';

/// Keşfet / liste ürün kartı.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final cat =
        kProfessionNames[product.categoryCode] ?? product.categoryCode;

    return TapScale(
      scale: 0.98,
      child: Material(
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
              aspectRatio: 1.15,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.featured)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ÖNE ÇIKAN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cat · ${product.placeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.inkMuted,
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

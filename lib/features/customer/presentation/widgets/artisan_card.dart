import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../artisan/data/artisan_repository.dart';

/// Keşif ızgarasındaki usta kartı — kompakt kare / dikey tile.
/// Yan yana 2+ sütun (ekran genişliğine göre); avatar üstte, özet altta.
/// Favori kalbi kartta YOK (usta profil sayfasında).
class ArtisanCard extends StatelessWidget {
  const ArtisanCard({super.key, required this.artisan, required this.onTap});

  final ArtisanSummary artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;

    final rating = artisan.totalReviews == 0
        ? 'Yeni'
        : '★ ${artisan.averageRating.toStringAsFixed(1)}';

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: scheme.primary.withValues(alpha: 0.03),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.hairline),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: _RingedAvatar(artisan: artisan),
                  ),
                ),
                const SizedBox(height: 6),
                // Ad + rozetler
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        artisan.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (artisan.isVerified) ...[
                      const SizedBox(width: 2),
                      Tooltip(
                        message: artisan.verifiedBadgeTooltip,
                        child: Icon(Icons.verified,
                            size: 13, color: palette.verified),
                      ),
                    ],
                    if (artisan.isPremium) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.workspace_premium,
                          size: 13, color: palette.premium),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  artisan.professionNameTR,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                // Puan · deneyim
                Text(
                  [
                    rating,
                    if (artisan.experienceYears > 0)
                      '${artisan.experienceYears}y',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                _StatusChip(
                  isAvailable: artisan.isAvailable,
                  isNew: artisan.isNewArtisan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Müsaitlik halkalı yuvarlak avatar; fotoğraf yoksa gradyan + baş harfler.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.artisan});
  final ArtisanSummary artisan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Hücreye sığacak en büyük avatar (kare tile için).
        final side = (constraints.biggest.shortestSide).clamp(40.0, 72.0);
        final ring = side < 52 ? 2.0 : 2.5;
        final gap = side < 52 ? 1.5 : 2.0;
        final diameter = side - (ring + gap) * 2;

        return Container(
          width: side,
          height: side,
          padding: EdgeInsets.all(ring),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: artisan.isAvailable ? AppColors.availableRing : null,
            color: artisan.isAvailable ? null : scheme.outlineVariant,
          ),
          child: Container(
            padding: EdgeInsets.all(gap),
            decoration: BoxDecoration(
              color: context.palette.card,
              shape: BoxShape.circle,
            ),
            child: _AvatarContent(
              initials: _initials(artisan.displayName),
              photoUrl: artisan.profilePhotoUrl,
              diameter: diameter,
            ),
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return t.substring(0, 1).toUpperCase();
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.initials,
    required this.diameter,
    this.photoUrl,
  });

  final String initials;
  final double diameter;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fontSize = (diameter * 0.36).clamp(12.0, 22.0);
    final letter = Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) return letter;
    final cache = (diameter * 2).round().clamp(64, 160);
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: AppImage(
          handle: url,
          width: diameter,
          height: diameter,
          memCacheWidth: cache,
          memCacheHeight: cache,
          placeholder: letter,
        ),
      ),
    );
  }
}

/// Kompakt durum etiketi (kare kart altına sığar).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isAvailable, required this.isNew});
  final bool isAvailable;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    late final Color color;
    late final Color surface;
    late final String label;
    IconData? icon;
    var showDot = false;

    if (isNew) {
      color = palette.info;
      surface = palette.infoSurface;
      icon = Icons.auto_awesome_rounded;
      label = 'Yeni';
    } else if (isAvailable) {
      color = palette.success;
      surface = palette.successSurface;
      showDot = true;
      label = 'Müsait';
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      surface = theme.colorScheme.surfaceContainer;
      showDot = true;
      label = 'Kapalı';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

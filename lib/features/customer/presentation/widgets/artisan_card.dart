import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/premium_surface_card.dart';
import '../../../artisan/data/artisan_repository.dart';

/// Keşif ızgarasındaki usta kartı — kompakt dikey tile, premium cam hissi.
///
/// Not: Gerçek [BackdropFilter] kullanılmaz (yüzlerce kartta kaydırma bozulur);
/// yarı saydam dolgu + kenar + üst ışıltı ile “glass” illüzyonu verilir.
class ArtisanCard extends StatelessWidget {
  const ArtisanCard({super.key, required this.artisan, required this.onTap});

  final ArtisanSummary artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final isDark = theme.brightness == Brightness.dark;

    final rating = artisan.totalReviews == 0
        ? 'Yeni'
        : '★ ${artisan.averageRating.toStringAsFixed(1)}';

    // Müsait: yeşil kenar; aksi halde varsayılan cam kenar. "Pro" yazısı yok.
    final accent = artisan.isAvailable
        ? palette.success.withValues(alpha: isDark ? 0.28 : 0.18)
        : null;

    return PremiumSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      accentBorder: accent,
      accentWidth: artisan.isAvailable ? 1.15 : 1,
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _RingedAvatar(artisan: artisan),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                    height: 1.15,
                    color: palette.ink,
                  ),
                ),
              ),
              if (artisan.isVerified) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: artisan.verifiedBadgeTooltip,
                  child: Icon(Icons.verified,
                      size: 14, color: palette.verified),
                ),
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
              color: palette.inkMuted,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest
                  .withValues(alpha: isDark ? 0.35 : 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.hairline.withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              [
                rating,
                if (artisan.experienceYears > 0)
                  '${artisan.experienceYears}y',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkMuted,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _StatusChip(
            isAvailable: artisan.isAvailable,
            isNew: artisan.isNewArtisan,
          ),
        ],
      ),
    );
  }
}

/// Müsaitlik halkalı **büyük daire** avatar — foto neredeyse tüm alanı doldurur.
/// Üst: [AspectRatio] 1:1. Gölge dışarı taşmasın diye kart [clipBehavior] kullanır.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.artisan});
  final ArtisanSummary artisan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;

    // İnce halka → foto daha büyük; dış gölge yok (taşma).
    const ring = 2.5;
    const gap = 1.5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        if (side <= 0 || !side.isFinite) return const SizedBox.shrink();

        return SizedBox(
          width: side,
          height: side,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: artisan.isAvailable ? AppColors.availableRing : null,
              color: artisan.isAvailable ? null : scheme.outlineVariant,
            ),
            child: Padding(
              padding: const EdgeInsets.all(ring),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.card,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(gap),
                  // ClipOval + Stack.expand: foto çerçeveyi tam doldurur.
                  child: ClipOval(
                    child: _AvatarFill(
                      initials: _initials(artisan.displayName),
                      photoUrl: artisan.profilePhotoUrl,
                    ),
                  ),
                ),
              ),
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

/// Parent ClipOval içinde tüm alanı kaplar (BoxFit.cover).
class _AvatarFill extends StatelessWidget {
  const _AvatarFill({required this.initials, this.photoUrl});

  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final letter = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );

    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) {
      return SizedBox.expand(child: letter);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    // ~96 logical * dpr — keskin ama aşırı decode yok.
    final cache = (96 * dpr).round().clamp(96, 256);

    return SizedBox.expand(
      child: AppImage(
        handle: url,
        fit: BoxFit.cover,
        memCacheWidth: cache,
        memCacheHeight: cache,
        placeholder: letter,
      ),
    );
  }
}

/// Cam hissi durum etiketi.
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ],
              ),
            )
          else if (icon != null)
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              height: 1.1,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

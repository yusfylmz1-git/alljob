import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../artisan/data/artisan_repository.dart';

/// Keşif ızgarasındaki usta kartı — KOMPAKT tek blok (liste kalabalıklaşınca
/// ekrana daha çok usta sığsın): solda müsaitlik halkalı avatar, ortada
/// ad+rozetler ve "meslek · ★puan · deneyim" özet satırı, sağda durum pill'i.
/// Favori kalbi kartta YOK (usta profil sayfasında duruyor).
class ArtisanCard extends StatelessWidget {
  const ArtisanCard({super.key, required this.artisan, required this.onTap});

  final ArtisanSummary artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Özet satırı: meslek · ★4.8 (12) · 15 yıl — tek satırda her şey.
    final rating = artisan.totalReviews == 0
        ? 'Yeni'
        : '★ ${artisan.averageRating.toStringAsFixed(1)} '
            '(${artisan.totalReviews})';
    final summary = [
      artisan.professionNameTR,
      rating,
      if (artisan.experienceYears > 0) '${artisan.experienceYears} yıl',
    ].join(' · ');

    final palette = context.palette;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: scheme.primary.withValues(alpha: 0.03),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _RingedAvatar(artisan: artisan),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artisan.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (artisan.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 15, color: palette.verified),
                          ],
                          if (artisan.isPremium) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.workspace_premium,
                                size: 15, color: palette.premium),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
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

/// Müsaitlik halkalı yuvarlak avatar; fotoğraf yoksa marka gradyanı üzerinde
/// baş harfler.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.artisan});
  final ArtisanSummary artisan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: artisan.isAvailable ? AppColors.availableRing : null,
        color: artisan.isAvailable ? null : scheme.outlineVariant,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: context.palette.card,
          shape: BoxShape.circle,
        ),
        child: _AvatarContent(
          initials: _initials(artisan.displayName),
          photoUrl: artisan.profilePhotoUrl,
        ),
      ),
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
  const _AvatarContent({required this.initials, this.photoUrl});

  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const double diameter = 44; // kompakt kart için küçültüldü (eski 54)
    if (photoUrl != null) {
      return CircleAvatar(
        radius: diameter / 2,
        backgroundColor: context.palette.surfaceMuted,
        foregroundImage: NetworkImage(photoUrl!),
      );
    }
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// "Müsait" / "Kapalı" (ve varsa "Yeni") durum etiketi.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isAvailable, required this.isNew});
  final bool isAvailable;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    if (isNew) {
      return _pill(
        theme,
        color: palette.info,
        surface: palette.infoSurface,
        icon: Icons.auto_awesome_rounded,
        label: 'Yeni',
      );
    }
    if (isAvailable) {
      return _pill(
        theme,
        color: palette.success,
        surface: palette.successSurface,
        dot: true,
        label: 'Müsait',
      );
    }
    return _pill(
      theme,
      color: theme.colorScheme.onSurfaceVariant,
      surface: theme.colorScheme.surfaceContainer,
      dot: true,
      label: 'Kapalı',
    );
  }

  Widget _pill(
    ThemeData theme, {
    required Color color,
    required Color surface,
    IconData? icon,
    bool dot = false,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

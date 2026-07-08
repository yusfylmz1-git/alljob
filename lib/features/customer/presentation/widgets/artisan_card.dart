import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../artisan/data/artisan_repository.dart';

/// Keşif ızgarasındaki usta kartı — nefes alan, yumuşak gölgeli beyaz kart:
/// solda müsaitlik halkalı avatar, ad/meslek üstte + müsait pill sağda,
/// ince ayraç ve altında puan satırı. Favori kalbi kartta YOK
/// (usta profil sayfasında duruyor).
class ArtisanCard extends StatelessWidget {
  const ArtisanCard({super.key, required this.artisan, required this.onTap});

  final ArtisanSummary artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: scheme.primary.withValues(alpha: 0.03),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.hairline),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RingedAvatar(artisan: artisan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  artisan.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (artisan.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    size: 16, color: AppColors.verified),
                              ],
                              if (artisan.isPremium) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.workspace_premium,
                                    size: 16, color: AppColors.premium),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artisan.professionNameTR,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusPill(
                      isAvailable: artisan.isAvailable,
                      isNew: artisan.isNewArtisan,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.hairline),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 17, color: AppColors.star),
                    const SizedBox(width: 4),
                    Text(
                      artisan.totalReviews == 0
                          ? 'Yeni'
                          : artisan.averageRating.toStringAsFixed(1),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (artisan.totalReviews > 0) ...[
                      const SizedBox(width: 6),
                      _dot(scheme),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${artisan.totalReviews} değerlendirme',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                    if (artisan.experienceYears > 0) ...[
                      const SizedBox(width: 6),
                      _dot(scheme),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${artisan.experienceYears} yıl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: scheme.outline),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _dot(ColorScheme scheme) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: scheme.outline,
          shape: BoxShape.circle,
        ),
      );
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
          color: scheme.surface,
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
    const double diameter = 54;
    if (photoUrl != null) {
      return CircleAvatar(
        radius: diameter / 2,
        backgroundColor: AppColors.surfaceMuted,
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
    if (isNew) {
      return _pill(
        theme,
        color: AppColors.info,
        surface: AppColors.infoSurface,
        icon: Icons.auto_awesome_rounded,
        label: 'Yeni',
      );
    }
    if (isAvailable) {
      return _pill(
        theme,
        color: AppColors.success,
        surface: AppColors.successSurface,
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

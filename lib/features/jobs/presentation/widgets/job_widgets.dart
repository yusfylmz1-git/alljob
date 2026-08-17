import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/premium_surface_card.dart';
import '../../../../data/models/job.dart';

/// Meslek/kategori koduna göre ilan kartında gösterilecek emoji.
String jobCategoryEmoji(String category) {
  switch (category) {
    case 'painter':
      return '🎨';
    case 'plumber':
      return '🚿';
    case 'electrician':
      return '⚡';
    case 'carpenter':
      return '🪚';
    case 'tiler':
      return '🧱';
    case 'welder':
      return '🔩';
    case 'ac_technician':
      return '❄️';
    case 'locksmith':
      return '🔑';
    case 'white_goods':
      return '🧺';
    case 'mover':
      return '📦';
    case 'gardener':
      return '🌿';
    case 'cleaner':
      return '🧽';
    case 'quick_support':
      return '⚡';
    case 'product_request':
      return '🛒';
    default:
      return '🔧';
  }
}

/// İlan durumunu renkli bir çip olarak gösterir (süre dolumu dahil).
/// Metin: [JobStatus.simpleLabelTR] — 3 evreli sade dil.
class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color fg, Color bg) = switch (status) {
      JobStatus.open => (palette.info, palette.infoSurface),
      JobStatus.cancelled || JobStatus.expired => (
          palette.inkMuted,
          palette.surfaceMuted,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.simpleLabelTR,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// İlan akış kartı — usta feed'i ve Keşfet "İlanlar" (usta modu) paneli.
/// KOMPAKT düzen: emoji rozeti + başlık + 1 satır açıklama +
/// "📍 ilçe · zaman · N ilgilendi" meta. Kartın tamamı tıklanabilir.
/// [ctaText] geriye dönük uyum için duruyor (görsel olarak kullanılmıyor).
class NearbyJobCard extends StatelessWidget {
  const NearbyJobCard({
    super.key,
    required this.job,
    this.ctaText = 'İletişime Geç',
    this.isNearby = false,
  });

  final Job job;
  final String ctaText;

  /// İlan ustanın KENDİ ilçesinde mi? Hemen Lazım ilanları il geneline
  /// gittiğinden, aynı ilçedekiler "Yakınında" rozetiyle ayrışır. Yalnız
  /// usta feed'inde anlamlıdır (bkz. Job.isNearbyForAreas).
  final bool isNearby;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final ago = _timeAgo(job.createdAt);

    return PremiumSurfaceCard(
      onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 16,
      glass: false, // iş ilanı listeleri: düz kart, gradyan yok
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlanı VEREN kişi kartın başında durur ve profiline gider.
          // Kategori emojisi avatarın köşesine rozet olarak iner — bilgi
          // kaybolmaz, ama kartın kimliği "kim veriyor" olur.
          //
          // Kartın kendi `onTap`'i ilan detayına gider; avatar onu
          // GÖLGELEMELİ, yoksa profile gitme imkânı olmaz.
          Semantics(
            button: true,
            label: '${job.customerName} profiline git',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push(RoutePaths.userProfile(job.customerId)),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: AppAvatar(
                        name: job.customerName,
                        photo: job.customerPhotoUrl,
                        size: 44,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: palette.card,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          jobCategoryEmoji(job.category),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(job.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isNearby) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Yakınında',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(job.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.inkMuted)),
                const SizedBox(height: 4),
                Text(
                  '📍 ${job.district} · $ago',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(Icons.chevron_right,
                size: 20, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return DateFormat('d MMM', 'tr_TR').format(t);
  }
}

/// "N usta ilgilendi" rozeti (müşteri İlanlarım).
class OfferCountBadge extends StatelessWidget {
  const OfferCountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? palette.primaryContainer : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined,
              size: 14,
              color:
                  count > 0 ? palette.onPrimaryContainer : palette.inkMuted),
          const SizedBox(width: 4),
          Text(
            count > 0 ? '$count usta ilgilendi' : 'Henüz ilgilenen yok',
            style: TextStyle(
              color:
                  count > 0 ? palette.onPrimaryContainer : palette.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

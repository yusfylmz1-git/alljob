import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
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
    default:
      return '🔧';
  }
}

/// İlan durumunu renkli bir çip olarak gösterir (süre dolumu dahil).
class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      JobStatus.open => (AppColors.info, AppColors.infoSurface),
      JobStatus.workerSelected => (AppColors.premium, AppColors.premiumSurface),
      JobStatus.inProgress => (AppColors.warning, AppColors.warningSurface),
      JobStatus.completed => (AppColors.success, AppColors.successSurface),
      JobStatus.rated => (AppColors.success, AppColors.successSurface),
      JobStatus.cancelled => (AppColors.inkMuted, AppColors.surfaceMuted),
      JobStatus.expired => (AppColors.inkMuted, AppColors.surfaceMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.labelTR,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// 🚨 Acil rozeti.
class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'ACİL',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// İlan akış kartı — usta feed'i ve Keşfet "İş İlanları" panelinde ortak.
/// KOMPAKT düzen (liste kalabalıklaşınca ekrana çok ilan sığsın): emoji rozeti
/// + başlık/acil + tek satır açıklama + "📍 ilçe · zaman · N ilgilendi" meta
/// satırı. Kartın tamamı tıklanabilir; ayrı CTA satırı kaldırıldı.
/// Acil ilan kırmızı vurgulanır (#urgent). [ctaText] geriye dönük uyum için
/// duruyor (artık görsel olarak kullanılmıyor).
class NearbyJobCard extends StatelessWidget {
  const NearbyJobCard({
    super.key,
    required this.job,
    this.ctaText = 'İletişime Geç',
  });

  final Job job;
  final String ctaText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ago = _timeAgo(job.createdAt);
    final offers = job.offerCount > 0 ? ' · ${job.offerCount} ilgilendi' : '';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: job.isUrgent ? AppColors.danger : AppColors.hairline,
                width: job.isUrgent ? 1.4 : 1),
            boxShadow: AppTheme.softShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meslek emojisi rozeti.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(jobCategoryEmoji(job.category),
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(job.title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (job.isUrgent) ...[
                          const SizedBox(width: 6),
                          const UrgentBadge(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(job.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      '📍 ${job.district} · $ago$offers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right,
                    size: 20, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.primaryContainer : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined,
              size: 14,
              color: count > 0 ? AppColors.onPrimaryContainer : AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(
            count > 0 ? '$count usta ilgilendi' : 'Henüz ilgilenen yok',
            style: TextStyle(
              color: count > 0 ? AppColors.onPrimaryContainer : AppColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

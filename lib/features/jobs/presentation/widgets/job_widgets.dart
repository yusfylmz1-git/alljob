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
/// Acil ilan kırmızı vurgulanır (#urgent). [ctaText] bağlama göre değişir
/// (usta: "İletişime Geç", keşfet: "Detayı Gör").
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
    final ago = _timeAgo(job.createdAt);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: job.isUrgent ? AppColors.danger : AppColors.hairline,
                width: job.isUrgent ? 1.4 : 1),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meslek emojisi rozeti.
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(jobCategoryEmoji(job.category),
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(job.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (job.isUrgent) ...[
                              const SizedBox(width: 8),
                              const UrgentBadge(compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '📍 ${job.district} · $ago',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  OfferCountBadge(count: job.offerCount),
                  const Spacer(),
                  Text(ctaText,
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
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

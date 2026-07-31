import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart';
import '../../../jobs/data/job_providers.dart';

/// Ana sayfa "⚡ Hemen Lazım" şeridi — market, taşıma, kısa gidiş gibi kısa
/// işler için açılmış ilanların yatay vitrini.
///
/// Kart: ilan başlığı + ilan sahibinin profil fotoğrafı + ilçe/zaman
/// (öne çıkan usta kartlarıyla aynı dil). Başlıkta "Tümünü Gör →".
///
/// Hemen Lazım ilanı yoksa bölüm TAMAMEN gizlenir — ana sayfada boş bir
/// başlık bırakmaz.
class HomeQuickSupport extends ConsumerWidget {
  const HomeQuickSupport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(quickSupportJobsProvider);
    if (jobs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: palette.warning, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                kQuickSupportName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(RoutePaths.quickSupportJobs),
              child: const Text('Tümünü Gör →'),
            ),
          ],
        ),
        Text(
          'Market, taşıma, kısa gidiş gibi hemen yapılması gereken işler',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 158,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: jobs.length > 8 ? 8 : jobs.length,
            itemBuilder: (context, i) => _QuickSupportCard(job: jobs[i]),
          ),
        ),
      ],
    );
  }
}

/// Tek Hemen Lazım ilanı kartı: sahibinin fotoğrafı + adı + ilan başlığı.
class _QuickSupportCard extends StatelessWidget {
  const _QuickSupportCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    // İlan sahibinin adı boş gelebilir (eski kayıt / silinmiş profil) —
    // kartta boşluk bırakmamak için nötr bir karşılık kullanılır.
    final ad = job.customerName.trim();
    final gorunenAd = ad.isEmpty ? 'Komşunuz' : ad;

    return TapScale(
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CustomerAvatar(handle: job.customerPhotoUrl),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gorunenAd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              job.district.trim().isEmpty
                                  ? job.province
                                  : job.district,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 14, color: palette.warning),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          kQuickSupportName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İlan sahibinin küçük yuvarlak profil fotoğrafı; yoksa nötr kişi ikonu.
class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.handle});

  final String? handle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const size = 34.0;
    if (handle == null || handle!.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_rounded, size: 20, color: palette.primary),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AppImage(
          handle: handle,
          fit: BoxFit.cover,
          memCacheWidth: 96,
        ),
      ),
    );
  }
}

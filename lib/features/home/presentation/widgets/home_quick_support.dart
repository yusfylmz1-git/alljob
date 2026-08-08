import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/job_thumb.dart';
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
        const SizedBox(height: 8),
        SizedBox(
          // Son İş İlanları şeridiyle AYNI yükseklik — iki ilan bölümü
          // birbirinin devamı gibi okunsun.
          height: 92,
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

/// Tek Hemen Lazım ilanı kartı — DAR (2026-08-08).
///
/// Solda görsel: ilanda fotoğraf varsa küçük hâli, yoksa kategori ikonu
/// ([JobThumb]). Sağda başlık + ilçe. "Son İş İlanları" kartıyla aynı
/// düzendir; ayırt edici işaret sol üstteki turuncu ⚡ rozetidir.
///
/// Eskiden kart 158px yüksekti ve sahibinin profil fotoğrafını gösteriyordu.
/// İlanın KENDİ görseli daha bilgilendirici; sahibin adı ilan detayında zaten
/// var, vitrin satırında yer kaplıyordu.
class _QuickSupportCard extends StatelessWidget {
  const _QuickSupportCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final yer = job.district.trim().isEmpty ? job.province : job.district;

    return TapScale(
      child: Container(
        width: 236,
        margin: const EdgeInsets.only(right: 10),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      JobThumb(
                        photos: job.photos,
                        category: job.category,
                        size: 60,
                      ),
                      // Acil işareti: kart düzeni "Son İş İlanları" ile aynı
                      // olduğu için ayrım bu rozetten okunur.
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: palette.warning,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (yer.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 13, color: palette.inkMuted),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  yer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: palette.inkMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

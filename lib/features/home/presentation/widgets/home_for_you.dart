import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/job_thumb.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../jobs/data/job_providers.dart';
import '../../../products/data/product_providers.dart';

/// Ana sayfanın **role duyarlı** bölümü — "Sana Özel".
///
/// Ana sayfanın geri kalanı müşteri gözüyle kuruludur (usta bul, ilan ver,
/// talep oluştur). Uygulamada dört durum vardır ve üçü bu düzende kendine
/// iş getiren hiçbir şey görmüyordu:
///
/// | Durum | Bu bölümde ne görür |
/// |---|---|
/// | Müşteri | (bölüm gizlenir — ana sayfa zaten müşteriye göre) |
/// | Müşteri + usta | İlindeki, mesleğine uyan açık ilanlar |
/// | Müşteri + mağaza | İlindeki açık ürün talepleri |
/// | Müşteri + usta + mağaza | İkisi de, ilanlar üstte |
///
/// 2026-08-20 kullanıcı bulgusu: usta ana sayfayı açtığında yalnız "İş İlanı
/// Ver" ve "usta bul" görüyordu; kendi işini bulmak için Keşfet'e geçip sekme
/// değiştirmesi gerekiyordu. Ana sayfa onlar için ölü alandı.
///
/// Veri kaynakları YENİDEN SORGULAMAZ: ilanlar [nearbyJobsProvider]
/// (il + meslek + kendi ilanın hariç), talepler [productRequestsProvider]
/// üzerinden gelir — ikisi de zaten ana sayfada dinlenen akışlardan türer.
class HomeForYou extends ConsumerWidget {
  const HomeForYou({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final ustaMi = user.hasArtisanProfile;
    final magazaVar = user.hasShopProfile;
    if (!ustaMi && !magazaVar) return const SizedBox.shrink();

    // Ustaya uygun ilanlar: il + meslek eşleşmesi zaten provider'da.
    final ilanlar = ustaMi
        ? (ref.watch(nearbyJobsProvider).valueOrNull ?? const <Job>[])
        : const <Job>[];

    // Talepler yalnız mağaza modülü açıkken anlamlı.
    final talepler = magazaVar && ref.watch(productsLiveProvider)
        ? ref.watch(productRequestsProvider)
        : const <Job>[];

    final bolumler = <Widget>[
      if (ilanlar.isNotEmpty)
        _ForYouStrip(
          title: 'Sana Uygun İlanlar',
          subtitle: 'İlindeki, mesleğine uyan açık ilanlar',
          icon: Icons.campaign_rounded,
          onSeeAll: () => context.push(RoutePaths.nearbyJobs),
          jobs: ilanlar,
        ),
      if (talepler.isNotEmpty)
        _ForYouStrip(
          title: 'İlindeki Talepler',
          subtitle: 'Satabileceğin ürünleri arayanlar',
          icon: Icons.shopping_bag_rounded,
          onSeeAll: () => context.go(RoutePaths.exploreTab('shop')),
          jobs: talepler,
        ),
    ];

    if (bolumler.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bolumler.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          bolumler[i],
        ],
        // Alt boşluk BÖLÜMÜN İÇİNDE: ana sayfa gizli bölüm için boşluk
        // ayırmasın (gizliyken çift boşluk görünürdü).
        const SizedBox(height: 22),
      ],
    );
  }
}

/// Başlık + "Tümünü Gör →" + yatay ilan/talep şeridi.
class _ForYouStrip extends StatelessWidget {
  const _ForYouStrip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSeeAll,
    required this.jobs,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSeeAll;
  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.primary, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('Tümünü Gör →')),
          ],
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          // "Son İş İlanları" ve "Hemen Lazım" şeritleriyle AYNI yükseklik —
          // ana sayfadaki ilan bölümleri birbirinin devamı gibi okunmalı.
          height: 92,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: jobs.length > 8 ? 8 : jobs.length,
            itemBuilder: (context, i) => _ForYouCard(job: jobs[i]),
          ),
        ),
      ],
    );
  }
}

/// Tek ilan/talep kartı — ana sayfadaki diğer ilan kartlarıyla aynı düzen.
class _ForYouCard extends StatelessWidget {
  const _ForYouCard({required this.job});

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
                border: Border.all(color: palette.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JobThumb(
                    photos: job.photos,
                    category: job.category,
                    size: 60,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 4),
                        Text(
                          yer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: palette.inkMuted),
                        ),
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

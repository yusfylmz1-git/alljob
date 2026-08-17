import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_runtime_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/job_thumb.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart';
import '../../../../data/models/product.dart';
import '../../../artisan/data/artisan_providers.dart';
import '../../../artisan/data/artisan_repository.dart';
import '../../../jobs/data/job_providers.dart';
import '../../../products/data/product_category_providers.dart';
import '../../../products/data/product_providers.dart';

/// Öne çıkan ustalar (algoritmik — şimdilik: müsait + puana göre ilk sonuçlar).
/// Boş filtreyle repo'dan çeker; hata/boşsa boş liste → bölüm gizlenir.
///
/// NOT: Salt "en yüksek puan" değil, "Öne Çıkan" yaklaşımıdır (PRD). İleride
/// premium, aktivite, profil doluluğu gibi kriterler eklenebilir; şu an mevcut
/// sıralama (müsait ustalar puana göre) makul bir vekil.
final oneChikanUstalarProvider =
    FutureProvider<List<ArtisanSummary>>((ref) async {
  try {
    // Premium kapısı aramayla AYNI olmalı (madde 7): ücretsiz dönem
    // kapandığında burada da premium olmayan usta öne çıkmamalı.
    final freeBeta = ref.watch(appRuntimeConfigProvider).valueOrNull
            ?.premiumFreeDuringBeta ??
        AppConstants.premiumFreeDuringBeta;
    final page = await ref.read(artisanRepositoryProvider).searchArtisans(
          filter: const ArtisanFilter(),
          offset: 0,
          limit: 6,
          premiumFreeDuringBeta: freeBeta,
        );
    return page.items;
  } catch (_) {
    return const [];
  }
});

/// Ana Sayfa "Öne Çıkanlar" — üç ayrı vitrin bölümü: Öne Çıkan Ustalar,
/// Popüler Ürünler, Son İş İlanları. Her bölüm bağımsız beslenir; verisi
/// yoksa o bölüm tamamen gizlenir. Her bölümün başında "Tümünü Gör →"
/// bağlantısı ilgili Keşfet sekmesine götürür (tür bazında ayrık liste).
class HomeFeatured extends ConsumerWidget {
  const HomeFeatured({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ustalar = ref.watch(oneChikanUstalarProvider).valueOrNull ?? const [];
    final isler = ref.watch(openJobsProvider).valueOrNull ?? const [];
    final urunler = ref.watch(productsLiveProvider)
        ? (ref.watch(discoverProductsProvider).valueOrNull ?? const <Product>[])
        : const <Product>[];

    final sections = <Widget>[
      if (ustalar.isNotEmpty)
        _FeaturedSection(
          title: 'Öne Çıkan Ustalar',
          exploreTab: 'artisans',
          tall: true, // fotoğraflı usta kartları daha uzundur
          children: [
            for (final u in ustalar.take(6)) _UstaKart(usta: u),
          ],
        ),
      if (urunler.isNotEmpty)
        _FeaturedSection(
          title: 'Son Paylaşılan Ürünler',
          exploreTab: 'shop',
          tall: true,
          children: [
            for (final p in urunler.take(6)) _UrunKart(urun: p),
          ],
        ),
      if (isler.isNotEmpty)
        _FeaturedSection(
          title: 'Son İş İlanları',
          exploreTab: 'jobs',
          children: [
            for (final j in isler.take(6)) _IsKart(is_: j),
          ],
        ),
    ];

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          sections[i],
        ],
      ],
    );
  }
}

/// Başlık + "Tümünü Gör →" + yatay kart şeridi taşıyan tek vitrin bölümü.
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({
    required this.title,
    required this.exploreTab,
    required this.children,
    this.tall = false,
  });

  final String title;
  final String exploreTab;
  final List<Widget> children;

  /// Fotoğraflı (tam boy) kartlar için şeridi yükseltir.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.go(RoutePaths.exploreTab(exploreTab)),
              child: const Text('Tümünü Gör →'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          // tall: fotoğraflı usta kartı · kısa: dar ilan satırı (JobThumb).
          height: tall ? 288 : 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Öne çıkan usta kartı — tam boy fotoğraf + üstte durum rozeti (MÜSAİT /
/// PREMIUM / YENİ), fotoğraf altında ad + puan + meslek + değerlendirme
/// etiketleri. Fotoğraf yoksa marka renginde ikon zemini gösterilir.
class _UstaKart extends StatelessWidget {
  const _UstaKart({required this.usta});
  final ArtisanSummary usta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    // Tek durum rozeti (öncelik: müsait > premium > yeni). Yoksa gösterilmez.
    final (String, Color)? rozet = usta.isAvailable
        ? ('MÜSAİT', palette.success)
        : usta.isPremium
            ? ('PREMIUM', palette.premium)
            : usta.isNewArtisan
                ? ('YENİ', palette.info)
                : null;

    return TapScale(
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 12),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RoutePaths.artisanProfile(usta.uid)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tam boy fotoğraf + durum rozeti ──
                Stack(
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: usta.profilePhotoUrl != null
                          ? AppImage(
                              handle: usta.profilePhotoUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                            )
                          : Container(
                              color: palette.primary.withValues(alpha: 0.12),
                              alignment: Alignment.center,
                              child: Icon(Icons.person_rounded,
                                  size: 52, color: palette.primary),
                            ),
                    ),
                    if (rozet != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _DurumRozet(text: rozet.$1, color: rozet.$2),
                      ),
                  ],
                ),
                // ── Alt metin bloğu ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              usta.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (usta.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified_rounded,
                                size: 15, color: palette.info),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (usta.totalReviews > 0)
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 15, color: palette.star),
                            const SizedBox(width: 2),
                            Text(
                              usta.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              ' (${usta.totalReviews})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      Text(
                        usta.professionNameTR,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      // Birincil hizmet bölgesi ("İl / İlçe") — varsa göster.
                      if (usta.areaLabel != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                usta.areaLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Değerlendirme etiketleri — en sık 2, tek satır.
                      if (usta.topTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final t in usta.topTags.take(2)) ...[
                              Flexible(child: _EtiketRozet(t)),
                              const SizedBox(width: 4),
                            ],
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
    );
  }
}

/// Fotoğraf üstündeki dolgu durum rozeti ("MÜSAİT" vb.) — okunurluk için
/// renkli zemin + beyaz metin.
class _DurumRozet extends StatelessWidget {
  const _DurumRozet({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

/// Usta kartındaki küçük değerlendirme etiketi rozeti ("Temiz işçilik" vb.).
class _EtiketRozet extends StatelessWidget {
  const _EtiketRozet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.success,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
      ),
    );
  }
}

/// Son paylaşılan ürün — usta kartıyla aynı boy: fotoğraf + ad + fiyat.
class _UrunKart extends ConsumerWidget {
  const _UrunKart({required this.urun});
  final Product urun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final cat = catalogOf(ref).label(urun.categoryCode);

    return TapScale(
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 12),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RoutePaths.productDetail(urun.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: urun.coverPhoto != null
                      ? AppImage(
                          handle: urun.coverPhoto,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                        )
                      : Container(
                          color: palette.primary.withValues(alpha: 0.10),
                          alignment: Alignment.center,
                          child: Icon(Icons.inventory_2_outlined,
                              size: 44, color: palette.primary),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urun.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        urun.priceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (urun.placeLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                urun.placeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
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
    );
  }
}

/// Son iş ilanı kartı — DAR (2026-08-08).
///
/// Solda görsel: ilanda fotoğraf varsa küçük hâli, yoksa meslek ikonu +
/// rengi ([JobThumb]). Sağda başlık + ilçe. Eskiden kart 204px yüksekti ve
/// görselsizdi; şeridi 112px'e indirmek ana sayfada bir bölüm daha
/// görünmesini sağlıyor.
class _IsKart extends StatelessWidget {
  const _IsKart({required this.is_});
  final Job is_;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final yer = is_.district.trim().isEmpty ? is_.province : is_.district;

    return TapScale(
      child: Container(
        width: 236,
        margin: const EdgeInsets.only(right: 10),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RoutePaths.jobDetail(is_.jobId)),
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
                    photos: is_.photos,
                    category: is_.category,
                    size: 60,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          is_.title,
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

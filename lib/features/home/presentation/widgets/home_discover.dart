import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_runtime_config.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../products/data/product_providers.dart';
import 'home_featured.dart' show oneChikanUstalarProvider;

/// Ana Sayfa "🔥 Bugün Sepette Hizmet'te" — platformun canlı vitrini. Yatay kayan
/// büyük keşif kartları: en çok görüntülenen ürün, haftanın ustası (en yüksek
/// puanlı) ve son sistem duyurusu. Her kart bağımsız beslenir; verisi yoksa o
/// kart atlanır, hiçbiri yoksa başlık dâhil tüm bölüm gizlenir.
class HomeDiscover extends ConsumerWidget {
  const HomeDiscover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final urunler = ref.watch(discoverProductsProvider).valueOrNull ?? const [];
    final ustalar = ref.watch(oneChikanUstalarProvider).valueOrNull ?? const [];
    final cfg = ref.watch(appRuntimeConfigProvider).valueOrNull;

    // En çok görüntülenen ürün (varsa) ve en yüksek puanlı usta (varsa).
    final enCokUrun = urunler.isEmpty
        ? null
        : (urunler.toList()
              ..sort((a, b) => b.viewCount.compareTo(a.viewCount)))
            .first;
    final haftaninUstasi = ustalar.isEmpty
        ? null
        : (ustalar.toList()
              ..sort((a, b) => b.averageRating.compareTo(a.averageRating)))
            .first;

    final kartlar = <Widget>[
      if (enCokUrun != null)
        _DiscoverCard(
          etiket: 'En Çok Görüntülenen Ürün',
          icon: Icons.local_fire_department_rounded,
          accent: const Color(0xFFEA580C),
          baslik: enCokUrun.title,
          altBilgi: enCokUrun.viewCount > 0
              ? '👁 ${enCokUrun.viewCount} görüntülenme'
              : enCokUrun.priceLabel,
          photo: enCokUrun.coverPhoto, // gerçek ürün kapağı (varsa)
          onTap: () => context.push(RoutePaths.productDetail(enCokUrun.id)),
        ),
      if (haftaninUstasi != null)
        _DiscoverCard(
          etiket: 'Haftanın Ustası',
          icon: Icons.workspace_premium_rounded,
          accent: const Color(0xFF2563EB),
          baslik: haftaninUstasi.displayName,
          altBilgi: haftaninUstasi.totalReviews > 0
              ? '⭐ ${haftaninUstasi.averageRating.toStringAsFixed(1)} · '
                  '${haftaninUstasi.professionNameTR}'
              : haftaninUstasi.professionNameTR,
          photo: haftaninUstasi.profilePhotoUrl, // gerçek usta fotoğrafı (varsa)
          onTap: () =>
              context.push(RoutePaths.artisanProfile(haftaninUstasi.uid)),
        ),
      if (cfg != null && cfg.hasAnnouncement)
        _DiscoverCard(
          etiket: 'Son Duyuru',
          icon: Icons.campaign_rounded,
          accent: palette.info,
          baslik: (cfg.announcementTitle ?? 'Sepette Hizmet Duyurusu').trim(),
          altBilgi: (cfg.announcementBody ?? '').trim(),
          photo: null,
          onTap: null,
        ),
    ];

    if (kartlar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🔥 ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text(
                'Bugün Sepette Hizmet\'da',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: kartlar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => kartlar[i],
          ),
        ),
      ],
    );
  }
}

/// Fotoğraf öncelikli keşif kartı: üstte gerçek kapak görseli (yoksa renkli
/// gradient + ikon), görsel üstünde renkli etiket rozeti; altında başlık +
/// alt bilgi.
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({
    required this.etiket,
    required this.icon,
    required this.accent,
    required this.baslik,
    required this.altBilgi,
    required this.photo,
    required this.onTap,
  });

  final String etiket;
  final IconData icon;
  final Color accent;
  final String baslik;
  final String altBilgi;
  final String? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return SizedBox(
      width: 260,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Görsel bandı + etiket rozeti ──
                Stack(
                  children: [
                    SizedBox(
                      height: 82,
                      width: double.infinity,
                      child: photo != null
                          ? AppImage(
                              handle: photo,
                              fit: BoxFit.cover,
                              memCacheWidth: 520,
                            )
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accent.withValues(alpha: 0.28),
                                    accent.withValues(alpha: 0.10),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(icon,
                                    color: accent.withValues(alpha: 0.9),
                                    size: 30),
                              ),
                            ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          etiket.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Metin bloğu ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          baslik,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const Spacer(),
                        if (altBilgi.isNotEmpty)
                          Text(
                            altBilgi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
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

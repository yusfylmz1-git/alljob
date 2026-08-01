import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart' show kQuickSupportName;
import '../../../auth/application/auth_controller.dart';

/// Ana Sayfa üst aksiyon bloğu: büyük "Usta Bul" davet kartı + altında iki
/// ikincil aksiyon kutusu (İş İlanı Ver / Ürünleri Keşfet). Etiketler role
/// göre değişir: müşteri "Usta Bul + İş İlanı Ver", usta "İş İlanları" görür.
/// Alt barın yerine geçmez; ana sayfanın birincil giriş noktasıdır.
class HomeQuickAccess extends ConsumerWidget {
  const HomeQuickAccess({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArtisan = ref.watch(
      currentUserProvider.select((u) => u?.isArtisan ?? false),
    );

    // ── Büyük davet kartı (rol bazlı) ──
    final hero = isArtisan
        ? _HeroCta(
            title: 'Sana uygun işi bul.',
            subtitle: 'Yakınındaki iş ilanları,\nhemen teklif ver.',
            ctaLabel: 'İş İlanları',
            icon: Icons.campaign_rounded,
            onTap: () => context.go(RoutePaths.exploreTab('jobs')),
          )
        : _HeroCta(
            title: 'İhtiyacın olan\nustayı bul.',
            subtitle: 'Güvenilir ustalar,\nprofesyonel hizmetler.',
            ctaLabel: 'Usta Bul',
            icon: Icons.handyman_rounded,
            onTap: () => context.go(RoutePaths.exploreTab('artisans')),
          );

    // ── İkincil iki aksiyon (rol bazlı) ──
    final secondary = <_QuickItem>[
      if (isArtisan)
        _QuickItem(
          icon: Icons.storefront_rounded,
          label: 'Ürünlerim',
          hint: 'Vitrinini yönet',
          color: const Color(0xFFEA580C),
          onTap: () => context.go(RoutePaths.exploreTab('products')),
        )
      else
        _QuickItem(
          icon: Icons.post_add_rounded,
          label: 'İş İlanı Ver',
          hint: 'İlan oluştur,\nteklif al',
          color: const Color(0xFF2563EB),
          onTap: () => context.push(RoutePaths.newJob),
        ),
      // Müşteri: Hemen Lazım'ı ikinci aksiyon olarak öne çıkarır (ilan formu
      // kategori seçili açılır). Usta: ürün keşfi.
      if (isArtisan)
        _QuickItem(
          icon: Icons.inventory_2_rounded,
          label: 'Ürünleri Keşfet',
          hint: 'Ürünleri incele,\nilham al',
          color: const Color(0xFF7C3AED),
          onTap: () => context.go(RoutePaths.exploreTab('products')),
        )
      else
        _QuickItem(
          icon: Icons.bolt_rounded,
          label: kQuickSupportName,
          hint: 'Market, taşıma,\nkısa işler',
          color: const Color(0xFFF59E0B),
          onTap: () => context.push(RoutePaths.newQuickSupportJob),
        ),
    ];

    return Column(
      children: [
        hero,
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < secondary.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _QuickCard(item: secondary[i])),
            ],
          ],
        ),
      ],
    );
  }
}

/// Görseldeki büyük gradient davet kartı: başlık + alt açıklama + dolgu CTA
/// düğmesi, sağda yarı saydam dev ikon süsü. Marka mavisi köşegen gradient.
class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return TapScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.heroTop, palette.heroBottom],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.heroTop.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Sağ üstteki yarı saydam dev ikon süsü.
                Positioned(
                  right: -8,
                  top: -6,
                  child: Icon(
                    icon,
                    size: 104,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                // width:infinity → Stack (dolayısıyla kart) tüm genişliği
                // kaplar; aksi halde içerik kadar daralıp ortada küçük kalır.
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Beyaz dolgu CTA düğmesi + ileri oku (içerik kadar).
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ctaLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: palette.heroBottom,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: palette.heroBottom,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class _QuickItem {
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;
}

/// İkincil aksiyon kutusu: renkli ikon rozeti + başlık + iki satır ipucu +
/// sağda ince ileri oku. Görseldeki "İş İlanı Ver / Ürünleri Keşfet" kutuları.
class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.item});

  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return TapScale(
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 21),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
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

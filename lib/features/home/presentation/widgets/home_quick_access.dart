import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart' show kQuickSupportName;

/// Ana Sayfa üst aksiyon bloğu: büyük "Usta Bul" davet kartı + altında iki
/// ikincil kutu (İş İlanı Ver / Hemen Lazım). Rol ayrımı YOK. Etiketler role
/// göre değişir: müşteri "Usta Bul + İş İlanı Ver", usta "İş İlanları" görür.
/// Alt barın yerine geçmez; ana sayfanın birincil giriş noktasıdır.
class HomeQuickAccess extends ConsumerWidget {
  const HomeQuickAccess({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ROL AYRIMI YOK (2026-08-08): herkes aynı üç aksiyonu görür.
    // Eskiden usta/müşteri iki ayrı kart dizisi görüyordu; üstelik usta
    // tarafındaki iki kutu da SİLİNEN ürünler modülüne gidiyordu.
    //
    // Ürünün ana işi: usta bul · ilan ver · hemen lazım.
    final hero = _HeroCta(
      title: 'İhtiyacın olan ustayı bul.',
      subtitle: 'Güvenilir ustalar, profesyonel hizmetler.',
      ctaLabel: 'Usta Bul',
      onTap: () => context.go(RoutePaths.explore),
    );

    final secondary = <_QuickItem>[
      _QuickItem(
        icon: Icons.post_add_rounded,
        label: 'İş İlanı Ver',
        hint: 'İlan oluştur,\nteklif al',
        color: const Color(0xFF2563EB),
        onTap: () => context.push(RoutePaths.newJob),
      ),
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

/// Büyük gradient davet kartı — YATAY düzen (2026-08-08).
///
/// Solda başlık + açıklama, SAĞDA "Usta Bul" düğmesi. Eskiden düğme metnin
/// ALTINDA duruyor, sağ üstte de 104px yarı saydam çekiç süsü vardı; kart
/// gereksiz uzuyor ve çekiç hiçbir iş yapmadan yer kaplıyordu.
///
/// Düğme sağda dikey ortalı: göz başlığı okuyup doğal olarak sağa kayıyor,
/// kart da ~70px kısalıyor — altındaki vitrin şeritleri ekrana giriyor.
class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
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
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.heroTop, palette.heroBottom],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.heroTop.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Çekiç süsünün DURDUĞU yer: artık işlevsiz ikon yerine
                // birincil eylem burada.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: palette.heroBottom,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ctaLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.heroBottom,
                            fontWeight: FontWeight.w800,
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

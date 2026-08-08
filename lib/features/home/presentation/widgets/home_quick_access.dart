import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/tap_scale.dart';
import '../../../../data/models/job.dart' show kQuickSupportName;

/// Ana Sayfa üst aksiyon bloğu — üç iş, üç kart:
///   1. Usta Bul (gradyan davet kartı)
///   2. Kolay İş — kısa işler, 1 günlük
///   3. İş İlanı Ver — usta arayan ilan, 3/5/7 gün
///
/// Rol ayrımı YOK: herkes aynı üçlüyü görür. Alt barın yerine geçmez;
/// ana sayfanın birincil giriş noktasıdır.
class HomeQuickAccess extends ConsumerWidget {
  const HomeQuickAccess({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = _HeroCta(
      title: 'İhtiyacın olan ustayı bul.',
      subtitle: 'Güvenilir ustalar, profesyonel hizmetler.',
      ctaLabel: 'Usta Bul',
      onTap: () => context.go(RoutePaths.explore),
    );

    return Column(
      children: [
        hero,
        const SizedBox(height: 12),

        // KOLAY İŞ ÖNE ÇIKTI (2026-08-08): eskiden "İş İlanı Ver"in yanında
        // yarım genişlikte bir kutuydu ve iki akış birbirine karışıyordu.
        // Artık kendi tam genişlikli, turuncu kartı var — bambaşka bir iş
        // (uzmanlık gerektirmeyen kısa işler) olduğu görünürde.
        _WideAction(
          icon: Icons.bolt_rounded,
          color: const Color(0xFFF59E0B),
          title: kQuickSupportName,
          subtitle: 'Market, taşıma, kısa gidiş — 1 günlük ilan',
          onTap: () => context.push(RoutePaths.newQuickSupportJob),
        ),
        const SizedBox(height: 10),
        _WideAction(
          icon: Icons.post_add_rounded,
          color: const Color(0xFF2563EB),
          title: 'İş İlanı Ver',
          subtitle: 'Usta arayan ilan oluştur — 3, 5 veya 7 gün',
          onTap: () => context.push(RoutePaths.newJob),
        ),
      ],
    );
  }
}

/// Tam genişlikli aksiyon satırı: renkli ikon rozeti + başlık + açıklama.
///
/// İki ilan akışı (Kolay İş / İş İlanı) yan yana yarım kutu yerine alt alta
/// tam satır duruyor: hangisinin ne olduğu tek bakışta okunuyor ve süre
/// farkı açıklamada görünüyor.
class _WideAction extends StatelessWidget {
  const _WideAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: palette.inkMuted),
              ],
            ),
          ),
        ),
      ),
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

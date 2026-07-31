import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Usta Çantası hub'ı (PRD-007). Saha hesap + AR ölçüm araçlarının giriş
/// ekranı. Misafir dâhil herkese açıktır (router `needsLogin`'e eklenmez).
///
/// Ölçüm (alan/boya/fayans), İş & Maliyet (maliyet/kâr/teklif) ve Diğer
/// (birim/süre) araçları aktiftir; "Ölç (AR)" şimdilik hazırlık ekranına gider
/// (native AR paketi + yeni mağaza sürümü bekliyor).
class ToolkitHubScreen extends StatelessWidget {
  const ToolkitHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usta Çantası')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(),
          const SizedBox(height: 20),

          // Yıldız akış: yönlendirmeli ölçüm & malzeme hesabı. Malzeme seç →
          // kamerayla/elle ölç → birkaç soru → direkt sonuç ("~X kutu fayans").
          // Yeni kullanıcının doğrudan sonuca ulaştığı ana giriş budur.
          _ToolCard(
            icon: Icons.straighten_rounded,
            title: 'Ölç & Hesapla',
            subtitle: 'Malzeme seç, ölç, ihtiyacı anında öğren',
            rota: RoutePaths.toolkitMeasure,
            vurgulu: true,
          ),

          _GroupLabel('Tek tek hesapla'),
          _ToolCard(
            icon: Icons.square_foot_outlined,
            title: 'Alan Hesapla',
            subtitle: 'En × boy, düşüm ve fire → net m²',
            rota: RoutePaths.toolkitArea,
          ),
          _ToolCard(
            icon: Icons.format_paint_outlined,
            title: 'Boya Hesapla',
            subtitle: 'Alan ve kat sayısına göre tahmini litre',
            rota: RoutePaths.toolkitPaint,
          ),
          _ToolCard(
            icon: Icons.grid_on_outlined,
            title: 'Fayans Hesapla',
            subtitle: 'Ebat, derz ve fire → yaklaşık adet',
            rota: RoutePaths.toolkitTile,
          ),

          _GroupLabel('İş & Maliyet'),
          _ToolCard(
            icon: Icons.calculate_outlined,
            title: 'Maliyet Hesapla',
            subtitle: 'Malzeme + işçilik + yol + diğer',
            rota: RoutePaths.toolkitCost,
          ),
          _ToolCard(
            icon: Icons.trending_up_outlined,
            title: 'Kâr Hesapla',
            subtitle: 'Maliyetten satış fiyatına',
            rota: RoutePaths.toolkitProfit,
          ),
          _ToolCard(
            icon: Icons.receipt_long_outlined,
            title: 'Teklif Oluştur',
            subtitle: 'Kalemler + KDV → paylaşılabilir teklif',
            rota: RoutePaths.toolkitQuote,
          ),

          _GroupLabel('Diğer'),
          _ToolCard(
            icon: Icons.swap_horiz_rounded,
            title: 'Birim Dönüştürücü',
            subtitle: 'm / cm / mm, m², litre, kg, inç',
            rota: RoutePaths.toolkitUnits,
          ),
          _ToolCard(
            icon: Icons.schedule_outlined,
            title: 'İş Süresi Tahmini',
            subtitle: 'm² × meslek şablonu → saat / gün',
            rota: RoutePaths.toolkitDuration,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('Usta Çantası nasıl çalışır?'),
              onPressed: () => context.push(RoutePaths.help),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı (Ölçüm / İş & Maliyet / Diğer).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.palette.inkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// Tek bir araç kartı. Dokununca [rota]ya gider. [vurgulu] AR gibi yıldız
/// aracı çerçeve + renkle öne çıkarır.
class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rota,
    this.vurgulu = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Dokununca gidilecek rota.
  final String rota;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              vurgulu ? palette.primary.withValues(alpha: 0.4) : palette.border,
          width: vurgulu ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: palette.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(rota),
      ),
    );
  }
}

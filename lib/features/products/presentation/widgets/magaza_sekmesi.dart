import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../jobs/data/job_providers.dart';
import '../../../jobs/presentation/widgets/job_widgets.dart';
import 'products_explore_panel.dart';

/// Keşfet'in üçüncü sekmesi: **Mağaza**.
///
/// İki bölüm (kullanıcı kararı 2026-08-10):
///  1. **Ürünler** — satılık ürün vitrini (eski PRD-006 modülü).
///  2. **Talepler** — "şu ürüne ihtiyacım var" ilanları.
///
/// ERİŞİM KAPISI YOK. Keşfet'in "İlanlar" sekmesi giriş + usta modu ister;
/// Mağaza istemez — herkes satabildiği için herkes bakabilmeli, misafir
/// dâhil (Ustalar sekmesi gibi). Yazma yolları (`/products/new`,
/// `/products/mine`) router'da oturum ister; kapı orada.
///
/// ADLANDIRMA: alt bölüm "Talepler", eylem düğmesi "İlan Ver". Alt barda ve
/// Keşfet'te zaten "İlanlar" var; üçüncü kez aynı kelimeyi başka anlamda
/// kullanmamak için bölüm adı ayrıldı.
class MagazaSekmesi extends ConsumerStatefulWidget {
  const MagazaSekmesi({super.key});

  @override
  ConsumerState<MagazaSekmesi> createState() => _MagazaSekmesiState();
}

class _MagazaSekmesiState extends ConsumerState<MagazaSekmesi>
    with SingleTickerProviderStateMixin {
  late final TabController _alt = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _alt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Material(
          color: palette.surfaceMuted,
          child: TabBar(
            controller: _alt,
            tabs: const [
              Tab(text: 'Ürünler'),
              Tab(text: 'Talepler'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _alt,
            children: const [
              ProductsExplorePanel(),
              _TaleplerBolumu(),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Şu ürüne ihtiyacım var" ilanları.
///
/// Liste [productRequestsProvider]'dan gelir — açık ilanlar üzerinden
/// süzülür, ayrı sorgu açmaz. Bu talepler usta feed'ine DÜŞMEZ; burası
/// tek görünür yerleri, o yüzden boş durum da açıklayıcı olmalı.
class _TaleplerBolumu extends ConsumerWidget {
  const _TaleplerBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final talepler = ref.watch(productRequestsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aranan ürünler',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'İhtiyacını yaz, ilindeki satıcılar görsün',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(
                  '${RoutePaths.newJob}?kind=product',
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('İlan Ver'),
              ),
            ],
          ),
        ),
        Expanded(
          child: talepler.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(28),
                  children: [
                    const SizedBox(height: 20),
                    Icon(Icons.search_rounded,
                        size: 44, color: palette.inkMuted),
                    const SizedBox(height: 14),
                    Text(
                      'Henüz ürün talebi yok',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aradığın bir ürün varsa "İlan Ver" ile yaz — '
                      'ilindeki satıcılara günlük özet olarak iletilir.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: talepler.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => NearbyJobCard(
                    job: talepler[i],
                    ctaText: 'Detayı Gör',
                  ),
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../jobs/data/job_providers.dart';
import '../../../jobs/presentation/widgets/job_widgets.dart';
import 'products_explore_panel.dart';

/// Mağazası olmayan / müsait olmayan kullanıcının görebileceği talep sayısı.
///
/// Değer bilinçli olarak küçük ama sıfır değil: kullanıcı ne kaçırdığını
/// görmeli ki mağaza açmak anlamlı gelsin. Sıfır göstermek "burada bir şey
/// yok" izlenimi verirdi.
const int kSinirliTalepSayisi = 3;

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
/// ADLANDIRMA: alt bölüm "Talepler", eylem düğmesi "Talep Oluştur". Alt barda
/// ve Keşfet'te zaten "İlanlar" var; üçüncü kez aynı kelimeyi başka anlamda
/// kullanmamak için hem bölüm adı hem düğme "talep" der (düğme eskiden
/// "İlan Ver"di, 2026-08-15'te bölümle aynı dile getirildi).
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

    // ÜRÜN TALEPLERİ SATICILARA AİTTİR (2026-08-14 ürün kararı).
    //
    // Talebe cevap verebilmek için mağaza gerekir; mağazası olmayan ya da
    // "müsait değil" durumundaki kullanıcı zaten mesaj atamaz
    // (`availability_gate.dart`). Listenin tamamını göstermek boş bir vaat
    // olurdu — üstelik talep sahibinin ihtiyacı da rakip taramasına açılır.
    //
    // Bu yüzden sınırlı gösterilir: birkaç örnek görünür (değer anlaşılsın),
    // gerisi mağaza açıp müsait olunca gelir.
    final user = ref.watch(currentUserProvider);
    final magazaVar = user?.hasShopProfile ?? false;
    final musait = user?.available ?? false;
    final kilitli = !(magazaVar && musait);
    final gorunen = kilitli
        ? talepler.take(kSinirliTalepSayisi).toList(growable: false)
        : talepler;

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
                label: const Text('Talep Oluştur'),
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
                      'Aradığın bir ürün varsa "Talep Oluştur" ile yaz — '
                      'ilindeki satıcılara günlük özet olarak iletilir.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  // Kilitliyse: ilk N talep + sonda kapı kartı.
                  itemCount: kilitli
                      ? gorunen.length + 1
                      : talepler.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (kilitli && i == gorunen.length) {
                      return _TalepKilidi(
                        gizliSayi: talepler.length - gorunen.length,
                        magazaVar: magazaVar,
                      );
                    }
                    return NearbyJobCard(
                      job: kilitli ? gorunen[i] : talepler[i],
                      ctaText: 'Detayı Gör',
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Sınırlı talep listesinin sonundaki kapı kartı.
///
/// İki farklı eksik olabilir; mesaj **hangisi eksikse** onu söyler:
///  - mağaza yok → mağaza açma çağrısı
///  - mağaza var ama "müsait değil" → müsaitliği açma çağrısı
///
/// Ceza dili kullanılmaz: kullanıcı bir şey kaybetmiyor, bir şey
/// kazanabiliyor. Kart "kilit" değil "davet" gibi okunmalı.
class _TalepKilidi extends StatelessWidget {
  const _TalepKilidi({required this.gizliSayi, required this.magazaVar});

  /// Gizlenen talep sayısı. 0 ise sayı yazılmaz (yanlış vaat olmasın).
  final int gizliSayi;
  final bool magazaVar;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  gizliSayi > 0
                      ? '$gizliSayi talep daha var'
                      : 'Tüm talepleri görün',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            magazaVar
                // Mağaza var, müsaitlik kapalı.
                ? 'Şu an "müsait değil" görünüyorsunuz. Müsaitliği açın; '
                    'tüm ürün taleplerini görün ve alıcılara mesaj atın.'
                // Mağaza hiç yok.
                : 'Ürün taleplerinin tamamı satıcılara açıktır. Mağazanızı '
                    'açın, ilinizdeki alıcıların ne aradığını görün ve '
                    'doğrudan teklif verin.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                magazaVar ? RoutePaths.profile : RoutePaths.shopSetup,
              ),
              icon: Icon(
                magazaVar ? Icons.toggle_on_outlined : Icons.add_business,
                size: 18,
              ),
              label: Text(magazaVar ? 'Müsaitliği aç' : 'Mağaza aç'),
            ),
          ),
        ],
      ),
    );
  }
}

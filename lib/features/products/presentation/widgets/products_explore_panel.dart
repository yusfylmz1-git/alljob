import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/search_fold.dart';
import '../../../../core/widgets/pull_to_refresh.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_views.dart';
import '../../../../data/local/local_data_service.dart';
import '../../../../data/models/geo_models.dart';
import '../../../../data/models/product_category.dart';
import '../../../../data/models/product.dart';
import '../../../auth/application/auth_controller.dart';
import '../../data/product_providers.dart';
import 'product_card.dart';

/// Keşfet → Ürünler sekmesi: arama + kategori/il filtresi + ızgara.
class ProductsExplorePanel extends ConsumerStatefulWidget {
  const ProductsExplorePanel({super.key});

  @override
  ConsumerState<ProductsExplorePanel> createState() =>
      _ProductsExplorePanelState();
}

class _ProductsExplorePanelState extends ConsumerState<ProductsExplorePanel> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _categoryCode;
  String? _province;

  bool get _hasFilter =>
      _query.trim().isNotEmpty || _categoryCode != null || _province != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _categoryCode = null;
      _province = null;
    });
  }

  Future<void> _refresh() => awaitRefresh(() async {
        ref.invalidate(discoverProductsProvider);
        await ref.read(discoverProductsProvider.future);
      });

  List<Product> _applyFilters(List<Product> products) {
    var list = products;
    if (_categoryCode != null) {
      list = list.where((p) => p.categoryCode == _categoryCode).toList();
    }
    if (_province != null) {
      list = list.where((p) => p.province == _province).toList();
    }
    final q = _query.trim();
    if (q.isNotEmpty) {
      list = list.where((p) {
        final cat = ProductCategory.label(p.categoryCode);
        return matchesTrSearch(p.title, q) ||
            matchesTrSearch(p.ownerName, q) ||
            matchesTrSearch(cat, q) ||
            p.tags.any((t) => matchesTrSearch(t, q));
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(productsLiveProvider)) {
      return const ErrorView(
        title: 'Yakında',
        message: 'Ürün vitrini şu an kapalı. Daha sonra tekrar bakın.',
      );
    }

    final async = ref.watch(discoverProductsProvider);
    final user = ref.watch(currentUserProvider);
    // 2026-08-10: "Ürünlerim" girişi USTA MODUNA bağlıydı. Herkes satabildiği
    // için kapı kalktı — ölçüt artık yalnızca oturum açmış olmak.
    // Misafir ürünleri görür ama kendi vitrinine giremez.
    final canSell = user != null;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(),
      ),
      error: (e, _) {
        final raw = e.toString();
        final denied = raw.contains('permission-denied') ||
            raw.contains('PERMISSION_DENIED');
        final index = raw.contains('failed-precondition') ||
            raw.contains('requires an index');
        return ErrorView(
          title: 'Ürünler yüklenemedi',
          message: denied
              ? 'Firestore kuralları henüz yayında olmayabilir. '
                  'Yönetici: firebase deploy --only firestore:rules'
              : index
                  ? 'Firestore indeksi hazırlanıyor. Birkaç dakika sonra tekrar deneyin.'
                  : 'Bağlantınızı kontrol edip tekrar deneyin.',
          onRetry: () => ref.invalidate(discoverProductsProvider),
        );
      },
      data: (products) {
        final filtered = _applyFilters(products);
        return PullToRefresh(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: kPullRefreshPhysics,
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  canSell: canSell,
                  searchCtrl: _searchCtrl,
                  onQueryChanged: _onQueryChanged,
                  categoryCode: _categoryCode,
                  onCategory: (v) => setState(() => _categoryCode = v),
                  province: _province,
                  onProvince: (v) => setState(() => _province = v),
                  hasFilter: _hasFilter,
                  onClearFilters: _clearFilters,
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: products.isEmpty
                      ? ErrorView(
                          title: 'Henüz ürün yok',
                          message: canSell
                              ? 'Keşfet’te görünecek ilk ürününüzü '
                                  'Ürünlerim’den ekleyebilirsiniz.'
                              : 'Ürünler paylaşıldıkça burada görünecek.',
                          icon: Icons.storefront_outlined,
                        )
                      : ErrorView(
                          title: 'Sonuç bulunamadı',
                          message:
                              'Bu arama/filtre ile eşleşen ürün yok. Filtreleri '
                              'temizleyip tekrar deneyin.',
                          icon: Icons.search_off_rounded,
                          onRetry: _clearFilters,
                          retryLabel: 'Filtreleri temizle',
                        ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final p = filtered[i];
                        return ProductCard(
                          product: p,
                          onTap: () =>
                              context.push(RoutePaths.productDetail(p.id)),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.canSell,
    required this.searchCtrl,
    required this.onQueryChanged,
    required this.categoryCode,
    required this.onCategory,
    required this.province,
    required this.onProvince,
    required this.hasFilter,
    required this.onClearFilters,
  });

  /// Oturum açmış mı — "Ürünlerim" girişi buna bağlı. Usta olma şartı YOK.
  final bool canSell;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQueryChanged;
  final String? categoryCode;
  final ValueChanged<String?> onCategory;
  final String? province;
  final ValueChanged<String?> onProvince;
  final bool hasFilter;
  final VoidCallback onClearFilters;

  Future<void> _pickCategory(BuildContext context) async {
    // Ürün kategorileri (meslek listesi DEĞİL) — tanımlı sırada.
    final picked = await _showFilterSheet(
      context,
      title: 'Kategori',
      options: [
        for (final c in ProductCategory.sirali)
          (value: c, label: ProductCategory.label(c)),
      ],
      selected: categoryCode,
    );
    if (picked == null) return;
    onCategory(picked.cleared ? null : picked.value);
  }

  Future<void> _pickProvince(BuildContext context, WidgetRef ref) async {
    final provinces = await ref
        .read(provincesProvider.future)
        .catchError((_) => const <Province>[]);
    if (!context.mounted) return;
    final picked = await _showFilterSheet(
      context,
      title: 'İl',
      options: [
        for (final p in provinces) (value: p.name, label: p.name),
      ],
      selected: province,
    );
    if (picked == null) return;
    onProvince(picked.cleared ? null : picked.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final catLabel = categoryCode == null
        ? 'Kategori'
        : ProductCategory.label(categoryCode!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ürünler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Satılık ürünler — iletişim sohbet ile',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canSell)
                TextButton.icon(
                  onPressed: () => context.push(RoutePaths.myProducts),
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('Ürünlerim'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchCtrl,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Ürün, etiket veya usta arayın…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: palette.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.hairline),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: categoryCode != null,
                  showCheckmark: false,
                  avatar: Icon(Icons.category_outlined,
                      size: 16,
                      color: categoryCode != null
                          ? palette.primary
                          : palette.inkMuted),
                  label: Text(catLabel, overflow: TextOverflow.ellipsis),
                  onSelected: (_) => _pickCategory(context),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: province != null,
                  showCheckmark: false,
                  avatar: Icon(Icons.location_city_outlined,
                      size: 16,
                      color:
                          province != null ? palette.primary : palette.inkMuted),
                  label: Text(province ?? 'İl'),
                  onSelected: (_) => _pickProvince(context, ref),
                ),
                if (hasFilter) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(Icons.close_rounded,
                        size: 16, color: palette.inkMuted),
                    label: const Text('Temizle'),
                    onPressed: onClearFilters,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtre sheet sonucu: [cleared] true → "Tümü" seçildi.
class _FilterPick {
  const _FilterPick({this.value, this.cleared = false});
  final String? value;
  final bool cleared;
}

Future<_FilterPick?> _showFilterSheet(
  BuildContext context, {
  required String title,
  required List<({String value, String label})> options,
  String? selected,
}) {
  return showModalBottomSheet<_FilterPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _FilterSheet(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<({String value, String label})> options;
  final String? selected;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _q.trim().isEmpty
        ? widget.options
        : widget.options
            .where((o) => matchesTrSearch(o.label, _q))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Ara…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: filtered.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(Icons.clear_all_rounded),
                    title: const Text('Tümü'),
                    selected: widget.selected == null,
                    onTap: () => Navigator.pop(
                        ctx, const _FilterPick(cleared: true)),
                  );
                }
                final o = filtered[i - 1];
                final isSel = o.value == widget.selected;
                return ListTile(
                  title: Text(o.label),
                  selected: isSel,
                  trailing:
                      isSel ? const Icon(Icons.check_rounded) : null,
                  onTap: () =>
                      Navigator.pop(ctx, _FilterPick(value: o.value)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

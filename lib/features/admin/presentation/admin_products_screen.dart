import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_category.dart';
import '../data/admin_product_repository.dart';
import '../data/admin_providers.dart';
import 'admin_chrome.dart';
import 'admin_list_search.dart';
import 'admin_moderation_glossary.dart';
import 'paged_footer.dart';

/// Mağaza ürün kuyruğu — inceleme / gizle / kaldır.
///
/// CF: `adminModerateProduct` (approve, reject, hide, unhide, force_remove,
/// hard_purge). Varsayılan filtre: `pending_review`.
class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Product? _idHit;
  bool _idSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupId(String q) async {
    final t = q.trim();
    if (t.isEmpty || t.contains(' ') || t.length < 8) {
      setState(() => _idHit = null);
      return;
    }
    setState(() => _idSearching = true);
    try {
      final p = await ref.read(adminProductRepositoryProvider).findById(t);
      if (!mounted) return;
      setState(() {
        _idHit = p;
        _idSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _idHit = null;
        _idSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(productDirectoryControllerProvider);
    final controller = ref.read(productDirectoryControllerProvider.notifier);
    final filter = ref.watch(productDirectoryFilterProvider);
    final canModerate =
        ref.watch(adminCapabilitiesProvider).allows('products.moderate');
    final canPurge =
        ref.watch(adminCapabilitiesProvider).allows('products.purge') ||
            ref.watch(isSuperAdminProvider);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Ürünler',
        icon: Icons.inventory_2_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? 'Mağaza moderasyonu'
            : '${pageAsync.value!.items.length} yüklü'
                '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          const AdminHelpButton(highlightTitle: 'Vitrini gizle'),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          AdminHintBanner(
            text:
                'Ürün “gizle” yalnız bu ürünü düşürür; satıcı hesabını askıya '
                'almaz. Onay = yayına al · Red = taslağa geri.',
            onHelp: () => AdminModerationGlossary.show(
              context,
              highlightTitle: 'Vitrini gizle',
            ),
          ),
          AdminListSearchBar(
            controller: _searchCtrl,
            label: 'Ürün ara',
            hint: 'Başlık, satıcı, kategori, ürün ID…',
            onChanged: (v) {
              setState(() => _query = v.trim());
              _lookupId(v);
            },
            onSubmitted: _lookupId,
            onClear: () => setState(() {
              _query = '';
              _idHit = null;
            }),
          ),
          if (_idSearching)
            const LinearProgressIndicator(minHeight: 2)
          else if (_idHit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: _ProductCard(
                product: _idHit!,
                canModerate: canModerate,
                canPurge: canPurge,
              ),
            ),
          _ProductFilters(
            filter: filter,
            onFilter: (f) {
              ref.read(productDirectoryFilterProvider.notifier).state = f;
            },
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) {
                final raw = e.toString();
                final index = raw.toLowerCase().contains('failed-precondition') ||
                    raw.toLowerCase().contains('requires an index');
                final denied = raw.toLowerCase().contains('permission-denied') ||
                    raw.toLowerCase().contains('permission_denied');
                return ErrorView(
                  message: index
                      ? 'Firestore bileşik indeksi hazır değil. '
                          'Console → Firestore → Indexes veya: '
                          'firebase deploy --only firestore:indexes'
                      : denied
                          ? 'Ürün okuma yetkisi yok (App Check / admin claim). '
                              'Sayfayı yenileyin veya superadmin ile giriş yapın.'
                          : 'Ürünler yüklenemedi.\n$raw',
                );
              },
              data: (page) {
                final items = _query.isEmpty
                    ? page.items
                    : page.items
                        .where(
                          (p) => adminAnyMatch(
                            [
                              p.id,
                              p.title,
                              p.ownerName,
                              p.ownerUid,
                              p.categoryCode,
                              ProductCategory.label(p.categoryCode),
                              p.province,
                              p.status.labelTR,
                            ],
                            _query,
                          ),
                        )
                        .toList();
                if (page.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        filter == AdminProductListFilter.pendingReview
                            ? 'İnceleme bekleyen ürün yok.'
                            : 'Bu filtrede ürün yok.',
                        style: TextStyle(color: context.palette.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (items.isEmpty && _idHit == null) {
                  return Center(
                    child: Text(
                      'Arama sonucu yok. Tam ürün ID veya daha fazla yükleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 960,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: ListView.separated(
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: controller.loadMore,
                            endLabel: _query.isEmpty
                                ? 'Ürün listesinin sonu'
                                : 'Yüklü listede arama',
                          );
                        }
                        return _ProductCard(
                          product: items[i],
                          canModerate: canModerate,
                          canPurge: canPurge,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFilters extends StatelessWidget {
  const _ProductFilters({required this.filter, required this.onFilter});

  final AdminProductListFilter filter;
  final ValueChanged<AdminProductListFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Kuyruk odaklı sıra: inceleme önce.
    const order = [
      AdminProductListFilter.pendingReview,
      AdminProductListFilter.active,
      AdminProductListFilter.hidden,
      AdminProductListFilter.draft,
      AdminProductListFilter.paused,
      AdminProductListFilter.sold,
      AdminProductListFilter.removed,
      AdminProductListFilter.all,
    ];
    return Material(
      color: palette.card,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            for (final f in order) ...[
              FilterChip(
                label: Text(f.labelTR),
                selected: filter == f,
                onSelected: (_) => onFilter(f),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.canModerate,
    required this.canPurge,
  });

  final Product product;
  final bool canModerate;
  final bool canPurge;

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    String decision, {
    String? note,
  }) async {
    if (!canModerate && decision != 'hard_purge') {
      context.showError('products.moderate yetkisi yok.');
      return;
    }
    if (decision == 'hard_purge' && !canPurge) {
      context.showError('products.purge yetkisi yok.');
      return;
    }
    try {
      await ref.read(adminProductRepositoryProvider).moderate(
            product.id,
            decision: decision,
            note: note,
          );
      if (context.mounted) {
        context.showSuccess(switch (decision) {
          'approve' => 'Ürün onaylandı (yayında).',
          'reject' => 'Ürün reddedildi (taslak).',
          'hide' => 'Ürün gizlendi.',
          'unhide' => 'Gizleme kaldırıldı.',
          'force_remove' => 'Ürün kaldırıldı.',
          'hard_purge' => 'Ürün kalıcı silindi.',
          _ => 'İşlem tamam.',
        });
        ref.invalidate(productDirectoryControllerProvider);
      }
    } catch (_) {
      if (context.mounted) context.showError('Moderasyon başarısız.');
    }
  }

  Future<void> _confirmNote(
    BuildContext context,
    WidgetRef ref,
    String decision,
    String title,
  ) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Not (isteğe bağlı)',
            hintText: 'Sahibe / denetime not',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _moderate(context, ref, decision, note: ctrl.text.trim());
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final p = product;
    final cat = ProductCategory.label(p.categoryCode);
    final cover = p.coverPhoto;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: p.moderationHidden
                ? palette.danger
                : p.status == ProductStatus.pendingReview
                    ? palette.warning.withValues(alpha: 0.55)
                    : palette.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: cover == null
                        ? ColoredBox(
                            color: palette.surfaceMuted,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: palette.inkFaint,
                            ),
                          )
                        : AppImage(
                            handle: cover,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title.isEmpty ? '(başlıksız)' : p.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cat · ${p.placeLabel} · ${p.priceLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(
                            label: p.status.labelTR,
                            color: p.status == ProductStatus.pendingReview
                                ? palette.warning
                                : palette.inkMuted,
                          ),
                          if (p.moderationHidden)
                            _Chip(label: 'Gizli', color: palette.danger),
                          if (p.reportCount > 0)
                            _Chip(
                              label: '${p.reportCount} şikayet',
                              color: palette.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.moderationNote != null &&
                p.moderationNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Not: ${p.moderationNote}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Sahip: ${p.ownerName.isEmpty ? p.ownerUid : p.ownerName}'
              ' · ${p.id}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkFaint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (p.status == ProductStatus.pendingReview)
                  FilledButton.tonal(
                    onPressed: canModerate
                        ? () => _moderate(context, ref, 'approve')
                        : null,
                    child: const Text('Onayla'),
                  ),
                if (p.status == ProductStatus.pendingReview)
                  OutlinedButton(
                    onPressed: canModerate
                        ? () => _confirmNote(
                              context,
                              ref,
                              'reject',
                              'Yayını reddet',
                            )
                        : null,
                    child: const Text('Reddet'),
                  ),
                if (!p.hiddenByModeration)
                  OutlinedButton(
                    onPressed: canModerate
                        ? () => _moderate(context, ref, 'hide')
                        : null,
                    child: const Text('Gizle'),
                  )
                else
                  OutlinedButton(
                    onPressed: canModerate
                        ? () => _moderate(context, ref, 'unhide')
                        : null,
                    child: const Text('Göster'),
                  ),
                OutlinedButton(
                  onPressed: canModerate
                      ? () => _confirmNote(
                            context,
                            ref,
                            'force_remove',
                            'Ürünü kaldır',
                          )
                      : null,
                  child: Text(
                    'Kaldır',
                    style: TextStyle(color: palette.danger),
                  ),
                ),
                if (canPurge)
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Kalıcı sil'),
                          content: const Text(
                            'Ürün ve depolama dosyaları silinir. '
                            'Geri alınamaz.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await _moderate(context, ref, 'hard_purge');
                      }
                    },
                    child: Text(
                      'Purge',
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/product.dart';
import '../../auth/application/auth_controller.dart';
import '../data/product_providers.dart';

/// Usta: ürün listesi + hızlı lifecycle.
class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // Geri tuşu: yığın yoksa Ana Sayfa'ya (Mağaza Keşfet'in sekmesi).
      return MainTabScope(
        tab: MainTab.explore,
        child: Scaffold(
          appBar: const GradientAppBar(title: 'Ürünlerim'),
          body: Center(
            child: FilledButton(
              onPressed: () => context.push(RoutePaths.login),
              child: const Text('Giriş yap'),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(myProductsProvider(user.uid));
    final palette = context.palette;

    return MainTabScope(
      tab: MainTab.explore,
      child: Scaffold(
      appBar: GradientAppBar(
        title: 'Ürünlerim',
        subtitle: 'Vitrin ürünlerinizi yönetin',
        icon: Icons.storefront_outlined,
        actions: [
          IconButton(
            tooltip: 'Yeni ürün',
            icon: const Icon(Icons.add),
            onPressed: () => context.push(RoutePaths.productNew),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.productNew),
        icon: const Icon(Icons.add),
        label: const Text('Ürün ekle'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          title: 'Yüklenemedi',
          message: 'Ürün listeniz alınamadı.',
          onRetry: () => ref.invalidate(myProductsProvider(user.uid)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return ErrorView(
              title: 'Henüz ürün yok',
              message: 'Keşfet’te görünecek ilk ürününüzü ekleyin.',
              icon: Icons.inventory_2_outlined,
              onRetry: () => context.push(RoutePaths.productNew),
              retryLabel: 'Ürün ekle',
            );
          }
          return ResponsiveCenter(
            maxWidth: 720,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = list[i];
                return Material(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(RoutePaths.productEdit(p.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: p.coverPhoto == null
                                  ? ColoredBox(
                                      color: palette.surfaceMuted,
                                      child: Icon(Icons.image_outlined,
                                          color: palette.inkMuted),
                                    )
                                  : AppImage(
                                      handle: p.coverPhoto,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title.isEmpty ? 'İsimsiz taslak' : p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${p.status.labelTR} · ${p.priceLabel}',
                                  style: TextStyle(
                                    color: palette.inkMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                if (p.moderationHidden)
                                  Text(
                                    'Keşfet’te gizli',
                                    style: TextStyle(
                                      color: palette.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) =>
                                _onAction(context, ref, p, v),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Düzenle')),
                              if (p.status == ProductStatus.draft ||
                                  p.status == ProductStatus.pendingReview)
                                const PopupMenuItem(
                                    value: 'publish',
                                    child: Text('Yayınla')),
                              if (p.status == ProductStatus.active) ...[
                                const PopupMenuItem(
                                    value: 'pause',
                                    child: Text('Duraklat')),
                                const PopupMenuItem(
                                    value: 'oos',
                                    child: Text('Stokta yok')),
                                const PopupMenuItem(
                                    value: 'sold', child: Text('Satıldı')),
                              ],
                              if (p.status == ProductStatus.paused ||
                                  p.status == ProductStatus.outOfStock)
                                const PopupMenuItem(
                                    value: 'resume',
                                    child: Text('Yeniden yayınla')),
                              if (p.status == ProductStatus.removed &&
                                  p.isOwnerRestorable)
                                const PopupMenuItem(
                                    value: 'restore',
                                    child: Text('Taslağa geri al')),
                              if (p.status != ProductStatus.removed)
                                const PopupMenuItem(
                                    value: 'remove', child: Text('Kaldır')),
                              const PopupMenuItem(
                                  value: 'view',
                                  child: Text('Keşfet görünümü')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }

  /// Geri alması zor işlemler için onay diyaloğu.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    Product p,
    String action,
  ) async {
    final repo = ref.read(productRepositoryProvider);
    if (action == 'remove') {
      final ok = await _confirm(
        context,
        title: 'Ürünü kaldır',
        message: '«${p.title.isEmpty ? 'İsimsiz taslak' : p.title}» '
            'Keşfet’ten ve listenizden kaldırılacak. Daha sonra '
            'Taslağa geri alabilirsiniz.',
        confirmLabel: 'Kaldır',
      );
      if (!ok || !context.mounted) return;
    }
    if (action == 'sold') {
      final ok = await _confirm(
        context,
        title: 'Satıldı olarak işaretle',
        message: 'Ürün yayından iner. Satıldı işaretinden sonra ürün '
            'yeniden yayına alınamaz (yalnız kaldırılabilir).',
        confirmLabel: 'Satıldı',
      );
      if (!ok || !context.mounted) return;
    }
    try {
      switch (action) {
        case 'edit':
          context.push(RoutePaths.productEdit(p.id));
          return;
        case 'view':
          context.push(RoutePaths.productDetail(p.id));
          return;
        case 'publish':
          if (!ref.read(productsLiveProvider)) {
            if (context.mounted) {
              context.showError('Mağaza şu an kapalı; ürün yayınlanamaz.');
            }
            return;
          }
          await repo.publishProduct(p.id);
          if (context.mounted) context.showSuccess('Ürün yayınlandı.');
          return;
        case 'pause':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.paused);
          break;
        case 'oos':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.outOfStock);
          break;
        case 'sold':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.sold);
          break;
        case 'resume':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.active);
          break;
        case 'restore':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.draft);
          break;
        case 'remove':
          await repo.setLifecycle(
              productId: p.id, to: ProductStatus.removed);
          break;
      }
      if (context.mounted) context.showSuccess('Güncellendi.');
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      if (msg.contains('resource-exhausted') ||
          msg.contains('Günlük')) {
        context.showError(
            'Günlük yayın limitine ulaştınız. Yarın tekrar deneyin.');
      } else if (msg.contains('failed-precondition') ||
          msg.contains('fields') ||
          msg.contains('incomplete')) {
        context.showError(
            'Yayın için zorunlu alanlar eksik. Ürünü düzenleyin.');
      } else {
        context.showError('İşlem yapılamadı. Tekrar deneyin.');
      }
    }
  }
}

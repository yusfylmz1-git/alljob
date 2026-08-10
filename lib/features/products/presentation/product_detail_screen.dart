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
import '../../../data/models/product_category.dart';
import '../../../data/models/product.dart';
import '../../../data/models/report.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../../safety/presentation/report_sheet.dart';
import '../data/product_providers.dart';

/// Ürün detay + sohbet CTA (K16: startChat + ilk mesaj şablonu).
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    Product p,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(RoutePaths.login);
      return;
    }
    if (user.uid == p.ownerUid) {
      context.showInfo('Bu sizin ürününüz.');
      return;
    }
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'satıcıyla iletişime geçmek',
    );
    if (!emailOk || !context.mounted) return;

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final chatId = await chatRepo.startChat(
        customerUid: user.uid,
        customerName: user.displayName.isEmpty ? 'Müşteri' : user.displayName,
        customerPhotoUrl: user.profilePhotoUrl,
        artisanUid: p.ownerUid,
        artisanName: p.ownerName,
        artisanPhotoUrl: p.ownerPhotoUrl,
      );
      // İlk mesaj şablonu (product context — chat schema değişmez).
      // NOT: deep-link şeması kayıtlı değil; ölü link yerine düz metin.
      final body = 'Merhaba, «${p.title}» ürününüz hakkında yazıyorum.';
      await chatRepo.sendMessage(
        chatId: chatId,
        senderUid: user.uid,
        text: body,
      );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        context.showError(
            'Sohbet açılamadı. E-posta doğrulamanızı kontrol edin.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productProvider(productId));
    final me = ref.watch(currentUserProvider);
    final palette = context.palette;
    final theme = Theme.of(context);

    // Geri tuşu: yığın varsa oraya (Keşfet/Dükkân/arama), yoksa Ana
    // Sayfa'ya. Derin bağlantıyla açılan ürün detayında yığın boştur ve
    // sarmalayıcı olmadan geri tuşu uygulamayı küçültürdü.
    return MainTabScope(
      tab: MainTab.explore,
      child: Scaffold(
      appBar: const GradientAppBar(
        title: 'Ürün',
        icon: Icons.inventory_2_outlined,
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          title: 'Yüklenemedi',
          message: 'Ürün bilgisi alınamadı.',
          onRetry: () => ref.invalidate(productProvider(productId)),
        ),
        data: (p) {
          if (p == null ||
              (!p.isLiveInDiscover && me?.uid != p.ownerUid)) {
            return const ErrorView(
              title: 'Ürün bulunamadı',
              message: 'Kaldırılmış, stokta yok veya yayında değil.',
              icon: Icons.inventory_2_outlined,
            );
          }
          final cat = ProductCategory.label(p.categoryCode);
          final isMine = me?.uid == p.ownerUid;

          return ResponsiveCenter(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (p.photos.isEmpty)
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.image_outlined,
                        size: 48, color: palette.inkMuted),
                  )
                else
                  _PhotoGallery(photos: p.photos),
                const SizedBox(height: 16),
                Text(
                  p.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.priceLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(p.condition.labelTR)),
                    Chip(label: Text(cat)),
                    Chip(label: Text(p.placeLabel)),
                    if (p.status != ProductStatus.active)
                      Chip(
                        label: Text(p.status.labelTR),
                        backgroundColor: palette.surfaceMuted,
                      ),
                  ],
                ),
                if (p.moderationHidden && isMine) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: palette.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Bu ürün yönetim veya hesap kısıtı nedeniyle '
                        'Keşfet’te gizli. Durum yayında olabilir.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Açıklama',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(p.description, style: theme.textTheme.bodyMedium),
                if (p.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: p.tags
                        .map((t) => Chip(
                              label: Text('#$t'),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(
                    name: p.ownerName,
                    photo: p.ownerPhotoUrl,
                    size: 40,
                  ),
                  title: Text(p.ownerName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Satıcı (usta)'),
                  trailing: IconButton(
                    tooltip: 'Usta profili',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () =>
                        context.push(RoutePaths.artisanProfile(p.ownerUid)),
                  ),
                ),
                const SizedBox(height: 12),
                if (isMine)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push(RoutePaths.productEdit(p.id)),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Ürünü düzenle'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _contact(context, ref, p),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Sohbet başlat'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: me == null
                        ? () => context.push(RoutePaths.login)
                        : () => showReportSheet(
                              context,
                              ref,
                              target: ReportTarget.product,
                              targetId: p.id,
                              reportedUid: p.ownerUid,
                            ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Ürünü şikayet et'),
                  ),
                ],
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

/// Foto galerisi: kaydırılabilir sayfalar + altta nokta göstergesi.
class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.photos.length;
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppImage(
                handle: widget.photos[i],
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: active ? 0.95 : 0.55),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

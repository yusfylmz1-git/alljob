import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_role.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/chat/data/chat_providers.dart';
import '../router/route_paths.dart';
import '../theme/app_colors.dart';
import 'brand_mark.dart';

/// ☰ menü düğmesi (hero başlıklarında kullanılır). Karşı moda okunmamış mesaj
/// düştüyse üzerinde küçük kırmızı nokta gösterir — kullanıcı hangi modda
/// olursa olsun diğer taraftaki mesajı fark eder.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossUnread = ref.watch(otherModeUnreadProvider);
    return IconButton(
      tooltip: 'Menü',
      onPressed: () => Scaffold.of(context).openDrawer(),
      icon: Badge(
        isLabelVisible: crossUnread > 0,
        smallSize: 9,
        backgroundColor: AppColors.danger,
        child: Icon(Icons.menu_rounded, color: color),
      ),
    );
  }
}

/// Sol üst hamburger menü — moda özgü özellikler burada yaşar; alt barda
/// yalnızca ortak sekmeler (Keşfet/Mesajlar/Profil) kalır.
///
/// İçerik duruma göre değişir:
/// - Misafir: Giriş Yap / Kayıt Ol.
/// - Müşteri modu: İş İlanı Ver, İlanlarım, Favorilerim (+ usta profili varsa
///   Usta Moduna Geç, yoksa Hizmet Vermeye Başla).
/// - Usta modu: Hizmetlerim, İletişimlerim, Bildirimler, Premium, Profili
///   Düzenle, Müşteri Moduna Geç.
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  /// Drawer'ı kapatıp sayfayı üste açar (geri oku hub'a döner).
  void _open(BuildContext context, String path) {
    Navigator.pop(context);
    context.push(path);
  }

  Future<void> _switchMode(
      BuildContext context, WidgetRef ref, UserRole mode) async {
    // Drawer async işlem sonunda kapanmış olabilir; router'ı önce yakala.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await ref.read(authControllerProvider.notifier).setActiveMode(mode);
    if (ok) {
      router.go(mode == UserRole.artisan ? RoutePaths.panel : RoutePaths.home);
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Mod değiştirilemedi, tekrar deneyin.')));
    }
  }

  Future<void> _becomeArtisan(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hizmet Vermeye Başla'),
        content: const Text(
            'Hesabınıza bir usta profili eklenecek. Meslek ve hizmet '
            'bölgenizi belirledikten sonra müşteriler sizi bulabilir. '
            'İstediğiniz zaman Müşteri Moduna geri dönebilirsiniz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Başla')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(authControllerProvider.notifier).becomeArtisan();
    if (ok) {
      router.go(RoutePaths.panelEdit);
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(AuthException.unknown.message)));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(authControllerProvider.notifier).signOut();
    router.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    // Karşı moda düşen okunmamışlar → mod geçiş satırında kırmızı rozet.
    final crossUnread = ref.watch(otherModeUnreadProvider);
    final crossBadge = crossUnread > 0
        ? Badge(
            label: Text('$crossUnread'),
            backgroundColor: AppColors.danger,
          )
        : null;

    return NavigationDrawer(
      children: [
        // Başlık: marka + kullanıcı kimliği.
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null
                          ? 'Usta Cepte'
                          : (user.displayName.isEmpty
                              ? 'Kullanıcı'
                              : user.displayName),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      user == null
                          ? 'Hoş geldiniz'
                          : (user.isArtisan ? 'Usta Modu' : 'Müşteri Modu'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- Misafir ---
        if (user == null) ...[
          ListTile(
            leading: const Icon(Icons.login_rounded),
            title: const Text('Giriş Yap'),
            onTap: () => _open(context, RoutePaths.login),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('Kayıt Ol'),
            onTap: () => _open(context, RoutePaths.register),
          ),
        ]

        // --- Müşteri modu ---
        else if (!user.isArtisan) ...[
          // İlanlarım artık alt barda ("İlanlarım" sekmesi).
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('İş İlanı Ver'),
            onTap: () => _open(context, RoutePaths.newJob),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Favorilerim'),
            onTap: () => _open(context, RoutePaths.favorites),
          ),
          const Divider(indent: 16, endIndent: 16),
          if (user.hasArtisanProfile)
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Usta Moduna Geç'),
              trailing: crossBadge,
              onTap: () => _switchMode(context, ref, UserRole.artisan),
            )
          else
            ListTile(
              leading: const Icon(Icons.handyman_outlined),
              title: const Text('Hizmet Vermeye Başla'),
              subtitle: const Text('Usta profili oluşturun'),
              onTap: () => _becomeArtisan(context, ref),
            ),
        ]

        // --- Usta modu ---
        else ...[
          // Hizmetlerim (yakındaki işler) artık alt barda ("İşler" sekmesi).
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('İletişimlerim'),
            onTap: () => _open(context, RoutePaths.panelOffers),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Bildirimler'),
            onTap: () => _open(context, RoutePaths.panelNotifications),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Premium'),
            onTap: () => _open(context, RoutePaths.panelPremium),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Profili Düzenle'),
            onTap: () => _open(context, RoutePaths.panelEdit),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Müşteri Moduna Geç'),
            trailing: crossBadge,
            onTap: () => _switchMode(context, ref, UserRole.customer),
          ),
        ],

        // Çıkış (oturum varsa).
        if (user != null)
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Çıkış Yap',
                style: TextStyle(color: AppColors.danger)),
            onTap: () => _signOut(context, ref),
          ),
      ],
    );
  }
}

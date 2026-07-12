import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_role.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/chat/data/chat_providers.dart';
import '../router/route_paths.dart';
import '../theme/accent_options.dart';
import '../theme/accent_state.dart';
import '../theme/app_palette.dart';
import '../theme/theme_mode_state.dart';
import '../utils/snackbar_helper.dart';
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
        backgroundColor: context.palette.danger,
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
    // Drawer async işlem sonunda kapanmış olabilir; kalıcı bağlamları
    // (router + kök navigator) önce yakala.
    final router = GoRouter.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final ok =
        await ref.read(authControllerProvider.notifier).setActiveMode(mode);
    if (ok) {
      // Mod geçişi sonrası birleşik profil sayfası — kullanıcı yeni modun
      // menüsünü tek yerde görür.
      router.go(RoutePaths.profile);
    } else if (nav.mounted) {
      nav.context.showError('Mod değiştirilemedi, tekrar deneyin.');
    }
  }

  Future<void> _becomeArtisan(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
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
    } else if (nav.mounted) {
      nav.context.showError(AuthException.unknown.message);
    }
  }

  /// Görünüm ayarları: tema (Sistem/Açık/Koyu) + mod başına vurgu rengi.
  /// Seçimler anında uygulanır ve cihazda saklanır (sonraki açılışta korunur).
  Future<void> _pickTheme(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AppearanceSheet(),
    );
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
            backgroundColor: context.palette.danger,
          )
        : null;

    return NavigationDrawer(
      children: [
        // Başlık: marka + kullanıcı kimliği.
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: context.palette.heroGradient,
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
            title: const Text('Takip Ettiklerim'),
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
          // Premium ve Profili Düzenle artık birleşik profil sayfasında —
          // menüde tekrar edilmez (mükerrer giriş kafa karıştırıyordu).
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Müşteri Moduna Geç'),
            trailing: crossBadge,
            onTap: () => _switchMode(context, ref, UserRole.customer),
          ),
        ],

        const Divider(indent: 16, endIndent: 16),

        // Görünüm (tema) — herkes için (misafir dâhil).
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Görünüm'),
          subtitle: Text(themeModeLabel(ref.watch(themeModeProvider))),
          onTap: () => _pickTheme(context, ref),
        ),

        // Çıkış (oturum varsa).
        if (user != null)
          ListTile(
            leading:
                Icon(Icons.logout_rounded, color: context.palette.danger),
            title: Text('Çıkış Yap',
                style: TextStyle(color: context.palette.danger)),
            onTap: () => _signOut(context, ref),
          ),
      ],
    );
  }
}

/// Görünüm alt sayfası: tema modu (Sistem/Açık/Koyu) + mod başına vurgu rengi.
/// Her dokunuş anında uygulanır (canlı önizleme) ve cihazda saklanır.
class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final mode = ref.watch(themeModeProvider);
    final customerId = ref.watch(customerAccentIdProvider);
    final artisanId = ref.watch(artisanAccentIdProvider);

    void setMode(ThemeMode? m) {
      if (m == null) return;
      ref.read(themeModeProvider.notifier).state = m;
      saveThemeMode(m);
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child:
                  Text('Görünüm', style: theme.textTheme.titleMedium),
            ),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: setMode,
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Sistem'),
                    subtitle: Text('Cihazın ayarını izler'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Açık'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Koyu'),
                  ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Text('Renk', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Her mod için ayrı bir vurgu rengi seç.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
            ),
            _AccentRow(
              label: 'Müşteri modu',
              currentId: customerId,
              onPick: (id) {
                ref.read(customerAccentIdProvider.notifier).state = id;
                saveCustomerAccentId(id);
              },
            ),
            _AccentRow(
              label: 'Usta modu',
              currentId: artisanId,
              onPick: (id) {
                ref.read(artisanAccentIdProvider.notifier).state = id;
                saveArtisanAccentId(id);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Bir mod için 4 renk örneği (swatch) satırı.
class _AccentRow extends StatelessWidget {
  const _AccentRow({
    required this.label,
    required this.currentId,
    required this.onPick,
  });

  final String label;
  final String currentId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: context.palette.inkMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final o in kAccentOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _Swatch(
                    option: o,
                    selected: o.id == currentId,
                    onTap: () => onPick(o.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tek bir renk örneği; seçiliyse çerçeve + tik gösterir.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.labelTR} rengi',
      child: Tooltip(
        message: option.labelTR,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: option.swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? context.palette.ink : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: option.swatch.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}

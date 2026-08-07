import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/chat/data/chat_providers.dart';
import '../constants/app_constants.dart';
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
///
/// Kompakt: varsayılan IconButton 48px padding metin satırını içeri iter;
/// [visualDensity] + dar padding ile marka/başlık hizasına yaklaşır.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossUnread = ref.watch(otherModeUnreadProvider);
    return IconButton(
      tooltip: 'Menü',
      onPressed: () => Scaffold.of(context).openDrawer(),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(8),
      ),
      icon: Badge(
        isLabelVisible: crossUnread > 0,
        smallSize: 9,
        backgroundColor: context.palette.danger,
        child: Icon(Icons.menu_rounded, color: color, size: 24),
      ),
    );
  }
}

/// Sol üst hamburger menü — moda özgü özellikler burada yaşar; alt barda
/// yalnızca ortak sekmeler (Keşfet/Mesajlar/Profil) kalır.
///
/// İçerik duruma göre değişir:
/// - Misafir: Google ile giriş.
/// - Oturum açık: İş İlanı Ver, Takip Ettiklerim (+ usta modunda İlanlarım
///   ve Bildirimler), Ajanda, Hesap Ayarları, Yardım, Görünüm, Çıkış.
///
/// MOD GEÇİŞİ BURADA YOK: profildeki "Usta modu" anahtarından yapılır.
/// İki ayrı yer olması hangi modda olunduğunu belirsizleştiriyordu (B-16).
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  /// Drawer'ı kapatıp sayfayı üste açar (geri oku hub'a döner).
  void _open(BuildContext context, String path) {
    Navigator.pop(context);
    context.push(path);
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
    // NOT: Karşı moddaki okunmamış rozeti (`otherModeUnreadProvider`) burada
    // mod geçiş satırında duruyordu. O satırlar kalktı; rozet profildeki
    // "Usta modu" anahtarına taşındı (bkz. _ArtisanModeSwitch).

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
              const BrandMark(size: 88),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null
                          ? AppConstants.appName
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
            title: const Text('Google ile giriş'),
            onTap: () => _open(context, RoutePaths.login),
          ),
        ]

        // --- Oturum açmış kullanıcı (rol ayrımı YOK) ---
        //
        // "Usta Moduna Geç / Müşteri Moduna Geç" satırları KALDIRILDI:
        // mod değişimi artık profildeki anahtardan yapılıyor, iki ayrı yer
        // olması karışıklık yaratıyordu (B-16).
        else ...[
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

          // Usta modülleri — yalnız anahtar açıkken.
          if (user.isArtisan) ...[
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('İlanlarım'),
              subtitle: const Text('Verdiğiniz hizmet ilanları'),
              onTap: () => _open(context, RoutePaths.myJobs),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Bildirimler'),
              onTap: () => _open(context, RoutePaths.panelNotifications),
            ),
          ],

          // Henüz usta profili yoksa dönüşüm çağrısı.
          if (!user.hasArtisanProfile) ...[
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.handyman_outlined),
              title: const Text('Usta olarak devam et'),
              subtitle: const Text('Meslek ve bölge ekle, iş almaya başla'),
              onTap: () => _becomeArtisan(context, ref),
            ),
          ],
        ],

        const Divider(indent: 16, endIndent: 16),

        // Ajanda — kişisel randevu/hatırlatma. Profil ekranından buraya
        // taşındı: profil İÇERİK gösterir (ilanlar, işler, takip), kişisel
        // araçlar menüde durur.
        if (user != null)
          ListTile(
            leading: const Icon(Icons.checklist_rounded),
            title: const Text('Ajanda'),
            subtitle: const Text('Randevu ve hatırlatmalar'),
            onTap: () => _open(context, RoutePaths.tracking),
          ),

        // Hesap Ayarları — profil ekranından buraya taşındı (sadeleştirme):
        // doğrulama, üyelik, hesap silme. Profil artık içerik gösterir.
        if (user != null)
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Hesap Ayarları'),
            subtitle: const Text('Doğrulama, üyelik, hesap'),
            onTap: () => _open(context, RoutePaths.accountSettings),
          ),

        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text('Yardım'),
          subtitle: const Text('SSS ve destek'),
          onTap: () => _open(context, RoutePaths.help),
        ),

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
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (final o in kAccentOptions)
                _Swatch(
                  option: o,
                  selected: o.id == currentId,
                  onTap: () => onPick(o.id),
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


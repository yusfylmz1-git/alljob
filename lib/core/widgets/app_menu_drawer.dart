import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/app_user.dart';
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

/// Menü alt başlığı — aktif mod değil, açık profiller.
String _profileSubtitle(AppUser user) {
  final parts = <String>[
    if (user.hasArtisanProfile) 'Usta',
    if (user.hasShopProfile) 'Mağaza',
  ];
  if (parts.isEmpty) return 'Hesap';
  return parts.join(' · ');
}

/// ☰ menü düğmesi (hero başlıklarında kullanılır). Karşı moda okunmamış mesaj
/// düştüyse üzerinde küçük kırmızı nokta gösterir — kullanıcı hangi modda
/// olursa olsun diğer taraftaki mesajı fark eder.
///
/// Kompakt: varsayılan IconButton 48px padding metin satırını içeri iter;
/// [visualDensity] + dar padding ile marka/başlık hizasına yaklaşır.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key, this.color});

  /// İkon rengi. Verilmezse marka rengi (`palette.primary`) kullanılır.
  ///
  /// Eskiden varsayılan sabit `Colors.white`'tı; profil gibi hero gradyanı
  /// OLMAYAN ekranlarda beyaz zemine beyaz ikon düşüyor ve menü
  /// görünmüyordu. Gradyan üstünde duran ekranlar beyazı AÇIKÇA verir.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossUnread = ref.watch(otherModeUnreadProvider);
    final iconColor = color ?? context.palette.primary;
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
        child: Icon(Icons.menu_rounded, color: iconColor, size: 24),
      ),
    );
  }
}

/// Sol üst hamburger menü — moda özgü özellikler burada yaşar; alt barda
/// yalnızca ortak sekmeler (Keşfet/Mesajlar/Profil) kalır.
///
/// İçerik duruma göre değişir:
/// - Misafir: Google ile giriş.
/// - Oturum açık: İş İlanı Ver (+ usta modunda İlanlarım), Hesap Ayarları,
///   Yardım, Görünüm, Çıkış.
///
/// Takip ve bildirimler BURADA YOK: takip profildeki sayaçtan, bildirimler
/// her ekranın sağ üstündeki zilden açılır.
///
/// MOD GEÇİŞİ YOK: yetenek hasArtisanProfile / hasShopProfile ile.
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  /// Drawer'ı kapatıp sayfayı üste açar (geri oku hub'a döner).
  void _open(BuildContext context, String path) {
    Navigator.pop(context);
    context.push(path);
  }

  /// Başlıktaki logo → ana sayfa. Önce çekmece kapanır, sonra geçilir.
  ///
  /// [_open]'dan farklı olarak `go` kullanır: ana sayfa yığının DİBİ,
  /// üstüne itilmemeli. `push` olsaydı geri tuşu kullanıcıyı ana sayfadan
  /// bir önceki sekmeye geri atardı.
  ///
  /// Zaten ana sayfadaysak yalnız çekmece kapanır — gereksiz geçiş yok.
  void _goHome(BuildContext context) {
    final zatenAnaSayfa =
        GoRouterState.of(context).uri.path == RoutePaths.home;
    Navigator.pop(context);
    if (!zatenAnaSayfa) context.go(RoutePaths.home);
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
    if (confirmed != true || !context.mounted) return;

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
    return NavigationDrawer(
      children: [
        // Başlık: marka + kullanıcı kimliği.
        //
        // Bandın yüksekliğini LOGO belirler (satır yüksekliği ondan gelir),
        // o yüzden daraltma logo + dikey padding üzerinden yapılır:
        // logo 88 → 72, dikey iç boşluk 16 → 10. Yatayda 16 kalıyor,
        // metin kenara yapışmasın.
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: context.palette.heroGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Logo → ana sayfa. Çekmece kapanır, sonra geçilir.
              Semantics(
                button: true,
                label: 'Ana sayfa',
                child: Tooltip(
                  message: 'Ana sayfa',
                  child: InkWell(
                    onTap: () => _goHome(context),
                    customBorder: const CircleBorder(),
                    child: const BrandMark(size: 72),
                  ),
                ),
              ),
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
                          : _profileSubtitle(user),
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

        // --- Oturum açmış kullanıcı (aktif mod switch'i yok) ---
        else ...[
          // "İş İlanı Ver" satırı KALDIRILDI (2026-08-09): Keşfet'in üst
          // barındaki ikon tek giriş oldu. Aynı yere giden üçüncü kapıydı.
          //
          // "Takip Ettiklerim" ve "Bildirimler" satırları KALDIRILDI
          // (2026-08-08): ikisinin de daha yakın girişi var — takip
          // profildeki sayaçtan, bildirimler her ekranın sağ üstündeki
          // zilden açılıyor. Menüde ikinci kez durmaları gereksizdi.
          //
          // Ayrıca "Bildirimler" satırı KIRIKTI: `/panel/notifications`
          // rotası router'da hiç tanımlı değil, dokunan kullanıcı hata
          // sayfasına düşüyordu.

          // İLANLARIM — HER İKİ MODDA (2026-08-09). Eskiden `user.isArtisan`
          // koşuluna bağlıydı; ilanı VEREN müşteridir, dolayısıyla asıl
          // sahibi kendi ilanlarına hiçbir yerden ulaşamıyordu. Profildeki
          // "Profilime bak" düğmesi de bunun yerine buraya bağlandı.
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('İlanlarım'),
            subtitle: const Text('Verdiğiniz iş ilanları'),
            onTap: () => _open(context, RoutePaths.myJobs),
          ),

          // TALEPLERİM (2026-08-20) — ürün talebi veren kullanıcının kendi
          // taleplerine ulaşabildiği TEK yer. Talepler Keşfet'te listelenmez
          // (kitlesi satıcılardır) ve artık "İlanlarım"da da görünmez; bu
          // satır olmadan kullanıcı kendi talebini hiçbir yerden göremezdi.
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Taleplerim'),
            subtitle: const Text('Verdiğiniz ürün talepleri'),
            onTap: () => _open(context, RoutePaths.myProductRequests),
          ),

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

        // Menü dibi: site bağlantısı + telif satırı.
        const Divider(indent: 16, endIndent: 16),
        const _DrawerFooter(),
      ],
    );
  }
}

/// Çekmecenin en altı: web sitesi bağlantısı ve telif satırı.
///
/// Site harici tarayıcıda açılır (uygulama içi web görünümü yok).
class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  Future<void> _openSite(BuildContext context) async {
    try {
      final ok = await launchUrl(
        Uri.parse(AppConstants.siteUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) context.showError('Bağlantı açılamadı.');
    } catch (_) {
      if (context.mounted) context.showError('Bağlantı açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => _openSite(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded,
                      size: 16, color: palette.primary),
                  const SizedBox(width: 6),
                  Text(
                    AppConstants.siteLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© ${DateTime.now().year} ${AppConstants.appName}\n'
            'Tüm hakları saklıdır.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Görünüm: tema (Sistem/Açık/Koyu) + tek vurgu rengi.
class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final mode = ref.watch(themeModeProvider);
    final accentId = ref.watch(accentIdProvider);

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
              child: Text('Vurgu rengi', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Düğmeler, linkler ve üst şerit bu rengi kullanır.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  for (final o in kAccentOptions)
                    _Swatch(
                      option: o,
                      selected: o.id == accentId,
                      onTap: () {
                        ref.read(accentIdProvider.notifier).state = o.id;
                        saveAccentId(o.id);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
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


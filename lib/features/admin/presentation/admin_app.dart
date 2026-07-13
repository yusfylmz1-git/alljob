import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_state.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_providers.dart';
import 'admin_audit_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_roster_screen.dart';
import 'admin_users_screen.dart';

/// AYRI admin web uygulamasının kökü. Tüketici uygulamasından TAMAMEN bağımsız
/// çalışır (kendi giriş noktası `main_admin.dart`, kendi Hosting sitesi); admin
/// kodu son kullanıcının indirdiği binary'e HİÇ girmez. Aynı Firebase projesi,
/// aynı modeller/kurallar/CF'ler paylaşılır.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Usta Cepte — Yönetim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const _AdminGate(),
    );
  }
}

/// Oturum + yetki kapısı: yükleniyor → giriş yok → yetkisiz → yönetici paneli.
class _AdminGate extends ConsumerWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _AdminLoginScreen(),
      data: (user) {
        if (user == null) return const _AdminLoginScreen();
        if (!user.isAdmin) return const _AccessDeniedScreen();
        return const _AdminHomeScreen();
      },
    );
  }
}

/// Yönetici ana kabuğu: alt gezinmeyle Şikayetler ⇄ Anlaşmazlıklar. Her sekme
/// kendi ekranını (kendi üst barı + çıkış düğmesiyle) taşır; sekmeler
/// [IndexedStack] ile canlı tutulur (geçişte akışlar yeniden kurulmaz).
/// Rozetler açık şikayet / açık anlaşmazlık sayısını gösterir.
class _AdminHomeScreen extends ConsumerStatefulWidget {
  const _AdminHomeScreen();

  @override
  ConsumerState<_AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<_AdminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final openReports = ref.watch(openReportCountProvider);
    final openDisputes = ref.watch(openDisputeCountProvider);
    // Kadro sekmesi yalnız süper yöneticiye (rol atama yetkisi onda).
    final isSuper = ref.watch(isSuperAdminProvider);

    final pages = <Widget>[
      const AdminReportsScreen(),
      const AdminDisputesScreen(),
      const AdminUsersScreen(),
      if (isSuper) const AdminRosterScreen(),
      if (isSuper) const AdminAuditScreen(),
    ];
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: _BadgeIcon(icon: Icons.flag_outlined, count: openReports),
        selectedIcon: _BadgeIcon(icon: Icons.flag, count: openReports),
        label: 'Şikayetler',
      ),
      NavigationDestination(
        icon: _BadgeIcon(icon: Icons.gavel_outlined, count: openDisputes),
        selectedIcon: _BadgeIcon(icon: Icons.gavel, count: openDisputes),
        label: 'Anlaşmazlıklar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.manage_accounts_outlined),
        selectedIcon: Icon(Icons.manage_accounts),
        label: 'Kullanıcılar',
      ),
      if (isSuper)
        const NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield),
          label: 'Kadro',
        ),
      if (isSuper)
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Denetim',
        ),
    ];
    // Rol düşerse (superadmin→moderatör) seçili index taşabilir; kırp.
    final safeIndex = _index.clamp(0, pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}

/// Sayaç > 0 ise ikonun üstünde küçük rozet.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}

/// Yönetici girişi (e-posta + şifre). Tüketici giriş ekranından bağımsız,
/// sade bir form; aynı [AuthController.] kimlik akışını kullanır.
class _AdminLoginScreen extends ConsumerStatefulWidget {
  const _AdminLoginScreen();

  @override
  ConsumerState<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<_AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // login() hata fırlatmaz: bool döndürür, hatayı controller state'ine koyar.
    final ok = await ref.read(authControllerProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      // Başarıda _AdminGate auth akışıyla otomatik ilerler.
      return;
    }
    final err = ref.read(authControllerProvider).error;
    setState(() {
      _busy = false;
      _error =
          err is AuthException ? err.message : 'Giriş yapılamadı. Tekrar deneyin.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 56, color: palette.primary),
                  const SizedBox(height: 16),
                  Text('Yönetim Paneli',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Yalnızca yetkili hesaplar erişebilir.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.inkMuted)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Geçerli bir e-posta girin'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Şifre'),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'En az 6 karakter'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: palette.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Giriş Yap',
                    isLoading: _busy,
                    onPressed: _busy ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Oturum açık ama yetkisiz. Bootstrap izinli e-posta ise "Yönetici erişimini
/// etkinleştir" ile kendini yükseltebilir; aksi halde yalnız çıkış.
class _AccessDeniedScreen extends ConsumerStatefulWidget {
  const _AccessDeniedScreen();

  @override
  ConsumerState<_AccessDeniedScreen> createState() =>
      _AccessDeniedScreenState();
}

class _AccessDeniedScreenState extends ConsumerState<_AccessDeniedScreen> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final ok =
          await ref.read(authControllerProvider.notifier).claimAdminAccess();
      if (!mounted) return;
      if (!ok) context.showError('Yönetici erişimi verilemedi.');
      // Başarıda auth akışı güncellenir → _AdminGate paneli açar.
    } on AuthException catch (e) {
      if (!mounted) return;
      context.showError(e.message);
    } catch (_) {
      if (!mounted) return;
      context.showError('İşlem başarısız oldu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: palette.warning),
                const SizedBox(height: 16),
                Text('Yetkiniz yok',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('$email hesabı yönetici değil.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: palette.inkMuted)),
                const SizedBox(height: 24),
                if (_busy)
                  const CircularProgressIndicator()
                else ...[
                  // Bootstrap denemesi: sunucu izin listesinde değilse reddeder.
                  OutlinedButton.icon(
                    onPressed: _enable,
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text('Yönetici erişimini etkinleştir'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('Çıkış Yap'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

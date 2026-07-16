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
import 'admin_artisans_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_chrome.dart';
import 'admin_dashboard_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_jobs_screen.dart';
import 'admin_platform_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_reviews_screen.dart';
import 'admin_roster_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_support_screen.dart';
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
      title: 'Ustasından — Yönetim',
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

/// Yönetici kabuğu (v2): geniş ekranda NavigationRail, dar ekranda alt bar.
/// Sayfalar [IndexedStack] ile canlı kalır. Rozetler şikayet/anlaşmazlık.
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
    final isSuper = ref.watch(isSuperAdminProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';
    final wide = MediaQuery.sizeOf(context).width >= 900;

    // Bilgi mimarisi: Operasyon → Kişiler → İletişim → Platform → Sistem
    final pages = <Widget>[
      AdminDashboardScreen(onOpenSection: (i) => setState(() => _index = i)),
      const AdminReportsScreen(),
      const AdminDisputesScreen(),
      const AdminUsersScreen(),
      const AdminArtisansScreen(),
      const AdminJobsScreen(),
      const AdminReviewsScreen(),
      const AdminSupportScreen(),
      const AdminBroadcastScreen(),
      const AdminPlatformScreen(),
      if (isSuper) const AdminRosterScreen(),
      if (isSuper) const AdminAuditScreen(),
      if (isSuper) const AdminSettingsScreen(),
    ];
    final destinations = <_NavItem>[
      const _NavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Özet',
      ),
      _NavItem(
        icon: Icons.flag_outlined,
        selectedIcon: Icons.flag,
        label: 'Şikayetler',
        badge: openReports,
      ),
      _NavItem(
        icon: Icons.gavel_outlined,
        selectedIcon: Icons.gavel,
        label: 'Anlaşmazlıklar',
        badge: openDisputes,
      ),
      const _NavItem(
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
        label: 'Kullanıcılar',
      ),
      const _NavItem(
        icon: Icons.handyman_outlined,
        selectedIcon: Icons.handyman,
        label: 'Ustalar',
      ),
      const _NavItem(
        icon: Icons.work_outline,
        selectedIcon: Icons.work,
        label: 'İlanlar',
      ),
      const _NavItem(
        icon: Icons.rate_review_outlined,
        selectedIcon: Icons.rate_review,
        label: 'Yorumlar',
      ),
      const _NavItem(
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        label: 'Destek',
      ),
      const _NavItem(
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        label: 'Bildirim',
      ),
      const _NavItem(
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        label: 'Platform',
      ),
      if (isSuper)
        const _NavItem(
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield,
          label: 'Kadro',
        ),
      if (isSuper)
        const _NavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Denetim',
        ),
      if (isSuper)
        const _NavItem(
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune,
          label: 'Sistem',
        ),
    ];

    final safeIndex = _index.clamp(0, pages.length - 1);
    void select(int i) => setState(() => _index = i);

    final stack = IndexedStack(index: safeIndex, children: pages);
    final roleLabel = isSuper ? 'Superadmin' : 'Moderatör';

    if (wide) {
      final extended = MediaQuery.sizeOf(context).width >= 1180;
      return Scaffold(
        backgroundColor: AdminChrome.surface,
        body: Row(
          children: [
            _AdminSideRail(
              extended: extended,
              destinations: destinations,
              selectedIndex: safeIndex,
              onSelect: select,
              email: email,
              roleLabel: roleLabel,
              onSignOut: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminTopBar(
                    section: destinations[safeIndex].label,
                    email: email,
                    roleLabel: roleLabel,
                    onSignOut: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                  Expanded(child: stack),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AppBar(
        backgroundColor: AdminChrome.topBarBg,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ustasından Ops',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            Text(
              destinations[safeIndex].label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: stack,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: select,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: d.badge > 0
                  ? _BadgeIcon(icon: d.icon, count: d.badge)
                  : Icon(d.icon),
              selectedIcon: d.badge > 0
                  ? _BadgeIcon(icon: d.selectedIcon, count: d.badge)
                  : Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Koyu yan menü — operasyon konsolu görünümü.
class _AdminSideRail extends StatelessWidget {
  const _AdminSideRail({
    required this.extended,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.email,
    required this.roleLabel,
    required this.onSignOut,
  });

  final bool extended;
  final List<_NavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String email;
  final String roleLabel;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 248.0 : 76.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: AdminChrome.railBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 16 : 12, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminChrome.railSelected.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminChrome.railSelected.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(Icons.shield_moon_outlined,
                        color: AdminChrome.railSelected, size: 20),
                  ),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ustasından',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Ops Console',
                            style: TextStyle(
                              color: AdminChrome.railMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (extended)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'alljob1 · production',
                    style: TextStyle(
                      color: AdminChrome.railMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: destinations.length,
                itemBuilder: (context, i) {
                  final d = destinations[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: selected
                          ? AdminChrome.railSelectedBg
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelect(i),
                        child: Tooltip(
                          message: extended ? '' : d.label,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: extended ? 12 : 0,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: extended
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                _BadgeIcon(
                                  icon: selected ? d.selectedIcon : d.icon,
                                  count: d.badge,
                                  color: selected
                                      ? AdminChrome.railSelected
                                      : AdminChrome.railMuted,
                                ),
                                if (extended) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      d.label,
                                      style: TextStyle(
                                        color: selected
                                            ? AdminChrome.railFg
                                            : AdminChrome.railMuted,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  if (d.badge > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        d.badge > 99 ? '99+' : '${d.badge}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  if (extended && email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AdminChrome.railSelected.withValues(alpha: 0.2),
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: AdminChrome.railSelected,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminChrome.railFg,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  roleLabel,
                                  style: const TextStyle(
                                    color: AdminChrome.railMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(extended ? 'Çıkış yap' : ''),
                      style: TextButton.styleFrom(
                        foregroundColor: AdminChrome.railMuted,
                        padding: EdgeInsets.symmetric(
                          horizontal: extended ? 12 : 0,
                          vertical: 10,
                        ),
                      ),
                    ),
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

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.section,
    required this.email,
    required this.roleLabel,
    required this.onSignOut,
  });

  final String section;
  final String email;
  final String roleLabel;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AdminChrome.cardBorder),
          ),
        ),
        child: Row(
          children: [
            Text(
              section,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Spacer(),
            if (email.isNotEmpty)
              Text(
                '$roleLabel · $email',
                style: TextStyle(
                  color: context.palette.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Çıkış',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Sayaç > 0 ise ikonun üstünde küçük rozet.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    this.color,
  });
  final IconData icon;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: 22);
    if (count <= 0) return iconWidget;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: iconWidget,
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
      body: Row(
        children: [
          // Sol marka paneli (geniş ekran)
          if (MediaQuery.sizeOf(context).width >= 840)
            Expanded(
              child: Container(
                color: AdminChrome.railBg,
                padding: const EdgeInsets.all(40),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_moon_outlined,
                        color: AdminChrome.railSelected, size: 40),
                    SizedBox(height: 20),
                    Text(
                      'Ustasından\nOps Console',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Şikayet, anlaşmazlık, kullanıcı ve platform\n'
                      'moderasyonu için güvenli yönetim alanı.',
                      style: TextStyle(
                        color: AdminChrome.railMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Yönetici girişi',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Yalnız yetkili personel. Tüm işlemler denetim kaydına yazılır.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: palette.inkMuted, height: 1.35),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Geçerli bir e-posta girin'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'En az 6 karakter'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: TextStyle(
                                  color: palette.danger, fontSize: 13)),
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
          ),
        ],
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

  Future<void> _acceptInvite() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminInviteRepositoryProvider).accept();
      if (!mounted) return;
      // CF claim yazar + refresh token iptal eder → yeniden giriş gerekir.
      context.showSuccess(
          'Davet kabul edildi. Lütfen tekrar giriş yapın.');
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      if (!mounted) return;
      context.showError(
          'Davet kabul edilemedi (bekleyen davet yok veya süresi dolmuş).');
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
                  OutlinedButton.icon(
                    onPressed: _enable,
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text('Yönetici erişimini etkinleştir'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _acceptInvite,
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Daveti kabul et'),
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

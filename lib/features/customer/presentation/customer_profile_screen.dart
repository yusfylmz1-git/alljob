import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/job.dart';
import '../../../data/models/user_role.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../jobs/data/job_providers.dart';

/// Müşteri profil sayfası (#8): temel bilgiler + kullanım istatistikleri.
class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHero(user: user),
                ResponsiveCenter(
                  maxWidth: 720,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatsCard(uid: user.uid),
                      const SizedBox(height: 14),
                      _ArtisanModeCard(user: user),
                      const SizedBox(height: 14),
                      _InfoCard(user: user),
                      const SizedBox(height: 14),
                      _SignOutCard(
                        onSignOut: () => ref
                            .read(authControllerProvider.notifier)
                            .signOut(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.profile),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: DrawerMenuButton(),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF13293F),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: user.profilePhotoUrl != null
                          ? AppImage(handle: user.profilePhotoUrl)
                          : Container(
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.isEmpty ? 'Müşteri' : name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kullanım istatistikleri — hepsi gerçek verilerden türetilir.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider(uid)).valueOrNull ?? const <Job>[];
    final favs = ref.watch(favoritesProvider(uid)).valueOrNull ?? const [];

    final active = jobs
        .where((j) =>
            j.effectiveStatus == JobStatus.open ||
            j.effectiveStatus == JobStatus.workerSelected ||
            j.effectiveStatus == JobStatus.inProgress)
        .length;
    final done = jobs
        .where((j) =>
            j.status == JobStatus.completed || j.status == JobStatus.rated)
        .length;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          _Stat(value: '${jobs.length}', label: 'Toplam İlan'),
          _divider(theme),
          _Stat(value: '$active', label: 'Aktif İlan'),
          _divider(theme),
          _Stat(value: '$done', label: 'Tamamlanan'),
          _divider(theme),
          _Stat(value: '${favs.length}', label: 'Favori'),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 34,
        color: theme.colorScheme.outlineVariant,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Tek hesap, çift rol: usta profili yoksa "Hizmet Vermeye Başla";
/// varsa "Usta Moduna Geç" (arayüz usta menüleriyle yeniden şekillenir).
class _ArtisanModeCard extends ConsumerWidget {
  const _ArtisanModeCard({required this.user});
  final AppUser user;

  Future<void> _becomeArtisan(BuildContext context, WidgetRef ref) async {
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

    final ok =
        await ref.read(authControllerProvider.notifier).becomeArtisan();
    if (!context.mounted) return;
    if (ok) {
      context.showSuccess(
          'Usta profiliniz açıldı. Şimdi meslek ve bölgenizi belirleyin.');
      context.go(RoutePaths.panelEdit);
    } else {
      final error = ref.read(authControllerProvider).error;
      context.showError(
          error is AuthException ? error.message : AuthException.unknown.message);
    }
  }

  Future<void> _switchToArtisan(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .setActiveMode(UserRole.artisan);
    if (!context.mounted) return;
    if (ok) {
      context.go(RoutePaths.panel);
    } else {
      context.showError(AuthException.unknown.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final hasProfile = user.hasArtisanProfile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppColors.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasProfile ? 'Usta Modu' : 'Usta mısınız?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasProfile
                ? 'Usta profiliniz hazır. Usta moduna geçerek işlerinizi ve '
                    'dükkânınızı yönetin.'
                : 'Hizmet vermeye başlayın: usta profilinizi oluşturun, '
                    'bölgenizdeki iş ilanlarını görün ve müşterilere ulaşın.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSecondaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () => hasProfile
                      ? _switchToArtisan(context, ref)
                      : _becomeArtisan(context, ref),
              icon: Icon(
                  hasProfile
                      ? Icons.swap_horiz_rounded
                      : Icons.handyman_outlined,
                  size: 18),
              label: Text(
                  hasProfile ? 'Usta Moduna Geç' : 'Hizmet Vermeye Başla'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Temel hesap bilgileri.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = DateFormat('MMMM yyyy', 'tr_TR').format(user.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hesap Bilgileri',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.person_outline,
              label: 'Ad Soyad',
              value: user.displayName.isEmpty ? '—' : user.displayName),
          const Divider(height: 20),
          _InfoRow(
              icon: Icons.mail_outline, label: 'E-posta', value: user.email),
          const Divider(height: 20),
          _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Üyelik',
              value: '$since itibarıyla üye'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const Spacer(),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Çıkış Yap'),
      onPressed: () {
        onSignOut();
        context.go(RoutePaths.home);
      },
    );
  }
}

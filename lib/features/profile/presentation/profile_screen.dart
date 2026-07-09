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
import '../../../data/local/mock_database.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
import '../../../data/models/user_role.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/phone_verification_sheet.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../jobs/data/job_providers.dart';

/// TEK birleşik profil sayfası (alt bar → Profil). Her iki modda da AYNI
/// sayfa açılır; içerik aktif moda göre şekillenir:
///  - Üstte kimlik (avatar + ad + mavi tik + e-posta),
///  - hemen altında NET mod anahtarı (Müşteri | Usta),
///  - altında gruplu, sade menü satırları (Uber/Airbnb ayarlar dili).
/// Eski kurgu (müşteride /profile, ustada /panel dashboard'u) iki farklı
/// "profil" hissi veriyordu — kullanıcı geri bildirimiyle birleştirildi.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : _Body(user: user),
      bottomNavigationBar: const MainBottomBar(current: MainTab.profile),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artisanMode = user.isArtisan;
    // Usta profili verisi yalnızca usta modunda gerekir (gereksiz okuma yok).
    final draft =
        artisanMode ? ref.watch(myProfileControllerProvider).valueOrNull : null;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(user: user, draft: draft),
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user.hasArtisanProfile) ...[
                _ModeSwitcher(user: user),
                const SizedBox(height: 20),
              ],
              if (artisanMode)
                _ArtisanSections(user: user, draft: draft)
              else
                _CustomerSections(user: user),
              const _SectionLabel('HESAP'),
              _AccountGroup(user: user),
              const SizedBox(height: 20),
              _Group(children: [
                _MenuRow(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.danger,
                  iconSurface: AppColors.danger.withValues(alpha: 0.10),
                  title: 'Çıkış Yap',
                  titleColor: AppColors.danger,
                  onTap: () async {
                    final router = GoRouter.of(context);
                    await ref.read(authControllerProvider.notifier).signOut();
                    router.go(RoutePaths.home);
                  },
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — kimlik: avatar + ad (+ mavi tik) + e-posta (+ ustada meslek)
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.user, required this.draft});
  final AppUser user;
  final MyProfileDraft? draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final photo = draft?.profilePhotoUrl ?? user.profilePhotoUrl;
    final profession = user.isArtisan && draft != null
        ? kProfessionNames[draft!.profile.profession]
        : null;

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
                      child: photo != null
                          ? AppImage(handle: photo)
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
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? 'Kullanıcı' : name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (user.phoneVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        size: 20, color: Color(0xFF60A5FA)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                profession != null ? '$profession · ${user.email}' : user.email,
                overflow: TextOverflow.ellipsis,
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

// ---------------------------------------------------------------------------
// Mod anahtarı — Müşteri | Usta (tek, belirgin, hep aynı yerde)
// ---------------------------------------------------------------------------

class _ModeSwitcher extends ConsumerWidget {
  const _ModeSwitcher({required this.user});
  final AppUser user;

  Future<void> _switch(
      BuildContext context, WidgetRef ref, UserRole mode) async {
    final ok =
        await ref.read(authControllerProvider.notifier).setActiveMode(mode);
    if (!context.mounted) return;
    if (!ok) {
      context.showError('Mod değiştirilemedi, tekrar deneyin.');
    }
    // Sayfadan ayrılmayız: içerik yeni moda göre kendini yeniler — kullanıcı
    // geçişin ne yaptığını gözüyle görür.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return SegmentedButton<UserRole>(
      segments: const [
        ButtonSegment(
          value: UserRole.customer,
          label: Text('Müşteri'),
          icon: Icon(Icons.person_search_outlined),
        ),
        ButtonSegment(
          value: UserRole.artisan,
          label: Text('Usta'),
          icon: Icon(Icons.handyman_outlined),
        ),
      ],
      selected: {user.activeMode},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        minimumSize: const Size(0, 46),
      ),
      onSelectionChanged: isLoading
          ? null
          : (selection) {
              final mode = selection.first;
              if (mode != user.activeMode) _switch(context, ref, mode);
            },
    );
  }
}

// ---------------------------------------------------------------------------
// Usta modu bölümleri
// ---------------------------------------------------------------------------

class _ArtisanSections extends ConsumerWidget {
  const _ArtisanSections({required this.user, required this.draft});
  final AppUser user;
  final MyProfileDraft? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = draft?.profile;
    final profileComplete = profile != null &&
        profile.profession.isNotEmpty &&
        profile.serviceAreas.isNotEmpty;
    final nearbyCount = ref.watch(nearbyJobsProvider).valueOrNull?.length ?? 0;
    final offers =
        ref.watch(myOffersProvider(user.uid)).valueOrNull ?? const <Offer>[];
    final pendingOffers =
        offers.where((o) => o.status == OfferStatus.pending).length;

    final rating = profile?.averageRating ?? 0;
    final reviews = profile?.totalReviews ?? 0;
    final shopSubtitle = reviews > 0
        ? '★ ${rating.toStringAsFixed(1)} · $reviews değerlendirme'
        : 'Müşterilerin gördüğü vitrin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile != null && !profileComplete) ...[
          _WarningBanner(
            text: 'Profilini tamamla — meslek ve hizmet bölgesi ekleyince '
                'aramada görünmeye başlarsın.',
            actionLabel: 'Tamamla',
            onAction: () => context.push(RoutePaths.panelEdit),
          ),
          const SizedBox(height: 20),
        ],
        const _SectionLabel('DÜKKÂNIM'),
        _Group(children: [
          _AvailabilityRow(draft: draft),
          _MenuRow(
            icon: Icons.storefront_outlined,
            iconColor: AppColors.primary,
            iconSurface: AppColors.primaryContainer,
            title: 'Dükkânımı Gör',
            subtitle: shopSubtitle,
            onTap: () => context.push(RoutePaths.artisanProfile(user.uid)),
          ),
          _MenuRow(
            icon: Icons.edit_outlined,
            iconColor: AppColors.info,
            iconSurface: AppColors.infoSurface,
            title: 'Profili Düzenle',
            subtitle: 'Meslek, bölge, fotoğraflar, çalışma takvimi',
            onTap: () => context.push(RoutePaths.panelEdit),
          ),
          _MenuRow(
            icon: profile?.hasActivePremium == true
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            iconColor: AppColors.premium,
            iconSurface: AppColors.premiumSurface,
            title: 'Premium',
            subtitle: profile == null
                ? null
                : (profile.hasActivePremium
                    ? (profile.premiumExpiresAt != null
                        ? '${DateFormat('d MMM yyyy', 'tr_TR').format(profile.premiumExpiresAt!)} tarihine kadar aktif'
                        : 'Aktif')
                    : 'Aramada görünmek için gerekli — ilk yıl ücretsiz'),
            onTap: () => context.push(RoutePaths.panelPremium),
          ),
        ]),
        const _SectionLabel('İŞLERİM'),
        _Group(children: [
          _MenuRow(
            icon: Icons.work_outline,
            iconColor: AppColors.info,
            iconSurface: AppColors.infoSurface,
            title: 'Yakınımdaki İşler',
            subtitle: 'Mesleğine ve bölgene uygun açık ilanlar',
            badge: nearbyCount,
            onTap: () => context.push(RoutePaths.panelJobs),
          ),
          _MenuRow(
            icon: Icons.forum_outlined,
            iconColor: AppColors.primary,
            iconSurface: AppColors.primaryContainer,
            title: 'İletişimlerim',
            subtitle: 'İlgilendiğin ve yürüyen işler',
            badge: pendingOffers,
            onTap: () => context.push(RoutePaths.panelOffers),
          ),
          _MenuRow(
            icon: Icons.notifications_none_rounded,
            iconColor: AppColors.warning,
            iconSurface: AppColors.warningSurface,
            title: 'Bildirimler',
            onTap: () => context.push(RoutePaths.panelNotifications),
          ),
        ]),
      ],
    );
  }
}

/// "Müsaitlik" satırı — switch sağda; açmak Premium ister (yönlendirir).
class _AvailabilityRow extends ConsumerWidget {
  const _AvailabilityRow({required this.draft});
  final MyProfileDraft? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = draft?.profile;
    final available = profile?.isAvailable ?? false;

    Future<void> onChanged(bool value) async {
      if (profile == null) return;
      if (value && !profile.hasActivePremium) {
        context.push(RoutePaths.panelPremium);
        return;
      }
      final ok = await ref
          .read(myProfileControllerProvider.notifier)
          .setAvailable(value);
      if (!context.mounted) return;
      if (ok) {
        context.showInfo(value
            ? 'Artık müsait görünüyorsunuz.'
            : 'Müsait değilsiniz. Aramada görünmezsiniz.');
      } else {
        context.showError('İşlem başarısız, tekrar deneyin.');
      }
    }

    return _MenuRow(
      icon: available
          ? Icons.check_circle_outline_rounded
          : Icons.do_not_disturb_on_outlined,
      iconColor: available
          ? AppColors.success
          : Theme.of(context).colorScheme.onSurfaceVariant,
      iconSurface: available
          ? AppColors.successSurface
          : Theme.of(context).colorScheme.surfaceContainer,
      title: available ? 'Müsaitsin' : 'Şu an kapalısın',
      subtitle: available
          ? 'Müşteriler seni "müsait" olarak görüyor'
          : 'Aç: müşteri aramalarında görün',
      trailing: Switch(
        value: available,
        onChanged: profile == null ? null : onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Müşteri modu bölümleri
// ---------------------------------------------------------------------------

class _CustomerSections extends ConsumerWidget {
  const _CustomerSections({required this.user});
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

    final ok = await ref.read(authControllerProvider.notifier).becomeArtisan();
    if (!context.mounted) return;
    if (ok) {
      context.showSuccess(
          'Usta profiliniz açıldı. Şimdi meslek ve bölgenizi belirleyin.');
      context.go(RoutePaths.panelEdit);
    } else {
      final error = ref.read(authControllerProvider).error;
      context.showError(error is AuthException
          ? error.message
          : AuthException.unknown.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs =
        ref.watch(myJobsProvider(user.uid)).valueOrNull ?? const <Job>[];
    final favs = ref.watch(favoritesProvider(user.uid)).valueOrNull ?? const [];
    final activeJobs = jobs
        .where((j) =>
            j.effectiveStatus == JobStatus.open ||
            j.effectiveStatus == JobStatus.workerSelected ||
            j.effectiveStatus == JobStatus.inProgress)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('AKTİVİTEM'),
        _Group(children: [
          _MenuRow(
            icon: Icons.campaign_outlined,
            iconColor: AppColors.primary,
            iconSurface: AppColors.primaryContainer,
            title: 'İlanlarım',
            subtitle: activeJobs > 0
                ? '$activeJobs aktif ilan'
                : 'Verdiğin iş ilanları',
            badge: jobs.length,
            onTap: () => context.push(RoutePaths.myJobs),
          ),
          _MenuRow(
            icon: Icons.favorite_border,
            iconColor: AppColors.danger,
            iconSurface: AppColors.danger.withValues(alpha: 0.10),
            title: 'Takip Ettiklerim',
            subtitle: 'Takip ettiğin ustalar',
            badge: favs.length,
            onTap: () => context.push(RoutePaths.favorites),
          ),
        ]),
        if (!user.hasArtisanProfile) ...[
          const _SectionLabel('USTA MISIN?'),
          _Group(children: [
            _MenuRow(
              icon: Icons.handyman_outlined,
              iconColor: AppColors.onSecondaryContainer,
              iconSurface: AppColors.secondaryContainer,
              title: 'Hizmet Vermeye Başla',
              subtitle: 'Usta profili aç, bölgendeki işlere ulaş',
              onTap: () => _becomeArtisan(context, ref),
            ),
          ]),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hesap grubu (her iki modda ortak)
// ---------------------------------------------------------------------------

class _AccountGroup extends ConsumerWidget {
  const _AccountGroup({required this.user});
  final AppUser user;

  Future<void> _verifyPhone(BuildContext context, WidgetRef ref) async {
    final ok = await PhoneVerificationSheet.show(context);
    if (ok == true && context.mounted) {
      context.showSuccess(user.hasArtisanProfile
          ? 'Telefonun doğrulandı — mavi tik aktif! 🎉'
          : 'Telefonun doğrulandı. Hesabın artık doğrulanmış. 🎉');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final since = DateFormat('MMMM yyyy', 'tr_TR').format(user.createdAt);

    return _Group(children: [
      if (user.phoneVerified)
        _MenuRow(
          icon: Icons.verified,
          iconColor: AppColors.verified,
          iconSurface: AppColors.info.withValues(alpha: 0.10),
          title: 'Doğrulanmış Hesap',
          subtitle: user.hasArtisanProfile
              ? 'Profilinde mavi tik görünüyor'
              : 'Telefon numaran doğrulandı',
          trailing: const Icon(Icons.check_circle,
              color: AppColors.success, size: 22),
        )
      else
        _MenuRow(
          icon: Icons.verified_outlined,
          iconColor: AppColors.verified,
          iconSurface: AppColors.info.withValues(alpha: 0.10),
          title: user.hasArtisanProfile
              ? 'Mavi Tik Al'
              : 'Telefonunu Doğrula',
          subtitle: user.hasArtisanProfile
              ? 'Telefonunu doğrula, profilinde mavi tik kazan'
              : 'Hesabını güvene al, doğrulanmış rozeti kazan',
          onTap: () => _verifyPhone(context, ref),
        ),
      _MenuRow(
        icon: Icons.mail_outline,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconSurface: theme.colorScheme.surfaceContainer,
        title: 'E-posta',
        trailing: Text(
          user.email,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      _MenuRow(
        icon: Icons.calendar_today_outlined,
        iconColor: theme.colorScheme.onSurfaceVariant,
        iconSurface: theme.colorScheme.surfaceContainer,
        title: 'Üyelik',
        trailing: Text(
          '$since itibarıyla',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Yapı taşları: bölüm etiketi, grup kartı, menü satırı, uyarı bandı
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Satırları ince ayraçlarla ayıran beyaz grup kartı.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 60,
                  color: theme.colorScheme.outlineVariant,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Tek tip menü satırı: ikon kutusu + başlık/alt yazı + (rozet | değer |
/// switch | chevron). Sayfadaki TÜM satırlar bundan türer — görsel tutarlılık.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.iconSurface,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.badge = 0,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconSurface;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final int badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconSurface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF7A4D00))),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

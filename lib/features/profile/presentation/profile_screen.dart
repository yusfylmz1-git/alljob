import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_format.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/user_role.dart';
import '../../../data/models/favorite.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/shop_completion.dart';
import '../../artisan/presentation/widgets/shop_completion_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/phone_verification_sheet.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../membership/membership_access.dart';
import '../../membership/membership_package.dart';

/// Profil (alt bar): tek hesap, iki yüzey.
///  - Müşteri: talepler (ilanlar, takip) — "iş seçimi" yok.
///  - Usta: dükkân + işler (müsaitlik, vitrin, yakındaki işler).
/// Ortak hesap/ayar en altta; araçlar (çanta, ajanda) kısa grup.
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
    final draft = artisanMode
        ? ref.watch(myProfileControllerProvider).valueOrNull
        : null;

    return ListView(
      // B-08: Alt bar (`MainBottomBar`) YÜZEN bir çubuk — gövdenin üstünü
      // kapatır. `EdgeInsets.zero` ile son öğeler (Kaydet vb.) barın altında
      // kalıyordu; bazı telefonlarda hiç erişilemiyordu. Bar yüksekliği
      // 68 + dikey padding 16 = ~84; güvenli pay bırakılır.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Hero(user: user, draft: draft, artisanMode: artisanMode),
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user.hasArtisanProfile) ...[
                _ModeSwitcher(user: user),
                const SizedBox(height: 8),
                Text(
                  artisanMode
                      ? 'Usta dükkânı — müsaitlik, vitrin ve işler'
                      : 'Müşteri hesabı — ilanlar ve takip',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (artisanMode)
                _ArtisanHome(user: user, draft: draft)
              else
                _CustomerHome(user: user),
              const _SectionLabel('ARAÇLAR'),
              _Group(
                children: [
                  _MenuRow(
                    icon: Icons.handyman_outlined,
                    iconColor: context.palette.primary,
                    iconSurface: context.palette.primaryContainer,
                    title: 'Usta Çantası',
                    subtitle: 'Ölçüm, maliyet ve teklif araçları',
                    onTap: () => context.push(RoutePaths.toolkit),
                  ),
                  _MenuRow(
                    icon: Icons.checklist_rounded,
                    iconColor: context.palette.primary,
                    iconSurface: context.palette.primaryContainer,
                    title: 'Ajanda',
                    subtitle: 'Kişisel randevu ve hatırlatma (ilan işi değil)',
                    onTap: () => context.push(RoutePaths.tracking),
                  ),
                  if (artisanMode)
                    _MenuRow(
                      icon: Icons.storefront_outlined,
                      iconColor: context.palette.primary,
                      iconSurface: context.palette.primaryContainer,
                      title: 'Ürünlerim',
                      subtitle: 'Keşfet vitrin ürünlerinizi yönetin',
                      onTap: () => context.push(RoutePaths.myProducts),
                    ),
                ],
              ),
              const _SectionLabel('HESABIM'),
              _AccountGroup(user: user),
              _Group(
                children: [
                  _MenuRow(
                    icon: Icons.logout_rounded,
                    iconColor: context.palette.danger,
                    iconSurface: context.palette.danger.withValues(alpha: 0.10),
                    title: 'Çıkış Yap',
                    titleColor: context.palette.danger,
                    onTap: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authControllerProvider.notifier).signOut();
                      router.go(RoutePaths.home);
                    },
                  ),
                  _MenuRow(
                    icon: Icons.delete_forever_outlined,
                    iconColor: context.palette.danger,
                    iconSurface: context.palette.danger.withValues(alpha: 0.10),
                    title: 'Hesabı Sil',
                    titleColor: context.palette.danger,
                    subtitle: 'Kalıcı — geri alınamaz',
                    onTap: () => _deleteAccountFlow(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — kimlik: avatar + ad (+ mavi tik); e-posta hesap bölümünde
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({
    required this.user,
    required this.draft,
    required this.artisanMode,
  });
  final AppUser user;
  final MyProfileDraft? draft;
  final bool artisanMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final photo = draft?.profilePhotoUrl ?? user.profilePhotoUrl;
    final profession = artisanMode && draft != null
        ? kProfessionNames[draft!.profile.profession]
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(
            children: [
              // Üst şerit: menü + başlık (ortada) + dengeleyici boşluk.
              // Menü yalnız avatar üstünde “uçan” durmasın.
              Row(
                children: [
                  const DrawerMenuButton(),
                  Expanded(
                    child: Text(
                      artisanMode ? 'Usta dükkânı' : 'Müşteri',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  // Menü ile simetrik genişlik (başlık gerçekten ortada).
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 14),
              // Avatar + altındaki kalem → profil / vitrin düzenleme.
              Tooltip(
                message: 'Profili düzenle',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => context.push(RoutePaths.profileEdit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                      ? AppImage(
                                          handle: photo,
                                          fit: BoxFit.cover,
                                          width: 72,
                                          height: 72,
                                          memCacheWidth: 144,
                                          memCacheHeight: 144,
                                        )
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
                          const SizedBox(height: 8),
                          // Resmin altı: kalem + "Düzenle"
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Düzenle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                    const Icon(
                      Icons.verified,
                      size: 20,
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ],
              ),
              if (profession != null && profession.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  profession,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mod anahtarı — Müşteri hesabı | Usta dükkânı
// ---------------------------------------------------------------------------

class _ModeSwitcher extends ConsumerWidget {
  const _ModeSwitcher({required this.user});
  final AppUser user;

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    UserRole mode,
  ) async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .setActiveMode(mode);
    if (!context.mounted) return;
    if (!ok) {
      context.showError('Mod değiştirilemedi, tekrar deneyin.');
    }
    // Sayfadan ayrılmayız: içerik yeni moda göre kendini yeniler — kullanıcı
    // geçişin ne yaptığını gözüyle görür.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Global authController.isLoading ile KİLİTLENMEZ (e-posta/login loading
    // sekmeleri pasif bırakıyordu). Repo optimistic; çift tık zararsız.
    return SegmentedButton<UserRole>(
      segments: const [
        ButtonSegment(
          value: UserRole.customer,
          label: Text('Müşteri'),
          icon: Icon(Icons.person_outline_rounded),
        ),
        ButtonSegment(
          value: UserRole.artisan,
          label: Text('Usta dükkânı'),
          icon: Icon(Icons.storefront_outlined),
        ),
      ],
      selected: {user.activeMode},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: context.palette.primary,
        selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
        minimumSize: const Size(0, 46),
      ),
      onSelectionChanged: (selection) {
        final mode = selection.first;
        if (mode != user.activeMode) _switch(context, ref, mode);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Usta dükkânı — müsaitlik, vitrin, işler (müşteri menüsü yok)
// ---------------------------------------------------------------------------

class _ArtisanHome extends ConsumerWidget {
  const _ArtisanHome({required this.user, required this.draft});
  final AppUser user;
  final MyProfileDraft? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = draft?.profile;
    // Rozet için nearbyJobs / myOffers canlı dinlenmez — profil menüsü
    // 100+ open job + tüm teklif snapshot'ını açık tutuyordu (maliyet/RAM).
    final rating = profile?.averageRating ?? 0;
    final reviews = profile?.totalReviews ?? 0;
    final shopSubtitle = reviews > 0
        ? '★ ${rating.toStringAsFixed(1)} · $reviews değerlendirme'
        : 'Müşterilerin gördüğü dükkân';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('DÜKKÂNIM'),
        _Group(children: [_AvailabilityRow(draft: draft)]),
        _ShopVitrineCard(user: user, draft: draft, shopSubtitle: shopSubtitle),
        const SizedBox(height: 4),
        _FollowersSection(artisanUid: user.uid),
        const _SectionLabel('İŞLER'),
        _Group(
          children: [
            _MenuRow(
              icon: Icons.work_outline,
              iconColor: context.palette.info,
              iconSurface: context.palette.infoSurface,
              // "İlgilendiğim işler" BURADAN KALKTI: iş akışının parçası
              // olduğu için alt bardaki "İşler" sekmesine taşındı (orada
              // "Yakınımdaki" ile yan yana iki sekme).
              title: 'İşler',
              subtitle: 'Yakınındakiler ve ilgilendiklerin',
              onTap: () => context.push(RoutePaths.panelJobs),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ustanın takipçileri — dükkân ekranında görünür.
class _FollowersSection extends ConsumerWidget {
  const _FollowersSection({required this.artisanUid});
  final String artisanUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followersProvider(artisanUid));
    final followers = async.valueOrNull ?? const <Favorite>[];
    if (followers.isEmpty && !async.isLoading) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('TAKİPÇİLER'),
          Material(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
                boxShadow: AppTheme.softShadow,
              ),
              child: async.isLoading && followers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < followers.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: palette.hairline),
                          _FollowerRow(follower: followers[i]),
                        ],
                      ],
                    ),
            ),
          ),
          if (followers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '${followers.length} kişi sizi takip ediyor',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowerRow extends StatelessWidget {
  const _FollowerRow({required this.follower});
  final Favorite follower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final name = follower.customerName.isEmpty
        ? 'Kullanıcı'
        : follower.customerName;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: follower.customerPhotoUrl != null
                  ? AppImage(
                      handle: follower.customerPhotoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
                    )
                  : Container(
                      color: palette.primaryContainer,
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.primary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'sizi takip ediyor',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.favorite_rounded,
            size: 18,
            color: palette.danger.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

/// Tek vitrin kartı: tamamla / görüntüle + düzenle (çift menü yok).
class _ShopVitrineCard extends StatelessWidget {
  const _ShopVitrineCard({
    required this.user,
    required this.draft,
    required this.shopSubtitle,
  });
  final AppUser user;
  final MyProfileDraft? draft;
  final String shopSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final completion = ShopCompletion.from(user: user, draft: draft);

    if (!completion.isComplete) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ShopCompletionBanner(
          completion: completion,
          title: 'Vitrini tamamla — aramada görün',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: palette.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vitrinim',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          shopSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push(RoutePaths.artisanProfile(user.uid)),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Görüntüle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(RoutePaths.panelEdit),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Düzenle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Müsaitlik" satırı — switch sağda; açmak Premium erişimi ister
/// (beta'da herkese açık; yoksa Premium sayfasına yönlendirir).
class _AvailabilityRow extends ConsumerWidget {
  const _AvailabilityRow({required this.draft});
  final MyProfileDraft? draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = draft?.profile;
    final available = profile?.isAvailable ?? false;

    Future<void> onChanged(bool value) async {
      if (profile == null) return;
      // Faz 2: plan (ücretsiz) veya ödeme kilidi.
      if (value && !ref.read(artisanProAccessProvider)) {
        context.push(RoutePaths.panelPremium);
        return;
      }
      final ok = await ref
          .read(myProfileControllerProvider.notifier)
          .setAvailable(value);
      if (!context.mounted) return;
      if (ok) {
        context.showInfo(
          value
              ? 'Artık müsait görünüyorsunuz.'
              : 'Müsait değilsiniz. Aramada görünmezsiniz.',
        );
      } else {
        context.showError('İşlem başarısız, tekrar deneyin.');
      }
    }

    return _MenuRow(
      icon: available
          ? Icons.check_circle_outline_rounded
          : Icons.do_not_disturb_on_outlined,
      iconColor: available
          ? context.palette.success
          : Theme.of(context).colorScheme.onSurfaceVariant,
      iconSurface: available
          ? context.palette.successSurface
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
// Müşteri hesabı — ilan / takip (iş seçimi / dükkân yok)
// ---------------------------------------------------------------------------

class _CustomerHome extends ConsumerWidget {
  const _CustomerHome({required this.user});
  final AppUser user;

  Future<void> _becomeArtisan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hizmet Vermeye Başla'),
        content: const Text(
          'Hesabınıza bir usta dükkânı eklenecek. Meslek ve hizmet '
          'bölgenizi belirledikten sonra müşteriler sizi bulabilir. '
          'İstediğiniz zaman Müşteri hesabına dönebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Başla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(authControllerProvider.notifier).becomeArtisan();
    if (!context.mounted) return;
    if (ok) {
      context.showSuccess(
        'Usta dükkânınız açıldı. Şimdi meslek ve bölgenizi belirleyin.',
      );
      context.go(RoutePaths.panelEdit);
    } else {
      final error = ref.read(authControllerProvider).error;
      context.showError(
        error is AuthException ? error.message : AuthException.unknown.message,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İlan/favori listelerini yalnızca rozet için dinleme — ilgili ekranlar
    // açılınca stream orada başlar (profil menüsü ucuz kalsın).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('TALEPLERİM'),
        _Group(
          children: [
            _MenuRow(
              icon: Icons.campaign_outlined,
              iconColor: context.palette.primary,
              iconSurface: context.palette.primaryContainer,
              title: 'İlanlarım',
              subtitle: 'Verdiğiniz hizmet ilanları',
              onTap: () => context.push(RoutePaths.myJobs),
            ),
            _MenuRow(
              icon: Icons.favorite_border,
              iconColor: context.palette.danger,
              iconSurface: context.palette.danger.withValues(alpha: 0.10),
              title: 'Takip ettiklerim',
              subtitle: 'Favori ustalar',
              onTap: () => context.push(RoutePaths.favorites),
            ),
          ],
        ),
        if (!user.hasArtisanProfile) ...[
          const _SectionLabel('HİZMET VER'),
          _Group(
            children: [
              _MenuRow(
                icon: Icons.handyman_outlined,
                iconColor: context.palette.onSecondaryContainer,
                iconSurface: context.palette.secondaryContainer,
                title: 'Usta dükkânı aç',
                subtitle: 'Meslek ve bölge ekle, iş al',
                onTap: () => _becomeArtisan(context, ref),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Hesap silme akışı: açık onay → engelleyici ilerleme → sonuç.
/// Silme kalıcıdır (sunucudaki `deleteAccount` CF'i veriyi temizler);
/// başarıda oturum kapanır ve ana sayfaya dönülür.
Future<void> _deleteAccountFlow(BuildContext context, WidgetRef ref) async {
  // Async adımlar sonrasında bu ekran kapanmış olabilir; kalıcı bağlamları
  // (router + kök navigator) önce yakala (drawer'daki kalıp).
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hesabınız silinsin mi?'),
      content: const Text(
        'Bu işlem geri alınamaz. Profiliniz, ilanlarınız, fotoğraflarınız, '
        'bildirimleriniz ve hesabınız kalıcı olarak silinir; sohbetlerde '
        'adınız "Silinmiş Kullanıcı" olarak görünür.\n\n'
        'Devam etmek istiyor musunuz?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.palette.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Kalıcı Olarak Sil'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Engelleyici ilerleme diyaloğu — silme sırasında geri tuşu/dokunma yutulur.
  unawaited(
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Hesabınız siliniyor…')),
            ],
          ),
        ),
      ),
    ),
  );

  final ok = await ref.read(authControllerProvider.notifier).deleteAccount();

  if (nav.mounted) nav.pop(); // ilerleme diyaloğunu kapat
  if (ok) {
    router.go(RoutePaths.home);
    if (nav.mounted) nav.context.showInfo('Hesabınız silindi.');
  } else if (nav.mounted) {
    final err = ref.read(authControllerProvider).error;
    nav.context.showError(
      err is AuthException
          ? err.message
          : 'Hesap silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
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
      context.showSuccess(
        user.hasArtisanProfile
            ? 'Telefonun doğrulandı — mavi tik aktif! 🎉'
            : 'Telefonun doğrulandı. Hesabın artık doğrulanmış. 🎉',
      );
    }
  }

  /// Doğrulanmış numarayı YENİSİYLE değiştirir (hat/operatör değişimi).
  /// Vitrinde numara gösteriliyorsa yenisi otomatik yerine geçer — sheet
  /// bunu kendisi yapar; burada yalnız sonucu bildiririz.
  Future<void> _changePhone(BuildContext context, WidgetRef ref) async {
    final wasPublic =
        ref
            .read(myProfileControllerProvider)
            .valueOrNull
            ?.profile
            .showPhoneOnProfile ??
        false;
    final ok = await PhoneVerificationSheet.show(context, isChange: true);
    if (ok == true && context.mounted) {
      context.showSuccess(
        wasPublic
            ? 'Numaran güncellendi; profilindeki numara da yenilendi.'
            : 'Numaran güncellendi.',
      );
    }
  }

  /// E-posta doğrulama akışı: bağlantıyı (yeniden) gönder veya durumu
  /// kontrol et. Doğrulama, e-postadaki bağlantıya tıklanınca Firebase Auth
  /// tarafında gerçekleşir; buradaki "kontrol et" durumu sunucudan tazeler.
  Future<void> _verifyEmail(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-postanı Doğrula',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${user.email} adresine gönderilen bağlantıya tıklayarak '
                'e-postanızı doğrulayın. E-posta gelmediyse spam/gereksiz '
                'klasörünü kontrol edin veya yeniden gönderin.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Doğrulama E-postasını Gönder'),
                  onPressed: () => Navigator.pop(ctx, 'send'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Bağlantıya Tıkladım — Kontrol Et'),
                  onPressed: () => Navigator.pop(ctx, 'check'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final ctrl = ref.read(authControllerProvider.notifier);
    if (action == 'send') {
      final ok = await ctrl.sendEmailVerification();
      if (!context.mounted) return;
      if (ok) {
        context.showSuccess(
          'Doğrulama bağlantısı ${user.email} adresine gönderildi.',
        );
      } else {
        final err = ref.read(authControllerProvider).error;
        context.showError(
          err is AuthException
              ? err.message
              : 'Gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin.',
        );
      }
      return;
    }

    final verified = await ctrl.checkEmailVerified();
    if (!context.mounted) return;
    if (verified == true) {
      context.showSuccess('E-postanız doğrulandı! 🎉');
    } else if (verified == false) {
      context.showInfo(
        'Henüz doğrulanmamış görünüyor. E-postanızdaki '
        'bağlantıya tıkladıktan sonra tekrar deneyin.',
      );
    } else {
      context.showError(
        'Kontrol edilemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan =
        ref.watch(selectedMembershipPackageProvider) ?? MembershipPackage.free;
    final proOpen = ref.watch(artisanProAccessProvider);
    final paidPremium =
        user.isArtisan &&
        (ref
                .watch(myProfileControllerProvider)
                .valueOrNull
                ?.profile
                .hasActivePremium ??
            false);

    return _Group(
      children: [
        _MenuRow(
          icon: Icons.person_outline_rounded,
          iconColor: context.palette.primary,
          iconSurface: context.palette.primaryContainer,
          title: 'Profili düzenle',
          subtitle: 'Ad ve fotoğraf',
          onTap: () => context.push(RoutePaths.profileEdit),
        ),
        // Tek üyelik girişi: plan + Pro erişim / faturalama (Premium ekranı).
        _MenuRow(
          icon: paidPremium || plan == MembershipPackage.pro
              ? Icons.workspace_premium
              : Icons.workspace_premium_outlined,
          iconColor: context.palette.premium,
          iconSurface: context.palette.premiumSurface,
          title: 'Üyelik: ${plan.titleTR}',
          subtitle: proOpen
              ? (plan == MembershipPackage.free
                    ? 'Pro özellikler açık'
                    : plan.summaryTR)
              : 'Pro özellikler kilitli · plan yükselt',
          onTap: () => context.push(RoutePaths.panelPremium),
        ),
        if (user.phoneVerified)
          _MenuRow(
            icon: Icons.verified,
            iconColor: context.palette.verified,
            iconSurface: context.palette.info.withValues(alpha: 0.10),
            title: 'Telefon doğrulandı',
            // Numarayı göster: hangi hattın kayıtlı olduğu görünmüyordu.
            subtitle: [
              if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                formatTrPhone(user.phoneNumber!),
              if (user.hasArtisanProfile) 'Mavi tik aktif',
            ].join(' · '),
            // Hat/operatör değişiminde numara güncellenebilmeli; aksi hâlde
            // vitrinde artık kullanılmayan numara kalırdı.
            trailing: TextButton(
              onPressed: () => _changePhone(context, ref),
              child: const Text('Değiştir'),
            ),
          ),
        // Usta + doğrulanmış telefon: numarayı vitrinde göster/gizle. Açıkken
        // profilde telefon + "Ara" düğmesi görünür (müşteri direkt arayabilir).
        if (user.isArtisan && user.phoneVerified)
          _PhoneVisibilityRow(phoneNumber: user.phoneNumber),
        if (!user.phoneVerified)
          _MenuRow(
            icon: Icons.verified_outlined,
            iconColor: context.palette.verified,
            iconSurface: context.palette.info.withValues(alpha: 0.10),
            title: user.hasArtisanProfile ? 'Mavi tik al' : 'Telefonu doğrula',
            subtitle: 'Hesabı güvene al',
            onTap: () => _verifyPhone(context, ref),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuRow(
              icon: user.emailVerified
                  ? Icons.mark_email_read_outlined
                  : Icons.mail_outline,
              iconColor: user.emailVerified
                  ? context.palette.success
                  : context.palette.warning,
              iconSurface: user.emailVerified
                  ? context.palette.success.withValues(alpha: 0.10)
                  : context.palette.warning.withValues(alpha: 0.10),
              title: 'E-posta',
              subtitle: user.email.isEmpty ? 'Kayıtlı e-posta yok' : user.email,
              trailing: user.emailVerified
                  ? Icon(
                      Icons.check_circle,
                      color: context.palette.success,
                      size: 22,
                    )
                  : Text(
                      'Doğrulanmadı',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.palette.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (!user.emailVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: FilledButton.tonalIcon(
                  onPressed: () => _verifyEmail(context, ref, user),
                  icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                  label: const Text('E-postayı doğrula'),
                ),
              ),
          ],
        ),
        _MenuRow(
          icon: Icons.tune_rounded,
          iconColor: theme.colorScheme.onSurfaceVariant,
          iconSurface: theme.colorScheme.surfaceContainer,
          title: 'Tercihler',
          subtitle: 'Bildirimler ve engellenenler',
          onTap: () => _openPreferences(context),
        ),
        _MenuRow(
          icon: Icons.help_outline_rounded,
          iconColor: theme.colorScheme.onSurfaceVariant,
          iconSurface: theme.colorScheme.surfaceContainer,
          title: 'Yardım ve yasal',
          subtitle: 'SSS, gizlilik, KVKK',
          onTap: () => _openHelpLegal(context),
        ),
      ],
    );
  }

  void _openPreferences(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Bildirim tercihleri'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.notificationPrefs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Engellenen kullanıcılar'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.blockedUsers);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openHelpLegal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: const Text('Yardım / SSS'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.help);
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Yasal metinler'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(RoutePaths.legal);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yapı taşları: bölüm etiketi, grup kartı, menü satırı, uyarı bandı
// ---------------------------------------------------------------------------

/// Usta için "telefonumu profilde göster" switch'i. Açıkken doğrulanmış
/// numara ([ArtisanProfile.publicPhone]) vitrinde görünür ve müşteri "Ara"
/// düğmesiyle arayabilir. Durum usta profil taslağından okunur.
class _PhoneVisibilityRow extends ConsumerWidget {
  const _PhoneVisibilityRow({required this.phoneNumber});
  final String? phoneNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    final shown = draft?.profile.hasPublicPhone ?? false;

    Future<void> onChanged(bool value) async {
      // Açarken doğrulanmış numara şart (numara yoksa gösterecek bir şey yok).
      if (value && (phoneNumber == null || phoneNumber!.trim().isEmpty)) {
        context.showError('Telefon numarası bulunamadı.');
        return;
      }
      final ok = await ref
          .read(myProfileControllerProvider.notifier)
          .setPhoneVisibility(show: value, publicPhone: phoneNumber);
      if (!context.mounted) return;
      if (ok) {
        context.showInfo(
          value
              ? 'Numaran profilinde görünüyor. Müşteriler seni arayabilir.'
              : 'Numaran artık profilinde gizli.',
        );
      } else {
        context.showError('İşlem başarısız, tekrar deneyin.');
      }
    }

    return _MenuRow(
      icon: shown ? Icons.phone_in_talk_rounded : Icons.phone_disabled_rounded,
      iconColor: shown
          ? context.palette.success
          : Theme.of(context).colorScheme.onSurfaceVariant,
      iconSurface: shown
          ? context.palette.successSurface
          : Theme.of(context).colorScheme.surfaceContainer,
      title: 'Telefonumu profilde göster',
      subtitle: shown
          ? 'Müşteriler numaranı görüp arayabilir'
          : 'Kapalı — numaran gizli',
      trailing: Switch(
        value: shown,
        onChanged: draft == null ? null : onChanged,
      ),
    );
  }
}

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
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconSurface;
  final String title;
  final Color? titleColor;
  final String? subtitle;
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/artisan_profile.dart';
import '../../../data/models/offer.dart';
import '../../../data/models/review.dart';
import '../../../data/models/user_role.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/job_providers.dart';
import '../../review/data/review_repository.dart';
import '../application/my_profile_controller.dart';

/// Usta Yönetim Paneli (Ekran D girişi) — ustanın "dijital dükkânının"
/// kontrol merkezi: lacivert hero (avatar → profil düzenleme, istatistikler,
/// hızlı eylemler) + durum/premium kartları + içerik bölümleri.
class ArtisanHomeScreen extends ConsumerWidget {
  const ArtisanHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(myProfileControllerProvider);

    return Scaffold(
      drawer: const AppMenuDrawer(),
      body: draftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Profil yüklenemedi. Tekrar deneyin.')),
        data: (draft) => _Dashboard(draft: draft),
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.profile),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.draft});
  final MyProfileDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = draft.profile;
    final reviews =
        ref.watch(artisanReviewsProvider(profile.uid)).valueOrNull ??
            const <Review>[];
    // Puan toplamları Cloud Functions gelene dek değerlendirmelerden hesaplanır.
    final avgRating = reviews.isEmpty
        ? profile.averageRating
        : reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
    final totalReviews =
        reviews.isEmpty ? profile.totalReviews : reviews.length;
    final profileComplete =
        profile.profession.isNotEmpty && profile.serviceAreas.isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PanelHero(
          draft: draft,
          averageRating: avgRating,
          totalReviews: totalReviews,
        ),
        ResponsiveCenter(
          maxWidth: 820,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Düzen: uyarı → durum → iş akışı → içerik → mod geçişi.
              if (!profileComplete) ...[
                _CompleteProfileCard(
                  onEdit: () => context.push(RoutePaths.panelEdit),
                ),
                const SizedBox(height: 14),
              ],
              _StatusCard(profile: profile),
              const SizedBox(height: 14),
              if (profileComplete) ...[
                _WorkflowCard(artisanUid: profile.uid),
                const SizedBox(height: 14),
              ],
              if (profile.aboutText.isNotEmpty) ...[
                _PanelSection(
                  icon: Icons.person_outline_rounded,
                  title: 'Hakkımda',
                  actionLabel: 'Düzenle',
                  onAction: () => context.push(RoutePaths.panelEdit),
                  child: Text(profile.aboutText,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 14),
              ],
              _PanelSection(
                icon: Icons.star_outline_rounded,
                title: 'Değerlendirmeler ($totalReviews)',
                child: reviews.isEmpty
                    ? Text(
                        'Henüz değerlendirme yok. Müşterilerinle sohbet edip '
                        'işini tamamladıkça değerlendirmeler burada birikecek.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      )
                    : Column(
                        children:
                            reviews.map((r) => _ReviewTile(review: r)).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              const _CustomerModeCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tek hesap, çift rol: usta panelinden Müşteri Moduna dönüş.
class _CustomerModeCard extends ConsumerWidget {
  const _CustomerModeCard();

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .setActiveMode(UserRole.customer);
    if (!context.mounted) return;
    if (ok) {
      context.go(RoutePaths.home);
    } else {
      context.showError('Mod değiştirilemedi, tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Müşteri Modu',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  'Usta aramak veya ilan vermek için müşteri arayüzüne geçin.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: isLoading ? null : () => _switch(context, ref),
            child: const Text('Geç'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: avatar (→ profil düzenleme) + istatistikler + hızlı eylemler
// ---------------------------------------------------------------------------

class _PanelHero extends StatelessWidget {
  const _PanelHero({
    required this.draft,
    required this.averageRating,
    required this.totalReviews,
  });

  final MyProfileDraft draft;
  final double averageRating;
  final int totalReviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = draft.profile;
    final professionName =
        kProfessionNames[profile.profession] ?? 'Meslek seçilmedi';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 820,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En üstte: solda menü, sağda Müsait switch'i (Premium gerektirir).
              Row(
                children: [
                  const DrawerMenuButton(),
                  const Spacer(),
                  _AvailabilitySwitch(profile: profile),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _HeroAvatar(
                    photoHandle: draft.profilePhotoUrl,
                    initials: _initials(draft.displayName),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.displayName.isEmpty
                              ? 'Adınız'
                              : draft.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          professionName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // İstatistik kartı.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Row(
                  children: [
                    _Stat(
                      value: averageRating.toStringAsFixed(1),
                      label: 'Puan',
                      icon: Icons.star_rounded,
                      iconColor: AppColors.star,
                    ),
                    _statDivider(theme),
                    _Stat(
                      value: '$totalReviews',
                      label: 'Değerlendirme',
                    ),
                    _statDivider(theme),
                    _Stat(
                      value: '${profile.experienceYears} yıl',
                      label: 'Deneyim',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Hızlı eylemler.
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.secondary,
                        minimumSize: const Size(64, 44),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Profili Düzenle'),
                      onPressed: () => context.push(RoutePaths.panelEdit),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5)),
                        minimumSize: const Size(64, 44),
                      ),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Dükkânımı Gör'),
                      onPressed: () => context
                          .push(RoutePaths.artisanProfile(profile.uid)),
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

  Widget _statDivider(ThemeData theme) => Container(
        width: 1,
        height: 34,
        color: theme.colorScheme.outlineVariant,
      );

  static String _initials(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }
}

/// Sağ üstteki ana "Müsait" switch'i. Açmak Premium gerektirir; Premium
/// değilse ödeme (Premium) sayfasına yönlendirir. Kapalıyken usta iş
/// ilanlarını göremez ve müşteri aramalarında görünmez.
class _AvailabilitySwitch extends ConsumerWidget {
  const _AvailabilitySwitch({required this.profile});
  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = profile.isAvailable;

    Future<void> onChanged(bool value) async {
      final ctrl = ref.read(myProfileControllerProvider.notifier);
      if (value && !profile.hasActivePremium) {
        // Premium değil → ödeme sayfasına yönlendir.
        context.push(RoutePaths.panelPremium);
        return;
      }
      final ok = await ctrl.setAvailable(value);
      if (!context.mounted) return;
      if (ok) {
        context.showInfo(value
            ? 'Artık müsait görünüyorsunuz.'
            : 'Müsait değilsiniz. Aramada görünmezsiniz.');
      } else {
        context.showError('İşlem başarısız, tekrar deneyin.');
      }
    }

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.do_not_disturb_on_outlined,
            size: 16,
            color: available ? const Color(0xFF34D399) : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Müsait' : 'Kapalı',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Switch(
            value: available,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF059669),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Hero'daki profil fotoğrafı — salt görsel. Düzenlemeye giden TEK görünür
/// yol "Profili Düzenle" butonu/menü satırıdır; fotoğrafın ikinci bir "profil
/// sayfası" açıyormuş hissi vermemesi için tıklanabilir DEĞİLDİR.
class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.initials,
    this.photoHandle,
  });

  final String initials;
  final String? photoHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Color(0xFF13293F),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: SizedBox(
            width: 52,
            height: 52,
            child: photoHandle != null
                ? AppImage(handle: photoHandle)
                : Container(
                    color: Colors.white12,
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 3),
              ],
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bölüm kartları
// ---------------------------------------------------------------------------

/// İkonlu başlığı ve opsiyonel eylemi olan beyaz bölüm kartı.
class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.icon,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, size: 18, color: AppColors.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (actionLabel != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CompleteProfileCard extends StatelessWidget {
  const _CompleteProfileCard({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Profilini tamamla — meslek ve hizmet bölgesi ekleyince '
              'aramada görünmeye başlarsın.',
              style: TextStyle(color: Color(0xFF7A4D00)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onEdit, child: const Text('Tamamla')),
        ],
      ),
    );
  }
}

/// Müsaitlik + Premium durumunu TEK kartta özetleyen iki satır. Ayrıntı ve
/// yönetim kendi sayfalarında (müsaitlik → profil düzenleme, premium →
/// Premium sayfası) — panel sadeleşir, bilgi tekrarı kalmaz.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});
  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = profile.isAvailable;
    final premium = profile.hasActivePremium;
    final expires = profile.premiumExpiresAt;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          _StatusRow(
            icon: available
                ? Icons.check_circle_outline_rounded
                : Icons.do_not_disturb_on_outlined,
            color: available
                ? AppColors.success
                : theme.colorScheme.onSurfaceVariant,
            surface: available
                ? AppColors.successSurface
                : theme.colorScheme.surfaceContainer,
            title: available ? 'Hizmete hazırsın' : 'Şu an kapalısın',
            subtitle: available
                ? 'Müşteriler seni "müsait" olarak görüyor.'
                : 'Çalışma takvimini açınca müşterilere görünürsün.',
            actionLabel: 'Düzenle',
            onAction: () => context.push(RoutePaths.panelEdit),
          ),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant),
          _StatusRow(
            icon: premium
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            color: AppColors.premium,
            surface: premium
                ? AppColors.premiumSurface
                : theme.colorScheme.surfaceContainer,
            title: premium ? 'Premium Üye' : 'Premium değil',
            subtitle: premium && expires != null
                ? '${DateFormat('d MMM yyyy', 'tr_TR').format(expires)} tarihine kadar geçerli.'
                : 'Aramada görünmek için gerekli — ilk yıl ücretsiz.',
            actionLabel: premium ? 'Yönet' : 'Premium Ol',
            onAction: () => context.push(RoutePaths.panelPremium),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final Color surface;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// İş akışı kısayolları: rozetli gezinme satırları. ("Aktif İş" istatistiği
/// kaldırıldı — kullanıcı geri bildirimi: işlevi yoktu; seçilen işler zaten
/// İletişimlerim ve Bildirimler'den izleniyor.)
class _WorkflowCard extends ConsumerWidget {
  const _WorkflowCard({required this.artisanUid});
  final String artisanUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nearbyCount =
        ref.watch(nearbyJobsProvider).valueOrNull?.length ?? 0;
    final myOffers =
        ref.watch(myOffersProvider(artisanUid)).valueOrNull ?? const <Offer>[];
    final pendingCount =
        myOffers.where((o) => o.status == OfferStatus.pending).length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          _NavRow(
            icon: Icons.work_outline,
            color: AppColors.info,
            surface: AppColors.infoSurface,
            title: 'Yakınımdaki İşler',
            subtitle: 'Mesleğine ve bölgene uygun açık ilanlar',
            count: nearbyCount,
            onTap: () => context.push(RoutePaths.panelJobs),
          ),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant),
          _NavRow(
            icon: Icons.forum_outlined,
            color: AppColors.primary,
            surface: AppColors.primaryContainer,
            title: 'İletişimlerim',
            subtitle: 'İlgilendiğin ve yürüyen işler',
            count: pendingCount,
            onTap: () => context.push(RoutePaths.panelOffers),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.color,
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color surface;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('d MMM yyyy', 'tr_TR').format(review.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.maskedName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              RatingStars(rating: review.rating.toDouble(), size: 14),
            ],
          ),
          const SizedBox(height: 2),
          Text(dateStr,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.tags
                  .map((t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          const Divider(height: 22),
        ],
      ),
    );
  }
}

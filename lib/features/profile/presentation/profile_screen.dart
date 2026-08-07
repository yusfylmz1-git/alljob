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
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/user_role.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/shop_completion.dart';
import '../../artisan/presentation/widgets/shop_completion_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/phone_verification_sheet.dart';
import '../../chat/data/chat_providers.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../membership/membership_access.dart';
import '../../membership/membership_package.dart';

/// Profil (alt bar) — TEK profil, açılıp kapanan usta modülleri.
///
/// Rol ayrımı YOK: herkes aynı profili görür. "Usta modu" anahtarı açıkken
/// dükkân modülleri (müsaitlik, vitrin, ürünler) üstüne biner; kapalıyken
/// sade kalır. Instagram'ın "profesyonel hesap" anahtarı gibi.
///
/// Profil yalnız İÇERİK gösterir. Hesap ayarları (doğrulama, üyelik, çıkış)
/// `/profile/account`'ta, kişisel araçlar (Ajanda) yan menüde.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return MainTabScope(
      tab: MainTab.profile,
      child: Scaffold(
        drawer: const AppMenuDrawer(),
        body: user == null
            ? const Center(child: Text('Oturum bulunamadı.'))
            : _Body(user: user),
        bottomNavigationBar: const MainBottomBar(current: MainTab.profile),
      ),
    );
  }
}

/// Hesap Ayarları (`/profile/account`) — yan menüden açılır.
///
/// Profil ekranından çıkarılan HESABIM bölümü burada yaşar: telefon/e-posta
/// doğrulama, üyelik, çıkış, hesap silme. Profil ekranı böylece yalnız
/// İÇERİK gösterir (ilanlar, işler, takip) — Instagram düzeninin ön şartı.
///
/// Aynı dosyada duruyor: `_MenuRow` / `_Group` / `_SectionLabel` ve
/// `_AccountGroup` private; ayrı dosyaya taşımak hepsini public yapmayı
/// gerektirirdi.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Hesap Ayarları',
        icon: Icons.manage_accounts_outlined,
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ResponsiveCenter(
              maxWidth: 720,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountGroup(user: user),
                  const SizedBox(height: 8),
                  _Group(
                    children: [
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        iconColor: context.palette.danger,
                        iconSurface:
                            context.palette.danger.withValues(alpha: 0.10),
                        title: 'Çıkış Yap',
                        titleColor: context.palette.danger,
                        onTap: () async {
                          final router = GoRouter.of(context);
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                          router.go(RoutePaths.home);
                        },
                      ),
                      _MenuRow(
                        icon: Icons.delete_forever_outlined,
                        iconColor: context.palette.danger,
                        iconSurface:
                            context.palette.danger.withValues(alpha: 0.10),
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
          // IG: başlık ile içerik arası dar; aksiyon düğmelerinin hemen
          // altında usta anahtarı gelir.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TEK PROFİL, ek modüller. Eskiden `artisanMode` iki AYRI
              // gövdeye ayırıyordu (_ArtisanHome / _CustomerHome) — kullanıcı
              // "iki farklı ekran" hissediyordu. Artık herkes aynı profili
              // görür; usta anahtarı açıkken ÜSTÜNE modül eklenir.
              if (user.hasArtisanProfile) ...[
                _ArtisanModeSwitch(user: user),
                const SizedBox(height: 14),
              ],

              // Usta modülleri (yalnız anahtar açıkken)
              if (artisanMode) ...[
                _ArtisanHome(user: user, draft: draft),
                const SizedBox(height: 8),
              ],

              // Herkeste ortak: ilanlarım (+ usta değilse dönüşüm çağrısı)
              _CustomerHome(user: user),
              // ARAÇLAR bölümü de KALDIRILDI: "Ajanda" yan menüye taşındı
              // (kişisel araç, profil içeriği değil). "Ürünlerim" usta
              // dükkânı bölümünde zaten var.
              //
              // HESABIM (doğrulama, üyelik, çıkış, hesap silme) → Hesap
              // Ayarları (`/profile/account`), yan menüden.
              //
              // Profil artık YALNIZ İÇERİK gösterir: ilanlarım · işlerim ·
              // takip. Ayarlar ve araçlar menüde.
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
    final palette = context.palette;
    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final photo = draft?.profilePhotoUrl ?? user.profilePhotoUrl;
    final profession = artisanMode && draft != null
        ? kProfessionNames[draft!.profile.profession]
        : null;
    final about = artisanMode ? draft?.profile.aboutText.trim() : null;

    return SafeArea(
      bottom: false,
      child: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst şerit: menü (sol) + ad (orta) + bildirim (sağ).
            Row(
              children: [
                const DrawerMenuButton(),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Kullanıcı' : name,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const NotificationBell(),
              ],
            ),
            const SizedBox(height: 8),

            // Instagram başlığı: avatar SOLDA, sayaçlar YANINDA (yatay).
            Row(
              children: [
                _AvatarWithEdit(photo: photo, initials: initials),
                const SizedBox(width: 8),
                Expanded(child: _HeroStats(user: user)),
              ],
            ),
            const SizedBox(height: 12),

            // Bio: ad + mavi tik, meslek, hakkımda — hepsi SOLA dayalı.
            Row(
              children: [
                Flexible(
                  child: Text(
                    name.isEmpty ? 'Kullanıcı' : name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (user.phoneVerified) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.verified, size: 16, color: palette.verified),
                ],
              ],
            ),
            if (profession != null && profession.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  profession,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (about != null && about.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  about,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),

            // Aksiyon çubuğu (IG: "Profili düzenle | Profili paylaş").
            Row(
              children: [
                Expanded(
                  child: _HeroAction(
                    label: 'Profili düzenle',
                    onTap: () => context.push(RoutePaths.profileEdit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroAction(
                    label: 'Profilime bak',
                    onTap: () =>
                        context.push(RoutePaths.artisanProfile(user.uid)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + sağ altında "+" rozeti (IG foto ekleme göstergesi).
class _AvatarWithEdit extends StatelessWidget {
  const _AvatarWithEdit({required this.photo, required this.initials});
  final String? photo;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () => context.push(RoutePaths.profileEdit),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: photo != null
                      ? AppImage(
                          handle: photo,
                          fit: BoxFit.cover,
                          width: 78,
                          height: 78,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                        )
                      : Container(
                          color: palette.primaryContainer,
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: palette.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IG'deki gri, geniş, düşük kontrastlı aksiyon düğmesi.
class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

/// Instagram tarzı 3'lü sayaç şeridi (başlığın yanında).
///
/// Herkeste aynı: **takip · takipçi · (puan | tamamlanan)**.
/// Usta modunda ve değerlendirme varsa 3. hücre puanı gösterir.
class _HeroStats extends ConsumerWidget {
  const _HeroStats({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers =
        ref.watch(followersProvider(user.uid)).valueOrNull?.length;
    final following =
        ref.watch(favoritesProvider(user.uid)).valueOrNull?.length;

    // TEK SATIR, HERKESTE AYNI (Instagram düzeni). Eskiden usta/müşteri iki
    // ayrı sayaç dizisi görüyordu; rol ayrımı kalktı.
    //
    // Usta modunda 3. hücre PUAN gösterir (vitrin argümanı); kapalıyken
    // "tamamlanan" kalır. Müşteri puanı herkese AÇILMAZ — düşük puan teşhir
    // olmasın (bkz. Firestore-Semasi notu).
    final profile = user.isArtisan
        ? ref.watch(myProfileControllerProvider).valueOrNull?.profile
        : null;
    final hasRating = (profile?.totalReviews ?? 0) > 0;

    return Row(
      children: [
        _StatCell(
          value: '${following ?? 0}',
          label: 'takip',
          onTap: () => context.push(RoutePaths.favorites),
        ),
        _StatCell(
          value: '${followers ?? 0}',
          label: 'takipçi',
          onTap: () => context.push(RoutePaths.favorites),
        ),
        if (user.isArtisan && hasRating)
          _StatCell(
            value: (profile?.averageRating ?? 0).toStringAsFixed(1),
            label: 'puan',
            icon: Icons.star_rounded,
          )
        else
          _StatCell(
            value: user.isArtisan
                ? '${profile?.completedJobs ?? 0}'
                : '${user.completedJobsAsCustomer}',
            label: 'tamamlanan',
          ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: const Color(0xFFFBBF24)),
                    const SizedBox(width: 2),
                  ],
                  // IG: sayı iri ve koyu, etiket altında küçük ve soluk.
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.inkMuted,
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
// Mod anahtarı — Müşteri hesabı | Usta dükkânı
// ---------------------------------------------------------------------------

/// Usta modu anahtarı — TEK profil, açılıp kapanan ek modüller.
///
/// Eskiden iki seçenekli `SegmentedButton`'dı ("Müşteri | Usta dükkânı") ve
/// iki AYRI hesap yüzeyi varmış izlenimi veriyordu. Instagram'da "profesyonel
/// hesap" nasıl tek anahtarla açılıyorsa burada da öyle: kapalıyken sade
/// profil, açıkken üstüne dükkân modülleri biner.
class _ArtisanModeSwitch extends ConsumerWidget {
  const _ArtisanModeSwitch({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final on = user.isArtisan;
    // Karşı modda bekleyen okunmamış mesaj sayısı. Bu rozet eskiden yan
    // menüdeki "Usta/Müşteri Moduna Geç" satırındaydı; o satırlar kalkınca
    // buraya taşındı — yoksa kullanıcı diğer taraftaki mesajı fark etmez.
    final crossUnread = ref.watch(otherModeUnreadProvider);

    Future<void> toggle(bool next) async {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .setActiveMode(next ? UserRole.artisan : UserRole.customer);
      if (!context.mounted) return;
      if (!ok) context.showError('Mod değiştirilemedi, tekrar deneyin.');
      // Sayfadan ayrılmayız: içerik kendini yeniler, kullanıcı değişimi görür.
    }

    return Material(
      color: on ? palette.primaryContainer : palette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? palette.primary : palette.border,
            width: on ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              on ? Icons.storefront_rounded : Icons.storefront_outlined,
              size: 20,
              color: on ? palette.primary : palette.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Usta modu',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: on ? palette.primary : null,
                    ),
                  ),
                  Text(
                    crossUnread > 0
                        ? (on
                            ? 'Müşteri tarafında $crossUnread okunmamış mesaj'
                            : 'Usta tarafında $crossUnread okunmamış mesaj')
                        : (on
                            ? 'Açık — iş alabilir, vitrinini yönetebilirsin'
                            : 'Kapalı — yalnız hizmet alıyorsun'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: crossUnread > 0
                          ? palette.danger
                          : palette.inkMuted,
                      fontWeight:
                          crossUnread > 0 ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
            // Karşı modda bekleyen mesaj varsa anahtarın yanında kırmızı sayı.
            if (crossUnread > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Badge(
                  label: Text('$crossUnread'),
                  backgroundColor: palette.danger,
                ),
              ),
            Switch(value: on, onChanged: toggle),
          ],
        ),
      ),
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
        // Sadeleştirme: bölüm etiketleri kalktı, mükerrerler temizlendi.
        //  - "İŞLER" satırı → alt bardaki "İlanlar" sekmesiyle aynı yere
        //    gidiyordu (mükerrer giriş).
        //  - "TAKİPÇİLER" listesi → başlıktaki takipçi sayacı zaten var ve
        //    dokununca aynı listeyi açıyor.
        //  - "İlanlarım" BURADA YOK: `_CustomerHome` herkeste çiziliyor ve
        //    o satır zaten orada. Usta modunda iki kez görünüyordu.
        _Group(children: [_AvailabilityRow(draft: draft)]),
        _ShopVitrineCard(user: user, draft: draft, shopSubtitle: shopSubtitle),
      ],
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
        // "İlanlarım" PROFİLDEN KALKTI → yan menüde (usta modunda görünür).
        // Alt bardaki "İlanlar" sekmesiyle de mükerrerdi.
        // "Takip ettiklerim" ise başlıktaki sayaçtan açılıyor.
        //
        // Usta modu yoksa tek çağrı: dükkân aç. Bu bir "içerik" değil ama
        // ürünün ana dönüşüm adımı — profilde kalması bilinçli.
        if (!user.hasArtisanProfile) ...[
          _Group(
            children: [
              _MenuRow(
                icon: Icons.handyman_outlined,
                iconColor: context.palette.onSecondaryContainer,
                iconSurface: context.palette.secondaryContainer,
                title: 'Usta olarak devam et',
                subtitle: 'Meslek ve bölge ekle, iş almaya başla',
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

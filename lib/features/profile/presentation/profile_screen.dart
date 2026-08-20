import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_format.dart';
import '../../../core/utils/photo_picker.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/collapsible_chips.dart';
import '../../../core/widgets/photo_gallery_page.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/profile_header.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/product.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../membership/membership_access.dart';
import '../../membership/membership_package.dart';
import '../../products/data/product_category_providers.dart';
import '../../products/data/product_providers.dart';
import '../../storage/storage_repository.dart';
import 'widgets/account_deletion_sheet.dart';

/// Profil (alt bar) — TEK profil; Usta | Mağaza sekmeleri.
///
/// Aktif "usta modu" switch'i YOK. Yetenek [AppUser.hasArtisanProfile] /
/// [AppUser.hasShopProfile] ile; müsaitlik ayrı anahtar.
///
/// Profil yalnız İÇERİK gösterir. Hesap ayarları (doğrulama, üyelik, çıkış)
/// `/profile/account`'ta, kişisel araçlar (Ajanda) yan menüde.
class ProfileScreen extends ConsumerWidget {
  ProfileScreen({super.key});

  /// Yan menü açıkken geri tuşunun menüyü kapatabilmesi için (madde 4).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return MainTabScope(
      tab: MainTab.profile,
      scaffoldKey: _scaffoldKey,
      child: Scaffold(
        key: _scaffoldKey,
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

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    // Usta profili (müsaitlik + iş foto) için taslak — usta veya mağaza
    // müsait anahtarı için de yüklenir.
    final needDraft = user.hasArtisanProfile || user.hasShopProfile;
    final draft = needDraft
        ? ref.watch(myProfileControllerProvider).valueOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Hero(
          user: user,
          draft: draft,
          showAvailability: user.hasArtisanProfile || user.hasShopProfile,
        ),
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Usta | Mağaza sekmeleri (sürekli switch yok).
              Material(
                color: context.palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                child: TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Usta'),
                    Tab(text: 'Mağaza'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _tabs,
                builder: (context, _) {
                  if (_tabs.index == 0) {
                    return _UstaTabPanel(user: user, draft: draft);
                  }
                  return _MagazaTabPanel(user: user);
                },
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

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.user,
    required this.draft,
    required this.showAvailability,
  });
  final AppUser user;
  final MyProfileDraft? draft;
  final bool showAvailability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = user.displayName.trim();
    final photo = draft?.profilePhotoUrl ?? user.profilePhotoUrl;
    final profession = user.hasArtisanProfile && draft != null
        ? kProfessionNames[draft!.profile.profession]
        : null;
    // "Hakkımda" HER İKİ MODDA da görünür (2026-08-08): ortak alan artık
    // `users` altında. Taslak yüklüyse ondan (yeni yazılan metin anında
    // görünsün), değilse kullanıcı dokümanından.
    final about = (draft?.profile.aboutText.trim().isNotEmpty ?? false)
        ? draft!.profile.aboutText.trim()
        : user.aboutText.trim();

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

            // ORTAK BAŞLIK — başkasının profiliyle AYNI widget.
            // Tek fark eylem düğmeleri: burada "düzenle | bak",
            // karşı tarafta "Mesaj | Takip et".
            ProfileHeader(
              user: user,
              isMe: true,
              photoOverride: photo,
              aboutOverride: about,
              professionOverride: profession,
              onAvatarTap: () => context.push(RoutePaths.profileEdit),
              avatarBadge: const _AvatarPlusBadge(),
              extra: showAvailability
                  ? _AvailabilitySwitch(user: user, draft: draft)
                  : null,
              actions: ProfileActionButton(
                label: 'Profili düzenle',
                onTap: () => context.push(RoutePaths.profileEdit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatarın sağ altındaki "+" rozeti — fotoğraf değiştirme göstergesi (IG).
class _AvatarPlusBadge extends StatelessWidget {
  const _AvatarPlusBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: palette.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: const Icon(Icons.add, size: 14, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------------------
// Usta | Mağaza sekmeleri
// ---------------------------------------------------------------------------

class _UstaTabPanel extends ConsumerWidget {
  const _UstaTabPanel({required this.user, required this.draft});
  final AppUser user;
  final MyProfileDraft? draft;

  Future<void> _becomeArtisan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hizmet vermeye başla'),
        content: const Text(
          'Meslek ve hizmet bölgenizi belirledikten sonra müşteriler sizi '
          'Keşfet’te bulabilir. Mağaza profiliniz varsa o da açık kalır — '
          'ikisini birden kullanabilirsiniz.',
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
        'Usta profili açıldı. Meslek ve bölgenizi kaydedin.',
      );
      context.push(RoutePaths.panelEdit);
    } else {
      final error = ref.read(authControllerProvider).error;
      context.showError(
        error is AuthException ? error.message : AuthException.unknown.message,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);

    if (!user.hasArtisanProfile) {
      // DAVET KARTI (2026-08-20 kullanıcı bulgusu): eskiden iki satırlık kuru
      // bir metindi ("meslek ve bölge ekleyerek ... mesaj atın"). Kullanıcı
      // "açarsam ne kazanırım" sorusunun cevabını alamıyordu.
      //
      // Maddeler UYDURMA DEĞİL, kodun gerçek davranışıdır:
      //  - bildirim  → `onJobCreated` (CF): aynı il + aynı meslek fan-out
      //  - sekme     → `_JobsTab` kapısı `hasArtisanProfile` ile açılır
      //  - liste     → Keşfet > Ustalar (`artisanProfiles`)
      //  - ana sayfa → `HomeForYou` "Sana Uygun İlanlar" şeridi
      return _RolDavetKarti(
        baslik: 'Hizmet verin',
        girisMetni: 'Meslek ve bölgenizi ekleyin; işler size gelsin.',
        ikon: Icons.handyman_outlined,
        faydalar: const [
          'İlinizdeki ilanlar için bildirim alırsınız — mesleğinize uyanlar',
          'Ana sayfada "Sana Uygun İlanlar" şeridi açılır',
          'Keşfette İlanlar sekmesi açılır, açık ilanları görürsünüz',
          'Ustalar listesinde görünür, müşteriler size ulaşır',
        ],
        sartMetni: 'İlanlara mesaj atabilmek ve listelerde görünmek için '
            'profilinizdeki "Müsait" anahtarını açmanız gerekir.',
        dugmeMetni: 'Hizmet vermeye başla',
        onTap: () => _becomeArtisan(context, ref),
      );
    }

    final available = draft?.profile.isAvailable ?? user.available;
    final workPhotos = draft?.profile.workPhotos ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => context.push(RoutePaths.myJobs),
          icon: const Icon(Icons.assignment_outlined, size: 18),
          label: const Text('İlanlarım'),
        ),
        const SizedBox(height: 12),
        if (!available)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: palette.warningSurface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Müsait değilsiniz: ustalar listesinde görünmezsiniz ve '
                  'ilan sahiplerine mesaj atamazsınız. Bildirim almaya devam '
                  'edebilirsiniz. Üstteki “Müsait” anahtarını açın.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        _WorkPhotoShareBlock(photos: workPhotos),
      ],
    );
  }
}

/// İş fotoğrafı ekle — doğrudan yükler, profil düzenlemeye gitmez.
class _WorkPhotoShareBlock extends ConsumerStatefulWidget {
  const _WorkPhotoShareBlock({required this.photos});
  final List<String> photos;

  @override
  ConsumerState<_WorkPhotoShareBlock> createState() =>
      _WorkPhotoShareBlockState();
}

class _WorkPhotoShareBlockState extends ConsumerState<_WorkPhotoShareBlock> {
  bool _uploading = false;

  Future<void> _addPhotos() async {
    if (_uploading) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final palette = context.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined,
                    color: palette.primary),
                title: const Text('Kamera ile çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: palette.primary),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    // Vitrin ızgarası 4:5; kırpma olmadan dikey fotoğrafın altı kesiliyordu.
    final List<Uint8List> files;
    try {
      final draftNow = ref.read(myProfileControllerProvider).valueOrNull;
      final kalan = AppConstants.maxWorkPhotos -
          (draftNow?.profile.workPhotos.length ?? 0);
      files = await PhotoPicker.pickMultiPhoto(
        context,
        source: source,
        limit: kalan,
        title: 'Vitrin fotoğrafı',
      );
    } catch (_) {
      if (mounted) context.showError('Görsel seçilemedi.');
      return;
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    final ctrl = ref.read(myProfileControllerProvider.notifier);
    final storage = ref.read(storageRepositoryProvider);
    try {
      for (final bytes in files) {
        if (bytes.length > AppConstants.maxPhotoSizeBytes) {
          if (mounted) {
            context.showError('Bir görsel 5 MB\'dan büyük; atlandı.');
          }
          continue;
        }
        final draft = ref.read(myProfileControllerProvider).valueOrNull;
        if (draft != null &&
            draft.profile.workPhotos.length >= AppConstants.maxWorkPhotos) {
          if (mounted) {
            context.showInfo(
              'En fazla ${AppConstants.maxWorkPhotos} iş fotoğrafı '
              'ekleyebilirsiniz.',
            );
          }
          break;
        }
        final handle = await storage.uploadImage(
          pathHint: 'work/$uid',
          bytes: Uint8List.fromList(bytes),
        );
        if (!ctrl.addWorkPhoto(handle)) {
          if (mounted) {
            context.showInfo(
              'En fazla ${AppConstants.maxWorkPhotos} iş fotoğrafı '
              'ekleyebilirsiniz.',
            );
          }
          break;
        }
      }
      final ok = await ctrl.save();
      if (!mounted) return;
      if (ok) {
        context.showSuccess('İş fotoğrafları kaydedildi.');
      } else {
        context.showError('Kayıt başarısız, tekrar deneyin.');
      }
    } catch (_) {
      if (mounted) {
        context.showError('Yükleme başarısız. Bağlantınızı kontrol edin.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photos = widget.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _addPhotos,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined, size: 18),
          label: Text(_uploading ? 'Yükleniyor…' : 'İş fotoğrafı paylaşın'),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => PhotoGalleryPage.open(
                    context,
                    handles: photos,
                    initialIndex: i,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: AppImage(handle: photos[i], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Yaptığınız işlerin fotoğraflarını ekleyin; profilinizde görünür.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.inkFaint,
                  ),
            ),
          ),
      ],
    );
  }
}

class _MagazaTabPanel extends ConsumerWidget {
  const _MagazaTabPanel({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final live = ref.watch(productsLiveProvider);

    if (!live) {
      return Text(
        'Mağaza şu an platform genelinde kapalı.',
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      );
    }

    if (!user.hasShopProfile) {
      // Usta kartıyla aynı gerekçe. Maddelerin kod karşılıkları:
      //  - talepler  → `_TaleplerBolumu`: mağaza + müsaitlik varsa TAMAMI,
      //                yoksa yalnız `kSinirliTalepSayisi` örnek
      //  - vitrin    → `availableDiscoverProductsProvider` (müsaitliğe bağlı)
      //  - ana sayfa → `HomeForYou` "İlindeki Talepler" şeridi
      //  - mesaj     → `availability_gate.dart`
      return _RolDavetKarti(
        baslik: 'Satış yapın',
        girisMetni: 'Ürün kategorilerinizi seçin, vitrininizi açın.',
        ikon: Icons.storefront_outlined,
        faydalar: const [
          'İlinizdeki ürün taleplerinin TAMAMINI görürsünüz',
          'Ana sayfada "İlindeki Talepler" şeridi açılır',
          'Ürünleriniz Keşfet > Mağaza vitrininde listelenir',
          'Talep sahiplerine mesaj yazabilirsiniz',
        ],
        sartMetni: 'Vitrininizin görünmesi, taleplerin tamamına erişmek ve '
            'mesaj yazabilmek için "Müsait" anahtarınız açık olmalıdır. '
            'Kapalıyken ürünleriniz listelerde görünmez.',
        dugmeMetni: 'Satış yapmaya başla',
        onTap: () => context.push(RoutePaths.shopSetup),
      );
    }

    final productsAsync = ref.watch(myProductsProvider(user.uid));
    final catalog = catalogOf(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!user.available)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: palette.warningSurface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Müsait değilsiniz: ürünleriniz vitrinde öne çıkmaz ve '
                  'ürün taleplerine mesaj atamazsınız. Üstteki “Müsait” '
                  'anahtarını açın.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Satış kategorileri',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(RoutePaths.shopEdit),
              child: const Text('Düzenle'),
            ),
          ],
        ),
        if (user.shopCategories.isEmpty)
          Text(
            'Henüz kategori seçilmedi. Düzenle ile ekleyin — talepler '
            'bu kategorilere gider.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.warning),
          )
        else
          // Çok kategori seçen mağaza profili şişirmesin: ilki görünür,
          // kalanı "+N daha" arkasında (new.md madde 4).
          CollapsibleChips(
            labels: [
              for (final code in user.shopCategories) catalog.label(code),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          'Mağaza bölgeleri',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.inkMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Müşteriler mağazanızın yerini burada görür.',
          style: theme.textTheme.labelSmall?.copyWith(color: palette.inkFaint),
        ),
        const SizedBox(height: 6),
        if (user.shopServiceAreas.isEmpty)
          Text(
            'Bölge yok. Düzenle ile il/ilçe ekleyin, yoksa talepler '
            'size ulaşmayabilir.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.warning),
          )
        else
          // Bölge listesi de uzayabilir (il+ilçe çiftleri) — aynı daraltma.
          CollapsibleChips(
            labels: [for (final a in user.shopServiceAreas) a.labelTR],
            avatarBuilder: (_) =>
                Icon(Icons.place_outlined, size: 14, color: palette.inkMuted),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.myProducts),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Ürünlerim'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.myProductRequests),
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Taleplerim'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(RoutePaths.productNew),
          // Düğme ürün EKLEME formunu açar (başlık, fiyat, kategori…),
          // yalnız fotoğraf paylaşmıyor — eski metin yanıltıcıydı.
          icon: const Icon(Icons.add_business_outlined, size: 18),
          label: const Text('Yeni ürün paylaşın'),
        ),
        const SizedBox(height: 8),
        Text(
          'Ürün fotoğrafına basınca detay ekranı açılır.',
          style: theme.textTheme.labelSmall?.copyWith(color: palette.inkFaint),
        ),
        const SizedBox(height: 14),
        Text(
          'Ürünlerim',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        productsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Ürünler yüklenemedi.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.danger),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'Henüz ürün yok. Yukarıdan fotoğraf ekleyerek başlayın.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ProfileProductRow(product: list[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Mağaza sekmesinde satır: tıkla → ürün detay (önizleme / keşfet görünümü).
class _ProfileProductRow extends StatelessWidget {
  const _ProfileProductRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = product;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(RoutePaths.productDetail(p.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: p.coverPhoto == null
                      ? ColoredBox(
                          color: palette.surfaceMuted,
                          child: Icon(
                            Icons.image_outlined,
                            color: palette.inkMuted,
                          ),
                        )
                      : AppImage(
                          handle: p.coverPhoto,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title.isEmpty ? 'İsimsiz taslak' : p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.status.labelTR} · ${p.priceLabel}',
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Müsaitlik — usta veya mağaza profili açılınca hep görünür.
///
/// Durumlu (2026-08-14): her değişim 3 Firestore yazması ve o satıcıyı
/// izleyen her istemciye 1 okuma üretir. İşlem sürerken anahtar kilitlenir;
/// hızlı aç-kapa-aç yazma fırtınası oluşturamaz.
class _AvailabilitySwitch extends ConsumerStatefulWidget {
  const _AvailabilitySwitch({required this.user, required this.draft});
  final AppUser user;
  final MyProfileDraft? draft;

  @override
  ConsumerState<_AvailabilitySwitch> createState() =>
      _AvailabilitySwitchState();
}

class _AvailabilitySwitchState extends ConsumerState<_AvailabilitySwitch> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final draft = widget.draft;
    final theme = Theme.of(context);
    final palette = context.palette;
    final profile = draft?.profile;
    // Usta profili varsa vitrin müsaitliği; yoksa users.available (mağaza).
    final available = user.hasArtisanProfile
        ? (profile?.isAvailable ?? user.available)
        : user.available;

    Future<void> onChanged(bool value) async {
      if (user.hasArtisanProfile) {
        if (value && !ref.read(artisanProAccessProvider)) {
          context.push(RoutePaths.panelPremium);
          return;
        }
        // Her zaman usta profili + users.available birlikte.
        // Eskiden taslak yokken yalnız users.available yazılıyordu; ilan
        // detayı profile.isAvailable görünce müsait sanıp mesaj açıyordu.
        if (profile == null) {
          try {
            await ref
                .read(authRepositoryProvider)
                .updateUserProfile(available: value);
          } catch (_) {
            if (context.mounted) {
              context.showError('İşlem başarısız, tekrar deneyin.');
            }
            return;
          }
          // Taslak yüklenince vitrin alanını da hizala.
          final ok = await ref
              .read(myProfileControllerProvider.notifier)
              .setAvailable(value);
          if (!context.mounted) return;
          if (!ok) {
            // users.available yazıldı; vitrin sonra yüklenebilir.
            context.showInfo(
              value
                  ? 'Müsaitlik güncellendi.'
                  : 'Müsaitlik kapatıldı. Profil yenilenince tam senkron olur.',
            );
            return;
          }
        } else {
          final ok = await ref
              .read(myProfileControllerProvider.notifier)
              .setAvailable(value);
          if (!context.mounted) return;
          if (!ok) {
            context.showError('İşlem başarısız, tekrar deneyin.');
            return;
          }
        }
      } else {
        try {
          await ref
              .read(authRepositoryProvider)
              .updateUserProfile(available: value);
        } catch (_) {
          if (context.mounted) {
            context.showError('İşlem başarısız, tekrar deneyin.');
          }
          return;
        }
      }
      if (!context.mounted) return;
      context.showInfo(
        value
            ? 'Artık müsait görünüyorsunuz.'
            : 'Müsait değilsiniz. Usta listesi / mağaza vitrini etkilenir.',
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 28,
          child: Switch(
            value: available,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            // YAZMA KORUMASI: işlem sürerken anahtar kilitlenir.
            //
            // Her değişim 3 Firestore yazması (artisanProfiles + users) ve
            // o satıcıyı izleyen HER istemciye 1 okuma üretir. Koruma
            // olmadan hızlı aç-kapa-aç bunu katlar; ölçekte hem fatura hem
            // gereksiz ağ yükü demek.
            onChanged: _busy ? null : _guardedChange(onChanged),
          ),
        ),
        const SizedBox(width: 8),
        if (_busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            'Müsait',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: available ? palette.ink : palette.inkMuted,
            ),
          ),
      ],
    );
  }

  /// [onChanged]'i meşguliyet bayrağıyla sarar: işlem bitmeden ikinci
  /// dokunuş yutulur.
  ValueChanged<bool> _guardedChange(Future<void> Function(bool) inner) {
    return (v) async {
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await inner(v);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    };
  }
}

/// Hesap silme akışı: Apple App Store, Google Play Store ve KVKK/GDPR uyumlu
/// çok adımlı kaza önleme kalkanına sahip [AccountDeletionSheet] modalını açar.
Future<void> _deleteAccountFlow(BuildContext context, WidgetRef ref) async {
  await AccountDeletionSheet.show(context);
}

// ---------------------------------------------------------------------------
// Hesap grubu (her iki modda ortak)
// ---------------------------------------------------------------------------

class _AccountGroup extends ConsumerWidget {
  const _AccountGroup({required this.user});
  final AppUser user;

  /// İletişim numarasını ekle / değiştir / kaldır.
  ///
  /// Numara DOĞRULANMAZ (SMS akışı kaldırıldı) — bu yüzden tek savunma
  /// [normalizeTrMobile] ayrıştırıcısıdır: kaydedilen değer her zaman
  /// E.164'tür, kullanıcı ne yazarsa yazsın.
  Future<void> _editPhone(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final sonuc = await _PhoneEditSheet.show(context, user.publicPhone);
    if (sonuc == null || !context.mounted) return;

    final kaldirildi = sonuc.isEmpty;
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
            // Boş dize = TEMİZLE (null "değiştirme" demek — bkz. AppUser).
            publicPhone: sonuc,
          );
      // Numara kaldırıldıysa vitrindeki gösterim de kapanmalı: aksi hâlde
      // profil "numaram görünsün" açık ama numara yok durumunda kalır.
      if (kaldirildi && (user.hasArtisanProfile || user.hasShopProfile)) {
        await ref
            .read(myProfileControllerProvider.notifier)
            .setPhoneVisibility(show: false);
      }
      if (!context.mounted) return;
      context.showSuccess(
        kaldirildi ? 'Numaran kaldırıldı.' : 'Numaran kaydedildi.',
      );
    } catch (_) {
      if (context.mounted) {
        context.showError('Numara kaydedilemedi, tekrar deneyin.');
      }
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
        user.hasArtisanProfile &&
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
        // Telefon numarası TAMAMEN İSTEĞE BAĞLIDIR ve doğrulanmaz
        // (SMS akışı 2026-08-18'de kaldırıldı). Numara girilince "profilde
        // göster" anahtarı açılabilir; yayınlanmış numara sohbet başlığında
        // WhatsApp düğmesini de açar.
        _MenuRow(
          icon: Icons.phone_outlined,
          iconColor: context.palette.primary,
          iconSurface: context.palette.primaryContainer,
          title: 'İletişim Numarası',
          subtitle: (user.publicPhone != null && user.publicPhone!.isNotEmpty)
              ? formatTrPhone(user.publicPhone!)
              : 'İsteğe bağlı — eklemezseniz numaranız hiç kaydedilmez',
          trailing: TextButton(
            onPressed: () => _editPhone(context, ref, user),
            child: Text(
              user.publicPhone != null && user.publicPhone!.isNotEmpty
                  ? 'Düzenle'
                  : 'Ekle',
            ),
          ),
        ),
        if (user.publicPhone != null && user.publicPhone!.isNotEmpty)
          _PhoneVisibilityRow(phoneNumber: user.publicPhone),
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
/// İletişim numarası giriş formu (alt sayfa).
///
/// Dönen değer: kaydedilecek E.164 numara, temizlemek için boş dize,
/// vazgeçildiyse `null`.
///
/// TASARIM NOTU — numara doğrulanmadığı için hataları kaydetmeden ÖNCE
/// yakalamak zorundayız:
///  - Girdi yalnız rakam + biçim işaretlerine izin verir (harf yazılamaz).
///  - Kaydet düğmesi geçersiz numarada PASİFTİR (sessiz başarısızlık yok).
///  - Kayıt her zaman E.164'e çevrilir; kullanıcının yazım biçimi
///    veritabanına sızmaz (`0532...`, `+90 532...` hepsi `+905...` olur).
class _PhoneEditSheet extends StatefulWidget {
  const _PhoneEditSheet({this.initial});

  final String? initial;

  static Future<String?> show(BuildContext context, String? initial) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhoneEditSheet(initial: initial),
    );
  }

  @override
  State<_PhoneEditSheet> createState() => _PhoneEditSheetState();
}

class _PhoneEditSheetState extends State<_PhoneEditSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial == null ? '' : formatTrPhone(widget.initial!),
  );
  String? _hata;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dogrula(String v) => setState(() => _hata = trPhoneError(v));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metin = _ctrl.text.trim();
    final gecerli = metin.isNotEmpty && normalizeTrMobile(metin) != null;
    final vardi = (widget.initial ?? '').isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İletişim Numarası',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'İsteğe bağlıdır ve doğrulanmaz. Numaranı yalnızca '
            '“profilimde görünsün” anahtarını açarsan diğer kullanıcılar '
            'görebilir; kapalıyken kimseye gösterilmez.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            // Harf ve beklenmedik işaretler hiç yazılamasın (hata sonradan
            // değil, tuşta engellenir).
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()+\-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: 'Cep telefonu',
              hintText: '0532 123 45 67',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _hata,
              border: const OutlineInputBorder(),
            ),
            onChanged: _dogrula,
            onSubmitted: (_) {
              if (gecerli) Navigator.of(context).pop(normalizeTrMobile(metin));
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (vardi)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(''),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Numarayı kaldır'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: gecerli
                    ? () =>
                        Navigator.of(context).pop(normalizeTrMobile(metin))
                    : null,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhoneVisibilityRow extends ConsumerWidget {
  const _PhoneVisibilityRow({required this.phoneNumber});
  final String? phoneNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    final shown = draft?.profile.hasPublicPhone ?? false;

    Future<void> onChanged(bool value) async {
      // Açarken numara şart (gösterecek bir şey yoksa anahtar anlamsız).
      //
      // NUMARA KAYNAĞI (2026-08-18): SMS doğrulaması kaldırıldı; numara
      // artık kullanıcının elle girdiği `publicPhone` alanıdır. Bu satır
      // zaten yalnız numara doluyken gösterilir — buraya düşmek, numaranın
      // arada silinmiş olması demektir.
      if (value && (phoneNumber == null || phoneNumber!.trim().isEmpty)) {
        context.showError(
          'Önce “İletişim Numarası” bölümünden numaranızı ekleyin.',
        );
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

/// Usta / Mağaza **davet kartı** — "açarsan ne kazanırsın".
///
/// 2026-08-20 kullanıcı bulgusu: iki sekmedeki davetler ikişer satırlık kuru
/// metindi; kullanıcı rolü açmanın ne getirdiğini anlamıyordu. Kart üç parça
/// taşır:
///
///  1. **Fayda listesi** — somut, kodun gerçek davranışı (uydurma vaat yok)
///  2. **Şart uyarısı** — müsaitlik anahtarı. Sonradan "ürünlerim neden
///     görünmüyor" sorusunu doğuran şey buydu; şimdi ÖNCEDEN söyleniyor
///  3. **Eylem düğmesi**
///
/// Dil DAVET'tir, ceza değil: kullanıcı bir şey kaybetmiyor, kazanabiliyor
/// (`_TalepKilidi` kartıyla aynı ton).
class _RolDavetKarti extends StatelessWidget {
  const _RolDavetKarti({
    required this.baslik,
    required this.girisMetni,
    required this.ikon,
    required this.faydalar,
    required this.sartMetni,
    required this.dugmeMetni,
    required this.onTap,
  });

  final String baslik;
  final String girisMetni;
  final IconData ikon;
  final List<String> faydalar;
  final String sartMetni;
  final String dugmeMetni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          baslik,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          girisMetni,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.inkMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),

        // Fayda listesi — her madde onay işaretiyle.
        for (final f in faydalar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: palette.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 6),

        // Şart uyarısı — müsaitlik. Sürpriz olmasın diye AÇMADAN ÖNCE.
        Material(
          color: palette.warningSurface,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: palette.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sartMetni,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onTap,
          icon: Icon(ikon, size: 18),
          label: Text(dugmeMetni),
        ),
      ],
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

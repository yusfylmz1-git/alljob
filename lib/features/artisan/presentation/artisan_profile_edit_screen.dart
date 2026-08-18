import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/photo_picker.dart';
import '../../../core/utils/search_fold.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/user_role.dart' show UserRole;
import '../../../data/models/availability.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/profession.dart'
    show Profession, ProfessionCategory;
import '../../../data/models/artisan_profile.dart';
import '../../../data/models/job.dart'
    show
        isQuickSupportProviderCodes,
        kOtherProfession,
        kQuickSupportCategory,
        kQuickSupportName;
import '../../../data/models/social_links.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/presentation/quick_support_intro_sheet.dart';
import '../../storage/storage_repository.dart';
import '../application/my_profile_controller.dart';

const _kEditAppBar = GradientAppBar(
  title: 'Profili Düzenle',
  icon: Icons.badge_outlined,
  // GradientAppBar KOYU: zil beyaz kalmalı.
  actions: [
    NotificationBell(color: Colors.white),
    SizedBox(width: 4),
  ],
);

/// Ekran F — Usta Dashboard / Profil Düzenleme Paneli.
///
/// [focusStep]: vitrin funnel deep-link (photo|about|profession|area|photos|hours).
class ArtisanProfileEditScreen extends ConsumerWidget {
  const ArtisanProfileEditScreen({super.key, this.focusStep});

  final String? focusStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(myProfileControllerProvider);

    // Çıkış Yap butonu kaldırıldı — çıkış, birleşik profil sayfasında
    // (düzenleme ekranında oturum kapatmak beklenmedik bir eylemdi).
    return draftAsync.when(
      loading: () => const Scaffold(
        appBar: _kEditAppBar,
        body: LoadingView(),
      ),
      error: (_, _) => const Scaffold(
        appBar: _kEditAppBar,
        body: ErrorView(
          message:
              'Profil yüklenemedi. Bağlantınızı kontrol edip '
              'tekrar deneyin.',
        ),
      ),
      data: (_) => _EditForm(focusStep: focusStep),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({this.focusStep});

  final String? focusStep;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  // "Hizmet bölgesi ekle" satırının yerel seçim durumu.
  Province? _addProvince;
  District? _addDistrict;

  final Map<String, GlobalKey> _sectionKeys = {
    'photo': GlobalKey(),
    'about': GlobalKey(),
    'profession': GlobalKey(),
    'area': GlobalKey(),
    'photos': GlobalKey(),
    'hours': GlobalKey(),
  };
  bool _didScrollToFocus = false;

  bool get _isSaving => ref.watch(myProfileControllerProvider).isLoading;

  MyProfileController get _controller =>
      ref.read(myProfileControllerProvider.notifier);

  /// Şu an yüklemesi süren hedef ('profile' | 'work' | 'certificate');
  /// null = yükleme yok. İlgili alanda spinner gösterilir, ikinci tık yutulur.
  String? _uploading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
  }

  void _scrollToFocus() {
    if (_didScrollToFocus) return;
    final id = widget.focusStep;
    if (id == null || id.isEmpty) return;
    final ctx = _sectionKeys[id]?.currentContext;
    if (ctx == null) {
      // Liste henüz boyanmamış olabilir; bir frame daha dene.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didScrollToFocus) return;
        final c = _sectionKeys[id]?.currentContext;
        if (c == null) return;
        _didScrollToFocus = true;
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      });
      return;
    }
    _didScrollToFocus = true;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Widget _focusWrap({required String id, required Widget child}) {
    final focused = widget.focusStep == id;
    final palette = context.palette;
    return KeyedSubtree(
      key: _sectionKeys[id],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: focused ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
        padding: focused ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: focused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.primary, width: 2),
                color: palette.primary.withValues(alpha: 0.06),
              )
            : null,
        child: child,
      ),
    );
  }

  /// Kamera veya galeri seçimi.
  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final palette = context.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_outlined,
                  color: palette.primary,
                ),
                title: const Text('Kamera ile çek'),
                subtitle: const Text('Yeni fotoğraf çekin'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: palette.primary,
                ),
                title: const Text('Galeriden seç'),
                subtitle: const Text('Mevcut fotoğraflardan'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  /// Kamera veya galeriden görsel alıp yükler; handle [onHandle]'a verilir.
  Future<void> _pickImage({
    required String pathHint,
    required void Function(String handle) onHandle,
    // Kırpma çerçevesi: profil 1:1 (avatar yuvarlak), vitrin 4:5 (kart
    // ızgarasıyla aynı oran), sertifika serbest (metin kesilmesin).
    PhotoShape shape = PhotoShape.portrait,
    String cropTitle = 'Fotoğrafı ayarla',
  }) async {
    if (_uploading != null) return; // aynı anda tek yükleme
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final Uint8List? bytes;
    try {
      bytes = await PhotoPicker.pickPhoto(
        context,
        source: source,
        shape: shape,
        title: cropTitle,
      );
    } catch (_) {
      if (mounted) {
        context.showError(
          source == ImageSource.camera
              ? 'Kamera açılamadı. İzinleri kontrol edin.'
              : 'Görsel seçilemedi.',
        );
      }
      return;
    }
    if (bytes == null) return;
    if (bytes.length > AppConstants.maxPhotoSizeBytes) {
      if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _uploading = pathHint);
    try {
      // Yol uid ile başlar: Storage kuralı yalnızca kendi klasörüne yazmaya izin verir.
      final handle = await ref
          .read(storageRepositoryProvider)
          .uploadImage(pathHint: '$pathHint/$uid', bytes: bytes);
      onHandle(handle);
    } catch (_) {
      if (mounted) {
        context.showError(
          'Görsel yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  void _addArea() {
    final p = _addProvince, d = _addDistrict;
    if (p == null || d == null) {
      context.showInfo('Lütfen il ve ilçe seçin.');
      return;
    }
    final added = _controller.addServiceArea(
      ServiceArea(province: p.name, district: d.name),
    );
    if (!added) {
      context.showInfo('Bu bölge zaten ekli.');
      return;
    }
    setState(() => _addDistrict = null); // sonraki ilçe için hazır
  }

  /// Usta kurulumu hiç yapılmamış mı? (meslek YOK ve bölge YOK)
  ///
  /// `becomeArtisan()` usta modunu AÇTIKTAN sonra buraya yönlendiriyor.
  /// Kullanıcı hiçbir şey seçmeden geri basarsa usta modu açık kalıyordu —
  /// aramada meslek/bölgesiz boş bir usta olarak görünürdü. Bu iki alan da
  /// boşsa "kurulum yapılmadı" kabul edip modu geri alıyoruz (madde 11).
  bool get _kurulumBos {
    final d = ref.read(myProfileControllerProvider).valueOrNull;
    if (d == null) return false;
    return d.profile.professionCodes.isEmpty && d.profile.serviceAreas.isEmpty;
  }

  /// Kaydetmeden çıkışta usta modunu geri alır. Yalnız kurulum hiç
  /// yapılmamışsa çalışır: mevcut bir ustanın profilini düzenlerken geri
  /// basması modunu KAPATMAMALI.
  Future<void> _cikistaModuGeriAl() async {
    final user = ref.read(currentUserProvider);
    // Aktif mod değil: kurulum yarıda kaldıysa müşteri rolüne dön.
    if (user == null || !user.hasArtisanProfile || !_kurulumBos) return;
    await ref
        .read(authControllerProvider.notifier)
        .setActiveMode(UserRole.customer);
    if (!mounted) return;
    context.showInfo(
      'Usta profili tamamlanmadı — meslek ve hizmet bölgesi seçilmedi.',
    );
  }

  Future<void> _save() async {
    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    if (draft == null) return;

    final nameError = Validators.displayName(draft.displayName);
    if (nameError != null) {
      context.showError(nameError);
      return;
    }
    final expError = Validators.experienceYears(
      draft.profile.experienceYears == 0
          ? ''
          : '${draft.profile.experienceYears}',
    );
    if (expError != null) {
      context.showError(expError);
      return;
    }
    final aboutError = Validators.freeText(
      draft.profile.aboutText,
      max: AppConstants.maxAboutLength,
      field: 'Hakkımda',
    );
    if (aboutError != null) {
      context.showError(aboutError);
      return;
    }
    // USTA ALANLARI YALNIZ USTAYA ZORUNLU (2026-08-15 kullanıcı bulgusu).
    //
    // Bu ekran `/profile/edit` üzerinden MÜŞTERİYE de açıktır (ad, hakkımda,
    // fotoğraf gibi ortak alanlar için). Meslek ve hizmet bölgesi seçicileri
    // ise `showArtisanVitrin` ile yalnız ustaya gösterilir. Kontroller mod
    // ayrımı yapmayınca müşteri, EKRANDA OLMAYAN bir alan yüzünden
    // "En az bir meslek seçin" uyarısı alıp profilini hiç kaydedemiyordu —
    // kullanıcının kendi başına çözemeyeceği bir çıkmaz.
    final ustaMi = ref.read(currentUserProvider)?.hasArtisanProfile ?? false;

    // Hemen Lazım de geçerli bir hizmettir: yalnız onu açan usta da kaydeder.
    if (ustaMi && draft.profile.professionCodes.isEmpty) {
      context.showError(
        'En az bir meslek seçin veya "$kQuickSupportName işleri al" '
        'anahtarını açın.',
      );
      return;
    }
    // BEKLEYEN BÖLGE SEÇİMİNİ OTOMATİK EKLE (2026-08-10, kullanıcı bulgusu).
    //
    // Kullanıcı il+ilçe seçip "+" düğmesine basmayı unutuyor, sonra Kaydet
    // deyince "en az bir hizmet bölgesi ekleyin" uyarısı alıyordu — oysa
    // seçimini EKRANDA görüyor. Uyarı haklı görünüp yanlış hissettiriyordu.
    //
    // Seçim zaten ekranda duruyorsa niyet açıktır; "+" bir onay adımı değil,
    // yalnızca birden fazla bölge eklemeyi mümkün kılan bir araçtır. Kaydet
    // basılınca bekleyen seçim de eklenir.
    //
    // `addServiceArea` zaten tekilleştiriyor: kullanıcı "+" bastıysa ve
    // seçim ekranda durmaya devam ediyorsa ikinci kez eklenmez.
    if (_addProvince != null && _addDistrict != null) {
      _controller.addServiceArea(
        ServiceArea(province: _addProvince!.name, district: _addDistrict!.name),
      );
    }
    // Bölge listesini otomatik eklemeden SONRA oku (controller güncellendi).
    final bolgeler =
        ref.read(myProfileControllerProvider).valueOrNull?.profile.serviceAreas ??
            draft.profile.serviceAreas;
    // Meslekte olduğu gibi: hizmet bölgesi seçicisi müşteriye gösterilmez,
    // dolayısıyla ondan istenemez.
    if (ustaMi && bolgeler.isEmpty) {
      context.showError('En az bir hizmet bölgesi ekleyin.');
      return;
    }

    final ok = await _controller.save();
    if (!mounted) return;
    if (ok) {
      context.showSuccess('Profiliniz kaydedildi.');
      // PopScope canPop:false programatik pop'u yutar (kullanıcı formda
      // kalırdı). go yığını sıfırlar — her zaman birleşik profile düşer.
      // `_kurulumBos` artık false: geri alma kancası devreye girmez.
      context.go(RoutePaths.profile);
    } else {
      // B-04: sabit metin yerine GERÇEK sebep — permission-denied mi, ağ mı?
      context.showError(_controller.saveErrorTR);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    if (draft == null) return const SizedBox.shrink();
    final profile = draft.profile;

    // Funnel deep-link: layout sonrası ilgili bölüme bir kez kaydır.
    if (!_didScrollToFocus &&
        widget.focusStep != null &&
        widget.focusStep!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }

    // Vitrin: usta PROFİLİ açılmışsa (aktif mod switch'i yok).
    final showArtisanVitrin =
        ref.watch(currentUserProvider)?.hasArtisanProfile ?? false;

    return PopScope(
      // Kurulum yapılmadan çıkılırsa usta modu geri alınır (madde 11).
      // `canPop: false` + elle pop: mod değişimi asenkron, çıkıştan ÖNCE
      // tamamlanmalı — yoksa ekran kapanır ve `mounted` false olurdu.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        await _cikistaModuGeriAl();
        if (router.canPop()) {
          router.pop();
        } else {
          router.go(RoutePaths.profile);
        }
      },
      child: Scaffold(
        appBar: _kEditAppBar,
        // Kaydet ListView'un son satırı olursa sistem gezinme çubuğunun
        // (ve varsa yüzen alt barın) altına düşer. İlan/ürün düzenleme
        // ile aynı sabit bar: her zaman görünür, SafeArea üstünde.
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.palette.card,
            border: Border(top: BorderSide(color: context.palette.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            // Align/ResponsiveCenter burada TÜM ekranı kaplar, gövdeye
            // 0 yükseklik kalır (create_job_screen notu). heightFactor:1.
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AppButton(
                  label: 'Kaydet',
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ),
            ),
          ),
        ),
        body: ResponsiveCenter(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
            // "Vitrini tamamla" bandı KALDIRILDI (2026-08-08): kullanıcı zaten
            // formun içinde — hangi alanın boş olduğunu doğrudan görüyor.
            // Formun tepesinde ayrıca uyarı göstermek yer kaplıyordu.
            // (Bant `nearby_jobs_screen`'de duruyor: orada usta ilanları
            // göremediğinde SEBEBİ açıklıyor, oradaki işlevi gerçek.)

            // --- Profil fotoğrafı ---
            _focusWrap(
              id: 'photo',
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: ClipOval(
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: draft.profilePhotoUrl != null
                              ? AppImage(handle: draft.profilePhotoUrl)
                              : Icon(
                                  Icons.person,
                                  size: 52,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                        ),
                      ),
                    ),
                    // Yükleme sürerken avatar üstünde karartma + spinner
                    // (WhatsApp foto balonuyla aynı dil).
                    if (_uploading == 'profile')
                      const Positioned.fill(
                        child: ClipOval(
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _pickImage(
                            pathHint: 'profile',
                            // Avatar HER YERDE yuvarlak çizilir; kare
                            // olmayan kaynak "yayık" görünüyordu.
                            shape: PhotoShape.square,
                            cropTitle: 'Profil fotoğrafı',
                            onHandle: _controller.setProfilePhoto,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Ad Soyad ---
            _Label('Ad Soyad'),
            TextFormField(
              initialValue: draft.displayName,
              textCapitalization: TextCapitalization.words,
              maxLength: AppConstants.maxDisplayNameLength,
              validator: Validators.displayName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                helperText: "Harf, rakam, boşluk ve . ' -",
              ),
              onChanged: _controller.setDisplayName,
            ),
            const SizedBox(height: 16),

            // --- Telefon (isteğe bağlı, herkese görünür) ---
            _Label('Telefon Numarası'),
            const SizedBox(height: 4),
            _PhoneVisibilityTile(profile: profile),
            const SizedBox(height: 20),

            // --- Sosyal Medya + Web Sitesi (isteğe bağlı) ---
            _Label('Sosyal Medya ve Web Sitesi'),
            const SizedBox(height: 4),
            Text(
              'İsteğe bağlı. Eklerseniz profilinizde dokunulabilir bağlantı '
              'olarak görünür; boş bıraktığınız alan gösterilmez.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _SocialLinksSection(
              value: profile.socialLinks,
              onChanged:
                  ({
                    String? instagram,
                    String? youtube,
                    String? tiktok,
                    String? whatsapp,
                    String? website,
                  }) => _controller.setSocialLinks(
                    instagram: instagram,
                    youtube: youtube,
                    tiktok: tiktok,
                    whatsapp: whatsapp,
                    website: website,
                  ),
            ),
            const SizedBox(height: 20),

            // --- Hakkımda (isteğe bağlı) ---
            _focusWrap(
              id: 'about',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label('Hakkımda'),
                  TextFormField(
                    initialValue: profile.aboutText,
                    maxLines: 4,
                    maxLength: AppConstants.maxAboutLength,
                    decoration: const InputDecoration(
                      hintText: 'Kendinizi kısaca tanıtın',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => Validators.freeText(
                      v,
                      max: AppConstants.maxAboutLength,
                      field: 'Hakkımda',
                    ),
                    onChanged: _controller.setAbout,
                  ),
                ],
              ),
            ),

            // ══════════════ USTA VİTRİNİ ══════════════
            //
            // Usta PROFİLİ açılmışsa görünür (aktif mod switch'i yok).
            // Ayrı "Vitrini Düzenle" sayfası YOK — tek form, tek Kaydet.
            if (!showArtisanVitrin) const SizedBox(height: 8),
            if (showArtisanVitrin) ...[
              const SizedBox(height: 28),
              Divider(color: context.palette.hairline),
              const SizedBox(height: 14),
              Text(
                'USTA VİTRİNİ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.palette.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Müşterilerin sizi bulmasını sağlayan bilgiler.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.inkMuted,
                ),
              ),
              const SizedBox(height: 16),

              // --- Kolay İş anahtarı (meslekten AYRI hizmet tercihi) ---
              _QuickSupportSwitch(
                enabled: isQuickSupportProviderCodes(profile.professionCodes),
                hasProfession: profile.professionCodes
                    .where(
                      (c) =>
                          c != kOtherProfession && c != kQuickSupportCategory,
                    )
                    .isNotEmpty,
                onChanged: (on) {
                  _controller.setQuickSupportEnabled(on);
                  // İlk kez açılınca bir kerelik tanıtım.
                  if (on) showQuickSupportArtisanIntro(context);
                },
              ),
              const SizedBox(height: 16),

              // --- Meslek(ler) ---
              _focusWrap(
                id: 'profession',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label(
                      'Meslekler (en fazla ${MyProfileController.maxProfessions})',
                    ),
                    Text(
                      'Arayarak seçin. En az bir meslek zorunlu.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfessionMultiSelect(
                      selected: profile.professionCodes,
                      onToggle: (code) {
                        final cur = profile.professionCodes;
                        final adding = !cur.contains(code);
                        // B-03: Hemen Lazım limite dahil değil — sayaç da onu
                        // elemişti (`_ProfessionMultiSelect`), kontrol elemiyordu.
                        if (adding &&
                            MyProfileController.realProfessionCount(cur) >=
                                MyProfileController.maxProfessions) {
                          context.showError(
                            'En fazla ${MyProfileController.maxProfessions} meslek seçebilirsiniz.',
                          );
                          return;
                        }
                        _controller.toggleProfession(code);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- Deneyim ---
              _Label('Deneyim (yıl)'),
              TextFormField(
                initialValue: () {
                  final y = Validators.clampExperienceYears(
                    profile.experienceYears,
                  );
                  return y == 0 ? '' : '$y';
                }(),
                keyboardType: TextInputType.number,
                maxLength: 2,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.workspace_premium_outlined),
                  hintText: 'Örn. 15',
                  helperText: 'En fazla ${AppConstants.maxExperienceYears} yıl',
                  counterText: '',
                ),
                validator: Validators.experienceYears,
                onChanged: (v) =>
                    _controller.setExperience(int.tryParse(v.trim()) ?? 0),
              ),
              const SizedBox(height: 16),

              // --- Hizmet Bölgeleri ---
              _focusWrap(
                id: 'area',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label('Hizmet Bölgeleri'),
                    const SizedBox(height: 4),
                    _ServiceAreaAdder(
                      province: _addProvince,
                      district: _addDistrict,
                      onProvince: (p) => setState(() {
                        _addProvince = p;
                        _addDistrict = null;
                      }),
                      onDistrict: (d) => setState(() => _addDistrict = d),
                      onAdd: _addArea,
                    ),
                    const SizedBox(height: 12),
                    if (profile.serviceAreas.isEmpty)
                      Text(
                        // Kullanıcı ilçeyi seçmiş ama "+" basmamışsa
                        // "eklemediniz" demek yanlış hissettiriyordu —
                        // seçimini ekranda görüyor. Kaydet zaten bekleyen
                        // seçimi otomatik ekler; metin de bunu söylesin.
                        _addProvince != null && _addDistrict != null
                            ? 'Seçtiğiniz bölge kaydederken eklenecek. '
                                'Birden fazla bölge için "+" kullanın.'
                            : 'Henüz bölge eklemediniz.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.serviceAreas
                            .map(
                              (a) => Chip(
                                label: Text(a.labelTR),
                                onDeleted: () =>
                                    _controller.removeServiceArea(a),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- İş Fotoğrafları ---
              _focusWrap(
                id: 'photos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label(
                      'İş Fotoğrafları '
                      '(${profile.workPhotos.length}/'
                      '${AppConstants.maxWorkPhotos})',
                    ),
                    const SizedBox(height: 8),
                    _WorkPhotos(
                      handles: profile.workPhotos,
                      uploading: _uploading == 'work',
                      canAdd: profile.workPhotos.length <
                          AppConstants.maxWorkPhotos,
                      onAdd: () {
                        if (profile.workPhotos.length >=
                            AppConstants.maxWorkPhotos) {
                          context.showInfo(
                            'En fazla ${AppConstants.maxWorkPhotos} '
                            'iş fotoğrafı ekleyebilirsiniz.',
                          );
                          return;
                        }
                        _pickImage(
                          pathHint: 'work',
                          cropTitle: 'Vitrin fotoğrafı',
                          onHandle: (h) {
                            if (!_controller.addWorkPhoto(h)) {
                              context.showInfo(
                                'En fazla ${AppConstants.maxWorkPhotos} '
                                'iş fotoğrafı ekleyebilirsiniz.',
                              );
                            }
                          },
                        );
                      },
                      onRemove: _controller.removeWorkPhoto,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Sertifikalar ve Belgeler ---
              _Label(
                'Sertifikalar ve Belgeler '
                '(${profile.certificates.length}/'
                '${AppConstants.maxCertificates})',
              ),
              const SizedBox(height: 4),
              Text(
                'Ustalık belgesi, sertifika vb. görsellerini ekleyin. '
                'En fazla ${AppConstants.maxCertificates} belge. '
                'Belgeler yönetici onayından geçer.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _WorkPhotos(
                handles: profile.certificates,
                uploading: _uploading == 'certificate',
                canAdd: profile.certificates.length <
                    AppConstants.maxCertificates,
                onAdd: () {
                  if (profile.certificates.length >=
                      AppConstants.maxCertificates) {
                    context.showInfo(
                      'En fazla ${AppConstants.maxCertificates} '
                      'belge ekleyebilirsiniz.',
                    );
                    return;
                  }
                  _pickImage(
                    pathHint: 'certificate',
                    // Belge: zorunlu oran metni keser → serbest kırpma.
                    shape: PhotoShape.free,
                    cropTitle: 'Belgeyi ayarla',
                    onHandle: (h) {
                      if (!_controller.addCertificate(h)) {
                        context.showInfo(
                          'En fazla ${AppConstants.maxCertificates} '
                          'belge ekleyebilirsiniz.',
                        );
                      }
                    },
                  );
                },
                onRemove: _controller.removeCertificate,
              ),
              if (profile.certificates.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CertificateStatusNote(profile: profile),
              ],
              const SizedBox(height: 24),

              // --- Çalışma Takvimi / Müsaitlik ---
              _focusWrap(
                id: 'hours',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label('Çalışma Takvimi'),
                    const SizedBox(height: 4),
                    Text(
                      'Müşteriler öncelikle "şu an müsait" ustaları görür.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AvailabilitySection(
                      mode: profile.availabilityMode,
                      schedule: profile.weeklySchedule,
                      onMode: _controller.setAvailabilityMode,
                      onToggleDay: _controller.toggleScheduleDay,
                      onDayHours: (wd, {startMinute, endMinute}) =>
                          _controller.setScheduleDayHours(
                            wd,
                            startMinute: startMinute,
                            endMinute: endMinute,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ], // ══════════ USTA VİTRİNİ sonu ══════════
          ],
        ),
      ),
      ),
    );
  }
}

/// Belgelerin inceleme durumu — ustaya nerede olduğunu söyler.
/// Reddedildiyse gerekçe gösterilir; usta neyi düzelteceğini bilmeli.
class _CertificateStatusNote extends StatelessWidget {
  const _CertificateStatusNote({required this.profile});
  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final (
      String text,
      Color color,
      IconData icon,
    ) = switch (profile.certificateStatus) {
      'approved' => (
        'Belgeleriniz onaylandı — profilinizde "Belgeli usta" rozeti '
            'görünüyor.',
        palette.success,
        Icons.verified_user_outlined,
      ),
      'rejected' => (
        'Belgeleriniz reddedildi. '
            '${profile.certificateNote ?? "Lütfen yeniden yükleyin."}',
        palette.danger,
        Icons.gpp_bad_outlined,
      ),
      'pending' => (
        'Belgeleriniz inceleniyor. Sonuç bildirim olarak gönderilecek.',
        palette.warning,
        Icons.hourglass_empty,
      ),
      _ => (
        'Belgeleriniz kaydedildikten sonra incelemeye alınır.',
        palette.inkMuted,
        Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Telefonun vitrinde görünmesi (KVKK: açık rıza, her an geri alınabilir).
/// Numara girilmemişse anahtar yerine yönlendirme gösterilir.
///
/// Numara DOĞRULANMAZ (SMS akışı 2026-08-18'de kaldırıldı); kullanıcının
/// Hesap Ayarları'ndan girdiği `publicPhone` kullanılır.
///
/// Anahtar ANINDA kaydeder (formun "Kaydet" düğmesini beklemez): rıza geri
/// alma tek dokunuşta etkili olmalı.
class _PhoneVisibilityTile extends ConsumerWidget {
  const _PhoneVisibilityTile({required this.profile});

  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final phone = user?.publicPhone ?? profile.publicPhone;

    if (phone == null || phone.trim().isEmpty) {
      return Text(
        'Profilinizde telefon numarası kayıtlı olduğunda vitrininizde '
        'gösterebilirsiniz.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: profile.showPhoneOnProfile,
      title: const Text('Telefon numaram profilimde görünsün'),
      subtitle: Text(
        profile.showPhoneOnProfile
            ? '$phone — müşteriler doğrudan arayabilir.'
            : 'Kapalıyken müşteriler yalnız uygulama içi sohbetle ulaşır.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onChanged: (v) async {
        final ok = await ref
            .read(myProfileControllerProvider.notifier)
            .setPhoneVisibility(show: v, publicPhone: v ? phone : null);
        if (!context.mounted) return;
        if (ok) {
          context.showSuccess(
            v ? 'Telefonunuz profilinizde görünecek.' : 'Telefonunuz gizlendi.',
          );
        } else {
          context.showError('Ayar kaydedilemedi, tekrar deneyin.');
        }
      },
    );
  }
}

/// Sosyal medya / iş hattı alanları. Kullanıcı adı ya da tam URL girilebilir;
/// odak alandan çıkınca [SocialLinks] normalize eder ve taslağa yazar.
///
/// Denetleyiciler bir kez kurulur (her yeniden çizimde değil) — aksi hâlde
/// yazarken imleç başa sıçrardı.
class _SocialLinksSection extends StatefulWidget {
  const _SocialLinksSection({required this.value, required this.onChanged});

  final SocialLinks value;
  final void Function({
    String? instagram,
    String? youtube,
    String? tiktok,
    String? whatsapp,
    String? website,
  })
  onChanged;

  @override
  State<_SocialLinksSection> createState() => _SocialLinksSectionState();
}

class _SocialLinksSectionState extends State<_SocialLinksSection> {
  late final TextEditingController _instagram;
  late final TextEditingController _youtube;
  late final TextEditingController _tiktok;
  late final TextEditingController _whatsapp;
  late final TextEditingController _website;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _instagram = TextEditingController(text: v.instagram ?? '');
    _youtube = TextEditingController(text: v.youtube ?? '');
    _tiktok = TextEditingController(text: v.tiktok ?? '');
    _whatsapp = TextEditingController(text: v.whatsapp ?? '');
    _website = TextEditingController(text: v.website ?? '');
  }

  @override
  void dispose() {
    _instagram.dispose();
    _youtube.dispose();
    _tiktok.dispose();
    _whatsapp.dispose();
    _website.dispose();
    super.dispose();
  }

  void _push() => widget.onChanged(
    instagram: _instagram.text,
    youtube: _youtube.text,
    tiktok: _tiktok.text,
    whatsapp: _whatsapp.text,
    website: _website.text,
  );

  /// Alan başına hata mesajı (null = sorun yok). Odak kaybında hesaplanır.
  final Map<String, String?> _errors = {};

  /// Odak kaybında normalize edilmiş değeri kutuya geri yazar; böylece
  /// kullanıcı tam URL yapıştırsa bile kaydedilecek adı görür.
  ///
  /// GEÇERSİZ girdi SİLİNMEZ (2026-08-09): eskiden `controller.text = ''`
  /// yazılıyordu ve kullanıcı yazdığının neden kaybolduğunu anlamıyordu.
  /// Artık metin kutuda kalır, altında kırmızı hata çıkar ve alan
  /// kaydedilmez.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String) normalize,
    required String? Function(String) validate,
    String? helper,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) return;
          final ham = controller.text;
          final hata = validate(ham);
          final normalized = normalize(ham);
          setState(() {
            _errors[label] = hata;
            // Yalnız GEÇERLİ girdi temizlenmiş hâliyle geri yazılır.
            // Hatalı metin kutuda kalır ki kullanıcı düzeltebilsin.
            if (hata == null) controller.text = normalized ?? '';
          });
          _push();
        },
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          // YAZARKEN de doğrula (2026-08-19): hata yalnız odak kaybında
          // hesaplanıyordu; kullanıcı yazıp doğrudan "Kaydet"e basınca
          // uyarıyı hiç görmüyor, alanın neden boş kaydedildiğini
          // anlamıyordu. `_push()` yine odak kaybında — her tuşta taslak
          // güncellemek gereksiz yazma üretirdi.
          onChanged: (ham) {
            final hata = validate(ham);
            if (_errors[label] != hata) {
              setState(() => _errors[label] = hata);
            }
          },
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: _errors[label] == null ? helper : null,
            helperMaxLines: 2,
            errorText: _errors[label],
            errorMaxLines: 2,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controller: _instagram,
          label: 'Instagram',
          hint: 'kullanici_adi',
          helper: 'Bağlantıyı yapıştırabilirsiniz, kullanıcı adına çevrilir.',
          icon: Icons.camera_alt_outlined,
          normalize: SocialLinks.normalizeHandle,
          validate: (v) => SocialLinks.handleError(v, platform: 'Instagram'),
        ),
        _field(
          controller: _youtube,
          label: 'YouTube',
          hint: 'kanal_adi',
          icon: Icons.play_circle_outline,
          normalize: SocialLinks.normalizeHandle,
          validate: (v) => SocialLinks.handleError(v, platform: 'YouTube'),
        ),
        _field(
          controller: _tiktok,
          label: 'TikTok',
          hint: 'kullanici_adi',
          icon: Icons.music_note_outlined,
          normalize: SocialLinks.normalizeHandle,
          validate: (v) => SocialLinks.handleError(v, platform: 'TikTok'),
        ),
        _field(
          controller: _whatsapp,
          label: 'WhatsApp iş hattı',
          hint: '0532 123 45 67',
          helper: 'Profil telefonunuzdan farklı bir hat verebilirsiniz.',
          icon: Icons.chat_outlined,
          keyboardType: TextInputType.phone,
          normalize: SocialLinks.normalizeWhatsapp,
          validate: SocialLinks.whatsappError,
        ),
        _field(
          controller: _website,
          label: 'Web sitesi',
          hint: 'ornek.com',
          icon: Icons.language_outlined,
          keyboardType: TextInputType.url,
          normalize: SocialLinks.normalizeWebsite,
          validate: SocialLinks.websiteError,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Çoklu meslek seçimi: seçili özet + arama + kaydırılabilir liste.
/// (~130 meslek; eski Wrap chip ızgarası dağınıktı ve arama yoktu.)
/// "Hemen Lazım" hizmet anahtarı — meslek seçiminin HEMEN ÜSTÜNDE, ayrı bir
/// karar olarak sunulur. Meslek listesinin içinde bir satır olduğunda ustalar
/// bunu bir meslek sanıyor ve fark etmeden atlıyordu.
///
/// Açıkken usta, ilindeki Hemen Lazım ilanlarını da alır (mesleğine ek olarak).
class _QuickSupportSwitch extends StatelessWidget {
  const _QuickSupportSwitch({
    required this.enabled,
    required this.hasProfession,
    required this.onChanged,
  });

  final bool enabled;

  /// Hemen Lazım DIŞINDA en az bir meslek seçili mi? (yalnız açıklama metni
  /// için — anahtarın kendisini kısıtlamaz.)
  final bool hasProfession;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: enabled ? palette.warningSurface : palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? palette.warning.withValues(alpha: 0.5)
              : palette.border,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: palette.warning, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$kQuickSupportName işleri al',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          Text(
            enabled
                ? (hasProfession
                      ? 'Açık: mesleğinize ek olarak ilinizdeki market, taşıma, '
                            'kısa gidiş gibi kısa işler de size gelir.'
                      : 'Açık: ilinizdeki market, taşıma, kısa gidiş gibi kısa '
                            'işler size gelir. Meslek seçmediğiniz için klasik '
                            'meslek ilanları (boya, elektrik vb.) GELMEZ.')
                : 'Kapalı: market, taşıma, kısa gidiş gibi uzmanlık '
                      'gerektirmeyen kısa işler size gelmez.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionMultiSelect extends ConsumerStatefulWidget {
  const _ProfessionMultiSelect({
    required this.selected,
    required this.onToggle,
  });
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  ConsumerState<_ProfessionMultiSelect> createState() =>
      _ProfessionMultiSelectState();
}

class _ProfessionMultiSelectState
    extends ConsumerState<_ProfessionMultiSelect> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final professionsAsync = ref.watch(professionsProvider);
    final palette = context.palette;
    final theme = Theme.of(context);

    return professionsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Meslek listesi yüklenemedi'),
      data: (allProfessions) {
        // Hemen Lazım bir MESLEK DEĞİL, ayrı hizmet anahtarı → listede yok
        // (bkz. _QuickSupportSwitch). Sayaç/chip'ler de onu saymaz.
        final professions = allProfessions
            .where(
              (p) =>
                  p.code != kOtherProfession && p.code != kQuickSupportCategory,
            )
            .toList(growable: false);
        final byCode = {for (final p in professions) p.code: p};
        final selected = widget.selected
            .where((c) => c != kOtherProfession && c != kQuickSupportCategory)
            .toList(growable: false);
        final q = _query.text;
        // Liste sırası sabit kalır (seçilince en üste zıplamaz); seçili
        // olanlar üstteki chip'lerde + satırda ✓ ile görünür.
        // Arama HEM meslek adına HEM KATEGORİ başlığına bakar (2026-08-10):
        // kullanıcı "İnşaat" yazınca o kategorinin altındaki tüm meslekler
        // listelenmeli. Başlıklar ekranda görünüyor, aranabilir olmaları
        // beklenir — yalnız ada bakılsaydı kategori adı sıfır sonuç verirdi.
        final filtered = professions
            .where(
              (p) =>
                  matchesTrSearch(p.nameTR, q) ||
                  matchesTrSearch(p.code, q) ||
                  matchesTrSearch(ProfessionCategory.label(p.category), q),
            )
            .toList(growable: false);

        // Satır listesi: kategori başlığı (String) + meslek (Profession).
        // 144 meslek düz listede taranamıyordu (2026-08-10).
        //
        // Normal metin aramasında gruplama kapanır (sonuç zaten daraldı,
        // başlık gürültü). Ama KATEGORİ adı yazıldıysa başlıklar KALIR —
        // sonucun neden geldiğini açıklar ve birden fazla kategori
        // eşleşebilir.
        final kategoriAramasi = q.trim().isNotEmpty &&
            filtered.any(
              (p) => matchesTrSearch(ProfessionCategory.label(p.category), q),
            );
        final rows = <Object>[];
        if (q.trim().isNotEmpty && !kategoriAramasi) {
          rows.addAll(filtered);
        } else {
          String? sonGrup;
          for (final p in filtered) {
            if (p.category != sonGrup) {
              rows.add(ProfessionCategory.label(p.category));
              sonGrup = p.category;
            }
            rows.add(p);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sayaç + seçili chip'ler
            Row(
              children: [
                Text(
                  '${selected.length}/${MyProfileController.maxProfessions} seçili',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
                const Spacer(),
                if (selected.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      for (final c in List<String>.from(selected)) {
                        widget.onToggle(c);
                      }
                    },
                    child: const Text('Temizle'),
                  ),
              ],
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in selected)
                    InputChip(
                      label: Text(
                        byCode[code]?.nameTR ?? code,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: true,
                      showCheckmark: false,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => widget.onToggle(code),
                      onPressed: () => widget.onToggle(code),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Meslek ara (örn. elektrik, klima…)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              q.trim().isEmpty
                  ? '${professions.length} meslek — kaydırarak seçin'
                  : '${filtered.length} sonuç',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            // Sabit yükseklikte kaydırılabilir liste (formu şişirmez).
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 280,
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Eşleşen meslek yok.\nFarklı bir arama deneyin.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.inkMuted,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: rows.length,
                          separatorBuilder: (_, i) {
                            // Başlığın üstüne çizgi çizme: grup zaten ayırır.
                            final sonraki =
                                i + 1 < rows.length ? rows[i + 1] : null;
                            if (sonraki is String) {
                              return const SizedBox.shrink();
                            }
                            return Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: palette.border.withValues(alpha: 0.7),
                            );
                          },
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            if (row is String) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 14, 14, 4),
                                child: Text(
                                  row.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: palette.inkMuted,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              );
                            }
                            final p = row as Profession;
                            final isOn = selected.contains(p.code);
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: Icon(
                                isOn
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: isOn
                                    ? palette.primary
                                    : palette.inkFaint,
                                size: 22,
                              ),
                              title: Text(
                                p.nameTR,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isOn
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              onTap: () => widget.onToggle(p.code),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 0,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// İl → ilçe seçip "Ekle" diyerek hizmet bölgesi ekleyen satır.
class _ServiceAreaAdder extends ConsumerWidget {
  const _ServiceAreaAdder({
    required this.province,
    required this.district,
    required this.onProvince,
    required this.onDistrict,
    required this.onAdd,
  });

  final Province? province;
  final District? district;
  final ValueChanged<Province?> onProvince;
  final ValueChanged<District?> onDistrict;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provincesAsync = ref.watch(provincesProvider);

    return Column(
      children: [
        provincesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('İl verisi yüklenemedi'),
          data: (provinces) => SearchableSelectField<Province>(
            label: 'İl',
            value: province,
            items: provinces,
            itemLabel: (p) => p.name,
            searchHint: 'İl ara…',
            prefixIcon: Icons.map_outlined,
            equals: (a, b) => a.id == b.id,
            onSelected: (p) => onProvince(p),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: province == null
                  ? SearchableSelectField<District>(
                      label: 'İlçe',
                      value: null,
                      items: const [],
                      itemLabel: (d) => d.name,
                      enabled: false,
                      hint: 'Önce il seçin',
                      onSelected: (_) {},
                    )
                  : ref
                        .watch(districtsProvider(province!.id))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) =>
                              const Text('İlçe verisi yüklenemedi'),
                          data: (districts) => SearchableSelectField<District>(
                            label: 'İlçe',
                            value: district,
                            items: districts,
                            itemLabel: (d) => d.name,
                            searchHint: 'İlçe ara…',
                            prefixIcon: Icons.location_city_outlined,
                            equals: (a, b) => a.id == b.id,
                            onSelected: (d) => onDistrict(d),
                          ),
                        ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onAdd,
              style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkPhotos extends StatelessWidget {
  const _WorkPhotos({
    required this.handles,
    required this.onAdd,
    required this.onRemove,
    this.uploading = false,
    this.canAdd = true,
  });

  final List<String> handles;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  /// true iken ekleme kutucuğu spinner gösterir ve tıklamayı yutar.
  final bool uploading;

  /// false ise ekleme kutusu gizlenir (tavan doldu).
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (canAdd || uploading)
            _AddTile(onTap: onAdd, loading: uploading),
          for (final h in handles) ...[
            const SizedBox(width: 8),
            _PhotoTile(handle: h, onRemove: () => onRemove(h)),
          ],
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, this.loading = false});
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Icon(Icons.add_a_photo_outlined, color: scheme.primary),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.handle, required this.onRemove});
  final String handle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 92,
            height: 92,
            child: AppImage(handle: handle),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Müsaitlik kipi seçimi + (haftalık kipte) gün-saat planı düzenleyicisi.
class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({
    required this.mode,
    required this.schedule,
    required this.onMode,
    required this.onToggleDay,
    required this.onDayHours,
  });

  final AvailabilityMode mode;
  final WeeklySchedule schedule;
  final ValueChanged<AvailabilityMode> onMode;
  final void Function(int weekday, bool enabled) onToggleDay;
  final void Function(int weekday, {int? startMinute, int? endMinute})
  onDayHours;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AvailabilityMode>(
          segments: const [
            ButtonSegment(
              value: AvailabilityMode.always,
              label: Text('Her zaman'),
              icon: Icon(Icons.check_circle_outline),
            ),
            ButtonSegment(
              value: AvailabilityMode.weekly,
              label: Text('Haftalık'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
            ButtonSegment(
              value: AvailabilityMode.paused,
              label: Text('Kapalı'),
              icon: Icon(Icons.do_not_disturb_on_outlined),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onMode(s.first),
        ),
        if (mode == AvailabilityMode.paused)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Geçici olarak müsait değilsiniz. Arama sonuçlarında "müsait değil" görünürsünüz.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (mode == AvailabilityMode.weekly) ...[
          const SizedBox(height: 12),
          for (var wd = 1; wd <= 7; wd++)
            _DayRow(
              day: schedule.dayFor(wd),
              onToggle: (v) => onToggleDay(wd, v),
              onPickStart: () => _pickTime(context, wd, isStart: true),
              onPickEnd: () => _pickTime(context, wd, isStart: false),
            ),
        ],
      ],
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    int weekday, {
    required bool isStart,
  }) async {
    final day = schedule.dayFor(weekday);
    final current = isStart ? day.startMinute : day.endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (isStart) {
      onDayHours(weekday, startMinute: minutes);
    } else {
      onDayHours(weekday, endMinute: minutes);
    }
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DayAvailability day;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              WeeklySchedule.weekdayName(day.weekday),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Switch(value: day.enabled, onChanged: onToggle),
          const Spacer(),
          if (day.enabled) ...[
            _TimeChip(label: day.startLabel, onTap: onPickStart),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('-'),
            ),
            _TimeChip(label: day.endLabel, onTap: onPickEnd),
          ] else
            Text(
              'Kapalı',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';
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
import '../../../data/models/availability.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart' show kOtherProfession;
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/verification_tile.dart';
import '../../jobs/presentation/quick_support_intro_sheet.dart';
import '../../storage/storage_repository.dart';
import '../application/my_profile_controller.dart';

/// Ekran F — Usta Dashboard / Profil Düzenleme Paneli.
///
/// [focusStep]: vitrin funnel deep-link (photo|about|profession|area|photos|hours).
class ArtisanProfileEditScreen extends ConsumerWidget {
  const ArtisanProfileEditScreen({super.key, this.focusStep});

  final String? focusStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(myProfileControllerProvider);

    return Scaffold(
      // Çıkış Yap butonu kaldırıldı — çıkış, birleşik profil sayfasında
      // (düzenleme ekranında oturum kapatmak beklenmedik bir eylemdi).
      appBar: const GradientAppBar(
        title: 'Profili Düzenle',
        icon: Icons.badge_outlined,
        actions: [NotificationBell(), SizedBox(width: 4)],
      ),
      body: draftAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
            message: 'Profil yüklenemedi. Bağlantınızı kontrol edip '
                'tekrar deneyin.'),
        data: (_) => _EditForm(focusStep: focusStep),
      ),
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

  Widget _focusWrap({
    required String id,
    required Widget child,
  }) {
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
                leading: Icon(Icons.photo_camera_outlined,
                    color: palette.primary),
                title: const Text('Kamera ile çek'),
                subtitle: const Text('Yeni fotoğraf çekin'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: palette.primary),
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
  }) async {
    if (_uploading != null) return; // aynı anda tek yükleme
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        // Profil / selfie için ön kamera tercih (yalnız kamera kaynağında).
        preferredCameraDevice: source == ImageSource.camera
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: AppConstants.imagePickMaxWidth,
        imageQuality: AppConstants.imagePickImageQuality,
      );
    } catch (_) {
      if (mounted) {
        context.showError(source == ImageSource.camera
            ? 'Kamera açılamadı. İzinleri kontrol edin.'
            : 'Görsel seçilemedi.');
      }
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConstants.maxPhotoSizeBytes) {
      if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _uploading = pathHint);
    try {
      // Yol uid ile başlar: Storage kuralı yalnızca kendi klasörüne yazmaya izin verir.
      final handle = await ref.read(storageRepositoryProvider).uploadImage(
            pathHint: '$pathHint/$uid',
            bytes: bytes,
          );
      onHandle(handle);
    } catch (_) {
      if (mounted) {
        context.showError(
            'Görsel yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');
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
    if (draft.profile.professionCodes.isEmpty) {
      context.showError('En az bir meslek seçin.');
      return;
    }
    if (draft.profile.serviceAreas.isEmpty) {
      context.showError('En az bir hizmet bölgesi ekleyin.');
      return;
    }

    final ok = await _controller.save();
    if (!mounted) return;
    if (ok) {
      context.showSuccess('Profiliniz kaydedildi.');
    } else {
      context.showError('Kaydetme başarısız, tekrar deneyin.');
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

    return ResponsiveCenter(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
            // --- Profil fotoğrafı ---
            _focusWrap(
              id: 'photo',
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: ClipOval(
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: draft.profilePhotoUrl != null
                              ? AppImage(handle: draft.profilePhotoUrl)
                              : Icon(Icons.person,
                                  size: 52,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer),
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
                                    strokeWidth: 3, color: Colors.white),
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
                              onHandle: _controller.setProfilePhoto),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
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

            // --- Meslek(ler) ---
            _focusWrap(
              id: 'profession',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Label(
                      'Meslekler (en fazla ${MyProfileController.maxProfessions})'),
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
                      if (adding &&
                          cur.length >= MyProfileController.maxProfessions) {
                        context.showError(
                            'En fazla ${MyProfileController.maxProfessions} meslek seçebilirsiniz.');
                        return;
                      }
                      _controller.toggleProfession(code);
                      // İlk kez Hızlı Destek mesleği seçilince bir kerelik tanıtım.
                      if (adding && code == kOtherProfession) {
                        showQuickSupportArtisanIntro(context);
                      }
                    },
                  ),
                  if (profile.professionCodes.contains(kOtherProfession)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.palette.warningSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt,
                              color: context.palette.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              profile.professionCodes
                                      .where((c) => c != kOtherProfession)
                                      .isEmpty
                                  ? 'Yalnız Hızlı Destek seçili: size market, taşıma '
                                      'gibi ayak işi ilanları gelir; boya/elektrik '
                                      'gibi klasik meslek ilanları gelmez.'
                                  : 'Hızlı Destek + meslek: hem ayak işi hem seçtiğiniz '
                                      'meslek ilanlarını alırsınız.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Deneyim ---
            _Label('Deneyim (yıl)'),
            TextFormField(
              initialValue: () {
                final y = Validators.clampExperienceYears(profile.experienceYears);
                return y == 0 ? '' : '$y';
              }(),
              keyboardType: TextInputType.number,
              maxLength: 2,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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

            // --- Hakkımda ---
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
                      hintText: 'Kendinizi ve işlerinizi kısaca tanıtın',
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
            const SizedBox(height: 8),

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
                    Text('Henüz bölge eklemediniz.',
                        style: Theme.of(context).textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.serviceAreas
                          .map((a) => Chip(
                                label: Text(a.labelTR),
                                onDeleted: () =>
                                    _controller.removeServiceArea(a),
                              ))
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
                  _Label('İş Fotoğrafları'),
                  const SizedBox(height: 8),
                  _WorkPhotos(
                    handles: profile.workPhotos,
                    uploading: _uploading == 'work',
                    onAdd: () => _pickImage(
                        pathHint: 'work', onHandle: _controller.addWorkPhoto),
                    onRemove: _controller.removeWorkPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Sertifikalar ve Belgeler ---
            _Label('Sertifikalar ve Belgeler'),
            const SizedBox(height: 4),
            Text(
              'Ustalık belgesi, sertifika vb. görsellerini ekleyin. '
              'Belgeler yönetici onayından geçer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _WorkPhotos(
              handles: profile.certificates,
              uploading: _uploading == 'certificate',
              onAdd: () => _pickImage(
                  pathHint: 'certificate',
                  onHandle: _controller.addCertificate),
              onRemove: _controller.removeCertificate,
            ),
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
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _AvailabilitySection(
                    mode: profile.availabilityMode,
                    schedule: profile.weeklySchedule,
                    onMode: _controller.setAvailabilityMode,
                    onToggleDay: _controller.toggleScheduleDay,
                    onDayHours: (wd, {startMinute, endMinute}) =>
                        _controller.setScheduleDayHours(wd,
                            startMinute: startMinute, endMinute: endMinute),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Doğrulama (mavi tik) — form alanlarının altında, kaydetmeden
            // bağımsız tek seferlik işlem olduğu için en sona alındı. ---
            const VerificationTile(artisanContext: true),
            const SizedBox(height: 28),

            AppButton(
              label: 'Kaydet',
              icon: Icons.save_outlined,
              isLoading: _isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
        ],
      ),
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
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

/// Çoklu meslek seçimi: seçili özet + arama + kaydırılabilir liste.
/// (~130 meslek; eski Wrap chip ızgarası dağınıktı ve arama yoktu.)
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
    final selected = widget.selected;

    return professionsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Meslek listesi yüklenemedi'),
      data: (professions) {
        final byCode = {for (final p in professions) p.code: p};
        final q = _query.text;
        // Liste sırası sabit kalır (seçilince en üste zıplamaz); seçili
        // olanlar üstteki chip'lerde + satırda ✓ ile görünür.
        final filtered = professions
            .where((p) =>
                matchesTrSearch(p.nameTR, q) || matchesTrSearch(p.code, q))
            .toList(growable: false);

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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: palette.inkMuted),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: palette.border.withValues(alpha: 0.7),
                          ),
                          itemBuilder: (context, i) {
                            final p = filtered[i];
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
                                  horizontal: 14, vertical: 0),
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
                  : ref.watch(districtsProvider(province!.id)).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('İlçe verisi yüklenemedi'),
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
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 56),
              ),
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
  });

  final List<String> handles;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  /// true iken ekleme kutucuğu spinner gösterir ve tıklamayı yutar.
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
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
  final void Function(int weekday, {int? startMinute, int? endMinute}) onDayHours;

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

  Future<void> _pickTime(BuildContext context, int weekday,
      {required bool isStart}) async {
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
            child: Text(WeeklySchedule.weekdayName(day.weekday),
                style: Theme.of(context).textTheme.bodyMedium),
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
            Text('Kapalı',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

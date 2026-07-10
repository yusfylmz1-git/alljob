import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../../storage/storage_repository.dart';
import '../data/job_providers.dart';

/// Müşterinin yeni iş ilanı oluşturduğu ekran (İş İlanı Ver).
class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _category;
  Province? _province;
  District? _district;
  final List<String> _photos = [];
  bool _isUrgent = false;
  JobDuration _duration = JobDuration.day3;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Yüklemesi süren fotoğraf var mı? (ekleme kutucuğunda spinner)
  bool _uploadingPhoto = false;

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return; // aynı anda tek yükleme
    if (_photos.length >= AppConstants.maxJobPhotos) {
      context.showInfo('En fazla ${AppConstants.maxJobPhotos} fotoğraf ekleyebilirsiniz.');
      return;
    }
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.imagePickMaxWidth,
        imageQuality: AppConstants.imagePickImageQuality,
      );
    } catch (_) {
      if (mounted) context.showError('Görsel seçilemedi.');
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
    setState(() => _uploadingPhoto = true);
    try {
      // Yol uid ile başlar: Storage kuralı yalnızca kendi klasörüne yazmaya izin verir.
      final handle = await ref
          .read(storageRepositoryProvider)
          .uploadImage(pathHint: 'job/$uid', bytes: bytes);
      if (mounted) setState(() => _photos.add(handle));
    } catch (_) {
      if (mounted) {
        context.showError(
            'Görsel yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      context.showError('Lütfen bir meslek/kategori seçin.');
      return;
    }
    if (_province == null || _district == null) {
      context.showError('Lütfen il ve ilçe seçin.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go(RoutePaths.login);
      return;
    }

    setState(() => _submitting = true);
    final now = DateTime.now();

    final job = Job(
      jobId: '',
      customerId: user.uid,
      customerName: user.displayName,
      customerPhotoUrl: user.profilePhotoUrl,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category!,
      province: _province!.name,
      district: _district!.name,
      photos: List.of(_photos),
      isUrgent: _isUrgent,
      priceType: JobPriceType.inspection,
      budget: null,
      status: JobStatus.open,
      offerCount: 0,
      customerConfirmedDone: false,
      artisanConfirmedDone: false,
      createdAt: now,
      expiresAt: now.add(_duration.duration),
    );

    try {
      await ref.read(jobRepositoryProvider).createJob(job);
      if (!mounted) return;
      context.showSuccess(
          'İlanınız yayında 🎉 Bölgenizdeki ustalar haberdar ediliyor.');
      context.go(RoutePaths.myJobs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.showError('İlan yayınlanamadı, tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İş İlanı Ver',
        subtitle: 'Bölgenizdeki ustalara anında duyurulur',
        icon: Icons.campaign_outlined,
      ),
      // Yayınla butonu altta sabit: uzun formda kaydırmadan hep erişilir.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.palette.card,
          border: Border(top: BorderSide(color: context.palette.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: ResponsiveCenter(
            maxWidth: 720,
            child: AppButton(
              label: 'İlanı Yayınla',
              icon: Icons.campaign_outlined,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                step: 1,
                title: 'İşi Tanımlayın',
                subtitle: 'Ne yaptırmak istiyorsunuz?',
                children: [
                  _Label('İlan Başlığı'),
                  TextFormField(
                    controller: _titleController,
                    maxLength: AppConstants.maxJobTitleLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Örn. Banyo bataryası değişimi',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'En az 5 karakter girin.'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  _Label('Kategori (Meslek)'),
                  _CategoryDropdown(
                    value: _category,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  if (_category == kQuickSupportCategory) ...[
                    const SizedBox(height: 10),
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
                              'Hızlı Destek: montaj, taşıma, ufak tamirat gibi '
                              'ayak işleri için. İlanınız meslek filtresi olmadan '
                              'ilçenizdeki TÜM ustalara bildirilir.',
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
              const SizedBox(height: 14),

              _SectionCard(
                step: 2,
                title: 'Konum',
                subtitle: 'İlan yalnızca bu bölgedeki ustalara gösterilir',
                children: [
                  _LocationPicker(
                    province: _province,
                    district: _district,
                    onProvince: (p) => setState(() {
                      _province = p;
                      _district = null;
                    }),
                    onDistrict: (d) => setState(() => _district = d),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _SectionCard(
                step: 3,
                title: 'Detaylar',
                subtitle: 'İyi anlatılan iş, doğru ustayı bulur',
                children: [
                  _Label('Açıklama'),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: AppConstants.maxJobDescriptionLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'İşi mümkün olduğunca ayrıntılı anlatın.',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'En az 10 karakter girin.'
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _Label('Fotoğraflar (isteğe bağlı)')),
                      Text(
                        '${_photos.length}/${AppConstants.maxJobPhotos}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: context.palette.inkMuted,
                                fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _JobPhotos(
                    handles: _photos,
                    uploading: _uploadingPhoto,
                    onAdd: _pickPhoto,
                    onRemove: (h) => setState(() => _photos.remove(h)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _SectionCard(
                step: 4,
                title: 'Yayın Ayarları',
                children: [
                  // Acil (#urgent)
                  _UrgentToggle(
                    value: _isUrgent,
                    onChanged: (v) => setState(() => _isUrgent = v),
                  ),
                  const SizedBox(height: 14),
                  _Label('İlan Süresi'),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<JobDuration>(
                      segments: const [
                        ButtonSegment(
                            value: JobDuration.day1, label: Text('24 saat')),
                        ButtonSegment(
                            value: JobDuration.day3, label: Text('3 gün')),
                        ButtonSegment(
                            value: JobDuration.day7, label: Text('7 gün')),
                      ],
                      selected: {_duration},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _duration = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.palette.infoSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: context.palette.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'İlgilenen ustalar sizinle doğrudan iletişime geçecek; '
                        'fiyatı ve ayrıntıları sohbette konuşabilirsiniz.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.palette.info,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numaralı bölüm kartı: formu "1 İşi Tanımlayın · 2 Konum · 3 Detaylar ·
/// 4 Yayın Ayarları" adımlarına bölen beyaz kart (uygulamadaki kart diliyle).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final int step;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: palette.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: palette.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _UrgentToggle extends StatelessWidget {
  const _UrgentToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: value ? palette.danger.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? palette.danger
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: palette.danger,
        secondary: Icon(Icons.warning_amber_rounded,
            color: value
                ? palette.danger
                : Theme.of(context).colorScheme.onSurfaceVariant),
        title: const Text('Acil İş'),
        subtitle: const Text('Ustaların panelinde 🚨 kırmızı olarak öne çıkar.'),
      ),
    );
  }
}

class _CategoryDropdown extends ConsumerWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final professionsAsync = ref.watch(professionsProvider);
    return professionsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Meslek listesi yüklenemedi'),
      data: (professions) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.handyman_outlined)),
        hint: const Text('Kategori seçin'),
        // En üstte Hızlı Destek (ayak işleri; meslek gerektirmez). "Diğer"
        // usta MESLEĞİDİR, ilan kategorisi olamaz (Hızlı Destek onu kapsar).
        items: [
          const DropdownMenuItem(
            value: kQuickSupportCategory,
            child: Text('⚡ Hızlı Destek (ayak işleri)'),
          ),
          ...professions
              .where((p) => p.code != kOtherProfession)
              .map((p) =>
                  DropdownMenuItem(value: p.code, child: Text(p.nameTR))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// İl → ilçe tek konum seçici.
class _LocationPicker extends ConsumerWidget {
  const _LocationPicker({
    required this.province,
    required this.district,
    required this.onProvince,
    required this.onDistrict,
  });

  final Province? province;
  final District? district;
  final ValueChanged<Province?> onProvince;
  final ValueChanged<District?> onDistrict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provincesAsync = ref.watch(provincesProvider);
    return Column(
      children: [
        provincesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('İl verisi yüklenemedi'),
          data: (provinces) => _dropdown<Province>(
            label: 'İl',
            value: province,
            items: provinces,
            itemLabel: (p) => p.name,
            onChanged: onProvince,
          ),
        ),
        const SizedBox(height: 8),
        if (province == null)
          _dropdown<District>(label: 'İlçe', value: null, items: const [], itemLabel: (d) => d.name, onChanged: null)
        else
          ref.watch(districtsProvider(province!.id)).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('İlçe verisi yüklenemedi'),
                data: (districts) => _dropdown<District>(
                  label: 'İlçe',
                  value: district,
                  items: districts,
                  itemLabel: (d) => d.name,
                  onChanged: onDistrict,
                ),
              ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      items: items
          .map((e) => DropdownMenuItem<T>(
              value: e, child: Text(itemLabel(e), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _JobPhotos extends StatelessWidget {
  const _JobPhotos({
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
          InkWell(
            onTap: uploading ? null : onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.borderStrong),
              ),
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: context.palette.primary),
                        const SizedBox(height: 4),
                        Text(
                          'Ekle',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          for (final h in handles) ...[
            const SizedBox(width: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 92, height: 92, child: AppImage(handle: h)),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(h),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

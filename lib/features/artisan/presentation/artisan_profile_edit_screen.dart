import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/availability.dart';
import '../../../data/models/geo_models.dart';
import '../../auth/presentation/verification_tile.dart';
import '../../storage/storage_repository.dart';
import '../application/my_profile_controller.dart';

/// Ekran F — Usta Dashboard / Profil Düzenleme Paneli.
class ArtisanProfileEditScreen extends ConsumerWidget {
  const ArtisanProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(myProfileControllerProvider);

    return Scaffold(
      // Çıkış Yap butonu kaldırıldı — çıkış, birleşik profil sayfasında
      // (düzenleme ekranında oturum kapatmak beklenmedik bir eylemdi).
      appBar: const GradientAppBar(
        title: 'Profili Düzenle',
        icon: Icons.badge_outlined,
      ),
      body: draftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Profil yüklenemedi. Tekrar deneyin.')),
        data: (_) => const _EditForm(),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm();

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  // "Hizmet bölgesi ekle" satırının yerel seçim durumu.
  Province? _addProvince;
  District? _addDistrict;

  bool get _isSaving => ref.watch(myProfileControllerProvider).isLoading;

  MyProfileController get _controller =>
      ref.read(myProfileControllerProvider.notifier);

  /// Galeriden görsel seçip yükler; elde edilen handle [onHandle]'a verilir.
  Future<void> _pickImage({
    required String pathHint,
    required void Function(String handle) onHandle,
  }) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.imagePickMaxWidth,
        imageQuality: AppConstants.imagePickImageQuality,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > AppConstants.maxPhotoSizeBytes) {
        if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
        return;
      }
      final handle = await ref.read(storageRepositoryProvider).uploadImage(
            pathHint: pathHint,
            bytes: bytes,
          );
      onHandle(handle);
    } catch (_) {
      if (mounted) context.showError('Görsel seçilemedi.');
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
    if (draft.profile.profession.isEmpty) {
      context.showError('Lütfen mesleğinizi seçin.');
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

    return ResponsiveCenter(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
            // --- Profil fotoğrafı ---
            Center(
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
            const SizedBox(height: 24),

            // --- Ad Soyad ---
            _Label('Ad Soyad'),
            TextFormField(
              initialValue: draft.displayName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: _controller.setDisplayName,
            ),
            const SizedBox(height: 16),

            // --- Meslek ---
            _Label('Meslek'),
            _ProfessionDropdown(
              value: profile.profession.isEmpty ? null : profile.profession,
              onChanged: (code) {
                if (code != null) _controller.setProfession(code);
              },
            ),
            const SizedBox(height: 16),

            // --- Deneyim ---
            _Label('Deneyim (yıl)'),
            TextFormField(
              initialValue:
                  profile.experienceYears == 0 ? '' : '${profile.experienceYears}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.workspace_premium_outlined),
                hintText: 'Örn. 15',
              ),
              onChanged: (v) =>
                  _controller.setExperience(int.tryParse(v.trim()) ?? 0),
            ),
            const SizedBox(height: 16),

            // --- Hakkımda ---
            _Label('Hakkımda'),
            TextFormField(
              initialValue: profile.aboutText,
              maxLines: 4,
              maxLength: AppConstants.maxAboutLength,
              decoration: const InputDecoration(
                hintText: 'Kendinizi ve işlerinizi kısaca tanıtın',
                alignLabelWithHint: true,
              ),
              onChanged: _controller.setAbout,
            ),
            const SizedBox(height: 8),

            // --- Hizmet Bölgeleri ---
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
                          onDeleted: () => _controller.removeServiceArea(a),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),

            // --- İş Fotoğrafları ---
            _Label('İş Fotoğrafları'),
            const SizedBox(height: 8),
            _WorkPhotos(
              handles: profile.workPhotos,
              onAdd: () => _pickImage(
                  pathHint: 'work', onHandle: _controller.addWorkPhoto),
              onRemove: _controller.removeWorkPhoto,
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
              onAdd: () => _pickImage(
                  pathHint: 'certificate',
                  onHandle: _controller.addCertificate),
              onRemove: _controller.removeCertificate,
            ),
            const SizedBox(height: 24),

            // --- Çalışma Takvimi / Müsaitlik ---
            _Label('Çalışma Takvimi'),
            const SizedBox(height: 4),
            Text(
              'Müşteriler öncelikle "şu an müsait" ustaları görür.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
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

class _ProfessionDropdown extends ConsumerWidget {
  const _ProfessionDropdown({required this.value, required this.onChanged});
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
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.handyman_outlined),
        ),
        hint: const Text('Meslek seçin'),
        items: professions
            .map((p) => DropdownMenuItem(value: p.code, child: Text(p.nameTR)))
            .toList(),
        onChanged: onChanged,
      ),
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
        // İl
        provincesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('İl verisi yüklenemedi'),
          data: (provinces) => _miniDropdown<Province>(
            label: 'İl',
            value: province,
            items: provinces,
            itemLabel: (p) => p.name,
            onChanged: onProvince,
          ),
        ),
        const SizedBox(height: 8),
        // İlçe + Ekle
        Row(
          children: [
            Expanded(
              child: province == null
                  ? _miniDropdown<District>(
                      label: 'İlçe',
                      value: null,
                      items: const [],
                      itemLabel: (d) => d.name,
                      onChanged: null)
                  : ref.watch(districtsProvider(province!.id)).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('İlçe verisi yüklenemedi'),
                        data: (districts) => _miniDropdown<District>(
                          label: 'İlçe',
                          value: district,
                          items: districts,
                          itemLabel: (d) => d.name,
                          onChanged: onDistrict,
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

  Widget _miniDropdown<T>({
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
              value: e,
              child: Text(itemLabel(e), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _WorkPhotos extends StatelessWidget {
  const _WorkPhotos({
    required this.handles,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> handles;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _AddTile(onTap: onAdd),
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
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(Icons.add_a_photo_outlined, color: scheme.primary),
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

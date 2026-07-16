import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/staffing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../data/staffing_providers.dart';
import 'staffing_location_fields.dart';

/// İŞ ARIYORUM — müsait eleman profili.
class WorkerListingEditScreen extends ConsumerStatefulWidget {
  const WorkerListingEditScreen({super.key});

  @override
  ConsumerState<WorkerListingEditScreen> createState() =>
      _WorkerListingEditScreenState();
}

class _WorkerListingEditScreenState
    extends ConsumerState<WorkerListingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _about = TextEditingController();
  final _profession = TextEditingController();
  final _rate = TextEditingController();
  StaffRateType _rateType = StaffRateType.negotiable;
  Province? _province;
  District? _district;
  bool _open = true;
  bool _isDaily = false;
  bool _saving = false;
  bool _seeded = false;
  bool _locationError = false;

  @override
  void dispose() {
    _title.dispose();
    _about.dispose();
    _profession.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _seed(StaffWorkerListing? existing) async {
    if (_seeded) return;
    _seeded = true;
    if (existing != null) {
      _title.text = existing.title;
      _about.text = existing.about;
      _profession.text = existing.professionLabel;
      _rateType = existing.rateType;
      _open = existing.openToWork;
      _isDaily = existing.isDaily;
      if (existing.rate != null) _rate.text = existing.rate!.round().toString();
      final loc = await resolveStaffLocation(
        data: ref.read(localDataServiceProvider),
        provinceName: existing.province,
        districtName: existing.district,
      );
      if (mounted) {
        setState(() {
          _province = loc.province;
          _district = loc.district;
        });
      }
    } else {
      _title.text = 'İş arıyorum';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final locOk = _province != null && _district != null;
    setState(() => _locationError = !locOk);
    if (!formOk || !locOk) {
      context.showError(locOk
          ? 'Lütfen zorunlu alanları doldurun.'
          : 'İl ve ilçeyi listeden seçin.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showError('Oturum bulunamadı. Tekrar giriş yapın.');
      return;
    }
    if (user.suspended) {
      context.showError('Hesabınız askıdayken profil yayınlanamaz.');
      return;
    }

    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'iş arıyorum profili yayınlamak',
    );
    if (!emailOk || !mounted) return;

    // Ücret: görüşülür değilse 1–1_000_000 arası zorunlu.
    double? rate;
    if (_rateType != StaffRateType.negotiable) {
      rate = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
      if (rate == null || rate < 1 || rate > 1000000) {
        context.showError('Ücret 1–1.000.000 ₺ arasında olmalı veya “Görüşülür” seçin.');
        return;
      }
    }

    final title = Validators.sanitizeFreeText(_title.text);
    final about = Validators.sanitizeFreeText(_about.text);
    final profession = Validators.sanitizeFreeText(_profession.text);
    if (title.length > 80 || about.length > 500 || profession.length > 60) {
      context.showError('Alan uzunlukları aşıldı.');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final listing = StaffWorkerListing(
      id: StaffWorkerListing.idFor(user.uid),
      uid: user.uid,
      displayName:
          user.displayName.isEmpty ? 'Kullanıcı' : user.displayName,
      photoUrl: user.profilePhotoUrl,
      title: title,
      about: about,
      professionLabel: profession,
      province: _province!.name,
      district: _district!.name,
      rateType: _rateType,
      rate: rate,
      openToWork: _open,
      isDaily: _isDaily,
      updatedAt: now,
      createdAt: now,
    );
    try {
      await ref.read(staffingRepositoryProvider).saveWorkerListing(listing);
      if (!mounted) return;
      context.showSuccess(_open
          ? 'Profiliniz yayında — işverenler sizi bulabilir.'
          : 'Profil kaydedildi (şu an gizli).');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final s = e.toString();
      if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
        context.showError(
            'Kayıt reddedildi. E-posta doğrulaması, oturum veya güvenlik '
            'jetonunu kontrol edin.');
      } else {
        context.showError('Kaydedilemedi. Bağlantınızı kontrol edin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Oturum gerekli.')));
    }
    final mine = ref.watch(myWorkerListingProvider(user.uid));
    final palette = context.palette;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Eleman · Profilim',
        icon: Icons.work_outline,
      ),
      body: mine.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          message: 'Profil yüklenemedi.',
          onRetry: () => ref.invalidate(myWorkerListingProvider(user.uid)),
        ),
        data: (existing) {
          // ignore: discarded_futures
          _seed(existing);
          return ResponsiveCenter(
            maxWidth: 640,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.infoSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ELEMAN · İşverenler sizi listede görür ve size yazar. '
                      'Siz başvuru göndermezsiniz.',
                      style: TextStyle(
                          color: palette.info,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('İşverenlere açık (iş arıyorum)'),
                    subtitle: Text(
                      _open
                          ? 'Listede görünürsünüz.'
                          : 'Gizli — aramada çıkmazsınız.',
                      style:
                          TextStyle(color: palette.inkMuted, fontSize: 13),
                    ),
                    value: _open,
                    onChanged: (v) => setState(() => _open = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gündelik işlere de açığım'),
                    subtitle: const Text(
                        'İşaretliyse “gündelik eleman” aramasında görünürsünüz'),
                    value: _isDaily,
                    onChanged: (v) => setState(() => _isDaily = v),
                  ),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      hintText: 'Örn. Deneyimli boya yardımcısı',
                    ),
                    maxLength: 80,
                    validator: (v) => Validators.freeText(
                      v,
                      min: 3,
                      max: 80,
                      field: 'Başlık',
                      required: true,
                    ),
                  ),
                  TextFormField(
                    controller: _profession,
                    decoration: const InputDecoration(
                      labelText: 'Meslek / alan',
                    ),
                    maxLength: 60,
                    validator: (v) => Validators.freeText(
                      v,
                      min: 2,
                      max: 60,
                      field: 'Meslek',
                      required: true,
                    ),
                  ),
                  TextFormField(
                    controller: _about,
                    decoration: const InputDecoration(
                      labelText: 'Kısa tanıtım',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: 500,
                    validator: (v) => Validators.freeText(
                      v,
                      min: 10,
                      max: 500,
                      field: 'Tanıtım',
                      required: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StaffingLocationFields(
                    province: _province,
                    district: _district,
                    showError: _locationError,
                    onProvince: (p) => setState(() {
                      _province = p;
                      _district = null;
                      _locationError = false;
                    }),
                    onDistrict: (d) => setState(() {
                      _district = d;
                      _locationError = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('Ücret', style: TextStyle(color: palette.inkMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in StaffRateType.values)
                        ChoiceChip(
                          label: Text(r.labelTR),
                          selected: _rateType == r,
                          onSelected: (_) =>
                              setState(() => _rateType = r),
                        ),
                    ],
                  ),
                  if (_rateType != StaffRateType.negotiable) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _rate,
                      decoration: InputDecoration(
                        labelText: _rateType == StaffRateType.daily
                            ? 'Günlük ücret (₺)'
                            : 'Aylık ücret (₺)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        if (_rateType == StaffRateType.negotiable) return null;
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1 || n > 1000000) {
                          return '1–1.000.000 arası girin';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

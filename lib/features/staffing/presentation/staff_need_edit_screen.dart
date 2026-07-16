import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/staffing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../data/staffing_providers.dart';
import 'staffing_location_fields.dart';

/// ELEMAN ARIYORUM — eleman ilanı.
class StaffNeedEditScreen extends ConsumerStatefulWidget {
  const StaffNeedEditScreen({super.key});

  @override
  ConsumerState<StaffNeedEditScreen> createState() =>
      _StaffNeedEditScreenState();
}

class _StaffNeedEditScreenState extends ConsumerState<StaffNeedEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _detail = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _rate = TextEditingController();
  Province? _province;
  District? _district;
  bool _isDaily = false;
  DateTime? _workDate;
  bool _saving = false;
  bool _locationError = false;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _count.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _workDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _workDate = d);
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
      context.showError('Hesabınız askıdayken ilan açılamaz.');
      return;
    }

    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'eleman ilanı yayınlamak',
    );
    if (!emailOk || !mounted) return;

    final count = int.tryParse(_count.text.trim()) ?? 0;
    if (count < 1 || count > 50) {
      context.showError('Kişi sayısı 1–50 arasında olmalı.');
      return;
    }

    double? dailyRate;
    final rateRaw = _rate.text.trim();
    if (rateRaw.isNotEmpty) {
      dailyRate = double.tryParse(rateRaw.replaceAll(',', '.'));
      if (dailyRate == null || dailyRate < 1 || dailyRate > 1000000) {
        context.showError('Günlük ücret 1–1.000.000 ₺ arası veya boş bırakın.');
        return;
      }
    }

    // İş tarihi geçmiş olamaz (picker zaten kısıtlar; ek güvenlik).
    if (_workDate != null) {
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      if (_workDate!.isBefore(startOfToday)) {
        context.showError('İş tarihi geçmiş bir gün olamaz.');
        return;
      }
    }

    setState(() => _saving = true);
    final need = StaffNeed(
      id: '',
      employerUid: user.uid,
      employerName:
          user.displayName.isEmpty ? 'İşveren' : user.displayName,
      employerPhotoUrl: user.profilePhotoUrl,
      title: Validators.sanitizeFreeText(_title.text),
      detail: Validators.sanitizeFreeText(_detail.text),
      province: _province!.name,
      district: _district!.name,
      neededCount: count,
      isDaily: _isDaily,
      dailyRate: dailyRate,
      workDate: _workDate,
      status: 'open',
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(staffingRepositoryProvider).createNeed(need);
      if (!mounted) return;
      context.showSuccess('Eleman ilanı yayınlandı.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final s = e.toString();
      if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
        context.showError(
            'Yayın reddedildi. E-posta doğrulaması veya oturumu kontrol edin.');
      } else {
        context.showError('Yayınlanamadı, tekrar deneyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İşveren · İlan aç',
        icon: Icons.campaign_outlined,
      ),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'İŞVEREN · İlanınız listelenir. Eleman “başvur” basmaz; '
                  'isterseniz müsait listeden siz yazarsınız.',
                  style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gündelik eleman arıyorum'),
                subtitle: const Text(
                    'İşaretliyse “gündelik” aramasında görünür'),
                value: _isDaily,
                onChanged: (v) => setState(() => _isDaily = v),
              ),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  hintText: 'Örn. Boya yardımcısı aranıyor',
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
                controller: _detail,
                decoration: const InputDecoration(
                  labelText: 'Ayrıntı',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 600,
                validator: (v) => Validators.freeText(
                  v,
                  min: 10,
                  max: 600,
                  field: 'Ayrıntı',
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _count,
                      decoration:
                          const InputDecoration(labelText: 'Kaç kişi'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1 || n > 50) {
                          return '1–50 arası';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _rate,
                      decoration: const InputDecoration(
                          labelText: 'Günlük (₺, opsiyonel)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t);
                        if (n == null || n < 1 || n > 1000000) {
                          return '1–1.000.000';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_workDate == null
                    ? 'İş tarihi (opsiyonel)'
                    : DateFormat('d MMMM yyyy', 'tr_TR').format(_workDate!)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_workDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _workDate = null),
                      ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Yayınlanıyor…' : 'Yayınla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

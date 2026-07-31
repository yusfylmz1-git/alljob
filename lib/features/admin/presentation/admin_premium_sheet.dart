import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/artisan_profile.dart';
import '../data/admin_providers.dart';

/// Manuel Premium tanımlama / uzatma / iptal sayfası (yalnız `finance.manage`).
///
/// Neden var: `verifyMembershipPurchase` Play makbuzuna dayanır. Destek
/// senaryolarında (ödeme alındı ama doğrulama düştü, telafi, kampanya)
/// makbuzsuz premium verilebilmesi gerekir.
///
/// Gerekçe ZORUNLUDUR — işlem denetim kaydına yazılır (para etkili).
Future<void> showPremiumOverrideSheet(
  BuildContext context,
  WidgetRef ref, {
  required ArtisanProfile profile,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PremiumOverrideSheet(profile: profile),
  );
}

class _PremiumOverrideSheet extends ConsumerStatefulWidget {
  const _PremiumOverrideSheet({required this.profile});
  final ArtisanProfile profile;

  @override
  ConsumerState<_PremiumOverrideSheet> createState() =>
      _PremiumOverrideSheetState();
}

class _PremiumOverrideSheetState extends ConsumerState<_PremiumOverrideSheet> {
  final _reason = TextEditingController();
  int _days = 30;
  bool _busy = false;

  /// Hazır süreler + "Özel" (gün girişi).
  static const _presets = <int>[7, 30, 90, 365];
  bool _custom = false;
  final _customDays = TextEditingController(text: '30');

  @override
  void dispose() {
    _reason.dispose();
    _customDays.dispose();
    super.dispose();
  }

  int? get _effectiveDays {
    if (!_custom) return _days;
    final n = int.tryParse(_customDays.text.trim());
    if (n == null || n < 1 || n > 3650) return null;
    return n;
  }

  Future<void> _apply({required bool revoke}) async {
    final reason = _reason.text.trim();
    if (reason.length < 5) {
      context.showError('Gerekçe zorunlu (en az 5 karakter).');
      return;
    }
    final days = revoke ? null : _effectiveDays;
    if (!revoke && days == null) {
      context.showError('Geçerli bir gün sayısı girin (1–3650).');
      return;
    }
    // Kilidi ilk anda al — ikinci dokunuş ikinci tanımlama yapmasın.
    setState(() => _busy = true);
    try {
      final until = await ref
          .read(adminArtisanRepositoryProvider)
          .setPremiumOverride(
            widget.profile.uid,
            reason: reason,
            days: days,
            revoke: revoke,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.invalidate(artisanDirectoryControllerProvider);
      context.showSuccess(
        revoke
            ? 'Premium iptal edildi.'
            : 'Premium tanımlandı — ${_fmtDate(until)} tarihine kadar.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız: ${_errText(e)}');
    }
  }

  static String _errText(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final p = widget.profile;
    final until = p.premiumExpiresAt;
    final active =
        p.isPremium && until != null && until.isAfter(DateTime.now());

    return Padding(
      // Klavye açılınca gerekçe alanı görünür kalsın.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Premium müdahalesi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'UID: ${p.uid}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
              const SizedBox(height: 10),

              // Mevcut durum.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  active
                      ? 'Şu an PREMIUM · bitiş ${_fmtDate(until)}'
                      : until != null
                      ? 'Premium süresi dolmuş · ${_fmtDate(until)}'
                      : 'Premium yok',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: active ? palette.success : palette.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(height: 6),
                Text(
                  'Uzatma, kalan süreye EKLENİR (mevcut üyelik kısalmaz).',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              Text('Süre', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in _presets)
                    ChoiceChip(
                      label: Text('$d gün'),
                      selected: !_custom && _days == d,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                              _custom = false;
                              _days = d;
                            }),
                    ),
                  ChoiceChip(
                    label: const Text('Özel'),
                    selected: _custom,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _custom = true),
                  ),
                ],
              ),
              if (_custom) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customDays,
                  keyboardType: TextInputType.number,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Gün sayısı (1–3650)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Gerekçe (zorunlu)',
                  hintText:
                      'Örn: Ödeme alındı, Play doğrulaması düştü — '
                      'destek talebi #123',
                  border: OutlineInputBorder(),
                ),
              ),
              Text(
                'Bu işlem denetim kaydına yazılır.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.workspace_premium, size: 18),
                      label: Text(active ? 'Uzat' : 'Premium ver'),
                      onPressed: _busy ? null : () => _apply(revoke: false),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.danger,
                      ),
                      onPressed: _busy ? null : () => _apply(revoke: true),
                      child: const Text('İptal et'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

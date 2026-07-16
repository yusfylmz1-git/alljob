import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../data/admin_providers.dart';
import '../data/admin_runtime_config_repository.dart';
import 'admin_chrome.dart';

/// Toplu bildirim: şimdi gönder veya zamanla + kampanya listesi.
class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _profession = TextEditingController();
  final _province = TextEditingController();
  String _audience = 'all';
  bool _sendPush = true;
  bool _busy = false;

  /// false = şimdi; true = zamanla
  bool _scheduleMode = false;
  DateTime? _scheduledAt;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _profession.dispose();
    _province.dispose();
    super.dispose();
  }

  bool _validate() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      context.showError('Başlık ve metin zorunlu.');
      return false;
    }
    if (_audience == 'profession' && _profession.text.trim().isEmpty) {
      context.showError('Meslek kodu girin (örn. painter).');
      return false;
    }
    if (_audience == 'province' && _province.text.trim().isEmpty) {
      context.showError('İl adı girin (örn. Bursa).');
      return false;
    }
    if (_scheduleMode) {
      final when = _scheduledAt;
      if (when == null) {
        context.showError('Tarih/saat seçin.');
        return false;
      }
      if (when.isBefore(DateTime.now().add(const Duration(minutes: 2)))) {
        context.showError('En az 2 dakika sonrası olmalı.');
        return false;
      }
    }
    return true;
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: (now.minute + 10) % 60),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _scheduleMode = true;
    });
  }

  Future<void> _submit() async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok.');
      return;
    }
    if (!_validate()) return;

    final title = _title.text.trim();
    final body = _body.text.trim();
    final when = _scheduledAt;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_scheduleMode ? 'Kampanya planlansın mı?' : 'Şimdi gönderilsin mi?'),
        content: Text(
          _scheduleMode
              ? 'Zaman: ${DateFormat('dd.MM.yyyy HH:mm').format(when!)}\n'
                  'Hedef: ${_audienceLabel()}\nPush: ${_sendPush ? "evet" : "hayır"}'
              : 'Hedef: ${_audienceLabel()}\nPush: ${_sendPush ? "evet" : "hayır"}\n\n'
                  'Anında gönderim 5 dk rate limit\'e tabidir.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_scheduleMode ? 'Planla' : 'Gönder')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(adminBroadcastRepositoryProvider);
      if (_scheduleMode && when != null) {
        final res = await repo.schedule(
          title: title,
          body: body,
          audience: _audience,
          scheduledAt: when,
          sendPush: _sendPush,
          profession: _profession.text.trim(),
          province: _province.text.trim(),
        );
        if (!mounted) return;
        context.showSuccess(
          'Planlandı · ${res['scheduledAt'] ?? when.toLocal()}',
        );
      } else {
        final res = await repo.send(
          title: title,
          body: body,
          audience: _audience,
          sendPush: _sendPush,
          profession: _profession.text.trim(),
          province: _province.text.trim(),
        );
        if (!mounted) return;
        context.showSuccess('Gönderildi · ${res['recipients'] ?? 0} alıcı.');
      }
      _title.clear();
      _body.clear();
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      if (s.contains('resource-exhausted')) {
        context.showError('5 dakika bekleyin (anında gönderim).');
      } else if (s.contains('failed-precondition')) {
        context.showError('Hedefte alıcı yok veya filtre hatalı.');
      } else {
        context.showError('İşlem başarısız (CF/ağ).');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _audienceLabel() => switch (_audience) {
        'artisans' => 'Ustalar',
        'customers' => 'Müşteriler',
        'profession' => 'Meslek: ${_profession.text.trim()}',
        'province' => 'İl: ${_province.text.trim()}',
        _ => 'Tümü (son 300)',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final can = ref.watch(adminCapabilitiesProvider).allows('config.manage');
    final theme = Theme.of(context);
    final campaignsAsync = ref.watch(scheduledCampaignsProvider);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Bildirim & kampanya',
        icon: Icons.campaign_outlined,
        subtitle: 'Şimdi gönder veya zamanla',
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: ListView(
          children: [
            Text('Gönderim tipi',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Şimdi'), icon: Icon(Icons.send, size: 16)),
                ButtonSegment(value: true, label: Text('Zamanla'), icon: Icon(Icons.schedule, size: 16)),
              ],
              selected: {_scheduleMode},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                        _scheduleMode = s.first;
                        if (!_scheduleMode) _scheduledAt = null;
                      }),
            ),
            if (_scheduleMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickSchedule,
                icon: const Icon(Icons.event),
                label: Text(
                  _scheduledAt == null
                      ? 'Tarih ve saat seç'
                      : DateFormat('dd.MM.yyyy HH:mm').format(_scheduledAt!),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'İşleyici her 5 dk çalışır (±5 dk gecikme normal). En az 2 dk sonrası.',
                style: TextStyle(color: palette.inkFaint, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Text('Hedef kitle',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  ('all', 'Tümü'),
                  ('artisans', 'Ustalar'),
                  ('customers', 'Müşteriler'),
                  ('profession', 'Meslek'),
                  ('province', 'İl'),
                ])
                  ChoiceChip(
                    label: Text(e.$2),
                    selected: _audience == e.$1,
                    onSelected:
                        _busy ? null : (_) => setState(() => _audience = e.$1),
                  ),
              ],
            ),
            if (_audience == 'profession') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _profession,
                enabled: can && !_busy,
                decoration: const InputDecoration(
                  labelText: 'Meslek kodu',
                  hintText: 'painter, electrician…',
                ),
              ),
            ],
            if (_audience == 'province') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _province,
                enabled: can && !_busy,
                decoration: const InputDecoration(
                  labelText: 'İl',
                  hintText: 'Bursa',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: can && !_busy,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            TextField(
              controller: _body,
              enabled: can && !_busy,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Mesaj',
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Push da gönder'),
              value: _sendPush,
              onChanged:
                  (!can || _busy) ? null : (v) => setState(() => _sendPush = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (!can || _busy) ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_scheduleMode ? Icons.event_available : Icons.send_outlined),
              label: Text(_busy
                  ? 'İşleniyor…'
                  : (_scheduleMode ? 'Kampanyayı planla' : 'Şimdi gönder')),
            ),
            const Divider(height: 40),
            Text('Planlanan / geçmiş kampanyalar',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            campaignsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Liste okunamadı (yetki/indeks): $e',
                style: TextStyle(color: palette.danger, fontSize: 13),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Henüz kampanya yok.',
                    style: TextStyle(color: palette.inkMuted),
                  );
                }
                return Column(
                  children: [
                    for (final c in list) _CampaignTile(campaign: c),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignTile extends ConsumerWidget {
  const _CampaignTile({required this.campaign});
  final ScheduledCampaign campaign;

  Color _statusColor(AppPalette p) => switch (campaign.status) {
        'pending' => p.warning,
        'processing' => p.primary,
        'sent' => p.success,
        'failed' => p.danger,
        'cancelled' => p.inkFaint,
        _ => p.inkMuted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final fmt = DateFormat('dd.MM.yy HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.hairline),
      ),
      child: ListTile(
        title: Text(campaign.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${campaign.status} · ${fmt.format(campaign.scheduledAt.toLocal())}\n'
          '${campaign.audience}'
          '${campaign.recipients != null ? ' · ${campaign.recipients} alıcı' : ''}'
          '${campaign.error != null ? '\n${campaign.error}' : ''}',
        ),
        isThreeLine: true,
        leading: Icon(Icons.campaign, color: _statusColor(palette)),
        trailing: campaign.isPending
            ? IconButton(
                tooltip: 'İptal',
                icon: const Icon(Icons.cancel_outlined),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Kampanya iptal?'),
                      content: Text(campaign.title),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Vazgeç')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('İptal et')),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  try {
                    await ref
                        .read(adminBroadcastRepositoryProvider)
                        .cancel(campaign.id);
                    if (context.mounted) {
                      context.showSuccess('İptal edildi.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      context.showError('İptal başarısız.');
                    }
                  }
                },
              )
            : null,
      ),
    );
  }
}

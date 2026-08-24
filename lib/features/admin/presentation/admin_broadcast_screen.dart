import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../data/admin_broadcast_history.dart';
import '../data/admin_providers.dart';
import 'admin_pickers.dart';
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
  /// Seçili meslek KODU (`painter`) — seçiciden gelir, elle yazılmaz.
  String? _professionCode;

  /// Seçili il ADI (`Bursa`) — seçiciden gelir.
  String? _provinceName;
  final _targetUser = TextEditingController();
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

    _targetUser.dispose();
    super.dispose();
  }

  /// E-posta ise targetEmail, aksi halde UID.
  ({String? uid, String? email}) _parseTargetUser() {
    final raw = _targetUser.text.trim();
    if (raw.isEmpty) return (uid: null, email: null);
    if (raw.contains('@')) {
      return (uid: null, email: raw.toLowerCase());
    }
    return (uid: raw, email: null);
  }

  bool _validate() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      context.showError('Başlık ve metin zorunlu.');
      return false;
    }
    if (_audience == 'profession' && (_professionCode ?? '').isEmpty) {
      context.showError('Meslek kodu girin (örn. painter).');
      return false;
    }
    if (_audience == 'province' && (_provinceName ?? '').isEmpty) {
      context.showError('İl adı girin (örn. Bursa).');
      return false;
    }
    if (_audience == 'user' && _targetUser.text.trim().isEmpty) {
      context.showError('E-posta veya kullanıcı UID girin.');
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
        title: Text(
          _scheduleMode ? 'Kampanya planlansın mı?' : 'Şimdi gönderilsin mi?',
        ),
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
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_scheduleMode ? 'Planla' : 'Gönder'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(adminBroadcastRepositoryProvider);
      final target = _parseTargetUser();
      if (_scheduleMode && when != null) {
        final res = await repo.schedule(
          title: title,
          body: body,
          audience: _audience,
          scheduledAt: when,
          sendPush: _sendPush,
          profession: _professionCode ?? '',
          province: _provinceName ?? '',
          targetUid: target.uid,
          targetEmail: target.email,
        );
        if (!mounted) return;
        context.showSuccess(
          'Planlandı · ${res['scheduledAt'] ?? when.toLocal()}',
        );
        ref.invalidate(broadcastHistoryProvider);
      } else {
        final res = await repo.send(
          title: title,
          body: body,
          audience: _audience,
          sendPush: _sendPush,
          profession: _professionCode ?? '',
          province: _provinceName ?? '',
          targetUid: target.uid,
          targetEmail: target.email,
        );
        if (!mounted) return;
        // NEREYE DÜŞTÜĞÜNÜ SÖYLE (2026-08-23): yönetici gönderdikten
        // sonra "gitti mi, nasıl görünüyor" sorusunun cevabını
        // bilmiyordu. Bildirim, kullanıcının bildirim merkezinde
        // (zil ikonu) görünür.
        context.showSuccess(
          '${res['recipients'] ?? 0} kişiye gönderildi · '
          'bildirim merkezinde görünüyor'
          '${_sendPush ? ' · push da gitti' : ''}',
        );
        ref.invalidate(broadcastHistoryProvider);
      }
      _title.clear();
      _body.clear();
      _targetUser.clear();
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      if (s.contains('resource-exhausted')) {
        context.showError('5 dakika bekleyin (anında gönderim).');
      } else if (s.contains('not-found')) {
        context.showError('Kullanıcı bulunamadı (e-posta veya UID).');
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
    // Kod DEĞİL ad gösterilir: yönetici ne seçtiğini okuyabilmeli.
    'profession' => 'Meslek: '
        '${kProfessionNames[_professionCode] ?? _professionCode ?? '—'}',
    'province' => 'İl: ${_provinceName ?? '—'}',
    'user' => 'Tek kişi: ${_targetUser.text.trim()}',
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
            Text(
              'Gönderim tipi',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 360;
                return SegmentedButton<bool>(
                  showSelectedIcon: !compact,
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(compact ? 'Şimdi' : 'Şimdi gönder'),
                      icon: compact ? null : const Icon(Icons.send, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: const Text('Zamanla'),
                      icon: compact
                          ? null
                          : const Icon(Icons.schedule, size: 16),
                    ),
                  ],
                  selected: {_scheduleMode},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() {
                          _scheduleMode = s.first;
                          if (!_scheduleMode) _scheduledAt = null;
                        }),
                );
              },
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
            Text(
              'Hedef kitle',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
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
                  ('user', 'Tek kişi'),
                ])
                  ChoiceChip(
                    label: Text(e.$2),
                    selected: _audience == e.$1,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _audience = e.$1),
                  ),
              ],
            ),
            // SEÇİCİ, METİN KUTUSU DEĞİL (2026-08-23).
            //
            // Yönetici `painter` yazmak zorundaydı ama katalogda 145 meslek
            // var ve hiçbiri ekranda görünmüyordu. Yanlış yazım hata da
            // vermiyordu: sunucu "alıcı bulunamadı" diyor, sebep belirsiz
            // kalıyordu — duyurunun kimseye gitmemesiyle aynı ekran.
            if (_audience == 'profession') ...[
              const SizedBox(height: 12),
              AdminProfessionPicker(
                value: _professionCode,
                enabled: can && !_busy,
                onChanged: (v) => setState(() => _professionCode = v),
              ),
            ],
            if (_audience == 'province') ...[
              const SizedBox(height: 12),
              AdminProvincePicker(
                value: _provinceName,
                enabled: can && !_busy,
                onChanged: (v) => setState(() => _provinceName = v),
              ),
            ],
            if (_audience == 'user') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _targetUser,
                enabled: can && !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta veya UID',
                  hintText: 'ornek@gmail.com veya Firebase uid',
                  helperText: '@ içeriyorsa e-posta, değilse UID sayılır',
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
              onChanged: (!can || _busy)
                  ? null
                  : (v) => setState(() => _sendPush = v),
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
                  : Icon(
                      _scheduleMode
                          ? Icons.event_available
                          : Icons.send_outlined,
                    ),
              label: Text(
                _busy
                    ? 'İşleniyor…'
                    : (_scheduleMode ? 'Kampanyayı planla' : 'Şimdi gönder'),
              ),
            ),
            const Divider(height: 40),
            Text(
              'Planlanan / geçmiş kampanyalar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
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
                  children: [for (final c in list) _CampaignTile(campaign: c)],
                );
              },
            ),

            // ANINDA GÖNDERİLENLER (2026-08-23).
            //
            // Üstteki liste yalnız ZAMANLANMIŞ kampanyaları gösteriyordu
            // (`scheduledCampaigns` koleksiyonu). "Şimdi gönder" ile
            // yollanan duyurunun hiçbir izi yoktu: yönetici "geçen hafta ne
            // gönderdim" sorusunu cevaplayamıyor, aynı duyuruyu iki kez
            // göndermeye karşı koruma da olmuyordu.
            //
            // Kaynak denetim kaydı — ayrı koleksiyon AÇILMADI, veri zaten
            // orada tam duruyor.
            const Divider(height: 40),
            Text(
              'Son gönderilenler',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kaynak: denetim kaydı. Bildirimler kullanıcının bildirim '
              'merkezinde (zil) görünür.',
              style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            ref.watch(broadcastHistoryProvider).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => Text(
                    'Geçmiş okunamadı (audit.read yetkisi gerekli).',
                    style: TextStyle(color: palette.inkMuted, fontSize: 13),
                  ),
                  data: (kayitlar) {
                    if (kayitlar.isEmpty) {
                      return Text(
                        'Henüz duyuru gönderilmemiş.',
                        style: TextStyle(color: palette.inkMuted),
                      );
                    }
                    return Column(
                      children: [
                        for (final k in kayitlar) _GonderimSatiri(kayit: k),
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

/// Gönderilmiş tek duyuru satırı.
class _GonderimSatiri extends StatelessWidget {
  const _GonderimSatiri({required this.kayit});
  final BroadcastRecord kayit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final fmt = DateFormat('dd.MM.yy HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            kayit.scheduled
                ? Icons.event_available_outlined
                : Icons.send_outlined,
            size: 18,
            color: palette.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kayit.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  // Hedef KOD değil AD olarak yazılır.
                  '${kayit.hedefTR(kProfessionNames)} · '
                  '${fmt.format(kayit.createdAt.toLocal())}'
                  '${kayit.pushSent ? ' · push' : ''}',
                  style: TextStyle(color: palette.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${kayit.recipients}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
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
        title: Text(
          campaign.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
                          child: const Text('Vazgeç'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('İptal et'),
                        ),
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

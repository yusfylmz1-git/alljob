import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../data/admin_providers.dart';
import '../data/admin_user_repository.dart';

/// 360° kullanıcı özeti + dahili admin notları.
///
/// Kullanıcı eylem sayfasına gömülür: moderasyon kararı verilmeden önce
/// "bu kullanıcı kim, ne yapmış, hakkında ne konuşulmuş" tek yerde görünür.
///
/// Notlar KULLANICIYA GÖRÜNMEZ (rules: adminUserNotes istemciye kapalı) ve
/// silinmez — destek geçmişinin bütünlüğü için append-only.
class AdminUserOverview extends ConsumerStatefulWidget {
  const AdminUserOverview({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<AdminUserOverview> createState() => _AdminUserOverviewState();
}

class _AdminUserOverviewState extends ConsumerState<AdminUserOverview> {
  final _noteCtrl = TextEditingController();

  AdminUserSummary? _summary;
  List<AdminUserNote> _notes = const [];
  bool _loading = true;
  bool _savingNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(adminUserRepositoryProvider);
      // Özet ve notlar bağımsız — biri düşerse diğeri yine gösterilsin.
      final results = await Future.wait([
        repo.summary(widget.uid),
        repo.notes(widget.uid),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AdminUserSummary;
        _notes = results[1] as List<AdminUserNote>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Özet yüklenemedi.';
      });
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.length < 2) {
      context.showError('Not boş olamaz.');
      return;
    }
    setState(() => _savingNote = true);
    try {
      await ref.read(adminUserRepositoryProvider).addNote(widget.uid, text);
      final fresh = await ref
          .read(adminUserRepositoryProvider)
          .notes(widget.uid);
      if (!mounted) return;
      setState(() {
        _notes = fresh;
        _savingNote = false;
        _noteCtrl.clear();
      });
      context.showSuccess('Not eklendi.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingNote = false);
      context.showError('Not eklenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Divider(color: palette.hairline, height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.insights_outlined, size: 16, color: palette.inkMuted),
            const SizedBox(width: 6),
            Text(
              'Aktivite özeti',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_error != null)
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          )
        else if (!_loading && _summary != null) ...[
          _CountGrid(summary: _summary!),
          if (_summary!.artisan != null) ...[
            const SizedBox(height: 10),
            _ArtisanFacts(artisan: _summary!.artisan!),
          ],
        ],

        const SizedBox(height: 18),
        Row(
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 16,
              color: palette.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Dahili notlar',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Yalnız yöneticiler görür. Notlar silinmez.',
          style: theme.textTheme.labelSmall?.copyWith(color: palette.inkFaint),
        ),
        const SizedBox(height: 8),

        if (_notes.isEmpty && !_loading)
          Text(
            'Henüz not yok.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          )
        else
          for (final n in _notes) _NoteTile(note: n),

        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          minLines: 2,
          maxLines: 4,
          maxLength: 2000,
          enabled: !_savingNote,
          decoration: const InputDecoration(
            hintText:
                'Örn: Kullanıcı arandı, sertifika orijinalini '
                'mail atacak.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            icon: _savingNote
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 16),
            label: const Text('Not ekle'),
            onPressed: _savingNote ? null : _addNote,
          ),
        ),
      ],
    );
  }
}

/// Sayaç kutucukları. Sayım yapılamayan alan "—" gösterir (0 demek DEĞİL).
class _CountGrid extends StatelessWidget {
  const _CountGrid({required this.summary});
  final AdminUserSummary summary;

  static const _labels = <String, String>{
    'jobsCreated': 'İlan',
    'jobsActive': 'Açık ilan',
    'reviewsReceived': 'Değerlendirme',
    'reportsAgainst': 'Hakkında şikayet',
    'reportsBy': 'Şikayet ettiği',
    'products': 'Ürün',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _labels.entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.counts[e.key]?.toString() ?? '—',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    // Hakkında şikayet varsa dikkat çeksin.
                    color:
                        e.key == 'reportsAgainst' &&
                            (summary.counts[e.key] ?? 0) > 0
                        ? palette.danger
                        : null,
                  ),
                ),
                Text(
                  e.value,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Usta profili varsa premium/onay/puan bilgileri.
class _ArtisanFacts extends StatelessWidget {
  const _ArtisanFacts({required this.artisan});
  final Map<String, dynamic> artisan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final premium = artisan['isPremium'] == true;
    final untilRaw = artisan['premiumExpiresAt'] as String?;
    final until = untilRaw == null ? null : DateTime.tryParse(untilRaw);
    final manual = artisan['premiumProductId'] == 'manual_admin_grant';

    final bits = <String>[
      if (premium)
        'Premium${until != null ? ' → ${until.day}.${until.month}.${until.year}' : ''}'
            '${manual ? ' (manuel)' : ''}'
      else
        'Premium yok',
      if (artisan['adminVerified'] == true) 'Platform onaylı',
      if (artisan['isVerified'] == true) 'Telefon doğrulanmış',
      if (artisan['moderationHidden'] == true) 'GİZLENMİŞ',
      '★ ${(artisan['averageRating'] as num? ?? 0).toStringAsFixed(1)}'
          ' (${artisan['totalReviews'] ?? 0})',
      '${artisan['completedJobs'] ?? 0} tamamlanan iş',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        bits.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: artisan['moderationHidden'] == true
              ? palette.danger
              : palette.inkMuted,
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final AdminUserNote note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final d = note.createdAt;
    final stamp = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}.'
              '${d.month.toString().padLeft(2, '0')}.${d.year}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.note, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            [
              stamp,
              if (note.actorUid != null) note.actorUid!,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

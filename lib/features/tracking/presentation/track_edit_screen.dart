import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/track_item.dart';
import '../application/tracking_controller.dart';
import '../data/track_notification_service.dart';
import '../data/tracking_providers.dart';

final _reminderFmt = DateFormat('d MMM yyyy, HH:mm', 'tr_TR');

/// Yeni takip oluşturma / var olanı düzenleme.
///
/// Akıllı arayüz (progressive disclosure): açılışta yalnız Başlık + Not
/// görünür; Öncelik ve Etiket "Ekle" çipleriyle istenince açılır. Kişi/konum/
/// hatırlatma/ek alanları sonraki fazlarda aynı çip kalıbıyla eklenecek.
class TrackEditScreen extends ConsumerStatefulWidget {
  const TrackEditScreen({super.key, this.trackId});

  /// null → yeni kayıt; doluysa düzenleme.
  final String? trackId;

  @override
  ConsumerState<TrackEditScreen> createState() => _TrackEditScreenState();
}

class _TrackEditScreenState extends ConsumerState<TrackEditScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();

  TrackItem? _existing;
  TrackPriority _priority = TrackPriority.normal;
  final List<String> _tags = [];
  DateTime? _reminderAt;
  TrackRecurrence _recurrence = TrackRecurrence.none;
  final Set<String> _revealed = {};
  bool _dirty = false;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.trackId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.trackId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final item = await ref.read(trackingRepositoryProvider).getById(id);
    if (!mounted) return;
    setState(() {
      _existing = item;
      if (item != null) {
        _titleController.text = item.title;
        _noteController.text = item.note ?? '';
        _priority = item.priority;
        _tags.addAll(item.tags);
        _reminderAt = item.reminderAt;
        _recurrence = item.recurrence;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _dirty = true;
      });
    }
    _tagController.clear();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değişiklikleri bırak?'),
        content: const Text(
            'Kaydedilmemiş değişiklikleriniz var. Çıkarsanız kaybolur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final base = _reminderAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    // İlk kez hatırlatma kurulurken bildirim iznini iste (reddedilse de kayıt
    // olur; yalnız bildirim düşmez).
    await ref.read(trackNotificationServiceProvider).ensurePermission();
    if (!mounted) return;
    setState(() {
      _reminderAt = picked;
      _dirty = true;
    });
  }

  void _clearReminder() => setState(() {
        _reminderAt = null;
        _recurrence = TrackRecurrence.none;
        _dirty = true;
      });

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      context.showError('Başlık gerekli.');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final note = _noteController.text.trim();
    final base = _existing;
    // copyWith null'ı temizleyemez (hatırlatma kaldırma) → alanları açıkça kur;
    // düzenlerken id/oluşturulma/durum/kişi/konum/ek KORUNUR.
    final item = TrackItem(
      id: base?.id ?? TrackItem.newId(),
      title: title,
      note: note.isEmpty ? null : note,
      status: base?.status ?? TrackStatus.active,
      priority: _priority,
      tags: List.of(_tags),
      reminderAt: _reminderAt,
      recurrence: _reminderAt == null ? TrackRecurrence.none : _recurrence,
      person: base?.person,
      location: base?.location,
      attachments: base?.attachments ?? const [],
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
      deletedAt: base?.deletedAt,
    );

    await ref.read(trackingControllerProvider).save(item);
    if (!mounted) return;
    _dirty = false;
    context.showSuccess(_isEditing ? 'Takip güncellendi.' : 'Takip eklendi.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final showPriority =
        _revealed.contains('priority') || _priority != TrackPriority.normal;
    final showTags = _revealed.contains('tags') || _tags.isNotEmpty;
    final showReminder =
        _revealed.contains('reminder') || _reminderAt != null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: GradientAppBar(
          title: _isEditing ? 'Takibi Düzenle' : 'Yeni Takip',
        ),
        bottomNavigationBar: _SaveBar(
          loading: _saving,
          label: _isEditing ? 'Güncelle' : 'Kaydet',
          onPressed: _save,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveCenter(
                maxWidth: 720,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ListView(
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        hintText: 'Ne takip ediyorsun?',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Not (isteğe bağlı)',
                        hintText: 'Detay, adres, hatırlatıcı bilgi…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (showPriority) ...[
                      _FieldLabel('Öncelik'),
                      const SizedBox(height: 8),
                      _PrioritySelector(
                        value: _priority,
                        onChanged: (p) => setState(() {
                          _priority = p;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (showTags) ...[
                      _FieldLabel('Etiketler'),
                      const SizedBox(height: 8),
                      _TagEditor(
                        tags: _tags,
                        controller: _tagController,
                        onAdd: _addTag,
                        onRemove: (t) => setState(() {
                          _tags.remove(t);
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (showReminder) ...[
                      _FieldLabel('Hatırlatma'),
                      const SizedBox(height: 8),
                      _ReminderEditor(
                        reminderAt: _reminderAt,
                        recurrence: _recurrence,
                        onPick: _pickReminder,
                        onClear: _clearReminder,
                        onRecurrence: (r) => setState(() {
                          _recurrence = r;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _AddFieldChips(
                      showPriority: !showPriority,
                      showTags: !showTags,
                      showReminder: !showReminder,
                      onReveal: (key) => setState(() => _revealed.add(key)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          // DİKKAT: bottomNavigationBar'da ResponsiveCenter/Align KULLANMA —
          // heightFactor'süz Align tüm ekran yüksekliğini kaplar, gövdeye 0px
          // bırakır (Oturum 41 create_job regresyonu). Center(heightFactor:1)
          // çubuğu çocuğu kadar tutar, genişliği yine sınırlar.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AppButton(
                label: label,
                isLoading: loading,
                icon: Icons.check,
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.inkMuted,
          ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});
  final TrackPriority value;
  final ValueChanged<TrackPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TrackPriority>(
      segments: const [
        ButtonSegment(
            value: TrackPriority.low, label: Text('Düşük')),
        ButtonSegment(
            value: TrackPriority.normal, label: Text('Normal')),
        ButtonSegment(
            value: TrackPriority.high, label: Text('Yüksek')),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  Chip(
                    label: Text(t),
                    onDeleted: () => onRemove(t),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: const InputDecoration(
                  hintText: 'Etiket ekle (ör. ev, acil)',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hatırlatma tarihi/saati + tekrarlama seçimi. Tarih seçili değilken seçtirir;
/// seçiliyken tarihi (dokununca değiştir) + Tekrar seçeneklerini gösterir.
class _ReminderEditor extends StatelessWidget {
  const _ReminderEditor({
    required this.reminderAt,
    required this.recurrence,
    required this.onPick,
    required this.onClear,
    required this.onRecurrence,
  });

  final DateTime? reminderAt;
  final TrackRecurrence recurrence;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ValueChanged<TrackRecurrence> onRecurrence;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final at = reminderAt;

    if (at == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.event_outlined, size: 18),
        label: const Text('Tarih ve saat seç'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 20, color: palette.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _reminderFmt.format(at),
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Hatırlatmayı kaldır',
                  icon: Icon(Icons.close, size: 18, color: palette.inkMuted),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Tekrar',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: palette.inkMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in TrackRecurrence.values)
              ChoiceChip(
                label: Text(r.labelTR),
                selected: recurrence == r,
                onSelected: (_) => onRecurrence(r),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Ekle" çipleri — henüz görünmeyen alanları açığa çıkarır (akıllı arayüz).
class _AddFieldChips extends StatelessWidget {
  const _AddFieldChips({
    required this.showPriority,
    required this.showTags,
    required this.showReminder,
    required this.onReveal,
  });

  final bool showPriority;
  final bool showTags;
  final bool showReminder;
  final ValueChanged<String> onReveal;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (showReminder)
        _AddChip(
          icon: Icons.notifications_outlined,
          label: 'Hatırlatma',
          onTap: () => onReveal('reminder'),
        ),
      if (showPriority)
        _AddChip(
          icon: Icons.flag_outlined,
          label: 'Öncelik',
          onTap: () => onReveal('priority'),
        ),
      if (showTags)
        _AddChip(
          icon: Icons.label_outline,
          label: 'Etiket',
          onTap: () => onReveal('tags'),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Ekle'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

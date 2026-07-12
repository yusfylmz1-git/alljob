import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/track_item.dart';
import '../application/tracking_controller.dart';
import '../data/tracking_providers.dart';

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
    final item = base == null
        ? TrackItem(
            id: TrackItem.newId(),
            title: title,
            note: note.isEmpty ? null : note,
            priority: _priority,
            tags: List.of(_tags),
            createdAt: now,
            updatedAt: now,
          )
        : base.copyWith(
            title: title,
            note: note.isEmpty ? null : note,
            priority: _priority,
            tags: List.of(_tags),
            updatedAt: now,
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
                    _AddFieldChips(
                      showPriority: !showPriority,
                      showTags: !showTags,
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

/// "Ekle" çipleri — henüz görünmeyen alanları açığa çıkarır (akıllı arayüz).
class _AddFieldChips extends StatelessWidget {
  const _AddFieldChips({
    required this.showPriority,
    required this.showTags,
    required this.onReveal,
  });

  final bool showPriority;
  final bool showTags;
  final ValueChanged<String> onReveal;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
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

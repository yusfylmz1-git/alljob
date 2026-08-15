import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/product_category.dart';
import '../data/admin_providers.dart';

/// Sistem ayarları → Mağaza ürün kategorileri düzenleyici.
///
/// Liste canlı `adminConfig/productCategories` dokümanından gelir;
/// boşsa gömülü yedek gösterilir. Kaydet → CF `adminUpdateProductCategories`.
class AdminProductCategoriesSection extends ConsumerStatefulWidget {
  const AdminProductCategoriesSection({super.key});

  @override
  ConsumerState<AdminProductCategoriesSection> createState() =>
      _AdminProductCategoriesSectionState();
}

class _AdminProductCategoriesSectionState
    extends ConsumerState<AdminProductCategoriesSection> {
  List<ProductCategoryItem>? _draft;
  bool _busy = false;
  bool _dirty = false;

  void _ensureDraft(ProductCategoryCatalog remote) {
    if (_draft != null) return;
    _draft = remote.items
        .map((e) => e.copyWith())
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  void _renumber() {
    final d = _draft;
    if (d == null) return;
    for (var i = 0; i < d.length; i++) {
      d[i] = d[i].copyWith(order: i);
    }
  }

  Future<void> _save() async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok.');
      return;
    }
    final d = _draft;
    if (d == null || d.isEmpty) {
      context.showError('En az bir kategori gerekli.');
      return;
    }
    if (!d.any((e) => e.active)) {
      context.showError('En az bir aktif kategori olmalı.');
      return;
    }
    for (final e in d) {
      if (!ProductCategory.isValidCode(e.code)) {
        context.showError('Geçersiz kod: ${e.code}');
        return;
      }
      if (e.label.trim().isEmpty) {
        context.showError('Etiket boş olamaz: ${e.code}');
        return;
      }
    }
    final codes = d.map((e) => e.code).toSet();
    if (codes.length != d.length) {
      context.showError('Mükerrer kod var.');
      return;
    }

    setState(() => _busy = true);
    try {
      _renumber();
      await ref
          .read(adminRuntimeConfigRepositoryProvider)
          .saveProductCategories(List.of(_draft!));
      if (!mounted) return;
      setState(() {
        _dirty = false;
        // Uzak stream tazeleyince yeniden seed etmeye gerek yok —
        // taslağı temizleyip stream'den al.
        _draft = null;
      });
      context.showSuccess('Ürün kategorileri kaydedildi.');
    } catch (e) {
      if (!mounted) return;
      context.showError('Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<_NewCat?>(
      context: context,
      builder: (ctx) => const _AddCategoryDialog(),
    );
    if (result == null || !mounted) return;
    final d = _draft ?? [];
    if (d.any((e) => e.code == result.code)) {
      context.showError('Bu kod zaten var: ${result.code}');
      return;
    }
    setState(() {
      _draft = [
        ...d,
        ProductCategoryItem(
          code: result.code,
          label: result.label,
          order: d.length,
          active: true,
        ),
      ];
      _dirty = true;
    });
  }

  Future<void> _editLabel(int index) async {
    final item = _draft![index];
    final ctrl = TextEditingController(text: item.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Etiketi düzenle · ${item.code}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Görünen ad',
            hintText: 'örn. Yapı Malzemesi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    final label = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted || label.isEmpty) return;
    setState(() {
      _draft![index] = item.copyWith(label: label);
      _dirty = true;
    });
  }

  void _move(int index, int delta) {
    final d = _draft!;
    final j = index + delta;
    if (j < 0 || j >= d.length) return;
    setState(() {
      final t = d[index];
      d[index] = d[j];
      d[j] = t;
      _renumber();
      _dirty = true;
    });
  }

  void _toggleActive(int index, bool v) {
    setState(() {
      _draft![index] = _draft![index].copyWith(active: v);
      _dirty = true;
    });
  }

  void _remove(int index) {
    final item = _draft![index];
    // digger kodunu silmeyi engelleme — admin özgür; ama en az 1 aktif kalmalı
    setState(() {
      _draft!.removeAt(index);
      _renumber();
      _dirty = true;
    });
    if (mounted) {
      context.showInfo('“${item.label}” listeden çıkarıldı (henüz kaydetmediniz).');
    }
  }

  void _resetToDefaults() {
    setState(() {
      _draft = ProductCategoryCatalog.defaults.items
          .map((e) => e.copyWith())
          .toList();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final canManage =
        ref.watch(adminCapabilitiesProvider).allows('config.manage');
    final async = ref.watch(adminProductCategoriesProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Text(
        'Kategoriler okunamadı.',
        style: TextStyle(color: palette.danger),
      ),
      data: (catalog) {
        _ensureDraft(catalog);
        final d = _draft!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ürün kategorileri',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mağaza kurulum, ürün formu ve ürün talebi bu listeyi kullanır. '
              'Yeni kategori ekleyin; kod kayıtlarda kalır (değiştirmeyin). '
              'Kaydetmek için config.manage gerekir.',
              style: TextStyle(color: palette.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < d.length; i++) ...[
              Material(
                color: palette.card,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Yukarı',
                            onPressed: (!canManage || _busy || i == 0)
                                ? null
                                : () => _move(i, -1),
                            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Aşağı',
                            onPressed:
                                (!canManage || _busy || i == d.length - 1)
                                    ? null
                                    : () => _move(i, 1),
                            icon:
                                const Icon(Icons.keyboard_arrow_down, size: 20),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d[i].label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: d[i].active
                                    ? null
                                    : palette.inkMuted,
                              ),
                            ),
                            Text(
                              d[i].code,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.inkFaint,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: d[i].active,
                        onChanged: (!canManage || _busy)
                            ? null
                            : (v) => _toggleActive(i, v),
                      ),
                      IconButton(
                        tooltip: 'Etiketi düzenle',
                        onPressed:
                            (!canManage || _busy) ? null : () => _editLabel(i),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        onPressed:
                            (!canManage || _busy) ? null : () => _remove(i),
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: palette.danger),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: (!canManage || _busy) ? null : _addCategory,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Kategori ekle'),
                ),
                OutlinedButton.icon(
                  onPressed: (!canManage || _busy) ? null : _resetToDefaults,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Varsayılana dön'),
                ),
                FilledButton.icon(
                  onPressed: (!canManage || _busy || !_dirty) ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_dirty ? 'Kategorileri kaydet' : 'Kaydedildi'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Not: Kodu değiştirmek mevcut ürün/mağaza kayıtlarını bozar. '
              'Pasif kategori yeni seçimde görünmez; eski kayıtlarda etiket '
              'görünmeye devam eder.',
              style: TextStyle(color: palette.inkFaint, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _NewCat {
  const _NewCat({required this.code, required this.label});
  final String code;
  final String label;
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _label = TextEditingController();
  final _code = TextEditingController();
  bool _codeTouched = false;

  @override
  void dispose() {
    _label.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni ürün kategorisi'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Görünen ad',
                hintText: 'örn. Ahşap Malzeme',
              ),
              onChanged: (v) {
                if (!_codeTouched) {
                  _code.text = ProductCategory.codeFromLabel(v);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Kod (değişmez kimlik)',
                hintText: 'ahsap_malzeme',
                helperText: 'Küçük harf, rakam, alt çizgi',
              ),
              onChanged: (_) => _codeTouched = true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            final code = _code.text.trim();
            if (label.isEmpty) return;
            if (!ProductCategory.isValidCode(code)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Kod a-z ile başlamalı; a-z, 0-9, _ (2–40 karakter).',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, _NewCat(code: code, label: label));
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

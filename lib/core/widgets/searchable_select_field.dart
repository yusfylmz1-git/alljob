import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../utils/search_fold.dart';

/// Sheet sonucu: seçim veya "Tümü" (temizle). Dismiss → null.
class _SelectOutcome<T> {
  const _SelectOutcome._({this.value, this.cleared = false});
  const _SelectOutcome.value(T v) : this._(value: v);
  const _SelectOutcome.clear() : this._(cleared: true);

  final T? value;
  final bool cleared;
}

/// Gruplanmış listede başlık satırını işaretler.
///
/// Satır listesi `Object?` taşır: `null` → "Tümü", [_GroupHeader] → başlık,
/// diğer her şey → öğe. Ayrı bir tip olması `is` ile güvenli ayırt etmeyi
/// sağlar; öğe tipi T rastgele olabileceğinden String kullanılamaz.
class _GroupHeader {
  const _GroupHeader(this.label);
  final String label;
}

/// Dokununca alt sayfada arama + liste açan tek seçimli alan.
///
/// Uzun listeler (meslek, il, ilçe) için klasik Dropdown yerine kullanılır.
/// [allowClear] true ise listede "Tümü" satırı çıkar (filtre yok).
class SearchableSelectField<T> extends StatelessWidget {
  const SearchableSelectField({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.value,
    this.hint = 'Seçin',
    this.searchHint = 'Ara…',
    this.prefixIcon,
    this.enabled = true,
    this.emptyMessage = 'Sonuç bulunamadı',
    this.equals,
    this.allowClear = false,
    this.clearLabel = 'Tümü',
    this.onClear,
    this.highlight = false,
    this.groupLabel,
  });

  /// Verilirse liste bu etikete göre gruplanır (uzun listelerde tarama
  /// kolaylığı). Öğelerin ZATEN gruba göre sıralı gelmesi beklenir.
  final String Function(T)? groupLabel;

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;
  final String hint;
  final String searchHint;
  final IconData? prefixIcon;
  final bool enabled;
  final String emptyMessage;

  /// Örn. Province id ile eşleştirme (yeniden yüklenen listelerde `==` yetmez).
  final bool Function(T a, T b)? equals;

  /// true → sheet'te [clearLabel] satırı; seçilince [onClear] (yoksa no-op).
  final bool allowClear;
  final String clearLabel;
  final VoidCallback? onClear;

  /// Sıradaki adım bu alan mı? true ise kenarlık vurgulanır — kullanıcı
  /// nereye dokunacağını arar (B-09: "il seçtim, sonra ne olacak?").
  final bool highlight;

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    if (items.isEmpty && !allowClear) return;
    // B-09: Başka bir alanda klavye açıkken bu sheet açılırsa klavye açık
    // kalır ve gövde yukarı kayar ("il seçince ekran yukarı kayıyor").
    // Seçim alanı metin girişi değil — odağı bırak.
    FocusManager.instance.primaryFocus?.unfocus();
    final outcome = await showModalBottomSheet<_SelectOutcome<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _SearchableSelectSheet<T>(
        title: label,
        items: items,
        itemLabel: itemLabel,
        selected: value,
        searchHint: searchHint,
        emptyMessage: emptyMessage,
        equals: equals,
        allowClear: allowClear,
        clearLabel: clearLabel,
        groupLabel: groupLabel,
      ),
    );
    if (outcome == null) return;
    if (outcome.cleared) {
      onClear?.call();
      return;
    }
    final v = outcome.value;
    if (v != null) onSelected(v);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final selectedText = value == null ? null : itemLabel(value as T);
    final display = selectedText ?? (allowClear ? clearLabel : hint);
    // isEmpty:true iken label ile child (Seçin) aynı yere biner → label
    // her zaman yukarıda (always), içerik her zaman satırda.
    final hasValue = selectedText != null;

    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: highlight ? palette.primary : null),
          suffixIcon: Icon(
            Icons.expand_more_rounded,
            color: highlight
                ? palette.primary
                : (enabled ? palette.inkMuted : palette.inkFaint),
          ),
          enabled: enabled,
          // Sıradaki adımsa kenarlık vurgulanır (B-09).
          enabledBorder: highlight
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: palette.primary, width: 1.6),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: !hasValue
                ? theme.hintColor
                : (enabled
                    ? theme.colorScheme.onSurface
                    : theme.disabledColor),
          ),
        ),
      ),
    );
  }
}

class _SearchableSelectSheet<T> extends StatefulWidget {
  const _SearchableSelectSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.selected,
    required this.searchHint,
    required this.emptyMessage,
    this.equals,
    this.allowClear = false,
    this.clearLabel = 'Tümü',
    this.groupLabel,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? selected;
  final String searchHint;
  final String emptyMessage;
  final bool Function(T a, T b)? equals;
  final bool allowClear;
  final String clearLabel;

  /// Verilirse liste bu etikete göre GRUPLANIR ve araya başlık satırı girer.
  /// Uzun listelerde (144 meslek) tarama yapılabilir olmasını sağlar.
  /// Arama yazılırken gruplama KAPANIR — sonuç zaten daralmıştır, başlık
  /// gürültü olur.
  final String Function(T)? groupLabel;

  @override
  State<_SearchableSelectSheet<T>> createState() =>
      _SearchableSelectSheetState<T>();
}

class _SearchableSelectSheetState<T> extends State<_SearchableSelectSheet<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final q = _query.text;
    // Arama HEM öğe adına HEM grup başlığına bakar (2026-08-10): kullanıcı
    // "İnşaat" yazınca o kategorinin altındaki tüm meslekler listelenmeli.
    // Yalnız ada bakılsaydı kategori adı yazmak sıfır sonuç verirdi — oysa
    // başlıklar ekranda görünüyor, aranabilir olmaları beklenir.
    final grupAdi = widget.groupLabel;
    final filtered = widget.items
        .where((e) =>
            matchesTrSearch(widget.itemLabel(e), q) ||
            (grupAdi != null && matchesTrSearch(grupAdi(e), q)))
        .toList(growable: false);
    final h = MediaQuery.sizeOf(context).height * 0.72;
    final showClear = widget.allowClear && q.trim().isEmpty;

    // Satır listesi: başlık (String) ve öğe (T) karışık. Index aritmetiği
    // yerine açık liste — gruplama eklenince "i - 1" hesabı kırılgan olurdu.
    final rows = <Object?>[
      if (showClear) null, // "Tümü" satırı
    ];
    final grup = widget.groupLabel;
    // Arama METİN eşleşmesiyse gruplama kapalı: sonuç zaten daraldı, başlık
    // gürültü olur. Ama kullanıcı KATEGORİ adı yazdıysa başlıklar kalır —
    // "tesisat" gibi bir kelime birden fazla kategoriye değebilir ve
    // sonucun neden geldiğini başlık açıklar.
    final kategoriAramasi = grup != null &&
        q.trim().isNotEmpty &&
        filtered.any((e) => matchesTrSearch(grup(e), q));
    if (grup == null || (q.trim().isNotEmpty && !kategoriAramasi)) {
      rows.addAll(filtered);
    } else {
      String? sonGrup;
      for (final e in filtered) {
        final g = grup(e);
        if (g != sonGrup) {
          rows.add(_GroupHeader(g));
          sonGrup = g;
        }
        rows.add(e);
      }
    }
    final totalRows = rows.length;

    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              // autofocus KAPALI: sheet açılır açılmaz klavye fırlıyordu ve
              // liste yarı yarıya kapanıyordu. İl/ilçe gibi kısa listelerde
              // kullanıcı çoğunlukla yazmadan seçiyor — klavye ancak arama
              // kutusuna dokununca açılmalı.
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              q.trim().isEmpty
                  ? '${widget.items.length} seçenek'
                  : '${filtered.length} sonuç',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: palette.inkMuted),
            ),
          ),
          Expanded(
            child: totalRows == 0
                ? Center(
                    child: Text(
                      widget.emptyMessage,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: totalRows,
                    separatorBuilder: (_, i) {
                      // Başlığın ÜSTÜNE çizgi çizme: grup zaten ayırıyor.
                      final sonraki = i + 1 < rows.length ? rows[i + 1] : null;
                      if (sonraki is _GroupHeader) {
                        return const SizedBox.shrink();
                      }
                      return Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: palette.border.withValues(alpha: 0.7),
                      );
                    },
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is _GroupHeader) {
                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 18, 16, 6),
                          child: Text(
                            row.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.inkMuted,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        );
                      }
                      if (showClear && i == 0) {
                        final isOn = widget.selected == null;
                        return ListTile(
                          leading: Icon(
                            isOn
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: isOn ? palette.primary : palette.inkFaint,
                          ),
                          title: Text(
                            widget.clearLabel,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Filtre uygulama',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: palette.inkMuted),
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            const _SelectOutcome.clear(),
                          ),
                        );
                      }
                      final item = row as T;
                      final label = widget.itemLabel(item);
                      final sel = widget.selected;
                      final isOn = sel != null &&
                          (widget.equals?.call(sel, item) ?? sel == item);
                      return ListTile(
                        title: Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                isOn ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        trailing: isOn
                            ? Icon(Icons.check_circle_rounded,
                                color: palette.primary)
                            : null,
                        onTap: () => Navigator.pop(
                          context,
                          _SelectOutcome.value(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

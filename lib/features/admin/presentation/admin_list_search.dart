import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Liste üstü arama kutusu (yüklü satırlar + tam eşleşme araması için ortak).
class AdminListSearchBar extends StatelessWidget {
  const AdminListSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.label = 'Ara',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            hintText: hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                      onChanged?.call('');
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

/// Küçük harf, Türkçe duyarsız basit içerir araması.
bool adminTextMatch(String? haystack, String query) {
  final q = _fold(query);
  if (q.isEmpty) return true;
  return _fold(haystack ?? '').contains(q);
}

bool adminAnyMatch(Iterable<String?> fields, String query) {
  final q = _fold(query);
  if (q.isEmpty) return true;
  for (final f in fields) {
    if (_fold(f ?? '').contains(q)) return true;
  }
  return false;
}

String _fold(String s) {
  return s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

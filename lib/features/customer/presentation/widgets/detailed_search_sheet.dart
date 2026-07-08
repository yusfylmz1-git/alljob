import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/local_data_service.dart';
import '../../../../data/models/geo_models.dart';
import '../../../../data/models/profession.dart';
import '../../application/artisan_search_controller.dart';

/// Detaylı arama panelini açılır pencere (bottom sheet) olarak gösterir.
/// "Usta Bul" basılınca kapanır ve aramayı tetikler.
Future<void> showDetailedSearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _DetailedSearchSheet(),
  );
}

class _DetailedSearchSheet extends ConsumerWidget {
  const _DetailedSearchSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(customerFilterProvider);
    final notifier = ref.read(customerFilterProvider.notifier);
    final provincesAsync = ref.watch(provincesProvider);
    final professionsAsync = ref.watch(professionsProvider);
    final theme = Theme.of(context);

    final provinceField = provincesAsync.when(
      loading: () => const _DropdownSkeleton(label: 'İl'),
      error: (_, _) => const Text('İl verisi yüklenemedi'),
      data: (provinces) => _AllOrOneDropdown<Province>(
        label: 'İl',
        icon: Icons.location_city_outlined,
        value: filter.province,
        items: provinces,
        itemLabel: (p) => p.name,
        onChanged: (p) {
          notifier.setProvince(p);
          // İl değişince ilçe "Tümü"ye döner (tutarsız seçim önlenir).
          notifier.setDistrict(null);
        },
      ),
    );

    final districtField = filter.province == null
        ? const _AllOrOneDropdown<District>(
            label: 'İlçe',
            icon: Icons.map_outlined,
            value: null,
            items: [],
            itemLabel: _districtLabel,
            onChanged: null,
          )
        : ref.watch(districtsProvider(filter.province!.id)).when(
              loading: () => const _DropdownSkeleton(label: 'İlçe'),
              error: (_, _) => const Text('İlçe verisi yüklenemedi'),
              data: (districts) => _AllOrOneDropdown<District>(
                label: 'İlçe',
                icon: Icons.map_outlined,
                value: filter.district,
                items: districts,
                itemLabel: (d) => d.name,
                onChanged: notifier.setDistrict,
              ),
            );

    final professionField = professionsAsync.when(
      loading: () => const _DropdownSkeleton(label: 'Meslek'),
      error: (_, _) => const Text('Meslek verisi yüklenemedi'),
      data: (professions) => _AllOrOneDropdown<Profession>(
        label: 'Meslek',
        icon: Icons.handyman_outlined,
        value: _professionByCode(professions, filter.profession),
        items: professions,
        itemLabel: (p) => p.nameTR,
        onChanged: (p) => notifier.setProfession(p?.code),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Detaylı Arama',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ref.read(customerFilterProvider.notifier).clearSelections();
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hiçbir alan zorunlu değildir — "Tümü" bırakılan alanlar '
            'aramayı daraltmaz.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          provinceField,
          const SizedBox(height: 12),
          districtField,
          const SizedBox(height: 12),
          professionField,
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.search_rounded),
            label: const Text('Usta Bul'),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(artisanSearchControllerProvider.notifier).search();
            },
          ),
        ],
      ),
    );
  }

  static String _districtLabel(District d) => d.name;

  static Profession? _professionByCode(List<Profession> list, String? code) {
    if (code == null) return null;
    for (final p in list) {
      if (p.code == code) return p;
    }
    return null;
  }
}

/// Başında "Tümü" (null) seçeneği bulunan dropdown — null değer "filtre yok"
/// anlamına gelir (il ve ilçeye Tümü seçeneği, #6).
class _AllOrOneDropdown<T> extends StatelessWidget {
  const _AllOrOneDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T?>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      items: [
        DropdownMenuItem<T?>(value: null, child: const Text('Tümü')),
        ...items.map((e) => DropdownMenuItem<T?>(
              value: e,
              child: Text(itemLabel(e), overflow: TextOverflow.ellipsis),
            )),
      ],
      // Kapalıyken (onChanged == null) bile "Tümü" yazsın.
      disabledHint: const Text('Tümü'),
      hint: const Text('Tümü'),
      onChanged: onChanged,
    );
  }
}

class _DropdownSkeleton extends StatelessWidget {
  const _DropdownSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/searchable_select_field.dart';
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
      data: (provinces) => SearchableSelectField<Province>(
        label: 'İl',
        value: filter.province,
        items: provinces,
        itemLabel: (p) => p.name,
        searchHint: 'İl ara…',
        prefixIcon: Icons.location_city_outlined,
        allowClear: true,
        clearLabel: 'Tümü',
        equals: (a, b) => a.id == b.id,
        onSelected: (p) {
          notifier.setProvince(p);
          // İl değişince ilçe "Tümü"ye döner (tutarsız seçim önlenir).
          notifier.setDistrict(null);
        },
        onClear: () {
          notifier.setProvince(null);
          notifier.setDistrict(null);
        },
      ),
    );

    final districtField = filter.province == null
        ? SearchableSelectField<District>(
            label: 'İlçe',
            value: null,
            items: const [],
            itemLabel: (d) => d.name,
            prefixIcon: Icons.map_outlined,
            enabled: false,
            allowClear: true,
            clearLabel: 'Tümü',
            hint: 'Önce il seçin',
            onSelected: (_) {},
          )
        : ref.watch(districtsProvider(filter.province!.id)).when(
              loading: () => const _DropdownSkeleton(label: 'İlçe'),
              error: (_, _) => const Text('İlçe verisi yüklenemedi'),
              data: (districts) => SearchableSelectField<District>(
                label: 'İlçe',
                value: filter.district,
                items: districts,
                itemLabel: (d) => d.name,
                searchHint: 'İlçe ara…',
                prefixIcon: Icons.map_outlined,
                allowClear: true,
                clearLabel: 'Tümü',
                equals: (a, b) => a.id == b.id,
                onSelected: notifier.setDistrict,
                onClear: () => notifier.setDistrict(null),
              ),
            );

    final professionField = professionsAsync.when(
      loading: () => const _DropdownSkeleton(label: 'Meslek'),
      error: (_, _) => const Text('Meslek verisi yüklenemedi'),
      data: (professions) => SearchableSelectField<Profession>(
        label: 'Meslek',
        value: _professionByCode(professions, filter.profession),
        items: professions,
        itemLabel: (p) => p.nameTR,
        searchHint: 'Meslek ara (örn. elektrik…)',
        prefixIcon: Icons.handyman_outlined,
        allowClear: true,
        clearLabel: 'Tümü',
        equals: (a, b) => a.code == b.code,
        onSelected: (p) => notifier.setProfession(p.code),
        onClear: () => notifier.setProfession(null),
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
            'aramayı daraltmaz. Listelerde yazarak arayabilirsiniz.',
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

  static Profession? _professionByCode(List<Profession> list, String? code) {
    if (code == null) return null;
    for (final p in list) {
      if (p.code == code) return p;
    }
    return null;
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

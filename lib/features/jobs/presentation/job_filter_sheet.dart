import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import 'job_explore_filter.dart';

/// Detaylı iş ilanı filtresi (il / ilçe).
Future<JobExploreFilter?> showJobFilterSheet(
  BuildContext context, {
  required JobExploreFilter initial,
}) {
  return showModalBottomSheet<JobExploreFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _JobFilterSheet(initial: initial),
  );
}

class _JobFilterSheet extends ConsumerStatefulWidget {
  const _JobFilterSheet({required this.initial});
  final JobExploreFilter initial;

  @override
  ConsumerState<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends ConsumerState<_JobFilterSheet> {
  Province? _province;
  District? _district;
  bool _geoSeeded = false;

  Future<void> _seedGeo(List<Province> provinces) async {
    if (_geoSeeded) return;
    _geoSeeded = true;
    final pName = widget.initial.province;
    if (pName == null || pName.isEmpty) return;
    Province? p;
    for (final x in provinces) {
      if (x.name == pName) {
        p = x;
        break;
      }
    }
    if (p == null) return;
    _province = p;
    final dName = widget.initial.district;
    if (dName != null && dName.isNotEmpty) {
      final districts =
          await ref.read(localDataServiceProvider).getDistricts(p.id);
      for (final d in districts) {
        if (d.name == dName) {
          _district = d;
          break;
        }
      }
    }
    if (mounted) setState(() {});
  }

  JobExploreFilter _buildResult() => JobExploreFilter(
        query: widget.initial.query,
        province: _province?.name,
        district: _district?.name,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final provincesAsync = ref.watch(provincesProvider);

    if (!_geoSeeded && provincesAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provincesAsync.value != null) {
          _seedGeo(provincesAsync.value!);
        }
      });
    }

    final provinceField = provincesAsync.when(
      loading: () => const _DropdownSkeleton(label: 'İl'),
      error: (_, _) => const Text('İl verisi yüklenemedi'),
      data: (provinces) => SearchableSelectField<Province>(
        label: 'İl',
        value: _province,
        items: provinces,
        itemLabel: (p) => p.name,
        searchHint: 'İl ara…',
        prefixIcon: Icons.location_city_outlined,
        allowClear: true,
        clearLabel: 'Tümü',
        equals: (a, b) => a.id == b.id,
        onSelected: (p) => setState(() {
          _province = p;
          _district = null;
        }),
        onClear: () => setState(() {
          _province = null;
          _district = null;
        }),
      ),
    );

    final districtField = _province == null
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
        : ref.watch(districtsProvider(_province!.id)).when(
              loading: () => const _DropdownSkeleton(label: 'İlçe'),
              error: (_, _) => const Text('İlçe verisi yüklenemedi'),
              data: (districts) => SearchableSelectField<District>(
                label: 'İlçe',
                value: _district,
                items: districts,
                itemLabel: (d) => d.name,
                searchHint: 'İlçe ara…',
                prefixIcon: Icons.map_outlined,
                allowClear: true,
                clearLabel: 'Tümü',
                equals: (a, b) => a.id == b.id,
                onSelected: (d) => setState(() => _district = d),
                onClear: () => setState(() => _district = null),
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
              Text(
                'İlan Filtrele',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _province = null;
                  _district = null;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'İl ve ilçe isteğe bağlıdır. Boş bırakılanlar listeyi daraltmaz.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: 16),
          provinceField,
          const SizedBox(height: 12),
          districtField,
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Uygula'),
            onPressed: () => Navigator.of(context).pop(_buildResult()),
          ),
        ],
      ),
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

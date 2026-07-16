import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/staffing.dart';
import 'worker_search_filter.dart';

Future<WorkerSearchFilter?> showWorkerDetailedSearchSheet(
  BuildContext context, {
  required WorkerSearchFilter initial,
}) {
  return showModalBottomSheet<WorkerSearchFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _WorkerDetailedSearchSheet(initial: initial),
  );
}

class _WorkerDetailedSearchSheet extends ConsumerStatefulWidget {
  const _WorkerDetailedSearchSheet({required this.initial});
  final WorkerSearchFilter initial;

  @override
  ConsumerState<_WorkerDetailedSearchSheet> createState() =>
      _WorkerDetailedSearchSheetState();
}

class _WorkerDetailedSearchSheetState
    extends ConsumerState<_WorkerDetailedSearchSheet> {
  late StaffRateType? _rateType;
  late bool _dailyOnly;
  Province? _province;
  District? _district;
  bool _geoSeeded = false;

  @override
  void initState() {
    super.initState();
    _rateType = widget.initial.rateType;
    _dailyOnly = widget.initial.dailyOnly;
  }

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
      loading: () => const LinearProgressIndicator(minHeight: 2),
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
              loading: () => const LinearProgressIndicator(minHeight: 2),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Detaylı arama',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _rateType = null;
                    _dailyOnly = false;
                    _province = null;
                    _district = null;
                  }),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            Text(
              'İl, ilçe, ücret ve gündelik eleman seçenekleri.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 14),
            provinceField,
            const SizedBox(height: 12),
            districtField,
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gündelik eleman'),
              subtitle: const Text(
                  'Yalnız gündelik işe açık profilleri göster'),
              value: _dailyOnly,
              onChanged: (v) => setState(() => _dailyOnly = v),
            ),
            const SizedBox(height: 8),
            Text('Ücret tipi', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _rateType == null,
                  onSelected: (_) => setState(() => _rateType = null),
                ),
                for (final r in StaffRateType.values)
                  ChoiceChip(
                    label: Text(r.labelTR),
                    selected: _rateType == r,
                    onSelected: (_) => setState(() => _rateType = r),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  WorkerSearchFilter(
                    province: _province?.name,
                    district: _district?.name,
                    rateType: _rateType,
                    dailyOnly: _dailyOnly,
                    query: widget.initial.query,
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Sonuçları göster'),
            ),
          ],
        ),
      ),
    );
  }
}

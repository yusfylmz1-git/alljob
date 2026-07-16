import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import 'need_search_filter.dart';

Future<NeedSearchFilter?> showNeedDetailedSearchSheet(
  BuildContext context, {
  required NeedSearchFilter initial,
}) {
  return showModalBottomSheet<NeedSearchFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NeedDetailedSearchSheet(initial: initial),
  );
}

class _NeedDetailedSearchSheet extends ConsumerStatefulWidget {
  const _NeedDetailedSearchSheet({required this.initial});
  final NeedSearchFilter initial;

  @override
  ConsumerState<_NeedDetailedSearchSheet> createState() =>
      _NeedDetailedSearchSheetState();
}

class _NeedDetailedSearchSheetState
    extends ConsumerState<_NeedDetailedSearchSheet> {
  late bool _dailyOnly;
  Province? _province;
  District? _district;
  bool _geoSeeded = false;

  @override
  void initState() {
    super.initState();
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
                    _dailyOnly = false;
                    _province = null;
                    _district = null;
                  }),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            Text(
              'Eleman ilanlarını il, ilçe ve gündelik seçeneğine göre süzün.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 14),
            provinceField,
            const SizedBox(height: 12),
            districtField,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gündelik eleman arayışı'),
              subtitle: const Text('Yalnız gündelik ilanları göster'),
              value: _dailyOnly,
              onChanged: (v) => setState(() => _dailyOnly = v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  NeedSearchFilter(
                    province: _province?.name,
                    district: _district?.name,
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

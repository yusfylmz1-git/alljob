import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';

/// İl + ilçe: arama yapılabilir açılır liste (serbest metin yok).
class StaffingLocationFields extends ConsumerWidget {
  const StaffingLocationFields({
    super.key,
    required this.province,
    required this.district,
    required this.onProvince,
    required this.onDistrict,
    this.showError = false,
  });

  final Province? province;
  final District? district;
  final ValueChanged<Province?> onProvince;
  final ValueChanged<District?> onDistrict;
  /// Form kaydında seçim yoksa kırmızı uyarı metni.
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final provincesAsync = ref.watch(provincesProvider);

    final provinceField = provincesAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) => Text(
        'İl listesi yüklenemedi. Bağlantınızı kontrol edip sayfayı yenileyin.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
      data: (provinces) => SearchableSelectField<Province>(
        label: 'İl',
        value: province,
        items: provinces,
        itemLabel: (p) => p.name,
        searchHint: 'İl ara…',
        prefixIcon: Icons.location_city_outlined,
        allowClear: false,
        equals: (a, b) => a.id == b.id,
        onSelected: (p) {
          onProvince(p);
          onDistrict(null); // il değişince ilçe sıfır
        },
      ),
    );

    final districtField = province == null
        ? SearchableSelectField<District>(
            label: 'İlçe',
            value: null,
            items: const [],
            itemLabel: (d) => d.name,
            prefixIcon: Icons.map_outlined,
            enabled: false,
            allowClear: false,
            hint: 'Önce il seçin',
            onSelected: (_) {},
          )
        : ref.watch(districtsProvider(province!.id)).when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => Text(
                'İlçe listesi yüklenemedi.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              data: (districts) => SearchableSelectField<District>(
                label: 'İlçe',
                value: district,
                items: districts,
                itemLabel: (d) => d.name,
                searchHint: 'İlçe ara…',
                prefixIcon: Icons.map_outlined,
                allowClear: false,
                equals: (a, b) => a.id == b.id,
                onSelected: onDistrict,
              ),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        provinceField,
        const SizedBox(height: 12),
        districtField,
        if (showError && (province == null || district == null)) ...[
          const SizedBox(height: 8),
          Text(
            province == null
                ? 'Lütfen listeden il seçin.'
                : 'Lütfen listeden ilçe seçin.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// Kayıtlı isimlerden Province/District çözümler (mevcut profili doldurmak için).
Future<({Province? province, District? district})> resolveStaffLocation({
  required LocalDataService data,
  required String? provinceName,
  required String? districtName,
}) async {
  if (provinceName == null || provinceName.isEmpty) {
    return (province: null, district: null);
  }
  final provinces = await data.getProvinces();
  Province? p;
  for (final x in provinces) {
    if (x.name == provinceName) {
      p = x;
      break;
    }
  }
  if (p == null) return (province: null, district: null);
  if (districtName == null || districtName.isEmpty) {
    return (province: p, district: null);
  }
  final districts = await data.getDistricts(p.id);
  District? d;
  for (final x in districts) {
    if (x.name == districtName) {
      d = x;
      break;
    }
  }
  return (province: p, district: d);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/geo_models.dart';

/// Admin ekranlarında meslek ve il seçimi (2026-08-23).
///
/// ── NEDEN VAR ──
///
/// Dört ekranda meslek/il **düz metin kutusuyla** isteniyordu:
/// bildirim (meslek + il), ilanlar (il), usta vitrini (meslek).
/// Yönetici `painter` yazmak zorundaydı — ama katalogda **145 meslek** var
/// ve hiçbiri ekranda görünmüyordu.
///
/// Daha kötüsü: yanlış yazım **hata vermiyordu**. Sunucu "alıcı bulunamadı"
/// diyor, yönetici sebebini bilmiyordu. Bir duyurunun kimseye gitmemesi ile
/// meslek kodunu yanlış yazmak aynı ekrana düşüyordu.
///
/// ── NEDEN ORTAK DOSYA ──
///
/// Dört ekranda ayrı ayrı yazılsaydı biri güncellenip diğerleri unutulurdu.
/// Katalog tek yerden okunur; yeni meslek eklenince dört ekran da görür.

/// Meslek kodu seçici — arama yapılabilir, 145 madde.
///
/// Değer olarak **kodu** tutar (`painter`), ekranda **adı** gösterir
/// (`Boyacı`). Sunucuya giden şey koddur; kullanıcı kodu hiç görmez.
///
/// [allowClear] true ise "Tümü" satırı çıkar — filtre alanlarında gerekli,
/// hedef seçiminde değil (kimseye gitmeyen duyuru anlamsız).
class AdminProfessionPicker extends StatelessWidget {
  const AdminProfessionPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Meslek',
    this.enabled = true,
    this.allowClear = false,
  });

  /// Seçili meslek KODU (`painter`), seçim yoksa null.
  final String? value;

  /// Yeni kod; "Tümü" seçilirse null.
  final ValueChanged<String?> onChanged;

  final String label;
  final bool enabled;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    // Ada göre sıralı: yönetici "Boyacı"yı B'de arar, `painter`ı p'de değil.
    final kodlar = kProfessionNames.keys.toList()
      ..sort((a, b) => (kProfessionNames[a] ?? a)
          .compareTo(kProfessionNames[b] ?? b));

    return SearchableSelectField<String>(
      label: label,
      value: value,
      items: kodlar,
      // Kodu da yaz: yönetici denetim kaydında ham kodu görecek ve iki
      // gösterimi eşleştirebilmeli.
      itemLabel: (k) => '${kProfessionNames[k] ?? k}  ·  $k',
      searchHint: 'Meslek ara…',
      prefixIcon: Icons.handyman_outlined,
      enabled: enabled,
      allowClear: allowClear,
      onClear: () => onChanged(null),
      onSelected: onChanged,
    );
  }
}

/// İl seçici — `local_data_service` kataloğundan.
///
/// Değer **il ADI** (`Bursa`) tutar; sorgular il adıyla çalışıyor
/// (`serviceAreas.province`, `jobs.province`). Id'ye çevirmek gereksiz bir
/// dönüşüm katmanı olurdu.
class AdminProvincePicker extends ConsumerWidget {
  const AdminProvincePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'İl',
    this.enabled = true,
    this.allowClear = false,
  });

  /// Seçili il ADI (`Bursa`), seçim yoksa null.
  final String? value;

  /// Yeni il adı; "Tümü" seçilirse null.
  final ValueChanged<String?> onChanged;

  final String label;
  final bool enabled;
  final bool allowClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provincesProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('İl verisi yüklenemedi'),
          data: (iller) {
            // Gelen değer adla tutuluyor; listedeki nesneye eşle.
            final secili = value == null
                ? null
                : iller.where((p) => p.name == value).firstOrNull;
            return SearchableSelectField<Province>(
              label: label,
              value: secili,
              items: iller,
              itemLabel: (p) => p.name,
              searchHint: 'İl ara…',
              prefixIcon: Icons.map_outlined,
              enabled: enabled,
              equals: (a, b) => a.id == b.id,
              allowClear: allowClear,
              onClear: () => onChanged(null),
              onSelected: (p) => onChanged(p.name),
            );
          },
        );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/backend_config.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../admin/data/admin_stats_repository.dart';

/// Ana Sayfa platform istatistikleri (Üye / Usta / Aktif İş / Toplam İş).
/// Veri `adminStats/global` dokümanından okunur.
///
/// **Önemli:** Bu doküman şu an yalnız admin okuyabilir (firestore.rules). Genel
/// kullanıcıda okuma başarısızsa (permission-denied) ya da doküman/sayılar boşsa
/// bölüm **tamamen gizlenir** — sahte rakam gösterilmez (PRD kararı: "şimdi UI,
/// veri sonra"). Kural herkese açılınca (ya da genel bir istatistik dokümanı
/// eklenince) bu bölüm otomatik görünür olur.
final homeStatsProvider = FutureProvider<AdminStatsSnapshot?>((ref) async {
  if (!useFirebaseBackend) return null;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('adminStats')
        .doc('global')
        .get();
    final data = snap.data();
    if (data == null) return null;
    return AdminStatsSnapshot.fromMap(Map<String, dynamic>.from(data));
  } catch (_) {
    // Yetki yok / ağ hatası → bölüm gizlensin.
    return null;
  }
});

/// Tek istatistik hücresi verisi: ikon + değer + etiket + vurgu rengi.
typedef _Stat = (IconData icon, String label, int value, Color color);

class HomeStats extends ConsumerWidget {
  const HomeStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider).valueOrNull;
    // Veri yok veya tüm sayılar 0 ise bölümü hiç gösterme (boş alan bırakma).
    if (stats == null) return const SizedBox.shrink();
    final toplam = stats.artisansTotal +
        stats.usersTotal +
        stats.productsTotal +
        stats.jobsTotal;
    if (toplam <= 0) return const SizedBox.shrink();

    final palette = context.palette;

    // Yalnız gerçek verisi olan hücreler gösterilir (sahte rakam yok).
    final items = <_Stat>[
      (Icons.people_alt_rounded, 'Üye', stats.usersTotal, palette.info),
      (Icons.handyman_rounded, 'Usta', stats.artisansTotal, palette.primary),
      (Icons.inventory_2_rounded, 'Ürün', stats.productsTotal, palette.premium),
      (Icons.campaign_rounded, 'İş İlanı', stats.jobsOpen, palette.success),
    ].where((s) => s.$3 > 0).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final palette2 = context.palette;
    // Minimal: başlıksız, tek kompakt şerit — küçük ikon + sayı + etiket,
    // aralarında ince ayraç. Vitrinden çok "alt bilgi" gibi durur.
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: palette2.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette2.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 26, color: palette2.hairline),
            Expanded(child: _StatCell(items[i])),
          ],
        ],
      ),
    );
  }
}

/// Minimal istatistik hücresi: küçük renkli ikon + sayı (yan yana) + altında
/// küçük etiket. Tek satırlık kompakt şeridin bir gözü.
class _StatCell extends StatelessWidget {
  const _StatCell(this.stat);
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, value, color) = stat;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _kisaSayi(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

/// Büyük sayıları kısaltır: 12450 → "12,4B", 1240 → "1.240".
String _kisaSayi(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  }
  if (n >= 10000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')}B';
  }
  // Binlik ayracı (nokta).
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

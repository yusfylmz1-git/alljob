import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../data/admin_province_stats.dart';

/// İl panosu — hangi il Pro geçişine ne kadar yakın (2026-08-23).
///
/// NEREDE DURUYOR: ayrı bir sekme değil, **toplu plan ekranının içinde**.
/// Yönetici zaten orada il seçiyor; hangi ilin hazır olduğunu aynı ekranda
/// görmesi gerekir. Ayrı sekme yapmak menüyü şişirir ve iki ekran arasında
/// gidip gelme zorunluluğu doğururdu.
///
/// VERİ: `adminStats/provinces/items` — günlük `rebuildProvinceStats` yazar.
/// Canlı değil; tabloda son güncelleme saati gösterilir ki yönetici
/// baktığı sayının ne kadar taze olduğunu bilsin.
class AdminProvincePanel extends ConsumerWidget {
  const AdminProvincePanel({super.key, this.onSelect});

  /// İl satırına dokununca çağrılır — toplu plan formundaki il seçicisini
  /// doldurur. Yönetici tabloda gördüğü ili elle aramak zorunda kalmasın.
  final void Function(String il)? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final async = ref.watch(provinceStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('İl durumu', style: theme.textTheme.labelLarge),
            ),
            IconButton(
              tooltip: 'Yenile',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => ref.invalidate(provinceStatsProvider),
            ),
          ],
        ),
        Text(
          'Şu an müsait kullanıcı sayısı. Eşik ${ProvinceStat.threshold}. '
          'Sayım her gece 03:00\'te yenilenir.',
          style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => _Bilgi(
            renk: palette.danger,
            metin: 'İl istatistikleri okunamadı.',
          ),
          data: (iller) {
            if (iller.isEmpty) {
              return _Bilgi(
                renk: palette.inkMuted,
                metin: 'Henüz sayım yapılmadı. İlk sonuç bu gece 03:00\'te '
                    'oluşur.',
              );
            }
            return Column(
              children: [
                for (final il in iller)
                  _IlSatiri(stat: il, onTap: onSelect),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IlSatiri extends StatelessWidget {
  const _IlSatiri({required this.stat, this.onTap});

  final ProvinceStat stat;
  final void Function(String il)? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final faz = stat.phaseAt(DateTime.now());

    // Eşiğe ulaşan il vurgulanır: yöneticinin ilk aradığı bilgi bu.
    final vurgu = stat.reached;
    final renk = switch (faz) {
      ProvincePhase.countdown => palette.warning,
      ProvincePhase.offer => palette.primary,
      ProvincePhase.paid => palette.success,
      null => palette.inkMuted,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap == null ? null : () => onTap!(stat.province),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stat.province,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                vurgu ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (faz != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: renk.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              faz.labelTR,
                              style: TextStyle(
                                color: renk,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stat.progress,
                        minHeight: 5,
                        backgroundColor: palette.hairline,
                        valueColor: AlwaysStoppedAnimation(
                          vurgu ? palette.success : palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.availableCount}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    // Eşiğe ulaşmayanda kalan sayı daha kullanışlı;
                    // ulaşanda tarih.
                    stat.reached
                        ? _tarih(stat.thresholdReachedAt!)
                        : '${stat.remaining} kaldı',
                    style: TextStyle(color: palette.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _tarih(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.'
      '${t.month.toString().padLeft(2, '0')}.${t.year}';
}

class _Bilgi extends StatelessWidget {
  const _Bilgi({required this.renk, required this.metin});
  final Color renk;
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(metin, style: TextStyle(color: renk, fontSize: 13)),
      );
}

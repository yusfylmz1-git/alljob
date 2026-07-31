import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/job.dart' show kQuickSupportName;
import '../data/quick_support.dart';

/// Usta "Hemen Lazım" anahtarını ilk kez açınca bir kez gösterilir.
Future<void> showQuickSupportArtisanIntro(BuildContext context) async {
  final seen = await readQuickSupportArtisanIntroSeen();
  if (seen || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => const _QuickSupportArtisanIntro(),
  );
  await markQuickSupportArtisanIntroSeen();
}

class _QuickSupportArtisanIntro extends StatelessWidget {
  const _QuickSupportArtisanIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.warningSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.bolt_rounded, color: palette.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$kQuickSupportName nedir?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Kısa süreli yardıma ihtiyacı olan komşuların ilanlarını '
            'görürsünüz. Örnekler:',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: palette.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final line in const [
            'Market / bakkal alışverişi',
            'Odun, koli veya kısa mesafe yük taşıma',
            'Eczane, kargo, ATM gidiş-dönüş',
            'Kısa ev içi yardım (uzmanlık istemeyen)',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: palette.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.infoSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Bu ilanlar İLİNİZİN tamamından gelir; ilçenizdekiler listede '
              'önce görünür. Meslek seçiminizden bağımsızdır: mesleğiniz '
              'varsa onun ilanlarını da almaya devam edersiniz. '
              'İstediğiniz zaman profilinizden kapatabilirsiniz.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım, devam'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';

/// Ana Sayfa "Usta Araçları" — Usta Çantası'ndaki hesap araçlarına + Ajanda'ya
/// hızlı erişim. "Tümünü Gör" Usta Çantası hub'ına götürür.
class HomeTools extends StatelessWidget {
  const HomeTools({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = <_Tool>[
      _Tool(Icons.straighten_rounded, 'Ölç & Hesapla',
          RoutePaths.toolkitMeasure),
      _Tool(Icons.receipt_long_rounded, 'Teklif Oluştur',
          RoutePaths.toolkitQuote),
      _Tool(Icons.checklist_rounded, 'İş Takibi', RoutePaths.tracking),
      _Tool(Icons.event_note_rounded, 'Ajanda', RoutePaths.tracking),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Usta Araçları',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push(RoutePaths.toolkit),
              child: const Text('Tümünü Gör →'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < tools.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _ToolButton(tool: tools[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.label, this.rota);
  final IconData icon;
  final String label;
  final String rota;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(tool.rota),
        child: Container(
          // Sabit yükseklik → etiket 1 veya 2 satır olsa da tüm düğmeler eşit.
          height: 84,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, color: palette.primary, size: 24),
              const SizedBox(height: 6),
              // 2 satırlık sabit alan: 1 satırlık etiketler de aynı yeri kaplar.
              SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    tool.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

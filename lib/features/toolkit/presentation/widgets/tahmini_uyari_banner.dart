import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Usta Çantası'nda her ölçüm/sonuç ekranında gösterilen zorunlu uyarı
/// (PRD-007 kritik ilke). Tüm sonuçlar tahminidir; profesyonel iş için
/// fiziksel ölçü aletiyle doğrulama gerekir.
///
/// Tek bir yerde tutulur ki dil ve görünüm tüm araçlarda tutarlı olsun.
class TahminiUyariBanner extends StatelessWidget {
  const TahminiUyariBanner({super.key, this.compact = false});

  /// Dar kartlarda daha küçük yazı/padding ile göster.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: compact ? 18 : 20,
            color: palette.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tahmini ölçüm / tahmini ihtiyaçtır. Profesyonel uygulamalar '
              'için fiziksel ölçü aletiyle doğrulayın.',
              style: (compact
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

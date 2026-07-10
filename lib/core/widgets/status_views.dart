import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Uygulama genelinde TEK yükleme/hata durum dili.
///
/// Ekranlar kendi Center(CircularProgressIndicator())'ını veya ham hata
/// metnini (ör. "$e") çizmek yerine bunları kullanır — böylece her yükleme
/// ve her hata aynı profesyonel görünümü taşır. Yalnızca görsel bileşendir;
/// davranış (ne zaman gösterileceği) çağıran ekranda kalır.

/// Ortalanmış, sakin yükleme görünümü. [compact] bölüm içi kullanımlar için
/// daha küçük ve az boşluklu çizer (tam ekran yerine panel/liste içi).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label, this.compact = false});

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 22.0 : 28.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2.8),
            ),
            if (label != null) ...[
              const SizedBox(height: 14),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.palette.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ortalanmış, dostça hata görünümü: yumuşak zeminli ikon + başlık + açıklama.
/// Ham exception metni ASLA gösterilmez.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Bir sorun oluştu',
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: context.palette.inkMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.palette.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'tap_scale.dart';

/// Yükleme durumu yönetimi olan birincil buton.
/// `isLoading` true iken buton devre dışı kalır ve spinner gösterir —
/// böylece çift gönderim (double-submit) hataları önlenir.
/// Basılınca hafifçe yaylanır (TapScale) — uygulama genel "canlılık" dili.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget button = switch (variant) {
      AppButtonVariant.filled =>
        FilledButton(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.outlined =>
        OutlinedButton(onPressed: effectiveOnPressed, child: child),
      AppButtonVariant.tonal =>
        FilledButton.tonal(onPressed: effectiveOnPressed, child: child),
    };

    // Birincil CTA her zaman tam genişlik olsun (tema artık genişliği
    // sonsuz yapmıyor; genişliği burada garanti ediyoruz).
    return TapScale(
      enabled: effectiveOnPressed != null,
      child: SizedBox(width: double.infinity, child: button),
    );
  }
}

enum AppButtonVariant { filled, outlined, tonal }

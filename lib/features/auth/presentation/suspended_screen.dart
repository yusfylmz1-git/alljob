import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../application/auth_controller.dart';

/// Hesap yönetici tarafından askıya alındığında gösterilen engelleme kapısı.
/// Router, `user.suspended` iken tüm rotaları buraya yönlendirir; kullanıcı
/// yalnızca çıkış yapabilir. Askıya alma nedeni gizlilik için burada
/// gösterilmez (yalnız denetim kaydında tutulur); itiraz için destek yönlendirir.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 64, color: palette.danger),
                const SizedBox(height: 20),
                Text(
                  'Hesabınız askıya alındı',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Topluluk kurallarının ihlali nedeniyle hesabınız geçici '
                  'olarak kısıtlandı. Bu süre boyunca yeni ilan, teklif, mesaj '
                  've değerlendirme oluşturamazsınız.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  'İtirazınız için destek ekibiyle iletişime geçin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkFaint),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

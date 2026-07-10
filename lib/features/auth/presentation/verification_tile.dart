import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../application/auth_controller.dart';
import 'phone_verification_sheet.dart';

/// Telefon doğrulama durumu kartı — hem müşteri profilinde hem usta düzenleme
/// ekranında kullanılır. Doğrulanmışsa yeşil "doğrulanmış" göstergesi; değilse
/// "Telefonunu Doğrula" butonu ([PhoneVerificationSheet] açar).
///
/// [artisanContext] true iken metin "mavi tik" vurgusu yapar (usta ekranı).
class VerificationTile extends ConsumerWidget {
  const VerificationTile({super.key, this.artisanContext = false});

  final bool artisanContext;

  Future<void> _verify(BuildContext context, WidgetRef ref) async {
    final ok = await PhoneVerificationSheet.show(context);
    if (ok == true && context.mounted) {
      context.showSuccess(artisanContext
          ? 'Telefonun doğrulandı — mavi tik aktif! 🎉'
          : 'Telefonun doğrulandı. Hesabın artık doğrulanmış. 🎉');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final verified = user.phoneVerified;

    final palette = context.palette;
    if (verified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified, color: palette.verified),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artisanContext ? 'Doğrulanmış Usta' : 'Doğrulanmış Hesap',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    artisanContext
                        ? 'Profilinde mavi tik görünüyor.'
                        : 'Telefon numaran doğrulandı.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: palette.verified),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  artisanContext ? 'Mavi Tik Al' : 'Telefonunu Doğrula',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            artisanContext
                ? 'Telefonunu doğrula, profilinde mavi tik kazan. Doğrulanmış '
                    'ustalar müşterilerde daha güvenilir görünür.'
                : 'Telefon numaranı doğrulayarak hesabını güvene al ve '
                    'doğrulanmış rozeti kazan.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _verify(context, ref),
              icon: const Icon(Icons.sms_outlined, size: 18),
              label: const Text('Telefonu Doğrula'),
            ),
          ),
        ],
      ),
    );
  }
}

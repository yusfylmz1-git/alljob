import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/app_user.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// E-posta doğrulanmamışsa bottom sheet gösterir; doğrulanmışsa `true`.
///
/// [actionLabel]: "ilan vermek", "iletişime geçmek" gibi cümle parçası.
Future<bool> ensureEmailVerified(
  BuildContext context,
  WidgetRef ref, {
  required String actionLabel,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return false;
  if (user.emailVerified) return true;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final palette = context.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      color: palette.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'E-posta doğrulaması gerekli',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$actionLabel için e-posta adresinizi doğrulamanız gerekir.\n\n'
                '${user.email} adresine gelen bağlantıya tıklayın; ardından '
                'aşağıdan kontrol edin.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Doğrulama E-postasını Gönder'),
                  onPressed: () => Navigator.pop(ctx, 'send'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Bağlantıya Tıkladım — Kontrol Et'),
                  onPressed: () => Navigator.pop(ctx, 'check'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (action == null || !context.mounted) return false;

  final ctrl = ref.read(authControllerProvider.notifier);
  if (action == 'send') {
    final ok = await ctrl.sendEmailVerification();
    if (!context.mounted) return false;
    if (ok) {
      context.showSuccess(
          'Doğrulama bağlantısı ${user.email} adresine gönderildi.');
    } else {
      final err = ref.read(authControllerProvider).error;
      context.showError(err is AuthException
          ? err.message
          : 'Gönderilemedi. Bir süre sonra tekrar deneyin.');
    }
    return false;
  }

  final verified = await ctrl.checkEmailVerified();
  if (!context.mounted) return false;
  if (verified == true) {
    context.showSuccess('E-postanız doğrulandı! Devam edebilirsiniz.');
    return true;
  }
  if (verified == false) {
    context.showInfo(
        'Henüz doğrulanmamış. E-postadaki bağlantıya tıkladıktan sonra '
        'tekrar “Kontrol Et” deyin.');
  } else {
    context.showError('Kontrol edilemedi. Bağlantınızı kontrol edin.');
  }
  return false;
}

/// Profil menüsü için aynı akış (gönder / kontrol); dönüş değeri doğrulandı mı.
Future<void> showEmailVerificationSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  await ensureEmailVerified(context, ref, actionLabel: 'hesabınızı güvene almak');
}

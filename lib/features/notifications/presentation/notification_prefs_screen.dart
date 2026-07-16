import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notification_prefs.dart';

/// Profil → Bildirim tercihleri. Yalnız cihaz push'unu yönetir.
class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim tercihleri')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Tercihler yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted),
            ),
          ),
        ),
        data: (prefs) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Uygulama içi bildirim merkezi her zaman çalışır. '
              'Aşağıdakiler yalnız telefonunuza gelen push bildirimleridir.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(Icons.chat_bubble_outline,
                        color: palette.primary),
                    title: const Text('Sohbet mesajları'),
                    subtitle: const Text('Yeni mesaj geldiğinde'),
                    value: prefs.chat,
                    onChanged: (v) => _set(
                      context,
                      ref,
                      prefs.copyWith(chat: v),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.work_outline,
                        color: palette.info),
                    title: const Text('İş durumu'),
                    subtitle: const Text(
                        'Seçilme, tamamlama, anlaşmazlık, iptal'),
                    value: prefs.jobUpdates,
                    onChanged: (v) => _set(
                      context,
                      ref,
                      prefs.copyWith(jobUpdates: v),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.campaign_outlined,
                        color: palette.warning),
                    title: const Text('Yeni ilanlar'),
                    subtitle: const Text(
                        'Bölgene ve mesleğine uygun açık ilanlar (usta)'),
                    value: prefs.nearbyJobs,
                    onChanged: (v) => _set(
                      context,
                      ref,
                      prefs.copyWith(nearbyJobs: v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefs next,
  ) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      await ref.read(notificationPrefsRepositoryProvider).save(uid, next);
    } catch (_) {
      if (context.mounted) {
        context.showError('Kaydedilemedi, tekrar deneyin.');
      }
    }
  }
}

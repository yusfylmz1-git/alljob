import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/staffing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../data/staffing_providers.dart';

/// İşveren eleman kartını inceler ve sohbet başlatır (eleman başvurmaz).
class WorkerListingDetailScreen extends ConsumerWidget {
  const WorkerListingDetailScreen({super.key, required this.listingId});
  final String listingId;

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    StaffWorkerListing w,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(RoutePaths.login);
      return;
    }
    if (user.uid == w.uid) {
      context.showInfo('Bu sizin profiliniz.');
      return;
    }
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'elemanla iletişime geçmek',
    );
    if (!emailOk || !context.mounted) return;

    try {
      // Sohbet kimliği: işveren = customer tarafı, eleman = artisan tarafı
      // (mevcut deterministik chat şeması).
      final chatId = await ref.read(chatRepositoryProvider).startChat(
            customerUid: user.uid,
            customerName:
                user.displayName.isEmpty ? 'İşveren' : user.displayName,
            customerPhotoUrl: user.profilePhotoUrl,
            artisanUid: w.uid,
            artisanName: w.displayName,
            artisanPhotoUrl: w.photoUrl,
          );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        context.showError(
            'Sohbet açılamadı. E-posta doğrulamanızı kontrol edin.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future =
        ref.watch(staffingRepositoryProvider).getWorkerListing(listingId);
    final palette = context.palette;
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İşveren · Eleman profili',
        icon: Icons.person_outline,
      ),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          final w = snap.data;
          if (w == null || !w.openToWork) {
            return const ErrorView(
              title: 'Profil yok',
              message: 'Bu eleman artık aranmıyor veya kaldırılmış.',
            );
          }
          final isMine = me?.uid == w.uid;
          return ResponsiveCenter(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    AppAvatar(
                        name: w.displayName, photo: w.photoUrl, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.displayName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(w.professionLabel,
                              style: TextStyle(color: palette.inkMuted)),
                          Text(w.placeLabel,
                              style: TextStyle(
                                  fontSize: 13, color: palette.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(w.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(w.rateLabel)),
                    if (w.isDaily) const Chip(label: Text('Gündelik')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(w.about, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                if (!isMine)
                  FilledButton.icon(
                    onPressed: () => _contact(context, ref, w),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('İletişime Geç'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => context.push(RoutePaths.staffMyWorker),
                    child: const Text('Profilimi düzenle'),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Not: Eleman size başvurmaz; sohbeti işveren başlatır.',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

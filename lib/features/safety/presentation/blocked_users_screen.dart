import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/blocked_user.dart';
import '../../auth/application/auth_controller.dart';
import '../data/safety_providers.dart';

/// Engellenen kullanıcılar yönetim ekranı (Profil → Engellenen Kullanıcılar).
/// Engellenen kişi size mesaj yazamaz ve sohbetleriniz listenizde gizlenir;
/// buradan engel kaldırılabilir.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(myBlockedListProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Engellenen Kullanıcılar',
        icon: Icons.block_outlined,
      ),
      body: listAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
            message: 'Liste yüklenemedi. Bağlantınızı kontrol edip '
                'tekrar deneyin.'),
        data: (blocked) => blocked.isEmpty
            ? const _EmptyBlocked()
            : ResponsiveCenter(
                maxWidth: 720,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: blocked.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _BlockedTile(user: blocked[i]),
                ),
              ),
      ),
    );
  }
}

class _BlockedTile extends ConsumerWidget {
  const _BlockedTile({required this.user});
  final BlockedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: user.photoUrl != null
                  ? AppImage(handle: user.photoUrl)
                  : ColoredBox(
                      color: palette.surfaceMuted,
                      child: Center(
                        child: Text(
                          user.name.isEmpty
                              ? '?'
                              : user.name.characters.first.toUpperCase(),
                          style: TextStyle(
                              color: palette.inkMuted,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name.isEmpty ? 'Kullanıcı' : user.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${DateFormat('d MMM yyyy', 'tr_TR').format(user.blockedAt)} '
                  'tarihinde engellendi',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: palette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final uid = ref.read(currentUserProvider)?.uid;
              if (uid == null) return;
              await ref
                  .read(blockRepositoryProvider)
                  .unblock(uid: uid, otherUid: user.uid);
              if (context.mounted) {
                context.showInfo('Engel kaldırıldı.');
              }
            },
            child: const Text('Engeli Kaldır'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlocked extends StatelessWidget {
  const _EmptyBlocked();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: context.palette.surfaceMuted, shape: BoxShape.circle),
              child: Icon(Icons.block_outlined,
                  size: 34, color: context.palette.inkMuted),
            ),
            const SizedBox(height: 16),
            Text('Engellenen kullanıcı yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Bir kullanıcıyı sohbet ekranındaki menüden engelleyebilirsiniz. '
              'Engellenen kişi size mesaj gönderemez.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_providers.dart';

/// Sohbet listesi — müşteri ve usta için ortak (karşı tarafın adını gösterir).
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final threadsAsync = ref.watch(myThreadsProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Mesajlar',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      drawer: const AppMenuDrawer(),
      bottomNavigationBar: const MainBottomBar(current: MainTab.chats),
      body: threadsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mesajlar yüklenemedi.'),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        data: (threads) {
          if (user == null) return const SizedBox.shrink();
          if (threads.isEmpty) {
            return const _Empty();
          }
          final repo = ref.watch(chatRepositoryProvider);
          return ResponsiveCenter(
            maxWidth: 760,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, i) => _ThreadTile(
                thread: threads[i],
                myUid: user.uid,
                unread:
                    repo.unreadCount(chatId: threads[i].id, uid: user.uid),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile(
      {required this.thread, required this.myUid, this.unread = 0});
  final ChatThread thread;
  final String myUid;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = thread.otherName(myUid);
    final photo = thread.otherPhoto(myUid);
    final time = DateFormat('d MMM', 'tr_TR').format(thread.updatedAt);
    final hasUnread = unread > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        child: ClipOval(
          child: SizedBox(
            width: 52,
            height: 52,
            child: photo != null
                ? AppImage(handle: photo)
                : Center(
                    child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20))),
          ),
        ),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(thread.lastMessage ?? 'Sohbeti başlatın',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: hasUnread
              ? TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700)
              : null),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: hasUnread ? theme.colorScheme.primary : null)),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(unread > 99 ? '99+' : '$unread',
                  style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
      onTap: () => context.push(RoutePaths.chatThread(thread.id)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Henüz mesajın yok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Bir ustanın profilinden "Sohbet Başlat" diyerek yazışmaya başlayabilirsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

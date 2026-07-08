import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_providers.dart';

/// Sohbet listesi — müşteri ve usta için ortak (Instagram DM dili):
/// üstte arama kutusu, kompakt satırlar (ad + "mesaj · zaman"), okunmamışta
/// kalın metin + mavi nokta.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
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
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Mesajlar yüklenemedi. Lütfen tekrar deneyin.'),
          ),
        ),
        data: (threads) {
          if (user == null) return const SizedBox.shrink();
          if (threads.isEmpty) return const _Empty();

          final repo = ref.watch(chatRepositoryProvider);
          final q = _query.trim().toLowerCase();
          final visible = q.isEmpty
              ? threads
              : threads
                  .where(
                      (t) => t.otherName(user.uid).toLowerCase().contains(q))
                  .toList();

          return ResponsiveCenter(
            maxWidth: 760,
            child: Column(
              children: [
                // Arama (Instagram DM üstündeki gibi).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Ara',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      isDense: true,
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Eşleşen sohbet yok.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: visible.length,
                          itemBuilder: (context, i) => _ThreadTile(
                            thread: visible[i],
                            myUid: user.uid,
                            unread: repo.unreadCount(
                                chatId: visible[i].id, uid: user.uid),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Instagram DM satırı: avatar · (ad / mesaj · zaman) · mavi nokta.
class _ThreadTile extends StatelessWidget {
  const _ThreadTile(
      {required this.thread, required this.myUid, this.unread = 0});
  final ChatThread thread;
  final String myUid;
  final int unread;

  static String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return DateFormat('d MMM', 'tr_TR').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = thread.otherName(myUid);
    final photo = thread.otherPhoto(myUid);
    final hasUnread = unread > 0;
    final preview = thread.lastMessage ?? 'Sohbeti başlatın';

    return InkWell(
      onTap: () => context.push(RoutePaths.chatThread(thread.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo != null
                      ? AppImage(handle: photo)
                      : Center(
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20),
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
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$preview · ${_timeLabel(thread.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasUnread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 10),
              // Instagram'daki mavi okunmamış noktası.
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
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

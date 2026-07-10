import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_providers.dart';

/// Sohbet listesi — müşteri ve usta için ortak (Instagram DM dili):
/// üstte arama kutusu, kompakt satırlar (ad + "mesaj · zaman"), okunmamışta
/// kalın metin + mavi nokta. Üst bardaki çöp kutusuyla çoklu seçim modu:
/// seçilen sohbetler YALNIZCA bu kullanıcı için silinir (karşı taraf
/// etkilenmez; karşı taraf yazarsa sohbet boş olarak yeniden belirir).
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _query = '';
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selected.clear();
      });

  void _toggleSelected(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _deleteSelected(String uid) async {
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Sohbeti sil' : '$count sohbeti sil'),
        content: const Text(
            'Sohbet yalnızca sizin listenizden silinir; karşı taraf sohbeti '
            'görmeye devam eder. Karşı taraf yeni mesaj yazarsa sohbet boş '
            'olarak yeniden görünür.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    var failed = 0;
    for (final id in _selected.toList()) {
      try {
        await repo.deleteThreadForMe(chatId: id, uid: uid);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelection();
    if (failed > 0) {
      context.showError('$failed sohbet silinemedi, tekrar deneyin.');
    } else {
      context
          .showInfo(count == 1 ? 'Sohbet silindi.' : '$count sohbet silindi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final threadsAsync = ref.watch(myThreadsProvider);
    final allIds = [
      for (final t in threadsAsync.valueOrNull ?? const <ChatThread>[]) t.id
    ];

    return PopScope(
      // Geri tuşu seçim modunda ekrandan çıkmasın, seçimi kapatsın.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
      appBar: _selectionMode
          ? GradientAppBar(
              title: '${_selected.length} seçildi',
              icon: Icons.delete_outline,
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Tümünü seç',
                  onPressed: allIds.isEmpty
                      ? null
                      : () => setState(() {
                            // Hepsi seçiliyse seçim kalkar (ikinci basış).
                            if (_selected.length == allIds.length) {
                              _selected.clear();
                            } else {
                              _selected
                                ..clear()
                                ..addAll(allIds);
                            }
                          }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Seçilenleri sil',
                  onPressed: _selected.isEmpty || user == null
                      ? null
                      : () => _deleteSelected(user.uid),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Vazgeç',
                  onPressed: _exitSelection,
                ),
              ],
            )
          : GradientAppBar(
              title: 'Mesajlar',
              icon: Icons.chat_bubble_outline_rounded,
              actions: [
                // Pasif (gri) ikon gradyan üzerinde kötü durur — sohbet
                // yokken çöp kutusu hiç gösterilmez.
                if (allIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Sohbet sil',
                    onPressed: () => setState(() => _selectionMode = true),
                  ),
              ],
            ),
      drawer: const AppMenuDrawer(),
      bottomNavigationBar: const MainBottomBar(current: MainTab.chats),
      body: threadsAsync.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorView(
            message: 'Mesajlar yüklenemedi. Bağlantınızı kontrol edip '
                'tekrar deneyin.'),
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
                                ?.copyWith(color: context.palette.inkMuted),
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
                            selectionMode: _selectionMode,
                            selected: _selected.contains(visible[i].id),
                            onToggle: () => _toggleSelected(visible[i].id),
                            // Uzun basış da seçim modunu açar (WhatsApp).
                            onEnterSelection: () => setState(() {
                              _selectionMode = true;
                              _selected.add(visible[i].id);
                            }),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Instagram DM satırı: avatar · (ad / mesaj · zaman) · mavi nokta.
/// Seçim modunda solda kutucuk belirir; dokunuş seçimi değiştirir.
class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.myUid,
    this.unread = 0,
    this.selectionMode = false,
    this.selected = false,
    this.onToggle,
    this.onEnterSelection,
  });
  final ChatThread thread;
  final String myUid;
  final int unread;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onEnterSelection;

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
      onTap: selectionMode
          ? onToggle
          : () => context.push(RoutePaths.chatThread(thread.id)),
      onLongPress: selectionMode ? null : onEnterSelection,
      child: Container(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            if (selectionMode) ...[
              Checkbox(
                value: selected,
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
              const SizedBox(width: 4),
            ],
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
                decoration: BoxDecoration(
                  color: context.palette.info,
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

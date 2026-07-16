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
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/chat.dart';
import '../../auth/application/auth_controller.dart';
import '../../safety/data/safety_providers.dart';
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

  /// Liste görünürken karşı taraf fotoğraflarını ısıt — thread açılınca
  /// avatar anında cache'ten gelsin.
  void _precacheThreadPhotos(List<ChatThread> threads, String? uid) {
    if (uid == null || !mounted) return;
    for (final t in threads) {
      AppImage.precacheHttp(context, t.otherPhoto(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final threadsAsync = ref.watch(myThreadsProvider);
    final threads = threadsAsync.valueOrNull ?? const <ChatThread>[];
    final allIds = [for (final t in threads) t.id];

    // Her liste güncellemesinde (ilk yük + yeni sohbet) önbellek ısıt.
    if (user != null && threads.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheThreadPhotos(threads, user.uid);
      });
    }

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
        error: (_, _) => RefreshableEmpty(
          onRefresh: () => awaitRefresh(() async {
            ref.invalidate(myThreadsProvider);
            await ref.read(myThreadsProvider.future);
          }),
          child: const ErrorView(
              message: 'Mesajlar yüklenemedi. Bağlantınızı kontrol edip '
                  'tekrar deneyin.'),
        ),
        data: (rawThreads) {
          if (user == null) return const SizedBox.shrink();

          Future<void> refresh() => awaitRefresh(() async {
                ref.invalidate(myThreadsProvider);
                await ref.read(myThreadsProvider.future);
              });

          // Engellenen kullanıcıların sohbetleri listede gizlenir (IG/WhatsApp
          // modeli); engel kalkınca kendiliğinden geri gelir.
          final blockedUids = ref.watch(myBlockedUidsProvider);
          final threads = blockedUids.isEmpty
              ? rawThreads
              : rawThreads
                  .where((t) => !blockedUids.contains(t.otherUid(user.uid)))
                  .toList();
          if (threads.isEmpty) {
            return RefreshableEmpty(
              onRefresh: refresh,
              child: const _Empty(),
            );
          }

          final repo = ref.watch(chatRepositoryProvider);
          final q = _query.trim().toLowerCase();
          final visible = q.isEmpty
              ? threads
              : threads
                  .where(
                      (t) => t.otherName(user.uid).toLowerCase().contains(q))
                  .toList();

          final palette = context.palette;
          return ColoredBox(
            color: palette.background,
            child: ResponsiveCenter(
              maxWidth: 760,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Kişi veya sohbet ara',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 22),
                        isDense: true,
                        filled: true,
                        fillColor: palette.card,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: palette.primary, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? RefreshableEmpty(
                            onRefresh: refresh,
                            child: Center(
                              child: Text(
                                'Eşleşen sohbet yok.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: palette.inkMuted),
                              ),
                            ),
                          )
                        : PullToRefresh(
                            onRefresh: refresh,
                            child: ListView.separated(
                              physics: kPullRefreshPhysics,
                              padding:
                                  const EdgeInsets.fromLTRB(0, 4, 0, 16),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 86,
                                endIndent: 16,
                                color:
                                    palette.border.withValues(alpha: 0.85),
                              ),
                              itemBuilder: (context, i) => _ThreadTile(
                                thread: visible[i],
                                myUid: user.uid,
                                unread: repo.unreadCount(
                                    chatId: visible[i].id, uid: user.uid),
                                selectionMode: _selectionMode,
                                selected:
                                    _selected.contains(visible[i].id),
                                onToggle: () =>
                                    _toggleSelected(visible[i].id),
                                onEnterSelection: () => setState(() {
                                  _selectionMode = true;
                                  _selected.add(visible[i].id);
                                }),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Profesyonel DM satırı: avatar · ad+saat · önizleme · okunmamış rozeti.
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
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24 && now.day == t.day) {
      return DateFormat('HH:mm').format(t);
    }
    if (diff.inDays < 7) return DateFormat('EEE', 'tr_TR').format(t);
    return DateFormat('d MMM', 'tr_TR').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final name = thread.otherName(myUid);
    final photo = thread.otherPhoto(myUid);
    final hasUnread = unread > 0;
    final preview = thread.lastMessage?.trim().isNotEmpty == true
        ? thread.lastMessage!
        : 'Sohbete başlayın';

    return Material(
      color: selected
          ? palette.primaryContainer.withValues(alpha: 0.35)
          : palette.card,
      child: InkWell(
        onTap: selectionMode
            ? onToggle
            : () => context.push(RoutePaths.chatThread(thread.id)),
        onLongPress: selectionMode ? null : onEnterSelection,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(
                  value: selected,
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                ),
                const SizedBox(width: 4),
              ],
              AppAvatar(name: name, photo: photo, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabel(thread.updatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hasUnread
                                ? palette.primary
                                : palette.inkMuted,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasUnread
                                  ? palette.ink
                                  : palette.inkMuted,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.primaryContainer,
                    palette.primary.withValues(alpha: 0.18),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: palette.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz mesajın yok',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Bir ustanın profilinden sohbet başlatarak yazışmaya '
              'başlayabilirsin. İletişim bilgileri otomatik gizlenir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

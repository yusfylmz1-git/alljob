import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/search_fold.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/surface_app_bar.dart';
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

/// Mesajlar listesinin görünüm kipi.
enum _ChatFilter { tumu, okunmamis, arsiv }

/// TEK KUTU (2026-08-08).
///
/// Eskiden burada "İlan Mesajları | Genel" sekmeleri vardı: sohbet kimliği
/// ilan bazlıydı, aynı çift her iş için ayrı oda açıyordu. Artık bir kişiyle
/// tek sohbet var (`chat_{müşteri}__{usta}`), dolayısıyla ayıracak bir eksen
/// de yok. Yalnızca [_ChatFilter] (tümü/okunmamış/arşiv) kaldı.
class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _query = '';
  bool _selectionMode = false;
  final Set<String> _selected = {};
  _ChatFilter _filter = _ChatFilter.tumu;

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

  /// Sohbeti arşivler/arşivden çıkarır. Kişiseldir; karşı taraf etkilenmez.
  Future<void> _toggleArchive(ChatThread t, String uid) async {
    final archived = t.isArchivedFor(uid);
    try {
      await ref.read(chatRepositoryProvider).setThreadArchived(
            chatId: t.id,
            uid: uid,
            archived: !archived,
          );
      if (!mounted) return;
      context.showInfo(archived ? 'Sohbet arşivden çıkarıldı.' : 'Sohbet arşivlendi.');
    } catch (_) {
      if (mounted) context.showError('İşlem başarısız, tekrar deneyin.');
    }
  }

  /// Sohbeti listenin başına sabitler/kaldırır (kişisel).
  Future<void> _togglePin(ChatThread t, String uid) async {
    final pinned = t.isPinnedFor(uid);
    try {
      await ref.read(chatRepositoryProvider).setThreadPinned(
            chatId: t.id,
            uid: uid,
            pinned: !pinned,
          );
      if (!mounted) return;
      context.showInfo(pinned ? 'Sabitleme kaldırıldı.' : 'Sohbet sabitlendi.');
    } catch (_) {
      if (mounted) context.showError('İşlem başarısız, tekrar deneyin.');
    }
  }

  /// Satıra uzun basınca açılan eylem menüsü (WhatsApp kalıbı).
  Future<void> _showThreadActions(ChatThread t, String uid) async {
    final pinned = t.isPinnedFor(uid);
    final archived = t.isArchivedFor(uid);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded),
              title: Text(pinned ? 'Sabitlemeyi kaldır' : 'Sohbeti sabitle'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(t, uid);
              },
            ),
            ListTile(
              leading: Icon(archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              title: Text(archived ? 'Arşivden çıkar' : 'Arşivle'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleArchive(t, uid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Seç'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectionMode = true;
                  _selected.add(t.id);
                });
              },
            ),
          ],
        ),
      ),
    );
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
      // Alt bar sekmesi: geri tuşu uygulamayı KAPATMAMALI, Ana Sayfa'ya
      // dönmeli (sekmeler `go()` ile açılır, geçmiş yığını bırakmaz).
      // Seçim modundaysa önce seçim kapanır.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectionMode) {
          _exitSelection();
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
      appBar: _selectionMode
          ? SurfaceAppBar(
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
          : SurfaceAppBar(
              title: 'Mesajlar',
              icon: Icons.chat_bubble_outline_rounded,
              // Sekme YOK: tüm sohbetler tek listede (bkz. _ChatListScreenState).
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
          final q = foldTrSearch(_query);

          // Kapsam ayrımı YOK: ilan ve genel sohbetler tek listede.
          final scoped = threads;

          // Arşiv sekmesi yalnız arşivlenenleri; diğer sekmeler arşivi GİZLER.
          final archivedCount =
              scoped.where((t) => t.isArchivedFor(user.uid)).length;
          Iterable<ChatThread> pool = scoped;
          switch (_filter) {
            case _ChatFilter.tumu:
              pool = scoped.where((t) => !t.isArchivedFor(user.uid));
            case _ChatFilter.okunmamis:
              pool = scoped.where((t) =>
                  !t.isArchivedFor(user.uid) &&
                  repo.unreadCount(chatId: t.id, uid: user.uid) > 0);
            case _ChatFilter.arsiv:
              pool = scoped.where((t) => t.isArchivedFor(user.uid));
          }

          // Arama: karşı taraf adı + son mesaj önizlemesi (Türkçe uyumlu fold).
          if (q.isNotEmpty) {
            pool = pool.where((t) =>
                foldTrSearch(t.otherName(user.uid)).contains(q) ||
                foldTrSearch(t.lastMessage ?? '').contains(q));
          }

          // Sabitlenenler her zaman üstte; kendi içlerinde tarih sırası korunur.
          final visible = pool.toList()
            ..sort((a, b) {
              final ap = a.isPinnedFor(user.uid);
              final bp = b.isPinnedFor(user.uid);
              if (ap != bp) return ap ? -1 : 1;
              return b.updatedAt.compareTo(a.updatedAt);
            });

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
                  // Filtre sekmeleri: Tümü · Okunmamış · Arşiv.
                  // Arşiv sekmesi arşivlenmiş sohbet yoksa gösterilmez.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        for (final f in [
                          _ChatFilter.tumu,
                          _ChatFilter.okunmamis,
                          if (archivedCount > 0 || _filter == _ChatFilter.arsiv)
                            _ChatFilter.arsiv,
                        ]) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _ChatFilter.tumu => 'Tümü',
                                _ChatFilter.okunmamis => 'Okunmamış',
                                _ChatFilter.arsiv => 'Arşiv ($archivedCount)',
                              }),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? RefreshableEmpty(
                            onRefresh: refresh,
                            child: Center(
                              child: Text(
                                switch (_filter) {
                                  _ChatFilter.okunmamis =>
                                    'Okunmamış mesaj yok.',
                                  _ChatFilter.arsiv => 'Arşiv boş.',
                                  _ChatFilter.tumu => 'Eşleşen sohbet yok.',
                                },
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
                                pinned: visible[i].isPinnedFor(user.uid),
                                // Karşı taraf bu sohbeti en son ne zaman
                                // okudu? Kendi son mesajımızın tiki için.
                                otherLastRead: repo.lastReadBy(
                                  chatId: visible[i].id,
                                  uid: visible[i].otherUid(user.uid),
                                ),
                                onToggle: () =>
                                    _toggleSelected(visible[i].id),
                                // Uzun basış: sabitle/arşivle/seç menüsü.
                                onEnterSelection: () =>
                                    _showThreadActions(visible[i], user.uid),
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
    this.pinned = false,
    this.otherLastRead,
    this.onToggle,
    this.onEnterSelection,
  });
  final ChatThread thread;
  final String myUid;
  final int unread;
  final bool selectionMode;
  final bool selected;
  final bool pinned;

  /// Karşı tarafın bu sohbeti son okuma anı — kendi mesajımızın "okundu"
  /// tikini belirler. Bilinmiyorsa null (tek tik gösterilir).
  final DateTime? otherLastRead;
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

    // Son mesajı biz mi yazdık? (tik yalnız kendi mesajımızda görünür)
    final isMine = thread.lastMessageSenderUid != null &&
        thread.lastMessageSenderUid == myUid;
    // Karşı taraf son mesajdan SONRA okuduysa çift tik.
    final isReadByOther =
        otherLastRead != null && !otherLastRead!.isBefore(thread.updatedAt);

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
                    // İlan bazlı sohbette hangi işin konuşulduğu ADIN ALTINDA
                    // yazar: aynı usta ile birden çok ilan varsa liste
                    // karışmasın (sohbet kimliği ilana bağlıdır).
                    // B-19: başlık eksik olsa da (eski/iskelet dökümanlar)
                    // satır ÇİZİLİR — ilan sohbeti ile genel sohbeti ayırt
                    // etmek listenin okunabilirliği için şart. Başlık yoksa
                    // nötr etiket yazılır; burada ilan dokümanı OKUNMAZ
                    // (her satır için ayrı okuma listeyi pahalılaştırır).
                    if (thread.isJobChat)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.work_outline,
                                size: 12, color: palette.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (thread.jobTitle ?? '').isNotEmpty
                                    ? thread.jobTitle!
                                    : 'İlan sohbeti',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (thread.isLocked) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.lock_outline,
                                  size: 12, color: palette.inkMuted),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Okundu/iletildi tiki — yalnız SON mesajı biz
                        // yazdıysak. Karşı taraf mesajdan sonra okuduysa
                        // çift mavi tik, yoksa tek gri tik (WhatsApp).
                        if (isMine && !hasUnread) ...[
                          Icon(
                            isReadByOther ? Icons.done_all : Icons.done,
                            size: 15,
                            color: isReadByOther
                                ? palette.primary
                                : palette.inkMuted,
                          ),
                          const SizedBox(width: 4),
                        ],
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
                        // Sabitlenmiş sohbet göstergesi (rozetin solunda).
                        if (pinned) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.push_pin_rounded,
                              size: 14, color: palette.inkMuted),
                        ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/surface_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/favorite.dart';
import '../../auth/application/auth_controller.dart';
import '../../favorites/data/favorite_providers.dart';
import '../data/notification_repository.dart';

/// Bildirim merkezi (iki rol tek ekran): Cloud Functions'ın kalıcılaştırdığı
/// bildirimler Instagram dilinde gruplanır (Bugün / Bu Hafta / Daha Önce);
/// dokununca ilgili sohbete/ilana gider. Ekran açılınca görünenler okundu
/// işaretlenir (zil rozeti söner). En altta "Sizi Takip Edenler": ustayı
/// takip eden müşteriler (usta kimseyi takip etmediği için tümü listelenir).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedRead = false;

  void _markVisibleRead(String uid, List<AppNotification> items) {
    if (_markedRead) return;
    final unreadIds =
        items.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    _markedRead = true;
    // Ekran kurulduktan sonra sessizce işaretle; akış kendini günceller.
    Future.microtask(() => ref
        .read(notificationRepositoryProvider)
        .markRead(uid, unreadIds)
        .catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink(); // rota zaten korumalı

    final notifsAsync = ref.watch(myNotificationsProvider(user.uid));
    final followers =
        ref.watch(followersProvider(user.uid)).valueOrNull ?? const <Favorite>[];

    return Scaffold(
      appBar: const SurfaceAppBar(
        title: 'Bildirimler',
        icon: Icons.notifications_none_rounded,
      ),
      body: notifsAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => RefreshableEmpty(
          onRefresh: () => awaitRefresh(() async {
            ref.invalidate(myNotificationsProvider(user.uid));
            ref.invalidate(followersProvider(user.uid));
            await ref.read(myNotificationsProvider(user.uid).future);
          }),
          child: const ErrorView(
              message: 'Bildirimler yüklenemedi. Bağlantınızı kontrol edip '
                  'tekrar deneyin.'),
        ),
        data: (items) {
          Future<void> refresh() => awaitRefresh(() async {
                ref.invalidate(myNotificationsProvider(user.uid));
                ref.invalidate(followersProvider(user.uid));
                await ref.read(myNotificationsProvider(user.uid).future);
              });
          _markVisibleRead(user.uid, items);
          if (items.isEmpty && followers.isEmpty) {
            return RefreshableEmpty(
              onRefresh: refresh,
              child: const _EmptyNotifications(),
            );
          }
          final groups = _groupByAge(items);
          return ResponsiveCenter(
            maxWidth: 720,
            child: PullToRefresh(
              onRefresh: refresh,
              child: ListView(
                physics: kPullRefreshPhysics,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final g in groups) ...[
                    _SectionHeader(title: g.$1),
                    const SizedBox(height: 8),
                    for (final n in g.$2) ...[
                      _NotificationTile(notification: n),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 10),
                  ],
                  if (followers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _SectionHeader(
                        title: 'Sizi Takip Edenler (${followers.length})'),
                    const SizedBox(height: 8),
                    for (final f in followers) ...[
                      _FollowerTile(follower: f),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bildirimleri IG dilinde yaş gruplarına ayırır (boş gruplar atlanır).
  List<(String, List<AppNotification>)> _groupByAge(
      List<AppNotification> items) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final week = <AppNotification>[];
    final older = <AppNotification>[];
    for (final n in items) {
      final age = now.difference(n.createdAt);
      if (age.inHours < 24) {
        today.add(n);
      } else if (age.inDays < 7) {
        week.add(n);
      } else {
        older.add(n);
      }
    }
    return [
      if (today.isNotEmpty) ('Bugün', today),
      if (week.isNotEmpty) ('Bu Hafta', week),
      if (older.isNotEmpty) ('Daha Önce', older),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w800));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  void _open(BuildContext context) {
    if (notification.isChat && notification.chatId != null) {
      context.push(RoutePaths.chatThread(notification.chatId!));
    } else if (notification.jobId != null) {
      context.push(RoutePaths.jobDetail(notification.jobId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChat = notification.isChat;
    final color = isChat ? context.palette.info : context.palette.success;

    return Material(
      color: notification.read
          ? context.palette.card
          : color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isChat
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.work_outline,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.read
                                ? FontWeight.w600
                                : FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(notification.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (!notification.read) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.palette.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ustayı takip eden müşteri satırı (avatar + ad + ne zaman).
class _FollowerTile extends StatelessWidget {
  const _FollowerTile({required this.follower});
  final Favorite follower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name =
        follower.customerName.isEmpty ? 'Kullanıcı' : follower.customerName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.palette.primaryContainer,
            child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: follower.customerPhotoUrl != null
                    ? AppImage(handle: follower.customerPhotoUrl)
                    : Icon(Icons.person,
                        size: 22,
                        color: context.palette.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('sizi takip ediyor',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(follower.createdAt),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// IG kısa zaman etiketi: "az önce", "5 dk", "3 sa", "2 g", "4 hf".
String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'az önce';
  if (d.inMinutes < 60) return '${d.inMinutes} dk';
  if (d.inHours < 24) return '${d.inHours} sa';
  if (d.inDays < 7) return '${d.inDays} g';
  return '${(d.inDays / 7).floor()} hf';
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Henüz bildiriminiz yok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Yeni mesajlar, bölgenizdeki iş ilanları ve iş güncellemeleri '
              'burada görünecek.',
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

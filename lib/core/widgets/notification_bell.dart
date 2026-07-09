import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../router/route_paths.dart';
import '../theme/app_colors.dart';

/// Sağ üst bildirim zili: okunmamış bildirim varsa kırmızı sayı rozeti
/// gösterir (Instagram dili), dokununca bildirim merkezine gider.
/// Misafirde gizlenir (bildirim oturum gerektirir).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.color = Colors.white});

  /// İkon rengi — koyu hero üstünde beyaz, açık app bar üstünde tema rengi.
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final unread = ref.watch(unreadNotificationCountProvider(user.uid));

    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.push(RoutePaths.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: color),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

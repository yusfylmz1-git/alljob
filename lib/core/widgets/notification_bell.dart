import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../router/route_paths.dart';
import '../theme/app_palette.dart';

/// Sağ üst bildirim zili: okunmamış bildirim varsa kırmızı sayı rozeti
/// gösterir (Instagram dili), dokununca bildirim merkezine gider.
/// Misafirde gizlenir (bildirim oturum gerektirir).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.color});

  /// İkon rengi. Verilmezse marka rengi (`palette.primary`) kullanılır.
  ///
  /// Eskiden varsayılan sabit `Colors.white`'tı; profil gibi hero gradyanı
  /// OLMAYAN ekranlarda beyaz zemine beyaz ikon düşüyor ve zil/menü
  /// görünmüyordu. Gradyan üstünde duran ekranlar beyazı AÇIKÇA verir.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final unread = ref.watch(unreadNotificationCountProvider(user.uid));
    final iconColor = color ?? context.palette.primary;

    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.push(RoutePaths.notifications),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(8),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: iconColor),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: context.palette.danger,
                  borderRadius: BorderRadius.circular(9),
                  // Kenarlık rozeti zeminden ayırır: koyu temada beyaz halka
                  // yamalı durur, sayfa zemininin rengi doğru olan.
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  unread >= kNotificationUnreadCap
                      ? '$kNotificationUnreadCap+'
                      : '$unread',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/chat/data/chat_providers.dart';
import '../router/route_paths.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Alt bar sekmeleri. `work` moda göre anlam değiştirir: müşteri = İlanlarım,
/// usta = İşler (yakındaki iş ilanları). Misafirde `work` görünmez.
enum MainTab { explore, work, chats, profile }

/// YÜZEN cam alt gezinme çubuğu. Kenardan boşluklu, yuvarlak, yumuşak gölgeli
/// bir pill olarak durur (Uber/Linear dili). `bottomNavigationBar` yuvasında
/// yaşar; sayfa zeminini arkasında bırakır, üstündeki içeriği örtmez.
/// - Keşfet herkese açık (usta da keşfeti görür).
/// - **İlanlarım/İşler** (work) moda göre gelir; misafirde gizli.
/// - Mesajlar/Profil misafirde girişe yönlenir (router guard).
/// - Profil TEK birleşik sayfadır (/profile); içerik aktif moda göre şekillenir.
class MainBottomBar extends ConsumerWidget {
  const MainBottomBar({super.key, required this.current});

  final MainTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(totalUnreadProvider);
    final isArtisan = user?.isArtisan ?? false;
    // work sekmesi yalnızca oturum açmış kullanıcıda görünür (müşteri/usta).
    final showWork = user != null;

    void go(MainTab tab) {
      if (tab == current) return;
      switch (tab) {
        case MainTab.explore:
          context.go(RoutePaths.home);
        case MainTab.work:
          context.go(isArtisan ? RoutePaths.panelJobs : RoutePaths.myJobs);
        case MainTab.chats:
          context.go(RoutePaths.chats);
        case MainTab.profile:
          // Tek birleşik profil sayfası — mod ne olursa olsun aynı yer.
          if (user == null) {
            context.push(RoutePaths.login);
          } else {
            context.go(RoutePaths.profile);
          }
      }
    }

    return SafeArea(
      top: false,
      // heightFactor: 1.0 → dikeyde içeriğe sarılır; aksi halde Align/Center
      // bottomNavigationBar yuvasındaki sınırlı yüksekliği doldurup barı
      // ekranın ortasına iter.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.palette.hairline),
                boxShadow: AppTheme.floatShadow,
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.search_rounded,
                    activeIcon: Icons.search_rounded,
                    label: 'Keşfet',
                    selected: current == MainTab.explore,
                    onTap: () => go(MainTab.explore),
                  ),
                  if (showWork)
                    _NavItem(
                      icon: isArtisan
                          ? Icons.handyman_outlined
                          : Icons.campaign_outlined,
                      activeIcon: isArtisan
                          ? Icons.handyman_rounded
                          : Icons.campaign_rounded,
                      label: isArtisan ? 'İşler' : 'İlanlarım',
                      selected: current == MainTab.work,
                      onTap: () => go(MainTab.work),
                    ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Mesajlar',
                    selected: current == MainTab.chats,
                    badge: unread,
                    onTap: () => go(MainTab.chats),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profil',
                    selected: current == MainTab.profile,
                    onTap: () => go(MainTab.profile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? context.palette.primary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              child: Icon(selected ? activeIcon : icon, size: 24, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

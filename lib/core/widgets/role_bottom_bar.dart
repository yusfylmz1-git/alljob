import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/chat/data/chat_providers.dart';
import '../router/route_paths.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Alt bar sekmeleri. `work` moda göre: müşteri = İlanlarım, usta = İşler.
/// `home` = platform Ana Sayfa (dashboard); `explore` = Keşfet arama ızgarası.
enum MainTab { home, explore, work, chats, profile }

/// Yüzen cam alt gezinme — Instagram netliği + pill derinlik.
/// Rotalar değişmez; yalnızca görsel/dokunuş dili.
class MainBottomBar extends ConsumerWidget {
  const MainBottomBar({super.key, required this.current});

  final MainTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(totalUnreadProvider);
    final isArtisan = user?.isArtisan ?? false;
    final showWork = user != null;
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void go(MainTab tab) {
      if (tab == current) return;
      switch (tab) {
        case MainTab.home:
          context.go(RoutePaths.home);
        case MainTab.explore:
          context.go(RoutePaths.explore);
        case MainTab.work:
          context.go(isArtisan ? RoutePaths.panelJobs : RoutePaths.myJobs);
        case MainTab.chats:
          context.go(RoutePaths.chats);
        case MainTab.profile:
          if (user == null) {
            context.push(RoutePaths.login);
          } else {
            context.go(RoutePaths.profile);
          }
      }
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                // Cam hissi: kart + hafif primary tint
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      palette.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                      palette.card,
                    ),
                    palette.card,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Color.alphaBlend(
                    palette.primary.withValues(alpha: 0.10),
                    palette.hairline,
                  ),
                ),
                boxShadow: AppTheme.floatShadow,
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Ana Sayfa',
                    selected: current == MainTab.home,
                    onTap: () => go(MainTab.home),
                  ),
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
                    // IG tarzı: seçili profilde dolu ikon + hap
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
    final palette = context.palette;
    final color =
        selected ? palette.primary : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: palette.primary.withValues(alpha: 0.10),
          highlightColor: palette.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? palette.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: selected
                  ? Border.all(
                      color: palette.primary.withValues(alpha: 0.18),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Badge(
                    isLabelVisible: badge > 0,
                    label: Text(badge > 99 ? '99+' : '$badge'),
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: (theme.textTheme.labelSmall ?? const TextStyle())
                      .copyWith(
                    color: color,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 10.5,
                    height: 1.1,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

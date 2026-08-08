import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../favorites/presentation/favorite_button.dart';

/// Genel kullanıcı profili (`/u/:uid`) — usta vitrini OLMAYAN kişiler için.
///
/// Takip listesinden bir ada dokunulduğunda buraya gelinir. Usta profili
/// olanlar `/artisan/:uid`'e yönlendirilir (router seviyesinde değil, burada
/// karar verilir: `hasArtisanProfile` yalnız dokümanı okuyunca bilinir).
///
/// Gösterilenler: avatar · ad + doğrulama · takip/takipçi sayacı ·
/// tamamlanan iş · Takip Et + Mesaj düğmeleri.
/// E-posta ve telefon GÖSTERİLMEZ — `users/{uid}` dokümanında zaten yoktur
/// (ADR-11: hassas veri `private/` altında).
class PublicUserScreen extends ConsumerWidget {
  const PublicUserScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicUserProvider(uid));

    return Scaffold(
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Profil yüklenemedi. Bağlantınızı kontrol edip '
              'tekrar deneyin.',
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }
          // Usta vitrini varsa zengin profile devret — burada tekrar
          // çizmek iki ayrı gerçek kaynak yaratırdı.
          if (user.hasArtisanProfile) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.pushReplacement(RoutePaths.artisanProfile(uid));
              }
            });
            return const LoadingView();
          }
          return _Body(user: user);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final me = ref.watch(currentUserProvider);
    final isMe = me != null && me.uid == user.uid;

    final followers =
        ref.watch(followersProvider(user.uid)).valueOrNull?.length;
    final following =
        ref.watch(favoritesProvider(user.uid)).valueOrNull?.length;
    final followsMe =
        ref.watch(isFollowedByProvider(user.uid)).valueOrNull ?? false;

    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero: usta profiliyle aynı görsel dil (gradyan + halkalı avatar).
        Container(
          decoration: BoxDecoration(
            gradient: palette.heroGradient,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(
            bottom: false,
            child: ResponsiveCenter(
              maxWidth: 760,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      BackButton(
                        color: Colors.white,
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(RoutePaths.home),
                      ),
                      const Spacer(),
                      if (!isMe)
                        FavoriteButton(
                          artisanUid: user.uid,
                          artisanName: user.displayName,
                          photoUrl: user.profilePhotoUrl,
                          filledBackground: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF13293F),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: user.profilePhotoUrl != null
                              ? AppImage(
                                  handle: user.profilePhotoUrl,
                                  fit: BoxFit.cover,
                                  width: 92,
                                  height: 92,
                                  memCacheWidth: 220,
                                  memCacheHeight: 220,
                                )
                              : Container(
                                  color: Colors.white12,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name.isEmpty ? 'Kullanıcı' : name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (user.phoneVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            color: Color(0xFF60A5FA), size: 22),
                      ],
                    ],
                  ),
                  if (followsMe && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Seni takip ediyor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Sayaçlar — profil ekranıyla aynı üçlü düzen.
                  Row(
                    children: [
                      _Stat(
                        value: '${following ?? 0}',
                        label: 'takip',
                        onTap: () => context.push(RoutePaths.favorites),
                      ),
                      _Stat(
                        value: '${followers ?? 0}',
                        label: 'takipçi',
                        onTap: () => context.push(RoutePaths.followers),
                      ),
                      _Stat(
                        value: '${user.completedJobsAsCustomer}',
                        label: 'tamamlanan',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (!isMe)
          ResponsiveCenter(
            maxWidth: 760,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openChat(context, ref, me, user),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Mesaj Gönder'),
              ),
            ),
          ),

        // Usta olmayan kullanıcıda gösterilecek vitrin yok — sade kalır.
        ResponsiveCenter(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Text(
            isMe
                ? 'Kendi profilin. Ustaysan vitrinini Profil → Usta modu ile '
                    'açabilirsin.'
                : 'Bu kullanıcı henüz usta vitrini açmamış.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
        ),
      ],
    );
  }

  /// Genel sohbet başlatır (ilan bağı YOK — `jobId` verilmez).
  Future<void> _openChat(
    BuildContext context,
    WidgetRef ref,
    AppUser? me,
    AppUser other,
  ) async {
    if (me == null) {
      context.push(RoutePaths.login);
      return;
    }
    try {
      final chatId = await ref.read(chatRepositoryProvider).startChat(
            customerUid: me.uid,
            customerName: me.displayName,
            customerPhotoUrl: me.profilePhotoUrl,
            artisanUid: other.uid,
            artisanName: other.displayName,
            artisanPhotoUrl: other.profilePhotoUrl,
          );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sohbet açılamadı, tekrar deneyin.')),
        );
      }
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

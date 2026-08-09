import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/app_user.dart';
import '../../artisan/application/availability_gate.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../products/presentation/widgets/dukkan_bolumu.dart';
import '../../review/presentation/widgets/review_cta.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/profile_header.dart';
import '../../../data/models/favorite.dart';

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

    final followsMe =
        ref.watch(isFollowedByProvider(user.uid)).valueOrNull ?? false;

    final name = user.displayName.trim();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ORTAK BAŞLIK — usta profili ve kendi profilimle AYNI widget.
        // Tek fark eylem düğmeleri: burada "Mesaj" + "Takip et".
        SafeArea(
          bottom: false,
          child: ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst şerit: geri (sol) + ad (orta) + takip yıldızı (sağ).
                Row(
                  children: [
                    BackButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(RoutePaths.home),
                    ),
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Kullanıcı' : name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (!isMe)
                      FavoriteButton(
                        artisanUid: user.uid,
                        artisanName: user.displayName,
                        photoUrl: user.profilePhotoUrl,
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 8),

                ProfileHeader(
                  user: user,
                  actions: isMe
                      ? Row(
                          children: [
                            Expanded(
                              child: ProfileActionButton(
                                label: 'Profili düzenle',
                                onTap: () =>
                                    context.push(RoutePaths.profileEdit),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ProfileActionButton(
                                label: 'Mesaj',
                                icon: Icons.chat_bubble_outline,
                                onTap: () => _openChat(context, ref, me, user),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TakipDugmesi(user: user),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),

        // "Seni takip ediyor" rozeti — başlığın altında, sola dayalı.
        if (followsMe && !isMe)
          ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Seni takip ediyor',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),
        Divider(color: palette.hairline, height: 24),

        // ── Dükkân ──
        // Usta olmayan da ürün satabilir (Mağaza modülü, 2026-08-10), bu
        // yüzden vitrin bu ekranda da görünür. Ürünü yoksa kendini gizler.
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: DukkanBolumu(
            saticiUid: user.uid,
            saticiAdi: name,
            bolumKurucu: ({
              required icon,
              required title,
              required child,
              trailing,
            }) =>
                _DukkanKabugu(
              icon: icon,
              title: title,
              trailing: trailing,
              child: child,
            ),
          ),
        ),

        // ── Değerlendirmeler ──
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ReviewCta(targetUid: user.uid),
        ),
        ResponsiveCenter(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ReviewList(targetUid: user.uid),
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
    // İlan kartındaki avatar BURAYA getiriyor. Kapı olmasaydı, ilan
    // detayından mesaj atamayan müsait olmayan usta profile geçip buradan
    // yazabilirdi (2026-08-10 bulgusu).
    if (!artisanAvailabilityAllowsNewChat(context, ref)) return;
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

/// Dükkân bölümünün bu ekrandaki kabuğu.
///
/// Usta profilindeki `_Section` kartlı/gölgeli; bu ekran sade akış olduğu
/// için burada yalnız başlık + içerik kullanılır. Aynı widget iki farklı
/// kabukla sarılabilsin diye [DukkanBolumu] kabuğu dışarıdan alır.
class _DukkanKabugu extends StatelessWidget {
  const _DukkanKabugu({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: palette.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// "Takip et" / "Takiptesin" — [FavoriteButton]'ın metinli hâli.
class _TakipDugmesi extends ConsumerWidget {
  const _TakipDugmesi({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takipte =
        ref.watch(isFavoriteProvider(user.uid)).valueOrNull ?? false;
    return ProfileActionButton(
      label: takipte ? 'Takiptesin' : 'Takip et',
      filled: !takipte,
      onTap: () async {
        final me = ref.read(currentUserProvider);
        if (me == null) {
          context.push(RoutePaths.login);
          return;
        }
        final fav = Favorite(
          customerUid: me.uid,
          artisanUid: user.uid,
          artisanName: user.displayName,
          photoUrl: user.profilePhotoUrl,
          // Takip EDENİN snapshot'ı — karşı tarafın "Takipçiler" listesi
          // ekstra okuma yapmadan dolsun.
          customerName: me.displayName,
          customerPhotoUrl: me.profilePhotoUrl,
          createdAt: DateTime.now(),
        );
        try {
          final eklendi =
              await ref.read(favoriteRepositoryProvider).toggle(fav);
          if (!context.mounted) return;
          context.showInfo(
              eklendi ? 'Takip ediliyor.' : 'Takipten çıkarıldı.');
        } catch (_) {
          if (context.mounted) {
            context.showError('İşlem başarısız, tekrar deneyin.');
          }
        }
      },
    );
  }
}

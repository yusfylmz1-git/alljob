import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/mock_database.dart' show kProfessionNames;
import '../../data/models/app_user.dart';
import '../../features/artisan/data/artisan_providers.dart';
import '../../features/favorites/data/favorite_providers.dart';
import '../../features/review/data/review_repository.dart';
import '../router/route_paths.dart';
import '../theme/app_palette.dart';
import 'app_image.dart';

/// Instagram tarzı profil başlığı — KENDİ ve BAŞKASININ profilinde AYNI.
///
/// Tek fark eylem düğmeleridir ([actions]):
///   kendi profilim → "Profili düzenle" · "Profilime bak"
///   başkası        → "Mesaj" · "Takip et"
///
/// Yapı (yukarıdan aşağı):
///   avatar + sayaçlar (yatay) → ad + mavi tik → meslek → hakkımda →
///   iletişim satırları → [extra] (ör. müsaitlik anahtarı) → [actions]
///
/// Böylece iki ekran birbirinden ayrışamaz: birine eklenen bir alan
/// diğerinde de görünür.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.actions,
    this.photoOverride,
    this.aboutOverride,
    this.professionOverride,
    this.extra,
    this.onAvatarTap,
    this.avatarBadge,
    this.isMe = false,
  });

  /// Profili gösterilen kişi.
  final AppUser user;

  /// Alt eylem çubuğu — ekrana göre değişen TEK parça.
  final Widget actions;

  /// Taslaktaki fotoğraf (kendi profilimde yeni seçilen anında görünsün).
  final String? photoOverride;

  /// Taslaktaki "hakkımda" (kendi profilimde anında görünsün).
  final String? aboutOverride;

  /// Meslek etiketi — usta profilinde gösterilir.
  final String? professionOverride;

  /// Eylem çubuğunun ÜSTÜNE eklenecek widget (ör. müsaitlik anahtarı).
  final Widget? extra;

  /// Avatara dokunma (kendi profilimde fotoğraf değiştirme).
  final VoidCallback? onAvatarTap;

  /// Avatarın sağ altındaki rozet (kendi profilimde "+").
  final Widget? avatarBadge;

  /// Kendi profilim mi? Sayaçlara dokunmak yalnız burada liste açar —
  /// başkasının takip listesi gezilemez.
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final name = user.displayName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final photo = photoOverride ?? user.profilePhotoUrl;
    final about = (aboutOverride?.trim().isNotEmpty ?? false)
        ? aboutOverride!.trim()
        : user.aboutText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar SOLDA, sayaçlar YANINDA (IG düzeni).
        Row(
          children: [
            _Avatar(
              photo: photo,
              initials: initials,
              onTap: onAvatarTap,
              badge: avatarBadge,
            ),
            const SizedBox(width: 8),
            Expanded(child: ProfileStats(user: user, isMe: isMe)),
          ],
        ),
        const SizedBox(height: 12),

        // Bio: ad + mavi tik.
        Row(
          children: [
            Flexible(
              child: Text(
                name.isEmpty ? 'Kullanıcı' : name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (user.phoneVerified) ...[
              const SizedBox(width: 5),
              Icon(Icons.verified, size: 16, color: palette.verified),
            ],
          ],
        ),

        if (professionOverride != null && professionOverride!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              professionOverride!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        if (about.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              about,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),

        // İletişim satırları — küçük font, ikonlu, boş olan çizilmez.
        ProfileBioDetails(user: user),
        const SizedBox(height: 12),

        if (extra != null) ...[extra!, const SizedBox(height: 10)],
        actions,
      ],
    );
  }
}

/// Profil avatarı — isteğe bağlı dokunma + rozet.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photo,
    required this.initials,
    this.onTap,
    this.badge,
  });

  final String? photo;
  final String initials;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const size = 78.0;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.primaryContainer,
        border: Border.all(color: palette.hairline, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photo != null
          ? AppImage(
              handle: photo,
              fit: BoxFit.cover,
              width: size,
              height: size,
              memCacheWidth: 240,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: palette.primary,
              ),
            ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          onTap == null
              ? avatar
              : InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: avatar,
                ),
          if (badge != null)
            Positioned(right: -2, bottom: -2, child: badge!),
        ],
      ),
    );
  }
}

/// Instagram tarzı 3'lü sayaç şeridi: **takip · takipçi · değerlendirme**.
///
/// Herkeste aynı — usta/müşteri ayrımı YOK. Sayaçlara dokunmak yalnız KENDİ
/// profilinde ilgili listeyi açar; başkasının takip listesi gezilemez.
class ProfileStats extends ConsumerWidget {
  const ProfileStats({super.key, required this.user, this.isMe = false});

  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers =
        ref.watch(followersProvider(user.uid)).valueOrNull?.length;
    final following =
        ref.watch(favoritesProvider(user.uid)).valueOrNull?.length;
    final reviews =
        ref.watch(reviewsForUserProvider(user.uid)).valueOrNull ?? const [];

    return Row(
      children: [
        _StatCell(
          value: '${following ?? 0}',
          label: 'takip',
          onTap: isMe ? () => context.push(RoutePaths.favorites) : null,
        ),
        _StatCell(
          value: '${followers ?? 0}',
          label: 'takipçi',
          onTap: isMe ? () => context.push(RoutePaths.followers) : null,
        ),
        // "tamamlanan" DEĞİL "değerlendirme": iş akışı kalktığı için
        // tamamlanan sayacı artık hiç artmıyor.
        _StatCell(value: '${reviews.length}', label: 'değerlendirme'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.onTap});

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
              // IG: sayı iri ve koyu, etiket altında küçük ve soluk.
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profil bio'sundaki iletişim satırları — Instagram dili.
///
/// Telefon, web sitesi ve sosyal medya hesapları küçük fontta, ikonlu tek
/// satırlar hâlinde. Boş olan alan HİÇ çizilmez: yarısı boş bir liste
/// profilin doluluk hissini düşürür.
class ProfileBioDetails extends StatelessWidget {
  const ProfileBioDetails({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final s = user.socialLinks;

    final satirlar = <({IconData icon, String text})>[
      if (user.publicPhone?.trim().isNotEmpty ?? false)
        (icon: Icons.phone_outlined, text: user.publicPhone!.trim()),
      if (s.website?.trim().isNotEmpty ?? false)
        (icon: Icons.link_rounded, text: kisaUrl(s.website!)),
      if (s.instagram?.trim().isNotEmpty ?? false)
        (icon: Icons.camera_alt_outlined, text: '@${s.instagram!.trim()}'),
      if (s.youtube?.trim().isNotEmpty ?? false)
        (icon: Icons.play_circle_outline, text: s.youtube!.trim()),
      if (s.tiktok?.trim().isNotEmpty ?? false)
        (icon: Icons.music_note_outlined, text: '@${s.tiktok!.trim()}'),
      if (s.whatsapp?.trim().isNotEmpty ?? false)
        (icon: Icons.chat_outlined, text: s.whatsapp!.trim()),
    ];

    if (satirlar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in satirlar)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(r.icon, size: 13, color: palette.inkMuted),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      r.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// `https://ornek.com/yol` → `ornek.com/yol` — şema satırı şişiriyor.
  static String kisaUrl(String raw) {
    var t = raw.trim();
    for (final on in ['https://', 'http://', 'www.']) {
      if (t.toLowerCase().startsWith(on)) t = t.substring(on.length);
    }
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}

/// Profil eylem düğmesi — gri zeminli, kompakt (IG dili).
class ProfileActionButton extends StatelessWidget {
  const ProfileActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// true: marka renginde dolgu (birincil eylem — ör. "Takip et").
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = filled ? Colors.white : null;
    return Material(
      color: filled ? palette.primary : palette.surfaceMuted,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Usta profilinde meslek adını çözer (kendi ve başkasının profilinde ortak).
String? professionLabel(WidgetRef ref, String uid) {
  final detail = ref.watch(artisanDetailProvider(uid)).valueOrNull;
  final code = detail?.profile.profession;
  if (code == null || code.isEmpty) return null;
  return kProfessionNames[code];
}

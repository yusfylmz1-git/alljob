import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/artisan_profile.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../artisan/data/artisan_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../../favorites/data/favorite_providers.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../review/presentation/widgets/review_cta.dart';
import '../../../core/widgets/profile_header.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/favorite.dart';

/// Ekran D — Usta Profil Sayfası (salt okunur). Müşteri kartına dokununca açılır.
/// E-posta asla gösterilmez. Telefon yalnız usta açık rıza verdiyse
/// ([ArtisanProfile.hasPublicPhone]) avatar altında görünür.
class ArtisanProfileScreen extends ConsumerWidget {
  const ArtisanProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(artisanDetailProvider(uid));

    return Scaffold(
      body: detailAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message:
              'Profil yüklenemedi. Bağlantınızı kontrol edip '
              'tekrar deneyin.',
        ),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Usta bulunamadı.'));
          }
          return _ProfileBody(detail: detail);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.detail});
  final ArtisanDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = detail.profile;
    final me = ref.watch(currentUserProvider)?.uid;
    final isOwner = me != null && me == detail.uid;
    final theme = Theme.of(context);
    final palette = context.palette;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroHeader(detail: detail, isOwner: isOwner),
              ResponsiveCenter(
                maxWidth: 760,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instagram tarzı: bio + meslek etiketleri
                    if (profile.aboutText.isNotEmpty) ...[
                      Text(
                        profile.aboutText,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 12),
                    ] else if (isOwner) ...[
                      Text(
                        'Henüz “Hakkımda” yazmadınız. Müşteriler sizi buradan tanır — '
                        'Profili Düzenle’den ekleyin.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.inkMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (profile.professionCodes.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final code in profile.professionCodes)
                            Chip(
                              avatar: Icon(
                                Icons.handyman_outlined,
                                size: 16,
                                color: palette.primary,
                              ),
                              label: Text(
                                kProfessionNames[code] ?? code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: palette.primaryContainer
                                  .withValues(alpha: 0.55),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // SOSYAL MEDYA SATIRI BURADAN KALDIRILDI (2026-08-09).
                    //
                    // İki sorun vardı:
                    //  1. Kaynağı ESKİ: `profile.socialLinks` artisanProfiles
                    //     kaydından geliyordu; ortak alanlar `users` altına
                    //     taşındıktan sonra kullanıcının yeni girdiği veri
                    //     burada görünmüyordu.
                    //  2. MÜKERRER: aynı bağlantılar başlıktaki bio
                    //     satırlarında (ProfileBioDetails) zaten var ve
                    //     onlar doğru kaynaktan okuyor.

                    // İş fotoğrafları — vitrinin kalbi (IG grid)
                    _Section(
                      icon: Icons.photo_library_outlined,
                      title: profile.workPhotos.isEmpty
                          ? 'İş fotoğrafları'
                          : 'İş fotoğrafları (${profile.workPhotos.length})',
                      trailing: isOwner && profile.workPhotos.isEmpty
                          ? TextButton(
                              onPressed: () =>
                                  context.push(RoutePaths.panelEdit),
                              child: const Text('Ekle'),
                            )
                          : null,
                      child: profile.workPhotos.isEmpty
                          ? Text(
                              isOwner
                                  ? 'Henüz iş fotoğrafı yok. Müşteriler yaptığınız '
                                        'işleri görmek ister — galerinizi doldurun.'
                                  : 'Bu usta henüz iş fotoğrafı eklememiş.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.inkMuted,
                              ),
                            )
                          : _WorkPhotoGrid(handles: profile.workPhotos),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      icon: Icons.location_on_outlined,
                      title: 'Hizmet bölgeleri',
                      child: profile.serviceAreas.isEmpty
                          ? Text(
                              isOwner
                                  ? 'Bölge eklenmemiş. Aramada görünmek için il/ilçe seçin.'
                                  : 'Bölge bilgisi yok.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: palette.inkMuted,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: profile.serviceAreas
                                  .map(
                                    (a) => Chip(
                                      avatar: const Icon(
                                        Icons.location_on,
                                        size: 16,
                                      ),
                                      label: Text(a.labelTR),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      icon: Icons.schedule_outlined,
                      title: 'Çalışma saatleri',
                      child: _ScheduleBlock(profile: profile),
                    ),
                    const SizedBox(height: 14),

                    if (profile.certificates.isNotEmpty) ...[
                      _Section(
                        // Yalnız ONAYLI belgeler "doğrulanmış" olarak sunulur;
                        // inceleme bekleyen/reddedilen belge müşteriye
                        // doğrulanmış gibi gösterilmez.
                        icon: profile.hasApprovedCertificates
                            ? Icons.verified_user
                            : Icons.verified_outlined,
                        title: profile.hasApprovedCertificates
                            ? 'Sertifikalar ve belgeler · onaylı'
                            : 'Sertifikalar ve belgeler',
                        // Instagram "Öne Çıkanlar" dili: dairesel, halkalı.
                        // Onaylı belgelerde halka vurgulu (yeşil), aksi hâlde
                        // nötr — "onaylı" iddiası görsel olarak da ayrışır.
                        child: SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: profile.certificates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => _showCertificate(
                                context,
                                profile.certificates[i],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: profile.hasApprovedCertificates
                                        ? palette.success
                                        : palette.borderStrong,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 76,
                                    height: 76,
                                    child: AppImage(
                                      handle: profile.certificates[i],
                                      fit: BoxFit.cover,
                                      memCacheWidth: 200,
                                      memCacheHeight: 200,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (isOwner) ...[
                      _Section(
                        icon: Icons.verified_outlined,
                        title: 'Sertifikalar',
                        trailing: TextButton(
                          onPressed: () => context.push(RoutePaths.panelEdit),
                          child: const Text('Ekle'),
                        ),
                        child: Text(
                          'Belge eklemek güveni artırır (isteğe bağlı).',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Puan özeti + "Değerlendir" düğmesi. Her profilde aynı
                    // blok durur (usta/müşteri ayrımı yok).
                    ReviewCta(targetUid: detail.uid),
                    const SizedBox(height: 12),
                    _ReviewsSection(reviews: detail.reviews),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isOwner)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(RoutePaths.panelEdit),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Profili düzenle'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _ChatBar(detail: detail),
      ],
    );
  }
}

/// 3 sütunlu iş fotoğrafı ızgarası (Instagram vitrin).
class _WorkPhotoGrid extends StatelessWidget {
  const _WorkPhotoGrid({required this.handles});
  final List<String> handles;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: handles.length,
      // Instagram ızgarası: 2 px aralık, köşe yuvarlaması YOK — kareler
      // birbirine bitişik durur, akış kesintisiz görünür.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, i) {
        final h = handles[i];
        return GestureDetector(
          onTap: () => _showCertificate(context, h),
          child: AppImage(
            handle: h,
            fit: BoxFit.cover,
            memCacheWidth: 320,
            memCacheHeight: 320,
          ),
        );
      },
    );
  }
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({required this.profile});
  final ArtisanProfile profile;

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final p = profile;
    if (p.manualPause) {
      return Text(
        'Şu an geçici olarak müsait değil.',
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.warning),
      );
    }
    if (p.alwaysAvailable) {
      return Row(
        children: [
          Icon(Icons.all_inclusive, size: 18, color: palette.success),
          const SizedBox(width: 8),
          Text(
            'Her zaman müsait',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final days = p.weeklySchedule.days;
    if (days.every((d) => !d.enabled)) {
      return Text(
        'Çalışma saatleri belirtilmemiş.',
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      );
    }
    return Column(
      children: [
        for (final d in days)
          if (d.enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      _days[(d.weekday - 1).clamp(0, 6)],
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${d.startLabel} – ${d.endLabel}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Sertifika görselini tam ekran (yakınlaştırmalı) diyalogda gösterir.
void _showCertificate(BuildContext context, String handle) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: InteractiveViewer(
              child: AppImage(handle: handle, fit: BoxFit.contain),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Usta profil başlığı — KENDİ PROFİLİMLE AYNI dil (2026-08-09).
///
/// Ortak [ProfileHeader] kullanır; tek fark eylem düğmeleridir:
/// burada "Mesaj" + "Takip et", kendi profilimde "düzenle | bak".
///
/// Eskiden koyu gradyanlı, ortalanmış, tamamen ayrı bir tasarımdı — aynı
/// kişinin profili nereden bakıldığına göre başka görünüyordu.
class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({required this.detail, this.isOwner = false});
  final ArtisanDetail detail;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(publicUserProvider(detail.uid));
    final me = ref.watch(currentUserProvider);

    // `users` dokümanı ortak profil alanlarını (telefon, sosyal, hakkımda)
    // taşır. Henüz gelmediyse usta kaydından geçici bir kabuk kurulur ki
    // başlık boş kalmasın.
    final user = userAsync.valueOrNull ??
        AppUser(
          uid: detail.uid,
          displayName: detail.displayName,
          email: '',
          createdAt: DateTime.now(),
          profilePhotoUrl: detail.profilePhotoUrl,
          hasArtisanProfile: true,
          aboutText: detail.profile.aboutText,
          publicPhone: detail.profile.publicPhone,
          socialLinks: detail.profile.socialLinks,
        );

    return SafeArea(
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
                    detail.displayName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (!isOwner)
                  FavoriteButton(
                    artisanUid: detail.uid,
                    artisanName: detail.displayName,
                    professionNameTR: detail.professionNameTR,
                    rating: detail.profile.averageRating,
                    totalReviews: detail.profile.totalReviews,
                    photoUrl: detail.profilePhotoUrl,
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),

            ProfileHeader(
              user: user,
              professionOverride: detail.professionNameTR,
              actions: isOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: ProfileActionButton(
                            label: 'Profili düzenle',
                            onTap: () => context.push(RoutePaths.profileEdit),
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
                            onTap: () =>
                                _mesajGonder(context, ref, me, detail),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TakipDugmesi(detail: detail),
                        ),
                      ],
                    ),
            ),
            // Karşılıklı takip göstergesi — Instagram dili.
            if (!isOwner) _SeniTakipEdiyor(uid: detail.uid),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Doğrudan sohbet açar (ilan bağı YOK).
  Future<void> _mesajGonder(
    BuildContext context,
    WidgetRef ref,
    AppUser? me,
    ArtisanDetail other,
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
        context.showError('Sohbet açılamadı, tekrar deneyin.');
      }
    }
  }
}

/// "Takip et" / "Takiptesin" — [FavoriteButton]'ın metinli hâli.
///
/// Yıldız ikonu üst şeritte duruyor; burada Instagram dilinde bir düğme
/// gerekiyor ki "Mesaj" ile aynı ağırlıkta görünsün.
class _TakipDugmesi extends ConsumerWidget {
  const _TakipDugmesi({required this.detail});
  final ArtisanDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takipte =
        ref.watch(isFavoriteProvider(detail.uid)).valueOrNull ?? false;
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
          artisanUid: detail.uid,
          artisanName: detail.displayName,
          professionNameTR: detail.professionNameTR,
          rating: detail.profile.averageRating,
          totalReviews: detail.profile.totalReviews,
          photoUrl: detail.profilePhotoUrl,
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

/// İkonlu başlığı olan, ince kenarlı beyaz bölüm kartı.
/// Usta profilindeki "Dükkan" bölümü — o ustanın sattığı ürünlerin yatay
/// resimli önizlemesi + "Tümünü Gör". Ürünü yoksa bölüm tamamen gizlenir.
class _Section extends StatelessWidget {
  const _Section({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.palette.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: context.palette.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      icon: Icons.star_outline_rounded,
      title: 'Değerlendirmeler (${reviews.length})',
      child: reviews.isEmpty
          ? Text(
              'Henüz değerlendirme yok.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: reviews.map((r) => _ReviewTile(review: r)).toList(),
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('d MMM yyyy', 'tr_TR').format(review.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Uzun ad yıldızları ekrandan itmesin.
              Expanded(
                child: Text(
                  review.maskedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RatingStars(rating: review.rating.toDouble(), size: 14),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.tags.map((t) => _ReviewTagChip(tag: t)).toList(),
            ),
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }
}

/// Değerlendirme etiketi rozeti (olumlu yeşil, olumsuz kırmızı tonlu).
class _ReviewTagChip extends StatelessWidget {
  const _ReviewTagChip({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final isNegative = ReviewTags.isNegative(tag);
    final color = isNegative ? context.palette.danger : context.palette.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bir ustayla sohbet başlatır (sohbet barı + profil fotoğrafı hızlı menüsü
/// ortak kullanır). Misafiri girişe, doğrulanmamış e-postayı doğrulamaya
/// yönlendirir; kendi profilinde no-op. Başarıda sohbet ekranını açar.
Future<void> startChatWithArtisan(
  BuildContext context,
  WidgetRef ref,
  ArtisanDetail detail,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    context.push(RoutePaths.login);
    return;
  }
  if (user.uid == detail.uid) return; // kendiyle sohbet olmaz

  // MÜSAİTLİK KAPISI: müsait olmayan ustaya YENİ sohbet açılamaz.
  //
  // Kapsam bilinçli olarak dar: yalnız YENİ sohbet engellenir. Var olan
  // sohbetler DEVAM EDER — müsaitlik "yeni iş almıyorum" demektir, "kimseyle
  // konuşmuyorum" değil. Süren bir iş varsa teslim/sorun bildirme/
  // değerlendirme hep o sohbetten yürür; kesilirse taraflar ortada kalır.
  //
  // Zaten sohbeti olan kullanıcı bu ekrandan değil, Mesajlar sekmesinden
  // devam eder; oradaki giriş bu kontrolden etkilenmez.
  if (!detail.profile.isAvailable) {
    context.showInfo(
      '${detail.displayName} şu an yeni iş almıyor. '
      'Müsait olduğunda mesaj gönderebilirsin.',
    );
    return;
  }

  final emailOk = await ensureEmailVerified(
    context,
    ref,
    actionLabel: 'sohbet başlatmak',
  );
  if (!emailOk || !context.mounted) return;
  if (user.suspended) {
    context.showError('Hesabınız askıya alındığı için sohbet açılamaz.');
    return;
  }
  try {
    final chatId = await ref
        .read(chatRepositoryProvider)
        .startChat(
          customerUid: user.uid,
          customerName: user.displayName,
          customerPhotoUrl: user.profilePhotoUrl,
          artisanUid: detail.uid,
          artisanName: detail.displayName,
          artisanPhotoUrl: detail.profilePhotoUrl,
        );
    if (!context.mounted) return;
    context.push(RoutePaths.chatThread(chatId));
  } catch (_) {
    if (context.mounted) {
      context.showError(
        'Sohbet açılamadı. E-posta doğrulamanızı kontrol edin.',
      );
    }
  }
}

class _ChatBar extends ConsumerWidget {
  const _ChatBar({required this.detail});
  final ArtisanDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = user == null;
    // Çift rol: kullanıcı kendi usta profiline bakıyorsa kendisiyle sohbet
    // başlatamaz.
    if (user != null && user.uid == detail.uid) {
      return const SizedBox.shrink();
    }
    // Müsait değilse düğme pasif ve SEBEBİ yazılı — kullanıcı tıklayıp
    // hata mesajı almasın, durumu önceden görsün. (Var olan sohbetler
    // Mesajlar sekmesinden sürer; bu yalnız YENİ sohbeti kapatır.)
    final available = detail.profile.isAvailable;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ResponsiveCenter(
          maxWidth: 760,
          child: available
              ? AppButton(
                  label: isGuest ? 'Sohbet için giriş yap' : 'Sohbet Başlat',
                  icon: isGuest ? Icons.login : Icons.chat_bubble_outline,
                  onPressed: () => startChatWithArtisan(context, ref, detail),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.do_not_disturb_on_outlined,
                          size: 18, color: context.palette.inkMuted),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Şu an yeni iş almıyor',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: context.palette.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
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

/// "Seni takip ediyor" rozeti — karşı taraf BENİ takip ediyorsa görünür.
class _SeniTakipEdiyor extends ConsumerWidget {
  const _SeniTakipEdiyor({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takipEdiyor =
        ref.watch(isFollowedByProvider(uid)).valueOrNull ?? false;
    if (!takipEdiyor) return const SizedBox.shrink();

    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Seni takip ediyor',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

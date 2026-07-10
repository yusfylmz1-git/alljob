import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../artisan/data/artisan_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../favorites/presentation/favorite_button.dart';

/// Ekran D — Usta Profil Sayfası (salt okunur). Müşteri kartına dokununca açılır.
/// İletişim bilgisi (telefon/e-posta) burada ASLA gösterilmez (PRD §6).
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
            message: 'Profil yüklenemedi. Bağlantınızı kontrol edip '
                'tekrar deneyin.'),
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

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.detail});
  final ArtisanDetail detail;

  @override
  Widget build(BuildContext context) {
    final profile = detail.profile;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroHeader(detail: detail),
              ResponsiveCenter(
                maxWidth: 760,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (profile.aboutText.isNotEmpty) ...[
                      _Section(
                        icon: Icons.person_outline_rounded,
                        title: 'Hakkımda',
                        child: Text(profile.aboutText,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _Section(
                      icon: Icons.location_on_outlined,
                      title: 'Hizmet Bölgeleri',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.serviceAreas
                            .map((a) => Chip(
                                  avatar: const Icon(Icons.location_on,
                                      size: 16),
                                  label: Text(a.labelTR),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (profile.certificates.isNotEmpty) ...[
                      _Section(
                        icon: Icons.verified_outlined,
                        title: 'Sertifikalar ve Belgeler',
                        child: SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: profile.certificates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => _showCertificate(
                                  context, profile.certificates[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: AppImage(
                                      handle: profile.certificates[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _ReviewsSection(reviews: detail.reviews),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        _ChatBar(detail: detail),
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: InteractiveViewer(
              child: AppImage(handle: handle),
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

/// Lacivert gradyan hero: geri butonu, canlı halkalı avatar, ad + doğrulama,
/// meslek, müsaitlik durumu ve beyaz istatistik kartı.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.detail});
  final ArtisanDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = detail.profile;
    final available = profile.isAvailable;
    final initials = detail.displayName.isNotEmpty
        ? detail.displayName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
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
                  FavoriteButton(
                    artisanUid: detail.uid,
                    artisanName: detail.displayName,
                    professionNameTR: detail.professionNameTR,
                    rating: profile.averageRating,
                    totalReviews: profile.totalReviews,
                    photoUrl: detail.profilePhotoUrl,
                    filledBackground: true,
                  ),
                ],
              ),
              // Canlı halkalı yuvarlak profil fotoğrafı (müsaitse yeşil).
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: available
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF34D399), Color(0xFF059669)],
                        )
                      : null,
                  color:
                      available ? null : Colors.white.withValues(alpha: 0.3),
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF13293F),
                    shape: BoxShape.circle,
                  ),
                  child: detail.profilePhotoUrl != null
                      ? CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white24,
                          foregroundImage:
                              NetworkImage(detail.profilePhotoUrl!),
                        )
                      : Container(
                          width: 92,
                          height: 92,
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(initials,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(detail.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Tooltip(
                      message: 'Doğrulanmış Usta',
                      child: Icon(Icons.verified,
                          color: Color(0xFF60A5FA), size: 22),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                detail.professionNameTR,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              // Müsaitlik durumu (PRD §3).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: available
                            ? const Color(0xFF34D399)
                            : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      available ? 'Şu an hizmete hazır' : 'Şu an müsait değil',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Değerlendirmelerden türeyen öne çıkan etiketler (Temiz İşçilik,
              // Dakik, Hızlı…). Sadece olumlu etiketler, en sık geçenler.
              if (_topPositiveTags(detail.reviews).isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _topPositiveTags(detail.reviews)
                      .map((t) => _HeroTag(label: t))
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              // İstatistik kartı.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    children: [
                      _Stat(
                        value: profile.averageRating.toStringAsFixed(1),
                        label: 'Puan',
                        icon: Icons.star_rounded,
                        iconColor: AppColors.star,
                      ),
                      _statDivider(theme),
                      _Stat(
                        value: '${profile.totalReviews}',
                        label: 'Değerlendirme',
                      ),
                      _statDivider(theme),
                      // Yalnızca CF yazar (onJobWritten) → güvenilir sayı.
                      _Stat(
                        value: '${profile.completedJobs}',
                        label: 'Tamamlanan İş',
                      ),
                      _statDivider(theme),
                      _Stat(
                        value: '${profile.experienceYears} yıl',
                        label: 'Deneyim',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statDivider(ThemeData theme) => Container(
        width: 1,
        height: 34,
        color: theme.colorScheme.outlineVariant,
      );

  /// Değerlendirmelerdeki en sık geçen olumlu etiketleri döndürür.
  static List<String> _topPositiveTags(List<Review> reviews, {int max = 4}) {
    final counts = <String, int>{};
    for (final r in reviews) {
      for (final tag in r.tags) {
        if (!ReviewTags.isNegative(tag)) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(max).toList();
  }
}

/// Hero üzerindeki cam dokulu etiket çipi (beyaz yarı saydam).
class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 3),
              ],
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// İkonlu başlığı olan, ince kenarlı beyaz bölüm kartı.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

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
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, size: 18, color: AppColors.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
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
          ? Text('Henüz değerlendirme yok.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
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
              Text(review.maskedName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              RatingStars(rating: review.rating.toDouble(), size: 14),
            ],
          ),
          const SizedBox(height: 2),
          Text(dateStr,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
    final color = isNegative ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ResponsiveCenter(
          maxWidth: 760,
          child: AppButton(
            label: isGuest ? 'Sohbet için giriş yap' : 'Sohbet Başlat',
            icon: isGuest ? Icons.login : Icons.chat_bubble_outline,
            onPressed: () {
              if (isGuest) {
                // Misafir iletişime geçmek isterse girişe yönlendir (PRD §2).
                context.push(RoutePaths.login);
                return;
              }
              // Oturum açmış müşteri: sohbeti başlat/aç ve sohbet ekranına git.
              final chatId = ref.read(chatRepositoryProvider).startChat(
                    customerUid: user.uid,
                    customerName: user.displayName,
                    customerPhotoUrl: user.profilePhotoUrl,
                    artisanUid: detail.uid,
                    artisanName: detail.displayName,
                    artisanPhotoUrl: detail.profilePhotoUrl,
                  );
              context.push(RoutePaths.chatThread(chatId));
            },
          ),
        ),
      ),
    );
  }
}

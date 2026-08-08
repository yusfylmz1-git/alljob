import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/review.dart';
import '../../../auth/application/auth_controller.dart';
import '../../data/review_repository.dart';

/// Profil sayfalarındaki değerlendirme özeti + "Değerlendir" düğmesi.
///
/// Usta/müşteri ayrımı YOK — her profilde aynı blok durur (2026-08-08).
/// Ortalama puan, yıldızlar, değerlendirme sayısı ve tek bir eylem düğmesi.
///
/// Düğme, kullanıcı o kişiyi daha önce puanladıysa **"Değerlendirmeni
/// Güncelle"** yazar: bir kişiye bir değerlendirme yazılır, ikincisi mevcut
/// kaydın üzerine gider (bkz. [reviewDocId]).
///
/// Kendi profilinde ve misafirde düğme gösterilmez.
class ReviewCta extends ConsumerWidget {
  const ReviewCta({super.key, required this.targetUid});

  /// Puanı ALAN kişi.
  final String targetUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final reviews =
        ref.watch(reviewsForUserProvider(targetUid)).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider);
    final kendiProfilim = me != null && me.uid == targetUid;

    final ortalama = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    // "Daha önce yazdım mı?" — düğmenin dilini belirler.
    final mevcut = (me == null || kendiProfilim)
        ? null
        : ref
            .watch(myReviewForProvider(
                (authorUid: me.uid, targetUid: targetUid)))
            .valueOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          Text(
            reviews.isEmpty ? '0' : ortalama.toStringAsFixed(1),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          _Yildizlar(ortalama: ortalama),
          const SizedBox(height: 6),
          Text(
            reviews.isEmpty
                ? '(İlk değerlendiren sen ol!)'
                : '${reviews.length} değerlendirme',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
          if (!kendiProfilim) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.review(targetUid)),
              icon: Icon(
                mevcut != null
                    ? Icons.edit_outlined
                    : Icons.rate_review_outlined,
                size: 18,
              ),
              label: Text(
                mevcut != null ? 'Değerlendirmeni Güncelle' : 'Değerlendir',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ortalamaya göre dolu/boş yıldız şeridi (yarım yıldız yok — 4.6 → 5 dolu
/// değil 4 dolu gösterilir; abartmamak için aşağı yuvarlanır).
class _Yildizlar extends StatelessWidget {
  const _Yildizlar({required this.ortalama});
  final double ortalama;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dolu = ortalama.floor();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.star_rounded,
              size: 26,
              color: i <= dolu ? palette.star : palette.hairline,
            ),
          ),
      ],
    );
  }
}

/// Profilde aldığı değerlendirmelerin listesi — usta/müşteri fark etmez.
class ReviewList extends ConsumerWidget {
  const ReviewList({super.key, required this.targetUid});

  final String targetUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final reviews =
        ref.watch(reviewsForUserProvider(targetUid)).valueOrNull ?? const [];

    if (reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yorumlar',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final r in reviews)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Ad MASKELİ: değerlendirme kimin yazdığını ifşa etmez.
                    Text(
                      r.maskedName,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Icon(Icons.star_rounded, size: 15, color: palette.star),
                    const SizedBox(width: 2),
                    Text(
                      '${r.rating}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (r.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in r.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (ReviewTags.isNegative(t)
                                    ? palette.danger
                                    : palette.success)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ReviewTags.isNegative(t)
                                  ? palette.danger
                                  : palette.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../data/admin_providers.dart';
import '../data/admin_review_repository.dart';
import 'paged_footer.dart';

/// Değerlendirme kuyruğu + soft-hide (puan toplamı MVP'de değişmez).
class AdminReviewsScreen extends ConsumerWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(reviewDirectoryControllerProvider);
    final ctrl = ref.read(reviewDirectoryControllerProvider.notifier);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Değerlendirmeler',
        icon: Icons.rate_review_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? null
            : '${pageAsync.value!.items.length} yüklü'
                '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: ctrl.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: palette.warningSurface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Gizlenen değerlendirmeler hâlâ ortalama puana dahildir. '
                'Puan düzeltmesi ayrı fazdadır.',
                style: TextStyle(color: palette.inkMuted, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(
                message: 'Değerlendirmeler yüklenemedi.',
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return Center(
                    child: Text('Kayıt yok.',
                        style: TextStyle(color: palette.inkMuted)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: ctrl.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 960,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: ListView.separated(
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == page.items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: ctrl.loadMore,
                            endLabel: 'Listenin sonu',
                          );
                        }
                        return _ReviewCard(item: page.items[i]);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item});
  final AdminReview item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final r = item.review;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.hiddenByAdmin ? palette.danger : palette.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('★ ${r.rating}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (item.hiddenByAdmin)
                  Text('Gizli',
                      style: TextStyle(
                          color: palette.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Usta: ${r.artisanUid}',
                style: TextStyle(color: palette.inkMuted, fontSize: 12)),
            Text('Müşteri: ${r.customerDisplayName} (${r.customerUid})',
                style: TextStyle(color: palette.inkFaint, fontSize: 11)),
            if (r.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.tags.join(' · '),
                  style: TextStyle(color: palette.inkMuted, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                try {
                  await ref.read(adminReviewRepositoryProvider).setHidden(
                        r.id,
                        hidden: !item.hiddenByAdmin,
                      );
                  if (context.mounted) {
                    context.showSuccess(item.hiddenByAdmin
                        ? 'Gizleme kaldırıldı.'
                        : 'Değerlendirme gizlendi.');
                    ref.invalidate(reviewDirectoryControllerProvider);
                  }
                } catch (_) {
                  if (context.mounted) {
                    context.showError('İşlem başarısız.');
                  }
                }
              },
              child: Text(item.hiddenByAdmin ? 'Göster' : 'Gizle'),
            ),
          ],
        ),
      ),
    );
  }
}

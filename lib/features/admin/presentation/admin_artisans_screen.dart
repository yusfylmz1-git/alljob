import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/artisan_profile.dart';
import '../data/admin_providers.dart';
import 'admin_users_screen.dart';
import 'paged_footer.dart';

/// Yönetici usta tarayıcısı (PR4 — salt okunur).
class AdminArtisansScreen extends ConsumerStatefulWidget {
  const AdminArtisansScreen({super.key});

  @override
  ConsumerState<AdminArtisansScreen> createState() =>
      _AdminArtisansScreenState();
}

class _AdminArtisansScreenState extends ConsumerState<AdminArtisansScreen> {
  final _professionCtrl = TextEditingController();

  @override
  void dispose() {
    _professionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(artisanDirectoryControllerProvider);
    final controller = ref.read(artisanDirectoryControllerProvider.notifier);
    final profession = ref.watch(artisanDirectoryProfessionFilterProvider);
    final verified = ref.watch(artisanDirectoryVerifiedFilterProvider);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Ustalar',
        icon: Icons.handyman_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? null
            : '${pageAsync.value!.items.length} yüklü'
                '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _ArtisanFilters(
            professionController: _professionCtrl,
            verified: verified,
            professionActive:
                profession != null && profession.isNotEmpty,
            onProfessionSubmit: () {
              final t = _professionCtrl.text.trim();
              ref
                  .read(artisanDirectoryProfessionFilterProvider.notifier)
                  .state = t.isEmpty ? null : t;
              if (t.isNotEmpty) {
                ref
                    .read(artisanDirectoryVerifiedFilterProvider.notifier)
                    .state = null;
              }
            },
            onVerified: (v) {
              ref
                  .read(artisanDirectoryVerifiedFilterProvider.notifier)
                  .state = v;
              if (v != null) {
                ref
                    .read(artisanDirectoryProfessionFilterProvider.notifier)
                    .state = null;
                _professionCtrl.clear();
              }
            },
            onClearAll: () {
              ref
                  .read(artisanDirectoryProfessionFilterProvider.notifier)
                  .state = null;
              ref
                  .read(artisanDirectoryVerifiedFilterProvider.notifier)
                  .state = null;
              _professionCtrl.clear();
            },
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(
                message:
                    'Ustalar yüklenemedi. Filtre indeksi hazır olmayabilir.',
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'Usta profili bulunamadı.',
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.refresh,
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
                            onLoadMore: controller.loadMore,
                            endLabel: 'Usta listesinin sonu',
                          );
                        }
                        return _ArtisanCard(profile: page.items[i]);
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

class _ArtisanFilters extends StatelessWidget {
  const _ArtisanFilters({
    required this.professionController,
    required this.verified,
    required this.professionActive,
    required this.onProfessionSubmit,
    required this.onVerified,
    required this.onClearAll,
  });

  final TextEditingController professionController;
  final bool? verified;
  final bool professionActive;
  final VoidCallback onProfessionSubmit;
  final ValueChanged<bool?> onVerified;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Tümü'),
              selected: !professionActive && verified == null,
              onSelected: (_) => onClearAll(),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Doğrulanmış'),
              selected: verified == true,
              onSelected: (v) => onVerified(v ? true : null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Doğrulanmamış'),
              selected: verified == false,
              onSelected: (v) => onVerified(v ? false : null),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: TextField(
                controller: professionController,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Meslek kodu',
                  hintText: 'plumber',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onProfessionSubmit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtisanCard extends ConsumerWidget {
  const _ArtisanCard({required this.profile});
  final ArtisanProfile profile;

  Future<void> _flag(
    BuildContext context,
    WidgetRef ref, {
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) async {
    try {
      await ref.read(adminArtisanRepositoryProvider).setFlags(
            profile.uid,
            adminVerified: adminVerified,
            featured: featured,
            moderationHidden: moderationHidden,
          );
      if (context.mounted) {
        context.showSuccess('Bayrak güncellendi.');
        ref.invalidate(artisanDirectoryControllerProvider);
      }
    } catch (_) {
      if (context.mounted) context.showError('Bayrak güncellenemedi.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final name = profile.professionLabelsTR(kProfessionNames);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                profile.moderationHidden ? palette.danger : palette.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? '(meslek yok)' : name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (profile.showVerifiedBadge)
                  Icon(Icons.verified, color: palette.primary, size: 18),
                if (profile.featured)
                  Icon(Icons.star, color: palette.warning, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text('UID: ${profile.uid}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.inkFaint)),
            const SizedBox(height: 6),
            Text(
              '★ ${profile.averageRating.toStringAsFixed(1)} · '
              '${profile.totalReviews} değerlendirme · '
              '${profile.completedJobs} iş',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () =>
                      showAdminUserActions(context, ref, profile.uid),
                  child: const Text('Kullanıcı'),
                ),
                OutlinedButton(
                  onPressed: () => _flag(context, ref,
                      adminVerified: !profile.adminVerified),
                  child: Text(profile.adminVerified
                      ? 'Platform onayını kaldır'
                      : 'Platform onayla'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _flag(context, ref, featured: !profile.featured),
                  child: Text(profile.featured ? 'Öne çıkarmayı kaldır' : 'Öne çıkar'),
                ),
                OutlinedButton(
                  onPressed: () => _flag(context, ref,
                      moderationHidden: !profile.moderationHidden),
                  child: Text(
                      profile.moderationHidden ? 'Profili göster' : 'Profili gizle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

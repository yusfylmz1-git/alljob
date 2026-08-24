import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/artisan_profile.dart';
import '../data/admin_artisan_repository.dart';
import '../data/admin_providers.dart';
import 'admin_pickers.dart';
import 'admin_certificate_sheet.dart';
import 'admin_chrome.dart';
import 'admin_list_search.dart';
import 'admin_moderation_glossary.dart';
import 'admin_premium_sheet.dart';
import 'admin_users_screen.dart';
import 'paged_footer.dart';

/// Usta vitrini dizini — Keşfet'te görünen profiller.
///
/// Kişi kimliği ve askı [Kullanıcılar] / kişi hub'ındadır. Bu sekme vitrin
/// bayrakları (onay, öne çıkar, gizle, premium, belge) için kısayoldur.
class AdminArtisansScreen extends ConsumerStatefulWidget {
  const AdminArtisansScreen({super.key});

  @override
  ConsumerState<AdminArtisansScreen> createState() =>
      _AdminArtisansScreenState();
}

class _AdminArtisansScreenState extends ConsumerState<AdminArtisansScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
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
        title: 'Usta vitrini',
        icon: Icons.handyman_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? 'Kişi adı · vitrin ayarları (kimlik → Kullanıcılar)'
            : '${pageAsync.value!.items.length} usta'
                '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          const AdminHelpButton(highlightTitle: 'Platform onayı'),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          AdminHintBanner(
            text:
                'Platform onayı = güven rozeti · Gizle = Keşfet’ten düşür · '
                'Askı = hesap dondurma (kişi dosyasında).',
            onHelp: () => AdminModerationGlossary.show(context),
          ),
          AdminListSearchBar(
            controller: _searchCtrl,
            label: 'Usta ara',
            hint: 'Ad, e-posta, UID veya meslek…',
            onChanged: (v) => setState(() => _query = v.trim()),
            onClear: () => setState(() => _query = ''),
          ),
          _ArtisanFilters(
            verified: verified,
            profession: profession,
            professionActive: profession != null && profession.isNotEmpty,
            onVerified: (v) {
              ref.read(artisanDirectoryVerifiedFilterProvider.notifier).state =
                  v;
              if (v != null) {
                ref
                    .read(artisanDirectoryProfessionFilterProvider.notifier)
                    .state = null;
              }
            },
            onProfession: (kod) {
              ref
                  .read(artisanDirectoryProfessionFilterProvider.notifier)
                  .state = kod;
              // Meslek ve doğrulama filtresi birlikte kullanılmıyor
              // (bileşik indeks yok); biri seçilince diğeri temizlenir.
              if (kod != null) {
                ref
                    .read(artisanDirectoryVerifiedFilterProvider.notifier)
                    .state = null;
              }
            },
            onClear: () {
              ref.read(artisanDirectoryVerifiedFilterProvider.notifier).state =
                  null;
              ref
                  .read(artisanDirectoryProfessionFilterProvider.notifier)
                  .state = null;
            },
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(
                message:
                    'Ustalar yüklenemedi. İndeks veya yetkiyi kontrol edin.',
              ),
              data: (page) {
                final items = _query.isEmpty
                    ? page.items
                    : page.items
                        .where(
                          (it) => adminAnyMatch(
                            [
                              it.displayName,
                              it.email,
                              it.uid,
                              it.profile.profession,
                              it.profile.professionLabelsTR(kProfessionNames),
                              ...it.profile.professionCodes,
                            ],
                            _query,
                          ),
                        )
                        .toList();
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'Usta bulunamadı.',
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Arama sonucu yok (yüklü ${page.items.length} satırda). '
                      'Daha fazla yükleyin veya başka kelime deneyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 720,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: ListView.separated(
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: controller.loadMore,
                            endLabel: _query.isEmpty
                                ? 'Liste sonu'
                                : 'Yüklü listede arama · daha fazla yükle',
                          );
                        }
                        return _PersonArtisanCard(item: items[i]);
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
    required this.verified,
    required this.profession,
    required this.professionActive,
    required this.onVerified,
    required this.onProfession,
    required this.onClear,
  });

  final bool? verified;
  final String? profession;
  final bool professionActive;
  final ValueChanged<bool?> onVerified;
  final ValueChanged<String?> onProfession;
  final VoidCallback onClear;

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
              selected: verified == null && !professionActive,
              onSelected: (_) => onClear(),
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
            const SizedBox(width: 10),
            // SEÇİCİ (2026-08-23): katalogda 145 meslek var; kodu ezberden
            // yazmak imkânsızdı ve yanlış yazım boş liste üretiyordu.
            SizedBox(
              width: 220,
              child: AdminProfessionPicker(
                value: profession,
                allowClear: true,
                onChanged: onProfession,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonArtisanCard extends ConsumerWidget {
  const _PersonArtisanCard({required this.item});
  final AdminArtisanListItem item;

  Future<void> _flag(
    BuildContext context,
    WidgetRef ref, {
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) async {
    try {
      await ref.read(adminArtisanRepositoryProvider).setFlags(
            item.uid,
            adminVerified: adminVerified,
            featured: featured,
            moderationHidden: moderationHidden,
          );
      if (context.mounted) {
        context.showSuccess('Güncellendi.');
        ref.invalidate(artisanDirectoryControllerProvider);
      }
    } catch (_) {
      if (context.mounted) context.showError('Güncellenemedi.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final p = item.profile;
    final professions = p.professionLabelsTR(kProfessionNames);
    final canFinance =
        ref.watch(adminCapabilitiesProvider).allows('finance.manage');

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showAdminUserActions(
          context,
          ref,
          item.uid,
          contextHint: 'Usta profili · kişi kaydı',
          onChanged: () =>
              ref.invalidate(artisanDirectoryControllerProvider),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: p.moderationHidden ? palette.danger : palette.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: item.displayName, photoUrl: item.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (item.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          professions.isEmpty
                              ? 'Meslek seçilmemiş'
                              : professions,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.inkMuted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (p.showVerifiedBadge)
                    Icon(Icons.verified, color: palette.primary, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(
                    label:
                        '★ ${p.averageRating.toStringAsFixed(1)} · ${p.totalReviews} değerlendirme',
                  ),
                  if (p.featured)
                    _StatusChip(label: 'Öne çıkan', color: palette.warning),
                  if (p.moderationHidden)
                    _StatusChip(label: 'Gizli', color: palette.danger),
                  if (p.adminVerified)
                    _StatusChip(label: 'Platform onaylı', color: palette.success),
                  _StatusChip(
                    label: _premiumLabel(p),
                    color: _premiumActive(p)
                        ? palette.success
                        : palette.inkFaint,
                  ),
                  if (p.certificatesPending)
                    _StatusChip(
                      label: 'Belge bekliyor',
                      color: palette.warning,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Kişi hub: kimlik + vitrin + askı + notlar tek yerde.
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => showAdminUserActions(
                    context,
                    ref,
                    item.uid,
                    contextHint: 'Usta vitrini · kişi dosyası',
                    onChanged: () =>
                        ref.invalidate(artisanDirectoryControllerProvider),
                  ),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('Kişi dosyasını aç'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _flag(
                      context,
                      ref,
                      adminVerified: !p.adminVerified,
                    ),
                    child: Text(
                      p.adminVerified ? 'Onayı kaldır' : 'Platform onayla',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _flag(context, ref, featured: !p.featured),
                    child: Text(
                      p.featured ? 'Öne çıkarma kaldır' : 'Öne çıkar',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _flag(
                      context,
                      ref,
                      moderationHidden: !p.moderationHidden,
                    ),
                    child: Text(
                      p.moderationHidden ? 'Vitrini göster' : 'Vitrini gizle',
                    ),
                  ),
                  if (canFinance)
                    OutlinedButton(
                      onPressed: () => showPremiumOverrideSheet(
                        context,
                        ref,
                        profile: p,
                      ),
                      child: const Text('Premium'),
                    ),
                  if (p.certificates.isNotEmpty)
                    OutlinedButton(
                      onPressed: () => showCertificateReviewSheet(
                        context,
                        ref,
                        profile: p,
                      ),
                      child: Text(
                        p.certificatesPending
                            ? 'Belgeleri incele'
                            : 'Belgeler',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _premiumActive(ArtisanProfile p) {
    final until = p.premiumExpiresAt;
    return p.isPremium && until != null && until.isAfter(DateTime.now());
  }

  static String _premiumLabel(ArtisanProfile p) {
    final until = p.premiumExpiresAt;
    if (_premiumActive(p) && until != null) {
      return 'Premium · ${until.day}.${until.month}.${until.year}';
    }
    if (until != null) return 'Premium bitti';
    return 'Premium yok';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = name.trim();
    final letter = t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
    final url = photoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url != null && url.startsWith('http')
            ? AppImage(handle: url, width: 52, height: 52, fit: BoxFit.cover)
            : ColoredBox(
                color: palette.primaryContainer,
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: palette.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = color ?? palette.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

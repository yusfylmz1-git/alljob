import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../data/admin_export_util.dart';
import '../data/admin_providers.dart';
import 'admin_pickers.dart';
import 'admin_chrome.dart';
import 'admin_list_search.dart';
import 'admin_users_screen.dart';
import 'paged_footer.dart';

/// Yönetici ilan tarayıcısı (PR3 — salt okunur).
class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Job? _idHit;
  bool _idSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupId(String q) async {
    final t = q.trim();
    if (t.isEmpty) {
      setState(() => _idHit = null);
      return;
    }
    // Yalnız ID benzeri (boşluksuz, makul uzunluk) sunucuya sor.
    if (t.contains(' ') || t.length < 8) {
      setState(() => _idHit = null);
      return;
    }
    setState(() => _idSearching = true);
    try {
      final job =
          await ref.read(adminJobRepositoryProvider).findById(t);
      if (!mounted) return;
      setState(() {
        _idHit = job;
        _idSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _idHit = null;
        _idSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(jobDirectoryControllerProvider);
    final controller = ref.read(jobDirectoryControllerProvider.notifier);
    final statusFilter = ref.watch(jobDirectoryStatusFilterProvider);
    final provinceFilter = ref.watch(jobDirectoryProvinceFilterProvider);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'İlanlar',
        icon: Icons.work_outline,
        subtitle: pageAsync.valueOrNull == null
            ? null
            : '${pageAsync.value!.items.length} yüklü'
                  '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          IconButton(
            tooltip: 'CSV kopyala (yüklü sayfa)',
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final caps = ref.read(adminCapabilitiesProvider);
              if (!caps.allows('export.run')) {
                context.showError('export.run yetkisi yok.');
                return;
              }
              final items =
                  ref.read(jobDirectoryControllerProvider).valueOrNull?.items ??
                  const <Job>[];
              if (items.isEmpty) {
                context.showError('Yüklü satır yok.');
                return;
              }
              await Clipboard.setData(ClipboardData(text: buildJobsCsv(items)));
              try {
                await ref
                    .read(adminUserRepositoryProvider)
                    .logExport(kind: 'jobs', rowCount: items.length);
              } catch (_) {}
              if (context.mounted) {
                context.showSuccess(
                  '${items.length} ilan CSV panoya kopyalandı.',
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          AdminListSearchBar(
            controller: _searchCtrl,
            label: 'İlan ara',
            hint: 'Başlık, il, kategori, müşteri, ilan ID…',
            onChanged: (v) {
              setState(() => _query = v.trim());
              _lookupId(v);
            },
            onSubmitted: _lookupId,
            onClear: () => setState(() {
              _query = '';
              _idHit = null;
            }),
          ),
          if (_idSearching)
            const LinearProgressIndicator(minHeight: 2)
          else if (_idHit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: _JobCard(job: _idHit!),
            ),
          _JobFilters(
            status: statusFilter,
            province: ref.watch(jobDirectoryProvinceFilterProvider),
            onStatus: (s) {
              ref.read(jobDirectoryStatusFilterProvider.notifier).state = s;
              if (s != null) {
                ref.read(jobDirectoryProvinceFilterProvider.notifier).state =
                    null;
              }
            },
            onProvince: (il) {
              ref.read(jobDirectoryProvinceFilterProvider.notifier).state = il;
              // İl ve durum filtresi birlikte kullanılmıyor (bileşik indeks
              // yok); biri seçilince diğeri temizlenir.
              if (il != null) {
                ref.read(jobDirectoryStatusFilterProvider.notifier).state =
                    null;
              }
            },
            onClearAll: () {
              ref.read(jobDirectoryStatusFilterProvider.notifier).state = null;
              ref.read(jobDirectoryProvinceFilterProvider.notifier).state =
                  null;
            },
            provinceActive: provinceFilter != null && provinceFilter.isNotEmpty,
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(
                message:
                    'İlanlar yüklenemedi. Filtre indeksi hazır olmayabilir.',
              ),
              data: (page) {
                final items = _query.isEmpty
                    ? page.items
                    : page.items
                        .where(
                          (j) => adminAnyMatch(
                            [
                              j.jobId,
                              j.title,
                              j.province,
                              j.district,
                              j.category,
                              kProfessionNames[j.category] ??
                                  j.categoryLabelTR,
                              j.customerId,
                              j.customerName,
                            ],
                            _query,
                          ),
                        )
                        .toList();
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'İlan bulunamadı.',
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                if (items.isEmpty && _idHit == null) {
                  return Center(
                    child: Text(
                      'Arama sonucu yok. Tam ilan ID yapıştırıp Enter deneyin '
                      'veya daha fazla yükleyin.',
                      textAlign: TextAlign.center,
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
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: controller.loadMore,
                            endLabel: _query.isEmpty
                                ? 'İlan listesinin sonu'
                                : 'Yüklü listede arama',
                          );
                        }
                        return _JobCard(job: items[i]);
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

class _JobFilters extends StatelessWidget {
  const _JobFilters({
    required this.status,
    required this.province,
    required this.onStatus,
    required this.onProvince,
    required this.onClearAll,
    required this.provinceActive,
  });

  final JobStatus? status;
  final String? province;
  final ValueChanged<JobStatus?> onStatus;
  final ValueChanged<String?> onProvince;
  final VoidCallback onClearAll;
  final bool provinceActive;

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
              selected: status == null && !provinceActive,
              onSelected: (_) => onClearAll(),
            ),
            const SizedBox(width: 6),
            for (final s in JobStatus.values) ...[
              FilterChip(
                label: Text(s.labelTR),
                selected: status == s,
                onSelected: (v) => onStatus(v ? s : null),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 8),
            // SEÇİCİ (2026-08-23): elle yazılan il adı yanlış olabiliyor
            // ve sonuç boş liste — yönetici filtrenin mi yanlış, verinin mi
            // yok olduğunu ayırt edemiyordu.
            SizedBox(
              width: 190,
              child: AdminProvincePicker(
                value: province,
                allowClear: true,
                onChanged: onProvince,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.job});
  final Job job;

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    String decision,
  ) async {
    try {
      await ref
          .read(adminJobRepositoryProvider)
          .moderate(job.jobId, decision: decision);
      if (context.mounted) {
        context.showSuccess(switch (decision) {
          'hide' => 'İlan gizlendi.',
          'unhide' => 'İlan tekrar görünür.',
          'force_cancel' => 'İlan iptal edildi ve gizlendi.',
          _ => 'İşlem tamam.',
        });
        ref.invalidate(jobDirectoryControllerProvider);
      }
    } catch (_) {
      if (context.mounted) context.showError('Moderasyon başarısız.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final cat = kProfessionNames[job.category] ?? job.categoryLabelTR;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: job.moderationHidden ? palette.danger : palette.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title.isEmpty ? '(başlıksız)' : job.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: job.status),
                if (job.moderationHidden) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.visibility_off, size: 16, color: palette.danger),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$cat · ${job.province} / ${job.district}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Müşteri: ${job.customerName}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkFaint,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () =>
                      showAdminUserActions(context, ref, job.customerId),
                  child: const Text('Müşteri'),
                ),
                if (!job.moderationHidden)
                  OutlinedButton(
                    onPressed: () => _moderate(context, ref, 'hide'),
                    child: const Text('Gizle'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _moderate(context, ref, 'unhide'),
                    child: const Text('Göster'),
                  ),
                if (job.status != JobStatus.cancelled)
                  TextButton(
                    onPressed: () => _moderate(context, ref, 'force_cancel'),
                    child: Text(
                      'Zorla iptal',
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = switch (status) {
      JobStatus.open => (palette.successSurface, palette.success),
      JobStatus.cancelled ||
      JobStatus.expired => (palette.surfaceMuted, palette.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.labelTR,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

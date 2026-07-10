import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// Müşterinin kendi iş ilanları (İlanlarım). Üst bardaki çöp kutusuyla çoklu
/// seçim modu açılır: ustaya bağlanmamış ilanlar kutucuklarla seçilip topluca
/// silinebilir ("Tümünü seç" dahil).
class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selected.clear();
      });

  void _toggleSelected(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$count ilanı sil'),
        content: const Text('Seçilen ilanlar kalıcı olarak silinecek. '
            'Bu işlem geri alınamaz. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(jobRepositoryProvider);
    var failed = 0;
    for (final id in _selected.toList()) {
      try {
        await repo.deleteJob(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelection();
    if (failed > 0) {
      context.showError('$failed ilan silinemedi, tekrar deneyin.');
    } else {
      context.showInfo(count == 1 ? 'İlan silindi.' : '$count ilan silindi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final jobsAsync =
        user == null ? null : ref.watch(myJobsProvider(user.uid));
    // Silinebilir ilanlar: ustaya bağlanmamış olanlar (Job.canDelete).
    final deletableIds = [
      for (final j in jobsAsync?.valueOrNull ?? const <Job>[])
        if (j.canDelete) j.jobId
    ];

    return PopScope(
      // Geri tuşu seçim modunda ekrandan çıkmasın, seçimi kapatsın.
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: _selectionMode
            ? GradientAppBar(
                title: '${_selected.length} seçildi',
                icon: Icons.delete_outline,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: 'Tümünü seç',
                    onPressed: deletableIds.isEmpty
                        ? null
                        : () => setState(() {
                              // Hepsi seçiliyse seçim kalkar (ikinci basış).
                              if (_selected.length == deletableIds.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(deletableIds);
                              }
                            }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Seçilenleri sil',
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Vazgeç',
                    onPressed: _exitSelection,
                  ),
                ],
              )
            : GradientAppBar(
                title: 'İlanlarım',
                subtitle: () {
                  final jobs = jobsAsync?.valueOrNull;
                  if (jobs == null || jobs.isEmpty) return null;
                  final open = jobs
                      .where((j) => j.effectiveStatus == JobStatus.open)
                      .length;
                  return open > 0
                      ? '$open açık · ${jobs.length} ilan'
                      : '${jobs.length} ilan';
                }(),
                icon: Icons.campaign_outlined,
                actions: [
                  // Pasif (gri) ikon gradyan üzerinde kötü durur — silinecek
                  // ilan yokken çöp kutusu hiç gösterilmez.
                  if (deletableIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'İlan sil',
                      onPressed: () => setState(() => _selectionMode = true),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, right: 12),
                    child: _NewJobButton(),
                  ),
                ],
              ),
        drawer: const AppMenuDrawer(),
        bottomNavigationBar: const MainBottomBar(current: MainTab.work),
        body: user == null
            ? const Center(child: Text('Oturum bulunamadı.'))
            : jobsAsync!.when(
                  loading: () => const SkeletonList(),
                  error: (e, _) =>
                      Center(child: Text('İlanlar yüklenemedi.\n$e')),
                  data: (jobs) => jobs.isEmpty
                      ? const _EmptyJobs()
                      : ResponsiveCenter(
                          maxWidth: 720,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: jobs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final job = jobs[i];
                              return _JobCard(
                                job: job,
                                selectionMode: _selectionMode,
                                selected: _selected.contains(job.jobId),
                                onToggle: job.canDelete
                                    ? () => _toggleSelected(job.jobId)
                                    : null,
                                // Uzun basış da seçim modunu açar (Android
                                // alışkanlığı) — yalnız silinebilir ilanlarda.
                                onEnterSelection: job.canDelete
                                    ? () => setState(() {
                                          _selectionMode = true;
                                          _selected.add(job.jobId);
                                        })
                                    : null,
                              );
                            },
                          ),
                        ),
                ),
      ),
    );
  }
}

/// Gradyan app bar üzerinde beyaz hap şeklinde "Yeni İlan" butonu — lacivert
/// zeminde net bir birincil aksiyon olarak öne çıkar (eski FAB'ın yerine).
class _NewJobButton extends StatelessWidget {
  const _NewJobButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push(RoutePaths.newJob),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Yeni İlan',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    this.selectionMode = false,
    this.selected = false,
    this.onToggle,
    this.onEnterSelection,
  });
  final Job job;
  final bool selectionMode;
  final bool selected;

  /// Seçim modunda karta/kutucuğa dokununca; null = bu ilan silinemez
  /// (ustaya bağlı), kutucuk devre dışı görünür.
  final VoidCallback? onToggle;

  /// Normal modda uzun basınca seçim modunu açar (silinebilir ilanlarda).
  final VoidCallback? onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final status = job.effectiveStatus;
    final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (job.isUrgent) ...[
                    const UrgentBadge(compact: true),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  JobStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${kProfessionNames[job.category] ?? job.category} • '
                '${job.district}${job.neighborhood != null ? ' / ${job.neighborhood}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status == JobStatus.open || status == JobStatus.expired)
                    OfferCountBadge(count: job.offerCount)
                  else
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: 'Usta seçildi',
                    ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                ],
              ),
            ],
          );

    return Material(
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Seçim modunda dokunuş seçimi değiştirir; normalde detaya gider.
        onTap: selectionMode
            ? onToggle
            : () => context.push(RoutePaths.jobDetail(job.jobId)),
        onLongPress: selectionMode ? null : onEnterSelection,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: !selectionMode
              ? content
              : Row(
                  children: [
                    Checkbox(
                      value: selected,
                      // null onToggle: ustaya bağlı ilan — silinemez,
                      // kutucuk devre dışı görünür.
                      onChanged:
                          onToggle == null ? null : (_) => onToggle!(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: content),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 34, color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Henüz ilanınız yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'İş ilanı verin, bölgenizdeki ustalar sizinle iletişime geçsin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.newJob),
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk İlanını Ver'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_menu_drawer.dart';
import '../../../core/widgets/surface_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// Müşterinin kendi iş ilanları (İlanlarım). Üst bardaki çöp kutusuyla çoklu
/// seçim modu açılır: ustaya bağlanmamış ilanlar kutucuklarla seçilip topluca
/// silinebilir ("Tümünü seç" dahil).
class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key, this.onlyProductRequests = false});

  /// true ise yalnız ürün talepleri (Mağaza → Taleplerim).
  final bool onlyProductRequests;

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  /// Yan menü açıkken geri tuşunun menüyü kapatabilmesi için (madde 4).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
              style: FilledButton.styleFrom(
                  backgroundColor: ctx.palette.danger),
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

  /// Ekranın gösterdiği kayıtlar. İŞ İLANI ve ÜRÜN TALEBİ aynı `jobs`
  /// koleksiyonunda durur (yalnız `category` ayırır), bu yüzden liste HER İKİ
  /// yönde de süzülmelidir.
  ///
  /// 2026-08-20 test bulgusu: talep oluşturan kullanıcı onu "İlanlarım"da
  /// görüyordu. Eskiden yalnız `onlyProductRequests` yönü süzülüyordu; ters
  /// yön (İlanlarım'dan talepleri elemek) YAZILMAMIŞTI.
  List<Job> _visible(List<Job> jobs) {
    if (widget.onlyProductRequests) {
      return jobs.where((j) => j.isProductRequest).toList(growable: false);
    }
    return jobs.where((j) => !j.isProductRequest).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final jobsAsync =
        user == null ? null : ref.watch(myJobsProvider(user.uid));
    final visible = _visible(jobsAsync?.valueOrNull ?? const <Job>[]);
    // Silinebilir ilanlar: ustaya bağlanmamış olanlar (Job.canDelete).
    final deletableIds = [
      for (final j in visible)
        if (j.canDelete) j.jobId
    ];
    final talepler = widget.onlyProductRequests;

    return PopScope(
      // Alt bar sekmesi: geri tuşu uygulamayı KAPATMAMALI, Ana Sayfa'ya
      // dönmeli (sekmeler `go()` ile açılır, geçmiş yığını bırakmaz).
      // Sıra: açık yan menü → seçim modu → yığın → Ana Sayfa.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Yan menü açıksa önce onu kapat (madde 4).
        final scaffold = _scaffoldKey.currentState;
        if (scaffold != null && scaffold.isDrawerOpen) {
          scaffold.closeDrawer();
        } else if (_selectionMode) {
          _exitSelection();
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.home);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _selectionMode
            ? SurfaceAppBar(
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
            : SurfaceAppBar(
                title: talepler ? 'Taleplerim' : 'İlanlarım',
                subtitle: () {
                  if (visible.isEmpty) return null;
                  final open = visible
                      .where((j) => j.effectiveStatus == JobStatus.open)
                      .length;
                  // Açık ilan KOTASI burada görünür: kullanıcı limite
                  // çarpmadan önce kaç hakkı kaldığını bilsin (aksi halde
                  // yayınlama anında anlamsız bir ret alıyordu).
                  return open > 0
                      ? '$open/${AppConstants.maxOpenJobs} açık · '
                          '${visible.length} ${talepler ? 'talep' : 'ilan'}'
                      : '${visible.length} ${talepler ? 'talep' : 'ilan'}';
                }(),
                icon: talepler
                    ? Icons.storefront_outlined
                    : Icons.campaign_outlined,
                actions: [
                  // Pasif (gri) ikon gradyan üzerinde kötü durur — silinecek
                  // ilan yokken çöp kutusu hiç gösterilmez.
                  if (deletableIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: talepler ? 'Talep sil' : 'İlan sil',
                      onPressed: () => setState(() => _selectionMode = true),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    child: _NewJobButton(productRequest: talepler),
                  ),
                ],
              ),
        drawer: const AppMenuDrawer(),
        bottomNavigationBar: const MainBottomBar(current: MainTab.work),
        body: user == null
            ? const Center(child: Text('Oturum bulunamadı.'))
            : jobsAsync!.when(
                  loading: () => const SkeletonList(),
                  error: (_, _) => RefreshableEmpty(
                    onRefresh: () => awaitRefresh(() async {
                      ref.invalidate(myJobsProvider(user.uid));
                      await ref.read(myJobsProvider(user.uid).future);
                    }),
                    child: ErrorView(
                        message: 'İlanlar yüklenemedi. Bağlantınızı kontrol '
                            'edip tekrar deneyin.',
                        onRetry: () =>
                            ref.invalidate(myJobsProvider(user.uid))),
                  ),
                  data: (all) {
                    final jobs = _visible(all);
                    return jobs.isEmpty
                      ? RefreshableEmpty(
                          onRefresh: () => awaitRefresh(() async {
                            ref.invalidate(myJobsProvider(user.uid));
                            await ref.read(myJobsProvider(user.uid).future);
                          }),
                          child: _EmptyJobs(productRequests: talepler),
                        )
                      : ResponsiveCenter(
                          maxWidth: 720,
                          child: PullToRefresh(
                            onRefresh: () => awaitRefresh(() async {
                              ref.invalidate(myJobsProvider(user.uid));
                              await ref
                                  .read(myJobsProvider(user.uid).future);
                            }),
                            child: ListView.separated(
                              physics: kPullRefreshPhysics,
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
                        );
                  },
                ),
      ),
    );
  }
}

/// Gradyan app bar üzerinde beyaz hap şeklinde "Yeni İlan" butonu — lacivert
/// zeminde net bir birincil aksiyon olarak öne çıkar (eski FAB'ın yerine).
class _NewJobButton extends StatelessWidget {
  const _NewJobButton({this.productRequest = false});

  final bool productRequest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push(
          productRequest
              ? RoutePaths.newProductRequestJob
              : RoutePaths.newJob,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                productRequest ? 'Yeni Talep' : 'Yeni İlan',
                style: const TextStyle(
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
    final palette = context.palette;
    final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                '${kProfessionNames[job.category] ?? job.categoryLabelTR} • '
                '${job.district}${job.neighborhood != null ? ' / ${job.neighborhood}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: switch (status) {
                      JobStatus.open => Icons.campaign_outlined,
                      JobStatus.cancelled => Icons.block_outlined,
                      JobStatus.expired => Icons.schedule_outlined,
                    },
                    label: status.simpleLabelTR,
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: palette.inkFaint),
                ],
              ),
            ],
          );

    return Material(
      color: selected ? palette.primaryContainer : palette.card,
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
                color: selected ? palette.primary : palette.border),
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
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.inkMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: palette.inkMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs({this.productRequests = false});

  final bool productRequests;

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
              decoration: BoxDecoration(
                color: context.palette.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  productRequests
                      ? Icons.storefront_outlined
                      : Icons.campaign_outlined,
                  size: 34,
                  color: context.palette.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
                productRequests
                    ? 'Henüz ürün talebiniz yok'
                    : 'Henüz ilanınız yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              productRequests
                  ? 'Aradığınız ürünü yazın, ilinizdeki satıcılar görsün.'
                  : 'İş ilanı verin, bölgenizdeki ustalar sizinle iletişime geçsin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.palette.inkMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(
                productRequests
                    ? RoutePaths.newProductRequestJob
                    : RoutePaths.newJob,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(productRequests ? 'Talep oluştur' : 'İlk İlanını Ver'),
            ),
          ],
        ),
      ),
    );
  }
}

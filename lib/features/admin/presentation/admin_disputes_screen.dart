import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_dispute_repository.dart';
import '../data/admin_providers.dart';
import 'admin_users_screen.dart';
import 'paged_footer.dart';

/// Yönetici anlaşmazlık (hakemlik) kuyruğu. `disputed` durumundaki işler
/// listelenir; bir işe dokununca detay + karar (İşi İptal Et / Devam Ettir)
/// açılır. Karar `adminResolveDispute` CF'inden geçer → durum güncellenir,
/// her iki tarafa bildirim gider, denetim kaydı atomik yazılır.
class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(disputeQueueControllerProvider);
    final controller = ref.read(disputeQueueControllerProvider.notifier);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Anlaşmazlıklar',
        icon: Icons.gavel_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? null
            : '${pageAsync.value!.items.length} anlaşmazlık'
                '${pageAsync.value!.hasMore ? '+' : ''}',
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message:
              'Anlaşmazlıklar yüklenemedi. Yetkiniz olduğundan emin olun.',
        ),
        data: (page) {
          if (page.items.isEmpty) return const _Empty();
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ResponsiveCenter(
              maxWidth: 720,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: page.items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == page.items.length) {
                    return PagedFooter(
                      hasMore: page.hasMore,
                      loadingMore: page.loadingMore,
                      onLoadMore: controller.loadMore,
                    );
                  }
                  return _DisputeCard(
                    job: page.items[i],
                    onTap: () => _openDetail(context, page.items[i]),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Job job) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DisputeDetailSheet(job: job),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PartyBadge(party: job.disputedBy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.disputeReason?.labelTR ?? 'Sorun bildirildi',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (job.disputeNote != null && job.disputeNote!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  job.disputeNote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatDate(job.disputedAt ?? job.createdAt),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sorunu bildiren tarafı gösteren rozet.
class _PartyBadge extends StatelessWidget {
  const _PartyBadge({required this.party});
  final JobDisputeParty? party;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, icon) = switch (party) {
      JobDisputeParty.customer => ('Müşteri', Icons.person_outline),
      JobDisputeParty.artisan => ('Usta', Icons.handyman_outlined),
      null => ('Taraf', Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.warning),
          const SizedBox(width: 4),
          Text('$label bildirdi',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.warning)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const ErrorView(
      icon: Icons.verified_outlined,
      title: 'Açık anlaşmazlık yok',
      message: 'Taraflar arasında çözüm bekleyen bir sorun yok.',
    );
  }
}

/// Detay + hakemlik kararı (bottom sheet). Yönetici işi iptal eder ya da
/// devam ettirir; opsiyonel not her iki tarafa bildirilir.
class _DisputeDetailSheet extends ConsumerStatefulWidget {
  const _DisputeDetailSheet({required this.job});
  final Job job;

  @override
  ConsumerState<_DisputeDetailSheet> createState() =>
      _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends ConsumerState<_DisputeDetailSheet> {
  final _noteController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _apply(DisputeDecision decision) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminDisputeRepositoryProvider).resolveDispute(
            widget.job.jobId,
            decision: decision,
            note: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccess(
        decision == DisputeDecision.cancelJob
            ? 'İş iptal edildi.'
            : 'İş kaldığı yerden devam ediyor.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız oldu. Tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final j = widget.job;
    final restoreLabel =
        (j.statusBeforeDispute ?? JobStatus.inProgress).labelTR;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _PartyBadge(party: j.disputedBy),
              const SizedBox(height: 12),
              Text(j.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(j.disputeReason?.labelTR ?? 'Sorun bildirildi',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 12),
              if (j.disputeNote != null && j.disputeNote!.isNotEmpty)
                _InfoBlock(label: 'Bildirim notu', value: j.disputeNote!),
              _InfoBlock(
                  label: 'Sorun öncesi durum',
                  value: (j.statusBeforeDispute ?? JobStatus.inProgress)
                      .labelTR),
              _InfoBlock(label: 'Müşteri (uid)', value: j.customerId),
              if (j.selectedArtisanId != null)
                _InfoBlock(label: 'Usta (uid)', value: j.selectedArtisanId!),
              _InfoBlock(label: 'İlan kimliği', value: j.jobId),
              _InfoBlock(
                  label: 'Bildirim tarihi',
                  value: _formatDate(j.disputedAt ?? j.createdAt)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => showAdminUserActions(context, ref, j.customerId),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Müşteriyi yönet'),
                  ),
                  if (j.selectedArtisanId != null)
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => showAdminUserActions(
                                context,
                                ref,
                                j.selectedArtisanId!,
                              ),
                      icon: const Icon(Icons.handyman_outlined, size: 18),
                      label: const Text('Ustayı yönet'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Karar notu (opsiyonel — her iki tarafa iletilir)',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                enabled: !_busy,
                decoration: const InputDecoration(
                  hintText: 'Kararınıza dair kısa bir açıklama…',
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _apply(DisputeDecision.restoreJob),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('Devam Ettir ($restoreLabel)'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: palette.danger),
                      onPressed: () => _apply(DisputeDecision.cancelJob),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('İşi İptal Et'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: palette.inkFaint)),
          const SizedBox(height: 2),
          SelectableText(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

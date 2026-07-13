import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/report.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_providers.dart';
import '../data/admin_report.dart';
import 'admin_users_screen.dart';

/// Yönetici şikayet kuyruğu. Yalnızca `admin:true` claim'i olan kullanıcı
/// açabilir (yönlendirme guard'ı + Firestore kuralı). Kayıtlar listelenir;
/// bir kayda dokununca detay + karar (incele / çöz / reddet) açılır.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminReportsProvider);

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Şikayet Kuyruğu',
        icon: Icons.flag_outlined,
        subtitle: reportsAsync.valueOrNull == null
            ? null
            : _subtitle(reportsAsync.value!),
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Şikayetler yüklenemedi. Yetkiniz olduğundan emin olun.',
        ),
        data: (all) {
          final list =
              _openOnly ? all.where((r) => !r.status.isClosed).toList() : all;
          return Column(
            children: [
              _FilterBar(
                openOnly: _openOnly,
                openCount: all.where((r) => !r.status.isClosed).length,
                totalCount: all.length,
                onChanged: (v) => setState(() => _openOnly = v),
              ),
              Expanded(
                child: list.isEmpty
                    ? _Empty(openOnly: _openOnly)
                    : ResponsiveCenter(
                        maxWidth: 720,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ReportCard(
                            report: list[i],
                            onTap: () => _openDetail(list[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(List<Report> all) {
    final open = all.where((r) => !r.status.isClosed).length;
    return '$open açık · ${all.length} toplam';
  }

  Future<void> _openDetail(Report report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReportDetailSheet(report: report),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.openOnly,
    required this.openCount,
    required this.totalCount,
    required this.onChanged,
  });

  final bool openOnly;
  final int openCount;
  final int totalCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _Seg(
            label: 'Açık ($openCount)',
            selected: openOnly,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 8),
          _Seg(
            label: 'Tümü ($totalCount)',
            selected: !openOnly,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : palette.inkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final Report report;
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
                  _TargetBadge(target: report.target),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.reason.labelTR,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: report.status),
                ],
              ),
              if (report.note != null && report.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  report.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatDate(report.createdAt),
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

class _TargetBadge extends StatelessWidget {
  const _TargetBadge({required this.target});
  final ReportTarget target;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, icon) = switch (target) {
      ReportTarget.message => ('Mesaj', Icons.chat_bubble_outline),
      ReportTarget.job => ('İlan', Icons.work_outline),
      ReportTarget.user => ('Kullanıcı', Icons.person_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.inkMuted),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.inkMuted)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = switch (status) {
      ReportStatus.open => (palette.warningSurface, palette.warning),
      ReportStatus.reviewing => (palette.infoSurface, palette.info),
      ReportStatus.resolved => (palette.successSurface, palette.success),
      ReportStatus.dismissed => (palette.surfaceMuted, palette.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.labelTR,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.openOnly});
  final bool openOnly;

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      icon: Icons.verified_outlined,
      title: openOnly ? 'Açık şikayet yok' : 'Şikayet yok',
      message: openOnly
          ? 'Kuyruk temiz. Yeni şikayet geldiğinde burada görünür.'
          : 'Henüz hiç şikayet kaydı yok.',
    );
  }
}

/// Detay + karar sayfası (bottom sheet). Yönetici durumu değiştirir; opsiyonel
/// bir çözüm notu ekleyebilir. İşlem sonrası kuyruk kendiliğinden yenilenir.
class _ReportDetailSheet extends ConsumerStatefulWidget {
  const _ReportDetailSheet({required this.report});
  final Report report;

  @override
  ConsumerState<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<_ReportDetailSheet> {
  final _noteController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.report.adminNote ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _apply(ReportStatus status) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminReportRepositoryProvider).updateStatus(
            widget.report.id,
            status: status,
            resolvedBy: uid,
            adminNote: _noteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccess('Şikayet "${status.labelTR}" olarak işaretlendi.');
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
    final r = widget.report;

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
              Row(
                children: [
                  _TargetBadge(target: r.target),
                  const Spacer(),
                  _StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(r.reason.labelTR,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (r.note != null && r.note!.isNotEmpty)
                _InfoBlock(label: 'Şikayet notu', value: r.note!),
              _InfoBlock(label: 'Şikayet eden (uid)', value: r.reporterUid),
              _InfoBlock(label: 'Şikayet edilen (uid)', value: r.reportedUid),
              _InfoBlock(label: 'Hedef kimliği', value: r.targetId),
              if (r.chatId != null)
                _InfoBlock(label: 'Sohbet kimliği', value: r.chatId!),
              _InfoBlock(label: 'Tarih', value: _formatDate(r.createdAt)),
              if (r.resolvedBy != null)
                _InfoBlock(label: 'İşleyen (uid)', value: r.resolvedBy!),
              if (r.reportedUid.isNotEmpty) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => showAdminUserActions(
                            context,
                            ref,
                            r.reportedUid,
                          ),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('Bildirilen kullanıcıyı yönet'),
                ),
              ],
              const SizedBox(height: 12),
              Text('Çözüm notu (opsiyonel)',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                enabled: !_busy,
                decoration: const InputDecoration(
                  hintText: 'Kararınıza dair kısa bir not…',
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
                    if (r.status != ReportStatus.reviewing)
                      OutlinedButton.icon(
                        onPressed: () => _apply(ReportStatus.reviewing),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('İncelemeye Al'),
                      ),
                    FilledButton.icon(
                      onPressed: () => _apply(ReportStatus.resolved),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Çözüldü'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _apply(ReportStatus.dismissed),
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Reddet'),
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

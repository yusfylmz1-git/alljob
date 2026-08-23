import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/report.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_providers.dart';
import '../data/admin_report.dart';
import '../data/admin_report_repository.dart' show ChatTranscript;
import '../data/paged_queue.dart';
import 'admin_users_screen.dart';
import 'paged_footer.dart';

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
    final pageAsync = ref.watch(reportQueueControllerProvider);
    final controller = ref.read(reportQueueControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Şikayet Kuyruğu',
        icon: Icons.flag_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? null
            : _subtitle(pageAsync.value!),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Şikayetler yüklenemedi. Yetkiniz olduğundan emin olun.',
        ),
        data: (page) {
          final all = page.items;
          if (all.isEmpty) return _Empty(openOnly: _openOnly);
          final list = _openOnly
              ? all.where((r) => !r.status.isClosed).toList()
              : all;
          final myUid = ref.read(currentUserProvider)?.uid;
          return Column(
            children: [
              _FilterBar(
                openOnly: _openOnly,
                openCount: all.where((r) => !r.status.isClosed).length,
                totalCount: all.length,
                onChanged: (v) => setState(() => _openOnly = v),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 720,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      // +1: alt "daha fazla" alanı. Filtre boşsa yalnız o + ipucu.
                      itemCount: list.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == list.length) {
                          return Column(
                            children: [
                              if (list.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    _openOnly
                                        ? 'Yüklü kayıtlarda açık şikayet yok.'
                                        : 'Kayıt yok.',
                                    style: TextStyle(
                                      color: context.palette.inkMuted,
                                    ),
                                  ),
                                ),
                              PagedFooter(
                                hasMore: page.hasMore,
                                loadingMore: page.loadingMore,
                                onLoadMore: controller.loadMore,
                              ),
                            ],
                          );
                        }
                        return _ReportCard(
                          report: list[i],
                          myUid: myUid,
                          onTap: () => _openDetail(list[i]),
                        );
                      },
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

  String _subtitle(PagedData<Report> page) {
    final open = page.items.where((r) => !r.status.isClosed).length;
    return '$open açık · ${page.items.length} yüklü${page.hasMore ? '+' : ''}';
  }

  Future<void> _openDetail(Report report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return SizedBox(
          height: h * 0.92,
          child: _ReportDetailSheet(report: report),
        );
      },
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
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
  const _ReportCard({required this.report, required this.onTap, this.myUid});
  final Report report;
  final String? myUid;
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatDate(report.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                  const Spacer(),
                  if (report.assignedTo != null)
                    _AssignBadge(mine: report.assignedTo == myUid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şikayeti bir yöneticinin üstlendiğini gösteren rozet ("Bende" / "Üstlenildi").
class _AssignBadge extends StatelessWidget {
  const _AssignBadge({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = mine
        ? (palette.infoSurface, palette.info)
        : (palette.surfaceMuted, palette.inkMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mine ? Icons.person_pin : Icons.lock_person_outlined,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            mine ? 'Bende' : 'Üstlenildi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sohbet kanıtı listesi. Şikayet edilen mesaj VURGULANIR (moderatör 100
/// mesaj içinde gözle aramasın); gönderen uid yerine görünen ad yazılır.
class _TranscriptList extends StatefulWidget {
  const _TranscriptList({required this.transcript});

  final ChatTranscript transcript;

  @override
  State<_TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<_TranscriptList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // Şikayet edilen mesaja kaydır: uzun sohbette elle aramak gerekmesin.
    final idx = widget.transcript.messages.indexWhere(
      (m) => m.id == widget.transcript.reportedMessageId,
    );
    if (idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        // Sabit satır yüksekliği varsaymak yerine oransal konum: liste
        // yüksekliği bilinmediğinden yaklaşık kaydırma yeterli.
        final target = (idx / widget.transcript.messages.length) *
            _controller.position.maxScrollExtent;
        _controller.jumpTo(target.clamp(
          0.0,
          _controller.position.maxScrollExtent,
        ));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// uid → görünen ad; bilinmiyorsa uid'in ilk 6 hanesi (ham uid duvarı olmasın).
  String _name(String uid) {
    final n = widget.transcript.names[uid];
    if (n != null && n.isNotEmpty) return n;
    if (uid.isEmpty) return 'Bilinmiyor';
    return uid.length <= 6 ? uid : '${uid.substring(0, 6)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final t = widget.transcript;

    return ListView.builder(
      controller: _controller,
      itemCount: t.messages.length,
      itemBuilder: (_, i) {
        final m = t.messages[i];
        final isReported = m.id == t.reportedMessageId;
        final text = m.deleted
            ? '(gönderen sildi)'
            : (m.text?.isNotEmpty == true ? m.text! : '(metin yok)');

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isReported
                ? palette.warningSurface
                : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: isReported
                ? Border.all(color: palette.warning, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isReported) ...[
                    Icon(Icons.flag_rounded,
                        size: 14, color: palette.warning),
                    const SizedBox(width: 4),
                    Text(
                      'ŞİKAYET EDİLEN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _name(m.senderUid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _shortTime(m.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.inkMuted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: m.deleted ? FontStyle.italic : null,
                  color: m.deleted ? palette.inkMuted : null,
                ),
              ),
              // Zaten kaldırılmış mesaj: yönetici tekrar kaldırmaya çalışmasın.
              if (m.moderationHidden) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, size: 12, color: palette.danger),
                    const SizedBox(width: 4),
                    Text(
                      'Yönetici kaldırdı (kullanıcılara görünmüyor)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// ISO/Timestamp metninden "gg.aa ss:dd" — tam tarih kartı şişiriyordu.
  static String _shortTime(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return '';
    final l = d.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(l.day)}.${p(l.month)} ${p(l.hour)}:${p(l.minute)}';
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
      ReportTarget.staffWorker => ('Eleman profili', Icons.badge_outlined),
      ReportTarget.staffNeed => ('Eleman ilanı', Icons.campaign_outlined),
      ReportTarget.product => ('Ürün', Icons.storefront_outlined),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.inkMuted,
            ),
          ),
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
      await ref
          .read(adminReportRepositoryProvider)
          .updateStatus(
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

  Future<void> _assign(bool assign) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminReportRepositoryProvider)
          .assignReport(widget.report.id, assign: assign, adminUid: uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccess(
        assign ? 'Şikayeti üstlendiniz.' : 'Şikayet bırakıldı.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız oldu. Tekrar deneyin.');
    }
  }

  /// Şikayet edilen mesajı kaldır / geri al (adminModerateMessage CF).
  /// Hedef mesaj SUNUCUDA şikayet kaydından türetilir. Sheet kapanmaz —
  /// yönetici ardından şikayeti karara bağlayabilir.
  Future<void> _moderateMessage(bool hidden) async {
    if (hidden) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mesaj kaldırılsın mı?'),
          content: const Text(
            'Mesaj her iki tarafta da "yönetici tarafından kaldırıldı" '
            'olarak görünecek ve gönderen bunu geri alamaz.\n\n'
            'Mesaj metni kanıt olarak şikayet kaydına yazılır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaldır'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adminReportRepositoryProvider)
          .moderateMessage(reportId: widget.report.id, hidden: hidden);
      if (!mounted) return;
      setState(() => _busy = false);
      context.showSuccess(
        hidden ? 'Mesaj kaldırıldı.' : 'Mesaj geri yüklendi.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError(
        'İşlem başarısız oldu. Yetkinizi ve mesajın hâlâ var olduğunu '
        'kontrol edin.',
      );
    }
  }

  Future<void> _openTranscript() async {
    final r = widget.report;
    final chatId = r.chatId;
    if (chatId == null || chatId.isEmpty) {
      context.showError('Bu şikayette sohbet kimliği yok.');
      return;
    }
    setState(() => _busy = true);
    try {
      final transcript = await ref
          .read(adminReportRepositoryProvider)
          .fetchChatTranscript(reportId: r.id, chatId: chatId);
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sohbet kanıtı'),
          content: SizedBox(
            width: 460,
            height: 400,
            child: transcript.isEmpty
                ? const Text('Mesaj yok veya yetki yok (chats.read).')
                : _TranscriptList(transcript: transcript),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('Transcript alınamadı (yetki, bağlam veya limit).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.report;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
              Row(
                children: [
                  _TargetBadge(target: r.target),
                  const Spacer(),
                  _StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                r.reason.labelTR,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (r.note != null && r.note!.isNotEmpty)
                _InfoBlock(label: 'Şikayet notu', value: r.note!),
              // Kaldırma anında saklanan kanıt: sohbet/mesaj sonradan silinse
              // de kararın gerekçesi burada durur.
              if (r.evidenceCapturedAt != null)
                _InfoBlock(
                  label: 'Kaldırılan mesaj (kanıt · '
                      '${_formatDate(r.evidenceCapturedAt!)})',
                  value: [
                    if (r.evidenceText?.isNotEmpty == true) r.evidenceText!,
                    if (r.evidenceHasImage) '[fotoğraf ekliydi]',
                    if ((r.evidenceText?.isEmpty ?? true) &&
                        !r.evidenceHasImage)
                      '(metin yoktu)',
                  ].join('\n'),
                ),
              // Taraflar — şikayet EDEN ile EDİLEN asla karışmasın.
              Text(
                'Taraflar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _InfoBlock(
                label: 'Şikayet eden (şikâyetçi)',
                // `system` çevirisi KORUNUYOR: otomatik filtre kaldırıldı
                // (2026-08-23) ama kısa süre canlıda kaldığı için birkaç
                // eski kayıt kuyrukta olabilir. Ham uid gösterilirse
                // moderatör "system" adlı bir kullanıcı arar.
                value: r.reporterUid.isEmpty
                    ? 'Hesap silindi'
                    : r.reporterUid == 'system'
                        ? 'Otomatik filtre (kaldırıldı)'
                        : r.reporterUid,
              ),
              _InfoBlock(
                label: 'Şikayet edilen (hedef kişi)',
                value: r.reportedUid.isEmpty ? '—' : r.reportedUid,
              ),
              _InfoBlock(label: 'Hedef kayıt', value: r.targetId),
              if (r.chatId != null)
                _InfoBlock(label: 'Sohbet', value: r.chatId!),
              _InfoBlock(label: 'Tarih', value: _formatDate(r.createdAt)),
              if (r.resolvedBy != null)
                _InfoBlock(label: 'İşleyen', value: r.resolvedBy!),
              if (r.assignedTo != null)
                _InfoBlock(
                  label: 'Üstlenen',
                  value: r.assignedTo == ref.read(currentUserProvider)?.uid
                      ? 'Siz'
                      : r.assignedTo!,
                ),

              // ── Birincil karar (en sık iş) ──
              const SizedBox(height: 16),
              Text(
                'Karar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 3,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Çözüm notu (isteğe bağlı)',
                  hintText: 'Kısa not…',
                ),
              ),
              const SizedBox(height: 12),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _apply(ReportStatus.resolved),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Çözüldü — kapat'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _apply(ReportStatus.dismissed),
                    icon: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('Geçersiz — kapat'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
                if (r.status != ReportStatus.reviewing) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _apply(ReportStatus.reviewing),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('İncelemeye al'),
                  ),
                ],

                // ── İkincil eylemler ──
                const SizedBox(height: 20),
                Text(
                  'İşlemler',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (!r.status.isClosed)
                  Builder(
                    builder: (context) {
                      final myUid = ref.read(currentUserProvider)?.uid;
                      final mine =
                          r.assignedTo != null && r.assignedTo == myUid;
                      if (r.assignedTo == null) {
                        return OutlinedButton.icon(
                          onPressed: () => _assign(true),
                          icon:
                              const Icon(Icons.pan_tool_alt_outlined, size: 18),
                          label: const Text('Şikayeti üstlen'),
                        );
                      }
                      if (mine) {
                        return OutlinedButton.icon(
                          onPressed: () => _assign(false),
                          icon: const Icon(
                            Icons.free_cancellation_outlined,
                            size: 18,
                          ),
                          label: const Text('Üstlenmeyi bırak'),
                        );
                      }
                      return OutlinedButton.icon(
                        onPressed: () => _assign(true),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Devral'),
                      );
                    },
                  ),
                if (r.chatId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openTranscript,
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text('Sohbet kanıtını aç'),
                  ),
                ],
                if (r.target == ReportTarget.message) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _moderateMessage(true),
                        icon: const Icon(Icons.gavel_rounded, size: 18),
                        label: const Text('Mesajı kaldır'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _moderateMessage(false),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Mesajı geri al'),
                      ),
                    ],
                  ),
                ],
                if (r.reportedUid.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => showAdminUserActions(
                      context,
                      ref,
                      r.reportedUid,
                      contextHint:
                          'Şikayet EDİLEN kişi — askı / not (rol atama yok)',
                    ),
                    icon: const Icon(Icons.gpp_bad_outlined, size: 18),
                    label: const Text('Şikayet edileni askıya al / not'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ],
        ],
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
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../data/admin_audit_repository.dart';
import '../data/admin_providers.dart';

/// Yönetici denetim kaydı görüntüleyici (`adminAuditLogs`). Her yetkili eylem
/// (rol atama, şikayet kararı, askıya alma…) burada izlenir —
/// hesap verebilirlik + KVKK/GDPR. Yalnız süper yöneticiye açık (gözetim).
/// Kategori çipleri + aktör/hedef uid araması ile süzülür (istemci-tarafı,
/// yüklü 200 kayıt penceresi üzerinde).
class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  final _query = TextEditingController();
  AuditCategory _category = AuditCategory.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(auditLogControllerProvider);
    final controller = ref.read(auditLogControllerProvider.notifier);
    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Denetim Kaydı',
        icon: Icons.receipt_long_outlined,
        subtitle: pageAsync.valueOrNull == null
            ? 'Kim ne yaptı — okunabilir özet'
            : '${pageAsync.value!.entries.length} kayıt'
                  '${pageAsync.value!.hasMore ? '+' : ''}',
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
          message: 'Denetim kaydı yüklenemedi. Yetkiniz olduğundan emin olun.',
        ),
        data: (page) {
          if (page.entries.isEmpty) {
            return const ErrorView(
              icon: Icons.history_outlined,
              title: 'Kayıt yok',
              message: 'Henüz kaydedilmiş bir yönetici eylemi yok.',
            );
          }
          final list = filterAudit(
            page.entries,
            category: _category,
            query: _query.text,
          );
          return Column(
            children: [
              _FilterBar(
                category: _category,
                query: _query,
                onCategory: (c) => setState(() => _category = c),
                onQueryChanged: () => setState(() {}),
              ),
              Expanded(
                child: list.isEmpty
                    ? _NoMatch(hasMore: page.hasMore, controller: controller)
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: ResponsiveCenter(
                          maxWidth: 720,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            // +1 satır: alt "daha fazla" alanı.
                            itemCount: list.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              if (i == list.length) {
                                return _LoadMoreFooter(
                                  page: page,
                                  onLoadMore: controller.loadMore,
                                );
                              }
                              return _AuditCard(entry: list[i]);
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
}

/// Filtre hiçbir yüklü kaydı geçirmediğinde: daha eski kayıtlar varsa yüklemeyi
/// öner (aranan kayıt henüz yüklenmemiş olabilir).
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.hasMore, required this.controller});
  final bool hasMore;
  final AuditLogController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: palette.inkFaint),
            const SizedBox(height: 12),
            Text(
              'Eşleşen kayıt yok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filtreyi değiştirin ya da daha eski kayıtları yükleyin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
              ),
            ),
            if (hasMore) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: controller.loadMore,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Daha eski kayıtları yükle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste altındaki "daha fazla" alanı: yüklüyorsa spinner, daha varsa buton,
/// yoksa "sonu" ibaresi.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.page, required this.onLoadMore});
  final AuditPage page;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: page.loadingMore
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : page.hasMore
            ? OutlinedButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: const Text('Daha fazla yükle'),
              )
            : Text(
                'Kaydın sonu',
                style: TextStyle(color: palette.inkFaint, fontSize: 12),
              ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.query,
    required this.onCategory,
    required this.onQueryChanged,
  });

  final AuditCategory category;
  final TextEditingController query;
  final ValueChanged<AuditCategory> onCategory;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: query,
            onChanged: (_) => onQueryChanged(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Aktör veya hedef UID ara…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        query.clear();
                        onQueryChanged();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in AuditCategory.values) ...[
                  ChoiceChip(
                    label: Text(c.labelTR),
                    selected: category == c,
                    onSelected: (_) => onCategory(c),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final detail = entry.detailSummary;
    final targetId = entry.targetId;
    final shortActor = _shortId(entry.actorUid);
    final shortTarget =
        targetId == null || targetId.isEmpty ? null : _shortId(targetId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(entry.action), size: 18, color: palette.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.actionLabelTR,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.person_outline,
                label: 'Yapan · $shortActor',
              ),
              if (shortTarget != null)
                _MetaChip(
                  icon: Icons.gps_fixed,
                  label: '${entry.targetTypeLabelTR} · $shortTarget',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(entry.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  /// Tam UID yerine okunabilir kısa imza (kopyalanabilir tam id ayrıntıda yok —
  /// arama kutusu hâlâ tam UID ile çalışır).
  static String _shortId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  IconData _icon(String action) => switch (action) {
    'grant_admin' || 'set_role' || 'set_capabilities' =>
      Icons.workspace_premium_outlined,
    'revoke_admin' => Icons.remove_moderator_outlined,
    'suspend_user' || 'bulk_suspend' => Icons.gpp_bad_outlined,
    'unsuspend_user' => Icons.lock_open_outlined,
    'resolve_report' => Icons.flag_outlined,
    'claim_report' => Icons.pan_tool_alt_outlined,
    'release_report' => Icons.free_cancellation_outlined,
    'resolve_dispute' => Icons.gavel_outlined,
    'hide_message' => Icons.speaker_notes_off_outlined,
    'unhide_message' => Icons.undo_rounded,
    'set_artisan_flags' => Icons.handyman_outlined,
    'moderate_job' => Icons.work_outline,
    'moderate_product' => Icons.inventory_2_outlined,
    'grant_premium' => Icons.workspace_premium,
    'broadcast' => Icons.campaign_outlined,
    'update_config' => Icons.tune_outlined,
    'export' => Icons.download_outlined,
    'stats_rebuild' => Icons.restart_alt,
    _ => Icons.history_outlined,
  };
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.inkFaint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.inkMuted,
              fontFamily: 'monospace',
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

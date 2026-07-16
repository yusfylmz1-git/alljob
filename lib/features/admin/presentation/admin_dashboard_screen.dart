import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../data/admin_providers.dart';
import '../data/admin_stats_repository.dart';
import 'admin_chrome.dart';

/// Admin Özet: adminStats KPI + yaklaşık kuyruk pencereleri (PR5+PR6).
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, this.onOpenSection});

  final void Function(int sectionIndex)? onOpenSection;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _rebuilding = false;

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    try {
      await ref.read(adminStatsRepositoryProvider).rebuild();
      if (mounted) context.showSuccess('Sayaçlar yeniden kuruldu.');
    } catch (_) {
      if (mounted) {
        context.showError(
            'Yeniden kurulum başarısız (10 dk limit veya yetki).');
      }
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isSuper = ref.watch(isSuperAdminProvider);
    final statsAsync = ref.watch(adminStatsProvider);
    final openReportsApprox = ref.watch(openReportCountProvider);
    final openDisputesApprox = ref.watch(openDisputeCountProvider);
    final reportWindow =
        ref.watch(adminReportsProvider).valueOrNull?.length;
    final disputeWindow =
        ref.watch(adminDisputesProvider).valueOrNull?.length;

    final stats = statsAsync.valueOrNull ?? const AdminStatsSnapshot();

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Kontrol paneli',
        icon: Icons.dashboard_outlined,
        subtitle: stats.updatedAt == null
            ? 'Sayaçlar henüz yok — yeniden kur'
            : 'Son güncelleme: ${stats.updatedAt!.toLocal()}',
        actions: [
          if (isSuper)
            FilledButton.tonalIcon(
              onPressed: _rebuilding ? null : _rebuild,
              icon: _rebuilding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Sayaçları yenile'),
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1100,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: ListView(
          children: [
            if (stats.isStale)
              Card(
                color: palette.warningSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: palette.warning.withValues(alpha: 0.35)),
                ),
                child: ListTile(
                  leading: Icon(Icons.warning_amber, color: palette.warning),
                  title: const Text('Sayaçlar güncel değil veya boş',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    isSuper
                        ? 'Üstten “Sayaçları yenile” ile tam tarama '
                            '(en fazla 10 dakikada bir).'
                        : 'Superadmin yeniden kurulum çalıştırmalı.',
                    style: TextStyle(color: palette.inkMuted, fontSize: 12),
                  ),
                ),
              ),
            if (stats.isStale) const SizedBox(height: 16),
            Text('Platform KPI',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Kaynak: adminStats/global (olay bazlı). Operasyon için birincil metrikler.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 14),
            _kpiGrid(context, [
              _KpiCard(
                title: 'Kayıtlı kullanıcı',
                value: '${stats.usersTotal}',
                icon: Icons.people_outline,
                color: palette.primary,
              ),
              _KpiCard(
                title: 'Askıdaki kullanıcı',
                value: '${stats.usersSuspended}',
                icon: Icons.block,
                color: palette.danger,
              ),
              _KpiCard(
                title: 'Usta profili',
                value: '${stats.artisansTotal}',
                icon: Icons.handyman_outlined,
                color: palette.primary,
              ),
              _KpiCard(
                title: 'Açık şikayet (sayaç)',
                value: '${stats.openReports}',
                icon: Icons.flag_outlined,
                color: palette.warning,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(1),
              ),
              _KpiCard(
                title: 'Açık anlaşmazlık (sayaç)',
                value: '${stats.openDisputes}',
                icon: Icons.gavel_outlined,
                color: palette.danger,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(2),
              ),
              _KpiCard(
                title: 'İlanlar (toplam)',
                value: '${stats.jobsTotal}',
                icon: Icons.work_outline,
                color: palette.primary,
                subtitle:
                    'Açık ${stats.jobsOpen} · Süren ${stats.jobsInProgress} · '
                    'Biten ${stats.jobsCompleted}',
              ),
              _KpiCard(
                title: 'İlan — anlaşmazlık / iptal',
                value: '${stats.jobsDisputed} / ${stats.jobsCancelled}',
                icon: Icons.balance_outlined,
                color: palette.inkMuted,
              ),
            ]),
            const SizedBox(height: 24),
            Text('Yaklaşık kuyruk pencereleri',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Canlı stream tavanı (son ~200). Tam toplam değildir — üstteki '
              'KPI tercih edilmeli.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 12),
            _kpiGrid(context, [
              _KpiCard(
                title:
                    'Son ${reportWindow ?? 200} kayıttaki açık şikayet',
                value: '$openReportsApprox',
                icon: Icons.flag_outlined,
                color: palette.warning,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(1),
              ),
              _KpiCard(
                title:
                    'Açık anlaşmazlık (max ${disputeWindow ?? 200})',
                value: '$openDisputesApprox',
                icon: Icons.gavel_outlined,
                color: palette.danger,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(2),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Hızlı erişim',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (1, Icons.flag_outlined, 'Şikayetler'),
                  (2, Icons.gavel_outlined, 'Anlaşmazlıklar'),
                  (3, Icons.manage_accounts_outlined, 'Kullanıcılar'),
                  (4, Icons.handyman_outlined, 'Ustalar'),
                  (5, Icons.work_outline, 'İlanlar'),
                  (7, Icons.support_agent_outlined, 'Destek'),
                  (8, Icons.campaign_outlined, 'Bildirim'),
                  (9, Icons.storefront_outlined, 'Platform'),
                ])
                  ActionChip(
                    avatar: Icon(e.$2, size: 18),
                    label: Text(e.$3),
                    onPressed: widget.onOpenSection == null
                        ? null
                        : () => widget.onOpenSection!(e.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Ops notu: Platform (marka/duyuru) ve Bildirim superadmin '
              'config.manage ile yönetilir. Sistem bayrakları menüde “Sistem”.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkFaint, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, List<_KpiCard> cards) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 960
            ? 3
            : c.maxWidth >= 560
                ? 2
                : 1;
        final gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: w, child: card),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminChrome.metricCard(
      context: context,
      label: title,
      value: value,
      icon: icon,
      accent: color,
      onTap: onTap,
      hint: subtitle,
    );
  }
}

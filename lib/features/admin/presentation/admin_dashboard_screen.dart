import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../data/admin_daily_stats_repository.dart';
import '../data/admin_export_util.dart';
import '../data/admin_insights_repository.dart';
import '../data/admin_providers.dart';
import '../data/admin_stats_repository.dart';
import 'admin_charts.dart';
import 'admin_chrome.dart';

/// Admin Özet: KPI + superadmin dağılım içgörüleri (bölge / meslek / ürün).
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, this.onOpenSection});

  final void Function(int sectionIndex)? onOpenSection;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _rebuilding = false;

  /// Günlük sayaçları CSV olarak panoya kopyalar.
  ///
  /// İndirme yerine PANO: admin paneli web'de çalışır ve mevcut dışa aktarma
  /// deseni (kullanıcılar, ilanlar) da böyledir — tarayıcı indirme izni,
  /// dosya adı ve mobil uyumu derdi olmadan yapıştırılabilir.
  Future<void> _exportDaily(List<AdminDailyStat> rows) async {
    final caps = ref.read(adminCapabilitiesProvider);
    if (!caps.allows('export.run')) {
      context.showError('export.run yetkisi yok.');
      return;
    }
    if (rows.isEmpty) {
      context.showError('Dışa aktarılacak veri yok.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: buildDailyStatsCsv(rows)));
    if (!mounted) return;
    context.showSuccess(
      '${rows.length} günlük satır panoya kopyalandı. '
      'Excel/Sheets içine yapıştırabilirsiniz.',
    );
  }

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    try {
      await ref.read(adminStatsRepositoryProvider).rebuild();
      ref.invalidate(adminInsightsProvider);
      ref.invalidate(adminDailyStatsProvider);
      if (mounted) context.showSuccess('Sayaçlar yeniden kuruldu.');
    } catch (_) {
      if (mounted) {
        context.showError(
          'Yeniden kurulum başarısız (10 dk limit veya yetki).',
        );
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
    final insightsAsync = ref.watch(adminInsightsProvider);
    final dailyAsync = ref.watch(adminDailyStatsProvider);
    final openReportsApprox = ref.watch(openReportCountProvider);
    final reportWindow = ref.watch(adminReportsProvider).valueOrNull?.length;

    final stats = statsAsync.valueOrNull ?? const AdminStatsSnapshot();

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Kontrol paneli',
        icon: Icons.dashboard_outlined,
        subtitle: stats.updatedAt == null
            ? 'Sayaçlar henüz yok — yeniden kur'
            : 'KPI: ${stats.updatedAt!.toLocal()}',
        actions: [
          if (isSuper)
            IconButton(
              tooltip: 'Dağılım içgörülerini yenile',
              onPressed: () => ref.invalidate(adminInsightsProvider),
              icon: const Icon(Icons.analytics_outlined),
            ),
          if (isSuper)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: FilledButton.tonalIcon(
                onPressed: _rebuilding ? null : _rebuild,
                icon: _rebuilding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  AdminChrome.isCompact(context)
                      ? 'KPI'
                      : 'Sayaçları yenile',
                ),
              ),
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
                  side: BorderSide(
                    color: palette.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.warning_amber, color: palette.warning),
                  title: const Text(
                    'Sayaçlar güncel değil veya boş',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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

            // ── Operasyon kuyrukları ─────────────────────────────
            _SectionTitle(
              title: 'Bugün ne yapmalıyım?',
              subtitle:
                  'Önce kuyruklar, sonra kişiler. Kişi dosyası = Kullanıcılar.',
            ),
            const SizedBox(height: 12),
            _kpiGrid(context, [
              _KpiCard(
                title: 'Açık şikayet',
                value: '${stats.openReports}',
                icon: Icons.flag_outlined,
                color: palette.warning,
                subtitle: openReportsApprox > 0
                    ? 'Pencerede ~$openReportsApprox'
                    : 'Şikayetler sekmesi',
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(2),
              ),
              _KpiCard(
                title: 'Askıdaki hesap',
                value: '${stats.usersSuspended}',
                icon: Icons.block,
                color: palette.danger,
                subtitle: 'Kullanıcılar → Askıda',
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(1),
              ),
              _KpiCard(
                title: 'Yayındaki ürün',
                value: '${stats.productsTotal}',
                icon: Icons.inventory_2_outlined,
                color: palette.primary,
                subtitle: 'Ürünler · inceleme kuyruğu',
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(5),
              ),
            ]),

            const SizedBox(height: 28),
            _SectionTitle(
              title: 'Platform KPI',
              subtitle: 'Kaynak: adminStats/global (olay bazlı, tam sayaç).',
            ),
            const SizedBox(height: 12),
            _kpiGrid(context, [
              _KpiCard(
                title: 'Kayıtlı kullanıcı',
                value: '${stats.usersTotal}',
                icon: Icons.people_outline,
                color: palette.primary,
              ),
              _KpiCard(
                title: 'Usta profili',
                value: '${stats.artisansTotal}',
                icon: Icons.handyman_outlined,
                color: palette.primary,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(3),
              ),
              _KpiCard(
                title: 'İlanlar (toplam)',
                value: '${stats.jobsTotal}',
                icon: Icons.work_outline,
                color: palette.primary,
                subtitle: 'Açık ${stats.jobsOpen} · '
                    'Kapalı ${stats.jobsCancelled}',
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(4),
              ),
              if (stats.jobsOther > 0)
                _KpiCard(
                  title: 'Eski durumlu ilan',
                  value: '${stats.jobsOther}',
                  icon: Icons.history_outlined,
                  color: palette.inkMuted,
                  subtitle: 'Kaldırılmış durum değeri',
                ),
              _KpiCard(
                title: 'Açık ilan oranı',
                value: stats.jobsTotal == 0
                    ? '—'
                    : '%${((stats.jobsOpen / stats.jobsTotal) * 100).round()}',
                icon: Icons.pie_chart_outline,
                color: palette.info,
                subtitle: '${stats.jobsOpen} / ${stats.jobsTotal}',
              ),
              _KpiCard(
                title: 'Usta / kullanıcı',
                value: stats.usersTotal == 0
                    ? '—'
                    : '%${((stats.artisansTotal / stats.usersTotal) * 100).round()}',
                icon: Icons.groups_outlined,
                color: palette.info,
                subtitle: 'Profil açmış oran',
              ),
            ]),

            // ── Günlük eğilim (gerçek sayım, örneklem DEĞİL) ─────
            //
            // Kaynak `adminStats/daily/days`: CF her olayda +1 yazar.
            // İçgörülerin aksine superadmin'e kapalı değil — 30 doküman
            // okur, ucuzdur ve moderatörün de işine yarar.
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    title: 'Günlük eğilim (son 30 gün)',
                    subtitle: 'Olay bazlı gerçek sayım. Ürün talebi, hizmet '
                        'ilanından ayrı gösterilir.',
                  ),
                ),
                if (dailyAsync.valueOrNull?.isNotEmpty ?? false)
                  TextButton.icon(
                    onPressed: () => _exportDaily(dailyAsync.value!),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            dailyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Card(
                color: palette.dangerSurface,
                elevation: 0,
                child: ListTile(
                  leading: Icon(Icons.error_outline, color: palette.danger),
                  title: const Text('Eğilim yüklenemedi'),
                  subtitle: Text(
                    '$e',
                    style: TextStyle(fontSize: 12, color: palette.inkMuted),
                  ),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(adminDailyStatsProvider),
                    child: const Text('Tekrar'),
                  ),
                ),
              ),
              data: (rows) => _DailyTrendBody(rows: rows),
            ),

            // ── Superadmin dağılım içgörüleri ────────────────────
            if (isSuper) ...[
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Dağılım içgörüleri',
                subtitle:
                    'Son ~400 kayıt örneklemi (canlı okuma). Tam sayaç değil — '
                    '“en çok nerede / hangi kategori?” sorusu için.',
              ),
              const SizedBox(height: 12),
              insightsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Card(
                  color: palette.dangerSurface,
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: palette.danger),
                    title: const Text('İçgörüler yüklenemedi'),
                    subtitle: Text(
                      '$e',
                      style: TextStyle(fontSize: 12, color: palette.inkMuted),
                    ),
                    trailing: TextButton(
                      onPressed: () => ref.invalidate(adminInsightsProvider),
                      child: const Text('Tekrar'),
                    ),
                  ),
                ),
                data: (ins) {
                  if (ins == null || ins.isEmpty) {
                    return Text(
                      'Örneklem boş — henüz veri yok veya okuma başarısız.',
                      style: TextStyle(color: palette.inkMuted),
                    );
                  }
                  return _InsightsBody(
                    insights: ins,
                    onOpenSection: widget.onOpenSection,
                  );
                },
              ),
            ],

            const SizedBox(height: 28),
            _SectionTitle(
              title: 'Yaklaşık kuyruk penceresi',
              subtitle:
                  'Canlı stream tavanı (son ~${reportWindow ?? 200}). '
                  'Tam toplam için üstteki KPI.',
            ),
            const SizedBox(height: 12),
            _kpiGrid(context, [
              _KpiCard(
                title: 'Penceredeki açık şikayet',
                value: '$openReportsApprox',
                icon: Icons.flag_outlined,
                color: palette.warning,
                onTap: widget.onOpenSection == null
                    ? null
                    : () => widget.onOpenSection!(2),
              ),
            ]),

            const SizedBox(height: 28),
            _SectionTitle(title: 'Hızlı erişim'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  (1, Icons.people_alt_outlined, 'Kullanıcılar'),
                  (2, Icons.flag_outlined, 'Şikayetler'),
                  (3, Icons.handyman_outlined, 'Usta vitrini'),
                  (4, Icons.work_outline, 'İlanlar'),
                  (5, Icons.inventory_2_outlined, 'Ürünler'),
                  (6, Icons.support_agent_outlined, 'Destek'),
                  (7, Icons.campaign_outlined, 'Bildirim'),
                  (8, Icons.storefront_outlined, 'Platform'),
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
              'İş akışı: Şikayetler → karar · kişi dosyası · ürün/ilan. '
              'Dağılım paneli superadmin. Rol: Kadro. Sistem: Sistem.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkFaint,
                height: 1.35,
              ),
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
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

// ── Dağılım paneli ──────────────────────────────────────────────────────────

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.insights, this.onOpenSection});

  final AdminInsights insights;
  final void Function(int sectionIndex)? onOpenSection;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final i = insights;
    String pct(int n, int d) =>
        d == 0 ? '—' : '%${((n / d) * 100).round()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini KPI strip from sample
        _kpiGrid(context, [
          _KpiCard(
            title: 'Son 7 gün ilan',
            value: '${i.jobsLast7d}',
            icon: Icons.schedule,
            color: palette.primary,
            subtitle: 'Örneklem ${i.jobsSampled} ilan',
            onTap: onOpenSection == null ? null : () => onOpenSection!(4),
          ),
          _KpiCard(
            title: 'Son 7 gün kayıt',
            value: '${i.usersLast7d}',
            icon: Icons.person_add_alt_1_outlined,
            color: palette.primary,
            subtitle: 'Örneklem ${i.usersSampled} kullanıcı',
            onTap: onOpenSection == null ? null : () => onOpenSection!(1),
          ),
          _KpiCard(
            title: 'İnceleme bekleyen ürün',
            value: '${i.productsPendingReview}',
            icon: Icons.hourglass_top_outlined,
            color: palette.warning,
            subtitle: 'Örneklem ${i.productsSampled}',
            onTap: onOpenSection == null ? null : () => onOpenSection!(5),
          ),
          _KpiCard(
            title: 'Belge bekleyen usta',
            value: '${i.artisansCertPending}',
            icon: Icons.badge_outlined,
            color: palette.warning,
            subtitle: 'Örneklem ${i.artisansSampled}',
            onTap: onOpenSection == null ? null : () => onOpenSection!(3),
          ),
          _KpiCard(
            title: 'Örneklemde açık ilan',
            value: '${i.jobsOpenInSample}',
            icon: Icons.work_outline,
            color: palette.info,
            subtitle: 'Son ${i.jobsSampled} ilan',
          ),
          _KpiCard(
            title: 'Usta oranı (örnek)',
            value: pct(i.usersWithArtisan, i.usersSampled),
            icon: Icons.handyman_outlined,
            color: palette.info,
            subtitle: '${i.usersWithArtisan}/${i.usersSampled}',
          ),
          _KpiCard(
            title: 'Tel. doğrulanmış',
            value: pct(i.usersPhoneVerified, i.usersSampled),
            icon: Icons.verified_user_outlined,
            color: palette.success,
            subtitle: '${i.usersPhoneVerified}/${i.usersSampled}',
          ),
          _KpiCard(
            title: 'Platform onaylı usta',
            value: pct(i.artisansAdminVerified, i.artisansSampled),
            icon: Icons.verified,
            color: palette.success,
            subtitle: '${i.artisansAdminVerified}/${i.artisansSampled}',
          ),
          _KpiCard(
            title: 'Premium usta',
            value: pct(i.artisansPremium, i.artisansSampled),
            icon: Icons.workspace_premium_outlined,
            color: palette.warning,
            subtitle: '${i.artisansPremium}/${i.artisansSampled}',
          ),
          _KpiCard(
            title: 'Gizli vitrin',
            value: '${i.artisansHidden}',
            icon: Icons.visibility_off_outlined,
            color: palette.danger,
            subtitle: 'Usta örneklemi',
          ),
          _KpiCard(
            title: 'Yayın ürün (örnek)',
            value: '${i.productsActive}',
            icon: Icons.storefront_outlined,
            color: palette.success,
            subtitle: 'Gizli ${i.productsHidden}',
          ),
          _KpiCard(
            title: 'Askı (örneklem)',
            value: '${i.usersSuspended}',
            icon: Icons.gpp_bad_outlined,
            color: palette.danger,
            subtitle: 'Son ${i.usersSampled} kullanıcı',
          ),
        ]),

        const SizedBox(height: 20),

        // ARZ–TALEP HARİTASI: ilan ili (talep) ↔ usta ili (arz).
        //
        // Tek başına "en çok ilan gelen il" listesi büyüme kararı için
        // yetmez; asıl soru "ilanın çok ama ustanın az olduğu il hangisi?"
        // İki dağılım AYNI ölçekte yan yana çizilir.
        Card(
          elevation: 0,
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.balance_outlined,
                        size: 18, color: palette.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Arz–talep: il bazında ilan ve usta',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'İlanı çok, ustası az olan il büyüme hedefidir. '
                  'Örneklem: ${i.jobsSampled} ilan · ${i.artisansSampled} usta.',
                  style: TextStyle(fontSize: 11, color: palette.inkMuted),
                ),
                const SizedBox(height: 12),
                AdminCompareBars(
                  rows: arzTalepSatirlari(i.jobProvinces, i.artisanProvinces),
                  leftLabel: 'İlan (talep)',
                  rightLabel: 'Usta (arz)',
                  leftColor: palette.primary,
                  rightColor: palette.success,
                  emptyText: 'İl verisi yok.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'En çok usta bulunan iller',
          icon: Icons.handyman_outlined,
          rows: i.artisanProvinces,
          empty: 'Usta örnekleminde il yok.',
          caption: 'Son ${i.artisansSampled} usta · çoklu bölge her ilde sayılır',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'En çok ilan gelen iller',
          icon: Icons.map_outlined,
          rows: i.jobProvinces,
          empty: 'İlan örnekleminde il yok.',
          caption: 'Son ${i.jobsSampled} ilan',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'En çok ilan açılan hizmet kategorileri',
          icon: Icons.category_outlined,
          rows: i.jobCategories,
          empty: 'Kategori yok.',
          caption: 'Son ${i.jobsSampled} ilan · meslek kodu',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'İlan durum dağılımı',
          icon: Icons.stacked_bar_chart,
          rows: i.jobStatus,
          empty: 'Durum yok.',
          caption: 'Son ${i.jobsSampled} ilan',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'En yoğun usta meslekleri',
          icon: Icons.handyman_outlined,
          rows: i.artisanProfessions,
          empty: 'Meslek yok.',
          caption:
              'Son ${i.artisansSampled} usta · çoklu meslek her kodda sayılır',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'En çok yayınlanan ürün kategorileri',
          icon: Icons.inventory_2_outlined,
          rows: i.productCategories,
          empty: 'Ürün yok.',
          caption: 'Son ${i.productsSampled} ürün',
        ),
        const SizedBox(height: 12),
        _RankCard(
          title: 'Ürün durum dağılımı',
          icon: Icons.pie_chart_outline,
          rows: i.productStatus,
          empty: 'Durum yok.',
          caption: 'Son ${i.productsSampled} ürün',
        ),
        const SizedBox(height: 8),
        Text(
          'Örneklem ${i.generatedAt.toLocal()} · '
          'üst çubuktaki analitik ikonu ile yenilenir.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.inkFaint,
              ),
        ),
      ],
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
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

/// Günlük eğilim gövdesi: beş metrik, her biri çizgi grafik + haftalık özet.
class _DailyTrendBody extends StatelessWidget {
  const _DailyTrendBody({required this.rows});

  final List<AdminDailyStat> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (rows.isEmpty) {
      return Text(
        'Henüz günlük veri yok.',
        style: TextStyle(color: palette.inkMuted),
      );
    }

    final seriler = <DailySeries>[
      seriesOf(rows, (r) => r.usersCreated, label: 'Yeni kullanıcı'),
      // Hizmet ilanı ve ürün talebi AYRI: `jobsCreated` ikisini de sayar.
      seriesOf(rows, (r) => r.serviceJobsCreated, label: 'Hizmet ilanı'),
      seriesOf(rows, (r) => r.productRequestsCreated, label: 'Ürün talebi'),
      seriesOf(rows, (r) => r.artisansCreated, label: 'Yeni usta'),
      seriesOf(rows, (r) => r.productsActivated, label: 'Yayınlanan ürün'),
      seriesOf(rows, (r) => r.reportsCreated, label: 'Şikayet'),
    ];
    final renkler = <Color>[
      palette.info,
      palette.primary,
      palette.secondary,
      palette.success,
      palette.premium,
      palette.danger,
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 960 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < seriler.length; i++)
              SizedBox(
                width: w,
                child: _TrendCard(series: seriler[i], color: renkler[i]),
              ),
          ],
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.series, required this.color});

  final DailySeries series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final son7 = series.lastDays(7);
    final degisim = series.weekOverWeekPercent;

    return Card(
      elevation: 0,
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    series.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (degisim != null)
                  _DegisimRozeti(percent: degisim)
                else
                  Text(
                    'yeni',
                    style: TextStyle(fontSize: 11, color: palette.inkFaint),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$son7',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              'son 7 gün · 30 günde ${series.total}',
              style: TextStyle(fontSize: 11, color: palette.inkMuted),
            ),
            const SizedBox(height: 6),
            AdminLineChart(
              values: series.values,
              days: series.days,
              color: color,
              height: 90,
              semanticLabel: '${series.label}: son 7 günde $son7, '
                  '30 günde ${series.total}',
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftalık değişim rozeti. Şikayet gibi metriklerde artış İYİ değildir;
/// bu yüzden renk "yön"e göre değil, nötr okunacak şekilde verilir —
/// yorumu operatör yapar.
class _DegisimRozeti extends StatelessWidget {
  const _DegisimRozeti({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final artis = percent >= 0;
    final renk = artis ? palette.success : palette.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${artis ? '+' : ''}${percent.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: renk,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.empty,
    this.caption,
  });

  final String title;
  final IconData icon;
  final List<NamedCount> rows;
  final String empty;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final maxCount = rows.isEmpty
        ? 1
        : rows.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkFaint,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              empty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _RankBar(
                rank: i + 1,
                label: rows[i].label,
                count: rows[i].count,
                maxCount: maxCount,
              ),
            ],
        ],
      ),
    );
  }
}

class _RankBar extends StatelessWidget {
  const _RankBar({
    required this.rank,
    required this.label,
    required this.count,
    required this.maxCount,
  });

  final int rank;
  final String label;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final frac = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$rank',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.inkFaint,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 6,
                  backgroundColor: palette.surfaceMuted,
                  color: palette.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
            ),
          ),
        ],
      ],
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

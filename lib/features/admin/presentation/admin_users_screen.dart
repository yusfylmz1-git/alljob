import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/app_user.dart';
import '../data/admin_export_util.dart';
import '../data/admin_providers.dart';
import '../data/admin_user_repository.dart';
import 'admin_chrome.dart';
import 'admin_pickers.dart';
import 'admin_list_search.dart';
import 'admin_moderation_glossary.dart';
import 'admin_person_hub.dart';
import 'paged_footer.dart';

export 'admin_person_hub.dart' show showAdminUserActions;

/// Kullanıcı dizini — kişi-merkezli adminin ana listesi.
///
/// Kart → [showAdminUserActions] (AdminPersonHub): kimlik, aktivite, usta
/// vitrini, notlar, askı. Rol atama yalnız Kadro sekmesinde.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _query = TextEditingController();
  final _listFilter = TextEditingController();
  String _listQuery = '';
  bool _searching = false;
  bool _searched = false;
  AppUser? _result;
  final Set<String> _selected = {};
  bool _selectMode = false;
  bool _bulkBusy = false;

  @override
  void dispose() {
    _query.dispose();
    _listFilter.dispose();
    super.dispose();
  }

  /// Firestore hata koduna göre okunabilir mesaj (App Check / indeks / yetki).
  static String _directoryErrorMessage(Object err) {
    final s = err.toString().toLowerCase();
    if (s.contains('permission-denied') || s.contains('permission_denied')) {
      return 'Dizin okunamadı (yetki / App Check). '
          'Web reCAPTCHA yokken App Check ENFORCE admin paneli kilitler; '
          'şu an monitor moda alındı — sayfayı yenileyin.';
    }
    if (s.contains('failed-precondition') || s.contains('requires an index')) {
      return 'Dizin yüklenemedi: Firestore bileşik indeksi hazır olmayabilir. '
          'Console → Firestore → Indexes kontrol edin.';
    }
    return 'Dizin yüklenemedi: $err';
  }

  Future<void> _exportCsv() async {
    final caps = ref.read(adminCapabilitiesProvider);
    if (!caps.allows('export.run')) {
      context.showError('export.run yetkisi yok.');
      return;
    }
    final page = ref.read(userDirectoryControllerProvider).valueOrNull;
    final users = page?.items ?? const <AppUser>[];
    if (users.isEmpty) {
      context.showError('Dışa aktarılacak yüklü satır yok.');
      return;
    }
    final csv = buildUsersCsv(users);
    await Clipboard.setData(ClipboardData(text: csv));
    try {
      await ref
          .read(adminUserRepositoryProvider)
          .logExport(kind: 'users', rowCount: users.length);
    } catch (_) {
      // Audit opsiyonel; CSV panoda.
    }
    if (!mounted) return;
    context.showSuccess(
      '${users.length} satır CSV panoya kopyalandı (telefon yok).',
    );
  }

  Future<void> _bulkSuspend({required bool suspended}) async {
    final caps = ref.read(adminCapabilitiesProvider);
    if (!caps.allows('users.suspend')) {
      context.showError('users.suspend yetkisi yok.');
      return;
    }
    final uids = _selected.toList();
    if (uids.isEmpty) return;
    if (uids.length > 25) {
      context.showError('En fazla 25 kullanıcı seçin.');
      return;
    }
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspended ? 'Toplu askıya al' : 'Toplu geri aç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${uids.length} kullanıcı. Neden (audit):'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: 'Opsiyonel neden'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final results = await ref
          .read(adminUserRepositoryProvider)
          .bulkSuspend(uids, suspended: suspended, reason: reasonCtrl.text);
      final okN = results.where((r) => r.ok).length;
      final failN = results.length - okN;
      if (!mounted) return;
      context.showSuccess('Tamam: $okN · Hata: $failN');
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      ref.read(userDirectoryControllerProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      context.showError('Toplu işlem başarısız (CF).');
    } finally {
      reasonCtrl.dispose();
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched = false;
      _result = null;
    });
    final repo = ref.read(adminUserRepositoryProvider);
    try {
      final user = q.contains('@')
          ? await repo.findByEmail(q)
          : await repo.findByUid(q);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searched = true;
        _result = user;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searched = true;
      });
      context.showError('Arama başarısız oldu. Tekrar deneyin.');
    }
  }

  Future<void> _openActions(AppUser user) async {
    await showAdminUserActions(
      context,
      ref,
      user.uid,
      onChanged: () {
        if (mounted) {
          _search();
          ref.read(userDirectoryControllerProvider.notifier).refresh();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filter = ref.watch(userDirectoryFilterProvider);
    final dirAsync = ref.watch(userDirectoryControllerProvider);
    final dirCtrl = ref.read(userDirectoryControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Kullanıcılar',
        icon: Icons.people_alt_outlined,
        subtitle: dirAsync.valueOrNull == null
            ? 'Kişi kartı · tüm işlemler tek yerde'
            : '${dirAsync.value!.items.length} kişi yüklü'
                  '${dirAsync.value!.hasMore ? '+' : ''}',
        actions: [
          if (_selectMode) ...[
            IconButton(
              tooltip: 'Toplu askıya al',
              onPressed: _bulkBusy || _selected.isEmpty
                  ? null
                  : () => _bulkSuspend(suspended: true),
              icon: const Icon(Icons.block),
            ),
            IconButton(
              tooltip: 'Toplu geri aç',
              onPressed: _bulkBusy || _selected.isEmpty
                  ? null
                  : () => _bulkSuspend(suspended: false),
              icon: const Icon(Icons.lock_open),
            ),
            IconButton(
              tooltip: 'Seçimi kapat',
              onPressed: _bulkBusy
                  ? null
                  : () => setState(() {
                      _selectMode = false;
                      _selected.clear();
                    }),
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            IconButton(
              tooltip: 'CSV kopyala (yüklü sayfa)',
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: 'Toplu seçim',
              onPressed: () => setState(() => _selectMode = true),
              icon: const Icon(Icons.checklist),
            ),
            const AdminHelpButton(highlightTitle: 'Hesap askıda'),
            IconButton(
              tooltip: 'Dizini yenile',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: dirCtrl.refresh,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          AdminHintBanner(
            text:
                'Askı = hesabı dondurur. Usta “gizle / platform onayı” vitrin '
                'ayarlarıdır (sözlük).',
            onHelp: () => AdminModerationGlossary.show(
              context,
              highlightTitle: 'Hesap askıda',
            ),
          ),
          if (_selectMode)
            Material(
              color: palette.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selected.length} seçili (max 25)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (_bulkBusy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ResponsiveCenter(
            maxWidth: 960,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _query,
                  enabled: !_searching,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Kişi ara (e-posta veya UID)',
                    hintText: 'ornek@eposta.com',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _searching ? null : _search,
                    ),
                  ),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_result != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _UserCard(
                      user: _result!,
                      onTap: () => _openActions(_result!),
                    ),
                  )
                else if (_searched)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Arama sonucu yok. Aşağıdaki dizin listesine bakın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.inkMuted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),

                // İL FİLTRESİ (2026-08-23) — şehir bazlı Pro geçişinde
                // yöneticinin ilk aradığı bilgi.
                //
                // Rol/askı filtreleriyle BİRLEŞMEZ: her kombinasyon ayrı
                // bileşik indeks isterdi. İl seçiliyken rozetlerden ayırt
                // edilir; kayıp küçük, maliyet farkı büyük.
                AdminProvincePicker(
                  label: 'İl filtresi',
                  value: ref.watch(userDirectoryProvinceProvider),
                  allowClear: true,
                  onChanged: (il) {
                    ref.read(userDirectoryProvinceProvider.notifier).state = il;
                    if (il != null) {
                      ref.read(userDirectoryFilterProvider.notifier).state =
                          AdminUserListFilter.all;
                    }
                    dirCtrl.refresh();
                  },
                ),
                if (ref.watch(userDirectoryProvinceProvider) != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'İl seçiliyken rol/askı filtreleri uygulanmaz. '
                    'Rozetlerden ayırt edin.',
                    style: TextStyle(color: palette.inkMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in AdminUserListFilter.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(switch (f) {
                              AdminUserListFilter.all => 'Tümü',
                              AdminUserListFilter.suspended => 'Askıda',
                              AdminUserListFilter.artisans => 'Ustalar',
                              AdminUserListFilter.nonArtisans => 'Müşteriler',
                            }),
                            selected: filter == f,
                            onSelected: (_) =>
                                ref
                                        .read(
                                          userDirectoryFilterProvider.notifier,
                                        )
                                        .state =
                                    f,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kayıtlı kişiler · karta dokun = tam dosya',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _listFilter,
                  onChanged: (v) => setState(() => _listQuery = v.trim()),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Dizinde süz (ad / e-posta / UID)',
                    hintText: 'Yüklü satırlarda anında süz',
                    prefixIcon: const Icon(Icons.filter_list, size: 20),
                    border: const OutlineInputBorder(),
                    suffixIcon: _listQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _listFilter.clear();
                              setState(() => _listQuery = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: dirAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) =>
                  ErrorView(message: _directoryErrorMessage(err)),
              data: (page) {
                final items = _listQuery.isEmpty
                    ? page.items
                    : page.items
                        .where(
                          (u) => adminAnyMatch(
                            [u.displayName, u.email, u.uid],
                            _listQuery,
                          ),
                        )
                        .toList();
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'Bu filtrede kullanıcı yok.',
                      style: TextStyle(color: palette.inkMuted),
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Süzme sonucu yok. Daha fazla yükleyin veya aramayı temizleyin.',
                      style: TextStyle(color: palette.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: dirCtrl.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 960,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: ListView.separated(
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: dirCtrl.loadMore,
                            endLabel: _listQuery.isEmpty
                                ? 'Dizinin sonu'
                                : 'Yüklü dizinde süzme',
                          );
                        }
                        final u = items[i];
                        final selected = _selected.contains(u.uid);
                        return _UserCard(
                          user: u,
                          selected: _selectMode ? selected : null,
                          onTap: () {
                            if (_selectMode) {
                              setState(() {
                                if (selected) {
                                  _selected.remove(u.uid);
                                } else if (_selected.length < 25) {
                                  _selected.add(u.uid);
                                } else {
                                  context.showError('En fazla 25 seçim.');
                                }
                              });
                            } else {
                              _openActions(u);
                            }
                          },
                        );
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap, this.selected});
  final AppUser user;
  final VoidCallback onTap;

  /// null = seçim modu kapalı; true/false = checkbox.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final name = user.displayName.isEmpty ? 'İsimsiz' : user.displayName;
    final letter = name.substring(0, 1).toUpperCase();
    final photo = user.profilePhotoUrl?.trim();
    final hasPhoto = photo != null && photo.startsWith('http');
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected == true ? palette.primary : palette.hairline,
              width: selected == true ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected != null) ...[
                Icon(
                  selected! ? Icons.check_box : Icons.check_box_outline_blank,
                  color: palette.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: hasPhoto
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: palette.primaryContainer,
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: palette.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: palette.primaryContainer,
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: palette.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isEmpty ? 'E-posta yok' : user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          label: user.suspended ? 'Askıda' : 'Aktif',
                          bg: user.suspended
                              ? palette.dangerSurface
                              : palette.successSurface,
                          fg: user.suspended
                              ? palette.danger
                              : palette.success,
                        ),
                        // ROL — usta ve mağaza AYRI (2026-08-23).
                        //
                        // Önce yalnız "Usta / Müşteri" vardı; mağaza sahibi
                        // müşteri görünüyordu. Pro modelinde ölçü müsaitlik
                        // ve mağaza sahibi de müsait olur — yöneticinin bunu
                        // listede ayırt etmesi gerekiyor.
                        if (user.hasArtisanProfile)
                          _Chip(
                            label: 'Usta',
                            bg: palette.infoSurface,
                            fg: palette.info,
                          ),
                        if (user.hasShopProfile)
                          _Chip(
                            label: 'Mağaza',
                            bg: palette.infoSurface,
                            fg: palette.info,
                          ),
                        if (!user.hasArtisanProfile && !user.hasShopProfile)
                          _Chip(
                            label: 'Müşteri',
                            bg: palette.surfaceMuted,
                            fg: palette.inkMuted,
                          ),

                        // MÜSAİTLİK — Pro modelinin ölçüsü.
                        //
                        // Kim ödeyecek sorusunun cevabı bu: müsait olan
                        // öder. Yalnız usta/mağazada anlamlı; müşteride
                        // gösterilmesi kafa karıştırır.
                        if (user.hasArtisanProfile || user.hasShopProfile)
                          _Chip(
                            label: user.available ? 'Müsait' : 'Kapalı',
                            bg: user.available
                                ? palette.successSurface
                                : palette.surfaceMuted,
                            fg: user.available
                                ? palette.success
                                : palette.inkMuted,
                          ),

                        // İL — şehir bazlı geçişte yöneticinin ilk aradığı
                        // bilgi. Tek il kuralı gereği en fazla bir tane.
                        if (_ilAdi(user) case final il?)
                          _Chip(
                            label: il,
                            bg: palette.surfaceMuted,
                            fg: palette.inkMuted,
                          ),

                        if (user.phoneVerified)
                          _Chip(
                            label: 'Tel. ✓',
                            bg: palette.surfaceMuted,
                            fg: palette.inkMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (selected == null)
                Icon(Icons.chevron_right, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kullanıcının hizmet İLİ — mağaza bölgesinden (2026-08-23).
///
/// Usta profilindeki `serviceAreas` burada OKUNAMAZ: o ayrı bir dokümanda
/// (`artisanProfiles`) ve liste başına 30 ekstra okuma demek olurdu. Mağaza
/// bölgesi `users` dokümanında olduğu için bedava.
///
/// Sonuç: mağazası olan kullanıcıda il görünür, yalnız usta olanda
/// görünmez. Eksik ama **maliyetsiz**; il filtresi geldiğinde
/// (`users.province`) bu boşluk da kapanacak.
String? _ilAdi(AppUser user) {
  for (final a in user.shopServiceAreas) {
    final il = a.province.trim();
    if (il.isNotEmpty) return il;
  }
  return null;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}


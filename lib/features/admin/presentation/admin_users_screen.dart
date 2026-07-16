import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/app_user.dart';
import '../data/admin_export_util.dart';
import '../data/admin_providers.dart';
import '../data/admin_user_repository.dart';
import 'paged_footer.dart';

/// Yönetici kullanıcı yönetimi: arama + sayfalı dizin (PR2) + bulk/export (PR14).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _query = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  AppUser? _result;
  final Set<String> _selected = {};
  bool _selectMode = false;
  bool _bulkBusy = false;

  @override
  void dispose() {
    _query.dispose();
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
      await ref.read(adminUserRepositoryProvider).logExport(
            kind: 'users',
            rowCount: users.length,
          );
    } catch (_) {
      // Audit opsiyonel; CSV panoda.
    }
    if (!mounted) return;
    context.showSuccess(
        '${users.length} satır CSV panoya kopyalandı (telefon yok).');
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
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final results = await ref.read(adminUserRepositoryProvider).bulkSuspend(
            uids,
            suspended: suspended,
            reason: reasonCtrl.text,
          );
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserActionSheet(
        user: user,
        onChanged: () {
          if (mounted) {
            _search();
            ref.read(userDirectoryControllerProvider.notifier).refresh();
          }
        },
      ),
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
        icon: Icons.manage_accounts_outlined,
        subtitle: dirAsync.valueOrNull == null
            ? null
            : 'Dizin: ${dirAsync.value!.items.length}'
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
          if (_selectMode)
            Material(
              color: palette.primary.withValues(alpha: 0.08),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    labelText: 'E-posta veya UID',
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
                        onTap: () => _openActions(_result!)),
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
                            onSelected: (_) => ref
                                .read(userDirectoryFilterProvider.notifier)
                                .state = f,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kayıtlı kullanıcı dizini (en yeni üstte)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: dirAsync.when(
              loading: () => const LoadingView(),
              error: (err, _) => ErrorView(
                message: _directoryErrorMessage(err),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return Center(
                    child: Text(
                      'Bu filtrede kullanıcı yok.',
                      style: TextStyle(color: palette.inkMuted),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: dirCtrl.refresh,
                  child: ResponsiveCenter(
                    maxWidth: 960,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: ListView.separated(
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == page.items.length) {
                          return PagedFooter(
                            hasMore: page.hasMore,
                            loadingMore: page.loadingMore,
                            onLoadMore: dirCtrl.loadMore,
                            endLabel: 'Dizinin sonu',
                          );
                        }
                        final u = page.items[i];
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
  const _UserCard({
    required this.user,
    required this.onTap,
    this.selected,
  });
  final AppUser user;
  final VoidCallback onTap;

  /// null = seçim modu kapalı; true/false = checkbox.
  final bool? selected;

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected == true ? palette.primary : palette.hairline,
              width: selected == true ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selected != null) ...[
                    Icon(
                      selected!
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: palette.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      user.displayName.isEmpty
                          ? '(isimsiz)'
                          : user.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.suspended)
                    _Chip(
                        label: 'Askıya Alındı',
                        bg: palette.dangerSurface,
                        fg: palette.danger)
                  else
                    _Chip(
                        label: 'Aktif',
                        bg: palette.successSurface,
                        fg: palette.success),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(user.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 2),
              SelectableText('UID: ${user.uid}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.inkFaint)),
              if (selected == null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Yönet →',
                      style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

/// Bir kullanıcıyı UID ile yükleyip askıya al / geri aç eylem sayfasını açar.
/// Şikayet ve anlaşmazlık detaylarından "kullanıcıyı yönet" için ortak giriş
/// noktası — moderasyon döngüsünü kapatır (bildirimden tek dokunuşla askıya al).
Future<void> showAdminUserActions(
  BuildContext context,
  WidgetRef ref,
  String uid, {
  VoidCallback? onChanged,
}) async {
  AppUser? user;
  try {
    user = await ref.read(adminUserRepositoryProvider).findByUid(uid);
  } catch (_) {
    if (context.mounted) context.showError('Kullanıcı yüklenemedi.');
    return;
  }
  if (!context.mounted) return;
  if (user == null) {
    context.showError('Kullanıcı bulunamadı.');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UserActionSheet(user: user!, onChanged: onChanged),
  );
}

/// Kullanıcı için askıya al / geri aç eylem sayfası.
class _UserActionSheet extends ConsumerStatefulWidget {
  const _UserActionSheet({required this.user, this.onChanged});
  final AppUser user;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_UserActionSheet> createState() => _UserActionSheetState();
}

class _UserActionSheetState extends ConsumerState<_UserActionSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _role; // hedefin mevcut yönetici rolü (null = yönetici değil)
  bool _roleLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final r =
          await ref.read(adminUserRepositoryProvider).findRole(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _role = r;
        _roleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _roleLoading = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _applyRole(String? role) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminUserRepositoryProvider)
          .setRole(widget.user.uid, role: role);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged?.call();
      context.showSuccess(role == null
          ? 'Yönetici yetkisi kaldırıldı.'
          : 'Rol atandı: ${_roleLabel(role)}.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız oldu. Tekrar deneyin.');
    }
  }

  Future<void> _apply(bool suspend) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminUserRepositoryProvider).setSuspended(
            widget.user.uid,
            suspended: suspend,
            reason: _reason.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged?.call();
      context.showSuccess(suspend
          ? 'Kullanıcı askıya alındı.'
          : 'Kullanıcının askısı kaldırıldı.');
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
    final u = widget.user;
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
              Text(u.displayName.isEmpty ? '(isimsiz)' : u.displayName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(u.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 16),
              if (u.suspended) ...[
                Text(
                  'Bu kullanıcı şu an askıda. Geri açıldığında yeniden içerik '
                  'oluşturabilir.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: 16),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton.icon(
                    onPressed: () => _apply(false),
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    label: const Text('Askıyı Kaldır'),
                  ),
              ] else ...[
                Text('Askıya alma nedeni (opsiyonel — yalnız denetim kaydına)',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: palette.inkMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    hintText: 'Örn. tekrarlanan spam / taciz…',
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: palette.danger),
                    onPressed: () => _apply(true),
                    icon: const Icon(Icons.gpp_bad_outlined, size: 18),
                    label: const Text('Askıya Al'),
                  ),
              ],
              _buildRoleSection(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Yönetici rolü bölümü. Herkese mevcut rol gösterilir; rol ATAMA yalnız
  /// oturumdaki SÜPER yöneticiye açıktır (RBAC).
  Widget _buildRoleSection(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final canAssign = ref.watch(isSuperAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Divider(color: palette.hairline, height: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: palette.inkMuted),
            const SizedBox(width: 6),
            Text('Yönetici rolü: ',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.inkMuted)),
            Text(
              _roleLoading ? '…' : _roleLabel(_role),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        if (canAssign && !_busy && !_roleLoading) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_role != 'moderator')
                OutlinedButton.icon(
                  onPressed: () => _applyRole('moderator'),
                  icon: const Icon(Icons.gavel_outlined, size: 16),
                  label: const Text('Moderatör yap'),
                ),
              if (_role != 'superadmin')
                OutlinedButton.icon(
                  onPressed: () => _applyRole('superadmin'),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 16),
                  label: const Text('Süper Yönetici yap'),
                ),
              if (_role != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger),
                  onPressed: () => _applyRole(null),
                  icon: const Icon(Icons.remove_moderator_outlined, size: 16),
                  label: const Text('Yetkiyi kaldır'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Rol kodunu Türkçe etikete çevirir (null = yönetici değil).
String _roleLabel(String? role) => switch (role) {
      'superadmin' => 'Süper Yönetici',
      'moderator' => 'Moderatör',
      _ => 'Yok',
    };

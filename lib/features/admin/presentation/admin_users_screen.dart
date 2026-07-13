import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/app_user.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_providers.dart';

/// Yönetici kullanıcı yönetimi: e-posta veya UID ile kullanıcı bul → askıya al
/// / geri aç. Askıya alma zorlaması sunucudadır (`suspended` claim); bu ekran
/// yalnız arama + `adminSetUserSuspended` CF çağrısıdır.
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

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
          // Karardan sonra kaydı tazele (askı durumu güncellensin).
          if (mounted) _search();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Kullanıcılar',
        icon: Icons.manage_accounts_outlined,
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
            const SizedBox(height: 16),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_result != null)
              _UserCard(user: _result!, onTap: () => _openActions(_result!))
            else if (_searched)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kullanıcı bulunamadı. E-posta veya UID\'yi kontrol edin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.inkMuted),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Bir kullanıcıyı e-posta adresi veya UID ile arayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.inkFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});
  final AppUser user;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Yönet →',
                    style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w700)),
              ),
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

/// Kullanıcı için askıya al / geri aç eylem sayfası.
class _UserActionSheet extends ConsumerStatefulWidget {
  const _UserActionSheet({required this.user, required this.onChanged});
  final AppUser user;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserActionSheet> createState() => _UserActionSheetState();
}

class _UserActionSheetState extends ConsumerState<_UserActionSheet> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
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
      widget.onChanged();
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
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_chrome.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../data/admin_capabilities.dart';
import '../data/admin_invite_repository.dart';
import '../data/admin_providers.dart';
import '../data/admin_user_repository.dart';
import 'admin_users_screen.dart';

/// Yönetici kadrosu + davetler + yetki düzenleme (Wave 2).
class AdminRosterScreen extends ConsumerStatefulWidget {
  const AdminRosterScreen({super.key});

  @override
  ConsumerState<AdminRosterScreen> createState() => _AdminRosterScreenState();
}

class _AdminRosterScreenState extends ConsumerState<AdminRosterScreen> {
  final _inviteEmail = TextEditingController();
  bool _inviting = false;

  @override
  void dispose() {
    _inviteEmail.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    final email = _inviteEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      context.showError('Geçerli bir e-posta girin.');
      return;
    }
    setState(() => _inviting = true);
    try {
      final sonuc = await ref
          .read(adminInviteRepositoryProvider)
          .create(email: email);
      if (!mounted) return;
      _inviteEmail.clear();
      // Bağlantı YALNIZ bu yanıtta gelir (sunucu saklamaz). Kaçırılırsa
      // yeniden üretilemez — bu yüzden snackbar değil, kapatılana kadar
      // duran bir pencerede gösterilir.
      await _sifreBaglantisiPenceresi(sonuc);
    } catch (_) {
      if (mounted) context.showError('Davet oluşturulamadı.');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  /// Şifre belirleme bağlantısını gösterir ve kopyalatır.
  ///
  /// Neden pencere: bağlantı tek kullanımlıktır ve sunucuda saklanmaz.
  /// Süperadmin onu davet edilen kişiye kendi güvendiği kanaldan iletir.
  /// Şifreyi kimse bilmez — kişi kendisi belirler.
  Future<void> _sifreBaglantisiPenceresi(AdminInviteResult sonuc) async {
    final link = sonuc.passwordSetupLink;
    if (link == null || link.isEmpty) {
      // Hesap zaten vardı ve bağlantı üretilemedi: kişi mevcut şifresiyle
      // girer, gerekirse giriş ekranından "şifremi unuttum" kullanır.
      context.showSuccess(
        'Davet oluşturuldu. ${sonuc.email} kendi hesabıyla giriş yapıp '
        '"Daveti kabul et" demeli.',
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Davet hazır'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sonuc.accountCreated
                      ? '${sonuc.email} için yönetici hesabı açıldı.'
                      : '${sonuc.email} zaten kayıtlıydı; yetki daveti '
                            'oluşturuldu.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aşağıdaki bağlantıyı bu kişiye iletin. Bağlantıyı açıp '
                  'kendi şifresini belirleyecek — şifreyi siz de bilmezsiniz.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  child: SelectableText(
                    link,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.warningSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Bu bağlantı bir daha gösterilmez. Şimdi kopyalayın — '
                    'kaybolursa yeni davet oluşturmanız gerekir.',
                    style: TextStyle(fontSize: 12, color: palette.ink),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kişi şifresini belirledikten sonra panele girip '
                  '"Daveti kabul et" demelidir — yetkiler ancak o zaman '
                  'yüklenir.',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Bağlantı kopyalandı')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Bağlantıyı kopyala'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCaps(AdminRosterEntry entry) async {
    if (entry.isSuperAdmin) {
      context.showError('Süper yönetici yetkileri kısıtlanmaz.');
      return;
    }
    final initial = entry.capabilitiesFieldPresent
        ? entry.capabilities!.toSet()
        : Set<String>.from(AdminCapabilities.defaultModerator);
    final selected = Set<String>.from(initial);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yetkiler — ${entry.uid}',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 360,
                      child: ListView(
                        children: [
                          for (final code in AdminCapabilities.allCodes)
                            CheckboxListTile(
                              dense: true,
                              value: selected.contains(code),
                              title: Text(AdminCapabilities.labelTR(code)),
                              subtitle: Text(
                                code,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    selected.add(code);
                                  } else {
                                    selected.remove(code);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(adminUserRepositoryProvider)
          .setCapabilities(entry.uid, selected.toList()..sort());
      if (mounted) context.showSuccess('Yetkiler güncellendi.');
    } catch (_) {
      if (mounted) context.showError('Yetkiler kaydedilemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(adminRosterProvider);
    final invitesAsync = ref.watch(adminPendingInvitesProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Kadro & Davetler',
        icon: Icons.shield_outlined,
        subtitle: rosterAsync.valueOrNull == null
            ? null
            : '${rosterAsync.value!.length} yetkili',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Moderatör davet et',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                // Akış ekranda YAZILI olmalı: yeni bir süperadmin
                // "şifreyi nereden vereceğim?" diye takılıyordu.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.infoSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nasıl çalışır?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. E-postayı girip "Davet" deyin — hesap açılır ve '
                        'size bir şifre belirleme bağlantısı verilir.\n'
                        '2. Bağlantıyı kişiye iletin; kendi şifresini '
                        'belirler (siz de bilmezsiniz).\n'
                        '3. Panele girip "Daveti kabul et" der — yetkiler '
                        'o zaman yüklenir.',
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Süper yönetici davet edilemez; yetki yükseltme '
                        'yalnız Kadro listesinden yapılır.',
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteEmail,
                        enabled: !_inviting,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          hintText: 'moderator@ornek.com',
                        ),
                        onSubmitted: (_) => _createInvite(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _inviting ? null : _createInvite,
                      child: _inviting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Davet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Bekleyen davetler',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                invitesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(
                    'Davetler yüklenemedi',
                    style: TextStyle(color: palette.danger),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return Text(
                        'Bekleyen davet yok.',
                        style: TextStyle(color: palette.inkFaint),
                      );
                    }
                    return Column(
                      children: [
                        for (final inv in list)
                          _InviteTile(
                            invite: inv,
                            onRevoke: () async {
                              try {
                                await ref
                                    .read(adminInviteRepositoryProvider)
                                    .revoke(inv.id);
                                if (context.mounted) {
                                  context.showSuccess('Davet iptal edildi.');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  context.showError('İptal başarısız.');
                                }
                              }
                            },
                            onCopy: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text:
                                      'https://alljob1-admin.web.app\n'
                                      'Hesabınız: ${inv.email}\n'
                                      'Giriş yapın → “Daveti kabul et”.',
                                ),
                              );
                              if (context.mounted) {
                                context.showSuccess(
                                  'Davet metni panoya kopyalandı.',
                                );
                              }
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Kadro',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          rosterAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const ErrorView(
              message: 'Kadro yüklenemedi. Yetkiniz olduğundan emin olun.',
            ),
            data: (list) {
              if (list.isEmpty) {
                return const ErrorView(
                  icon: Icons.group_outlined,
                  title: 'Kadro boş',
                  message: 'Henüz atanmış bir yönetici rolü yok.',
                );
              }
              return ResponsiveCenter(
                maxWidth: 720,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _RosterCard(
                        entry: list[i],
                        onOpenUser: () =>
                            showAdminUserActions(context, ref, list[i].uid),
                        onEditCaps: list[i].isSuperAdmin
                            ? null
                            : () => _editCaps(list[i]),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.onRevoke,
    required this.onCopy,
  });
  final AdminInvite invite;
  final VoidCallback onRevoke;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          invite.email,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Bitiş: ${invite.expiresAt?.toLocal() ?? "—"} · '
          '${invite.capabilities.length} yetki',
          style: TextStyle(color: palette.inkMuted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Kopyala',
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: onCopy,
            ),
            IconButton(
              tooltip: 'İptal',
              icon: Icon(Icons.close, color: palette.danger, size: 20),
              onPressed: onRevoke,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({
    required this.entry,
    required this.onOpenUser,
    this.onEditCaps,
  });
  final AdminRosterEntry entry;
  final VoidCallback onOpenUser;
  final VoidCallback? onEditCaps;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isSuper = entry.isSuperAdmin;
    final capCount = entry.isSuperAdmin
        ? 'tüm'
        : entry.capabilitiesFieldPresent
        ? '${entry.capabilities?.length ?? 0}'
        : 'varsayılan';
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpenUser,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              Icon(
                isSuper
                    ? Icons.workspace_premium_outlined
                    : Icons.gavel_outlined,
                color: isSuper ? palette.primary : palette.inkMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuper ? 'Süper Yönetici' : 'Moderatör',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (entry.email != null && entry.email!.isNotEmpty)
                      Text(
                        entry.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    Text(
                      'UID: ${entry.uid}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.inkFaint,
                      ),
                    ),
                    Text(
                      'Yetki: $capCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEditCaps != null)
                IconButton(
                  tooltip: 'Yetkileri düzenle',
                  icon: const Icon(Icons.tune),
                  onPressed: onEditCaps,
                ),
              Icon(Icons.chevron_right, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

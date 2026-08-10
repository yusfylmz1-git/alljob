import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

/// Yönetici kendi hesabı: e-posta bilgisi + şifre değiştirme / sıfırlama.
///
/// Her moderatör ve superadmin kendi girişini yönetir; başkasının şifresine
/// dokunmaz (Firebase Admin SDK gerekir — o ayrı süreç).
Future<void> showAdminAccountSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: h * 0.78,
        child: const _AdminAccountSheet(),
      );
    },
  );
}

class _AdminAccountSheet extends ConsumerStatefulWidget {
  const _AdminAccountSheet();

  @override
  ConsumerState<_AdminAccountSheet> createState() => _AdminAccountSheetState();
}

class _AdminAccountSheetState extends ConsumerState<_AdminAccountSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _next2 = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _next2.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final cur = _current.text;
    final n1 = _next.text;
    final n2 = _next2.text;
    if (cur.isEmpty) {
      context.showError('Mevcut şifreyi girin.');
      return;
    }
    if (n1.length < 6) {
      context.showError('Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (n1 != n2) {
      context.showError('Yeni şifreler eşleşmiyor.');
      return;
    }
    setState(() => _busy = true);
    final ok = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: cur,
          newPassword: n1,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _current.clear();
      _next.clear();
      _next2.clear();
      context.showSuccess('Şifre güncellendi.');
      Navigator.of(context).pop();
    } else {
      final err = ref.read(authControllerProvider).error;
      final msg = err is AuthException
          ? err.message
          : (err?.toString() ?? 'Şifre değiştirilemedi.');
      context.showError(msg);
    }
  }

  Future<void> _sendReset() async {
    final email = ref.read(currentUserProvider)?.email.trim() ?? '';
    if (email.isEmpty) {
      context.showError('E-posta bulunamadı.');
      return;
    }
    setState(() => _busy = true);
    final ok =
        await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      context.showSuccess(
        'Sıfırlama bağlantısı $email adresine gönderildi '
        '(spam klasörünü de kontrol edin).',
      );
    } else {
      final err = ref.read(authControllerProvider).error;
      final msg = err is AuthException
          ? err.message
          : 'E-posta gönderilemedi.';
      context.showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';
    final role = user?.isSuperAdmin == true
        ? 'Superadmin'
        : (user?.isAdmin == true ? 'Moderatör' : '—');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Hesabım',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Giriş bilgilerinizi buradan yönetin. Başka bir yöneticinin '
            'şifresini buradan değiştiremezsiniz.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oturum',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty ? 'E-posta yok' : email,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Şifre değiştir',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Yalnız e-posta/şifre ile giriş yapan hesaplar. Google ile '
            'giriyorsanız Google hesabınızdan yönetin.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _current,
            obscureText: _obscure,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Mevcut şifre',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: _obscure,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Yeni şifre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next2,
            obscureText: _obscure,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Yeni şifre (tekrar)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _changePassword,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset, size: 18),
            label: const Text('Şifreyi güncelle'),
          ),
          const SizedBox(height: 20),
          Divider(color: palette.hairline),
          const SizedBox(height: 12),
          Text(
            'Şifremi unuttum',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'E-posta adresinize sıfırlama bağlantısı gönderilir. Oturum açık '
            'kalır; bağlantıya tıklayınca yeni şifre belirlersiniz.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _sendReset,
            icon: const Icon(Icons.mark_email_read_outlined, size: 18),
            label: const Text('Sıfırlama e-postası gönder'),
          ),
        ],
      ),
    );
  }
}

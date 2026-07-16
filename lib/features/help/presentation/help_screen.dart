import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../admin/data/admin_support_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../legal/legal_docs.dart';
import '../help_faq.dart';

/// Yardım / SSS + destek talebi (girişli) + e-posta.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _category = kFaqCategories.first;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showInfo('Destek talebi için giriş yapın.');
      context.push(RoutePaths.login);
      return;
    }
    final s = _subject.text.trim();
    final b = _body.text.trim();
    if (s.length < 3 || b.length < 10) {
      context.showError('Konu min. 3, mesaj min. 10 karakter.');
      return;
    }
    setState(() => _sending = true);
    try {
      await SupportTicketClient().create(subject: s, body: b);
      if (!mounted) return;
      _subject.clear();
      _body.clear();
      context.showSuccess('Talebiniz alındı. Bildirimlerden takip edebilirsiniz.');
    } catch (_) {
      if (!mounted) return;
      context.showError('Gönderilemedi. Bağlantı veya oturumu kontrol edin.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final items =
        kFaqItems.where((f) => f.category == _category).toList(growable: false);
    final loggedIn = ref.watch(currentUserProvider) != null;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Yardım',
        icon: Icons.help_outline_rounded,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              '${AppConstants.appName} nasıl çalışır?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Sık sorulanlar aşağıda. Bulamazsanız destek talebi açın.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in kFaqCategories) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    item.question,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.answer,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: palette.inkMuted, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Destek talebi',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              loggedIn
                  ? 'Mesajınız yönetim paneline düşer; yanıt bildirim olarak gelir.'
                  : 'Talep açmak için giriş yapın. İsterseniz e-posta da yazabilirsiniz.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subject,
              enabled: loggedIn && !_sending,
              decoration: const InputDecoration(
                labelText: 'Konu',
                hintText: 'Örn. Ödeme sorunu',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              enabled: loggedIn && !_sending,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mesajınız',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _sending
                  ? null
                  : loggedIn
                      ? _submitTicket
                      : () => context.push(RoutePaths.login),
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(loggedIn ? Icons.send_outlined : Icons.login),
              label: Text(loggedIn
                  ? (_sending ? 'Gönderiliyor…' : 'Talebi gönder')
                  : 'Giriş yap'),
            ),
            const SizedBox(height: 20),
            Text(
              'Diğer kanallar',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.mail_outline, color: palette.primary),
                    title: const Text('E-posta ile yaz'),
                    subtitle: Text(kLegalContactEmail),
                    trailing: const Icon(Icons.copy_rounded, size: 20),
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: kLegalContactEmail));
                      if (context.mounted) {
                        context.showInfo('E-posta adresi kopyalandı.');
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.policy_outlined, color: palette.inkMuted),
                    title: const Text('Yasal metinler'),
                    subtitle: const Text('Gizlilik, KVKK, kullanım koşulları'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.legal),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.notifications_active_outlined,
                        color: palette.inkMuted),
                    title: const Text('Bildirim tercihleri'),
                    subtitle: const Text('Push bildirimlerini yönet'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.notificationPrefs),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

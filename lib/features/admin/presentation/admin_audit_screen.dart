import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_audit_repository.dart';
import '../data/admin_providers.dart';

/// Yönetici denetim kaydı görüntüleyici (`adminAuditLogs`). Her yetkili eylem
/// (rol atama, şikayet/anlaşmazlık kararı, askıya alma…) burada izlenir —
/// hesap verebilirlik + KVKK/GDPR. Yalnız süper yöneticiye açık (gözetim).
class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(adminAuditLogProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Denetim Kaydı',
        icon: Icons.receipt_long_outlined,
        subtitle: auditAsync.valueOrNull == null
            ? null
            : '${auditAsync.value!.length} kayıt (en yeni üstte)',
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: auditAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Denetim kaydı yüklenemedi. Yetkiniz olduğundan emin olun.',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const ErrorView(
              icon: Icons.history_outlined,
              title: 'Kayıt yok',
              message: 'Henüz kaydedilmiş bir yönetici eylemi yok.',
            );
          }
          return ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AuditCard(entry: list[i]),
            ),
          );
        },
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
    final detail = _detailLine(entry);
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
            children: [
              Icon(_icon(entry.action), size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.actionLabelTR,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv(context, 'Yapan', entry.actorUid),
          if (entry.targetId != null && entry.targetId!.isNotEmpty)
            _kv(context, 'Hedef', entry.targetId!),
          if (detail != null) _kv(context, 'Ayrıntı', detail),
          const SizedBox(height: 6),
          Text(_formatDate(entry.createdAt),
              style:
                  theme.textTheme.labelSmall?.copyWith(color: palette.inkFaint)),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$k: ',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint)),
        TextSpan(
            text: v,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: palette.inkMuted, fontWeight: FontWeight.w600)),
      ])),
    );
  }

  IconData _icon(String action) => switch (action) {
        'grant_admin' || 'set_role' => Icons.workspace_premium_outlined,
        'revoke_admin' => Icons.remove_moderator_outlined,
        'suspend_user' => Icons.gpp_bad_outlined,
        'unsuspend_user' => Icons.lock_open_outlined,
        'resolve_report' => Icons.flag_outlined,
        'claim_report' => Icons.pan_tool_alt_outlined,
        'release_report' => Icons.free_cancellation_outlined,
        'resolve_dispute' => Icons.gavel_outlined,
        _ => Icons.bolt_outlined,
      };

  /// `after` haritasından okunabilir kısa bir özet üretir.
  String? _detailLine(AuditEntry e) {
    final a = e.after;
    if (a == null) return null;
    final parts = <String>[];
    if (a['role'] != null) parts.add('rol: ${a['role']}');
    if (a['status'] != null) parts.add('durum: ${a['status']}');
    if (a['decision'] != null) parts.add('karar: ${a['decision']}');
    if (a['suspended'] != null) {
      parts.add(a['suspended'] == true ? 'askıya alındı' : 'askı kaldırıldı');
    }
    if (a['reason'] != null && '${a['reason']}'.isNotEmpty) {
      parts.add('neden: ${a['reason']}');
    }
    if (a['assignedTo'] != null) parts.add('üstlenen: ${a['assignedTo']}');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

String _formatDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

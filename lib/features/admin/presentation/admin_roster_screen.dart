import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/application/auth_controller.dart';
import '../data/admin_providers.dart';
import '../data/admin_user_repository.dart';
import 'admin_users_screen.dart';

/// Yönetici kadrosu: tüm rol sahipleri (superadmin'ler üstte). Yalnız süper
/// yöneticiye açık (rol atama yetkisi onda). Bir satıra dokununca ilgili
/// kullanıcının yönetim sayfası açılır (rol değiştir / kaldır).
class AdminRosterScreen extends ConsumerWidget {
  const AdminRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(adminRosterProvider);
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Yönetici Kadrosu',
        icon: Icons.shield_outlined,
        subtitle: rosterAsync.valueOrNull == null
            ? null
            : '${rosterAsync.value!.length} yetkili',
        actions: [
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: rosterAsync.when(
        loading: () => const LoadingView(),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RosterCard(
                entry: list[i],
                onTap: () => showAdminUserActions(context, ref, list[i].uid),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.entry, required this.onTap});
  final AdminRosterEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final isSuper = entry.isSuperAdmin;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text('UID: ${entry.uid}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: palette.inkFaint)),
                    if (entry.updatedAt != null)
                      Text('Güncellendi: ${_formatDate(entry.updatedAt!)}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: palette.inkFaint)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}

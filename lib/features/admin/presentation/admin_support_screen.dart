import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../data/admin_providers.dart';
import '../data/admin_support_repository.dart';
import 'admin_chrome.dart';

/// Destek talepleri kuyruğu.
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final async = ref.watch(adminSupportTicketsProvider(_openOnly));

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Destek talepleri',
        icon: Icons.support_agent_outlined,
        subtitle: 'Kullanıcıdan gelen ticket’lar',
        actions: [
          FilterChip(
            label: Text(_openOnly ? 'Açıklar' : 'Tümü'),
            selected: _openOnly,
            onSelected: (v) => setState(() => _openOnly = true),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Tümü'),
            selected: !_openOnly,
            onSelected: (_) => setState(() => _openOnly = false),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Talepler yüklenemedi. İndeks veya yetki: $e',
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                _openOnly ? 'Açık talep yok.' : 'Henüz talep yok.',
                style: TextStyle(color: palette.inkMuted),
              ),
            );
          }
          return ResponsiveCenter(
            maxWidth: 800,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = list[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.hairline),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    title: Text(
                      t.subject,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${t.status} · ${t.email ?? t.uid}\n'
                      '${t.body.length > 120 ? '${t.body.substring(0, 120)}…' : t.body}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(t),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(SupportTicket t) async {
    final note = TextEditingController(text: t.adminNote ?? '');
    String status = t.status;
    final can = ref.read(adminCapabilitiesProvider).allows('reports.manage');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.subject,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      '${t.email ?? t.uid} · ${t.createdAt.toLocal()}',
                      style: TextStyle(
                          color: context.palette.inkMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Text(t.body, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: status,
                      decoration: const InputDecoration(labelText: 'Durum'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Açık')),
                        DropdownMenuItem(
                            value: 'in_progress', child: Text('İnceleniyor')),
                        DropdownMenuItem(
                            value: 'resolved', child: Text('Çözüldü')),
                        DropdownMenuItem(
                            value: 'closed', child: Text('Kapalı')),
                      ],
                      onChanged: !can
                          ? null
                          : (v) {
                              if (v != null) setLocal(() => status = v);
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      maxLines: 3,
                      enabled: can,
                      decoration: const InputDecoration(
                        labelText: 'Yönetici notu',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: !can
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(adminSupportRepositoryProvider)
                                    .updateTicket(
                                      ticketId: t.id,
                                      status: status,
                                      adminNote: note.text,
                                    );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Talep güncellendi.')),
                                );
                              } catch (_) {
                                if (!ctx.mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Güncellenemedi.')),
                                );
                              }
                            },
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    note.dispose();
  }
}

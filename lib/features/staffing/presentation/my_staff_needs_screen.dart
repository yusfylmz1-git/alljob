import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/application/auth_controller.dart';
import '../data/staffing_providers.dart';

class MyStaffNeedsScreen extends ConsumerWidget {
  const MyStaffNeedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Oturum gerekli.')));
    }
    final async = ref.watch(myStaffNeedsProvider(user.uid));
    final palette = context.palette;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İşveren · İlanlarım',
        icon: Icons.folder_open_outlined,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.staffNeedNew),
        icon: const Icon(Icons.add),
        label: const Text('Yeni ilan'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => RefreshableEmpty(
          onRefresh: () => awaitRefresh(() async {
            ref.invalidate(myStaffNeedsProvider(user.uid));
            await ref.read(myStaffNeedsProvider(user.uid).future);
          }),
          child: ErrorView(
            message: 'Liste yüklenemedi.',
            onRetry: () => ref.invalidate(myStaffNeedsProvider(user.uid)),
          ),
        ),
        data: (list) {
          Future<void> refresh() => awaitRefresh(() async {
                ref.invalidate(myStaffNeedsProvider(user.uid));
                await ref.read(myStaffNeedsProvider(user.uid).future);
              });
          if (list.isEmpty) {
            return RefreshableEmpty(
              onRefresh: refresh,
              child: Center(
                child: Text(
                  'Henüz işveren ilanı açmadınız.',
                  style: TextStyle(color: palette.inkMuted),
                ),
              ),
            );
          }
          return ResponsiveCenter(
            maxWidth: 720,
            child: PullToRefresh(
              onRefresh: refresh,
              child: ListView.separated(
                physics: kPullRefreshPhysics,
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = list[i];
                  return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: palette.border),
                  ),
                  title: Text(n.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${n.isDaily ? "Gündelik · " : ""}'
                    '${n.placeLabel} · ${n.isOpen ? "Açık" : "Kapalı"}',
                  ),
                  trailing: n.isOpen
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(staffingRepositoryProvider)
                                  .closeNeed(n.id);
                              if (context.mounted) {
                                context.showInfo('İlan kapatıldı.');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                context.showError('Kapatılamadı.');
                              }
                            }
                          },
                          child: const Text('Kapat'),
                        )
                      : null,
                );
              },
              ),
            ),
          );
        },
      ),
    );
  }
}

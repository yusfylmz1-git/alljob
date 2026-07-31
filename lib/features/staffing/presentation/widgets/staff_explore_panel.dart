import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/pull_to_refresh.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../data/models/staffing.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/email_verification_gate.dart';
import '../../../chat/data/chat_providers.dart';
import '../../data/staffing_providers.dart';
import '../need_search_filter.dart';
import '../worker_search_filter.dart';
import 'staff_cards.dart';

enum _StaffExploreTab { seeker, employer }

/// Keşfet → Eleman: iki alt sekme (başlık = içerik).
///
/// - **Eleman**: müsait eleman ilanları + “Eleman profilim”
/// - **İşveren**: işverenlerin açtığı ilanlar + “İşveren ilanı aç”
class StaffExplorePanel extends ConsumerStatefulWidget {
  const StaffExplorePanel({super.key});

  @override
  ConsumerState<StaffExplorePanel> createState() => _StaffExplorePanelState();
}

class _StaffExplorePanelState extends ConsumerState<StaffExplorePanel> {
  _StaffExploreTab _tab = _StaffExploreTab.seeker;
  final _queryCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _dailyOnly = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _requireLoginThen(String path) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(RoutePaths.login);
      return;
    }
    context.push(path);
  }

  Future<void> _contactEmployer(StaffNeed n) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(RoutePaths.login);
      return;
    }
    if (user.uid == n.employerUid) {
      context.showInfo('Bu sizin ilanınız.');
      return;
    }
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'işverenle iletişime geçmek',
    );
    if (!emailOk || !mounted) return;
    try {
      final chatId = await ref.read(chatRepositoryProvider).startChat(
            customerUid: n.employerUid,
            customerName: n.employerName,
            customerPhotoUrl: n.employerPhotoUrl,
            artisanUid: user.uid,
            artisanName:
                user.displayName.isEmpty ? 'Eleman' : user.displayName,
            artisanPhotoUrl: user.profilePhotoUrl,
          );
      if (!mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (mounted) {
        context.showError('Sohbet açılamadı, tekrar deneyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    // Eleman sekmesi → eleman ilanları; İşveren → işveren ilanları.
    final isWorkersTab = _tab == _StaffExploreTab.seeker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StaffSubTabs(
                selected: _tab,
                onChanged: (t) {
                  if (t == _tab) return;
                  setState(() {
                    _tab = t;
                    _queryCtrl.clear();
                    _query = '';
                    _dailyOnly = false;
                  });
                },
              ),
              const SizedBox(height: 10),
              // Rol aksiyonu: sekme içeriğiyle uyumlu birincil düğme.
              if (isWorkersTab)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Eleman profilim'),
                  onPressed: () =>
                      _requireLoginThen(RoutePaths.staffMyWorker),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('İşveren ilanı aç'),
                        onPressed: () =>
                            _requireLoginThen(RoutePaths.staffNeedNew),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'İlanlarım',
                      onPressed: () =>
                          _requireLoginThen(RoutePaths.staffMyNeeds),
                      icon: const Icon(Icons.folder_open_outlined, size: 20),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              _SearchBar(
                controller: _queryCtrl,
                hint: isWorkersTab
                    ? 'Meslek, eleman veya bölge ara…'
                    : 'İlan, işveren veya bölge ara…',
                onChanged: _onQueryChanged,
                onClear: () {
                  _queryCtrl.clear();
                  _onQueryChanged('');
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                      isWorkersTab ? 'Gündelik eleman' : 'Gündelik ilan'),
                  selected: _dailyOnly,
                  onSelected: (v) => setState(() => _dailyOnly = v),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isWorkersTab
                    ? 'Elemanların yayınladığı müsait ilanlar'
                    : 'İşverenlerin açtığı eleman arama ilanları',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isWorkersTab
              ? _WorkersList(
                  query: _query,
                  dailyOnly: _dailyOnly,
                )
              : _NeedsList(
                  query: _query,
                  dailyOnly: _dailyOnly,
                  onContact: _contactEmployer,
                ),
        ),
      ],
    );
  }
}

class _StaffSubTabs extends StatelessWidget {
  const _StaffSubTabs({
    required this.selected,
    required this.onChanged,
  });

  final _StaffExploreTab selected;
  final ValueChanged<_StaffExploreTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tab({
      required _StaffExploreTab value,
      required String label,
      required IconData icon,
      required Color accent,
    }) {
      final on = selected == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: on
                    ? Color.alphaBlend(
                        accent.withValues(alpha: isDark ? 0.28 : 0.14),
                        palette.card,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: on
                      ? accent.withValues(alpha: 0.45)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: on ? accent : palette.inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                      color: on ? accent : palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? palette.surfaceMuted.withValues(alpha: 0.55)
            : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          tab(
            value: _StaffExploreTab.seeker,
            label: 'Eleman',
            icon: Icons.badge_outlined,
            accent: const Color(0xFF2563EB),
          ),
          tab(
            value: _StaffExploreTab.employer,
            label: 'İşveren',
            icon: Icons.business_center_outlined,
            accent: const Color(0xFFEA580C),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClear,
                  ),
          ),
        ),
      ),
    );
  }
}

class _NeedsList extends ConsumerWidget {
  const _NeedsList({
    required this.query,
    required this.dailyOnly,
    required this.onContact,
  });

  final String query;
  final bool dailyOnly;
  final ValueChanged<StaffNeed> onContact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final serverFilter = (
      province: null as String?,
      dailyOnly: dailyOnly ? true : null,
    );
    final async = ref.watch(openStaffNeedsProvider(serverFilter));
    final filter = NeedSearchFilter(query: query, dailyOnly: dailyOnly);

    return async.when(
      loading: () => const SkeletonList(count: 4),
      error: (_, _) => _Empty(
        icon: Icons.error_outline_rounded,
        title: 'İlanlar yüklenemedi',
        message: 'Bağlantınızı kontrol edip tekrar deneyin.',
        onRetry: () => ref.invalidate(openStaffNeedsProvider(serverFilter)),
      ),
      data: (raw) {
        final list = filter.applyClientFilters(raw);
        Future<void> refresh() => awaitRefresh(() async {
              ref.invalidate(openStaffNeedsProvider(serverFilter));
              await ref.read(openStaffNeedsProvider(serverFilter).future);
            });

        if (list.isEmpty) {
          return RefreshableEmpty(
            onRefresh: refresh,
            child: _Empty(
              icon: Icons.work_off_outlined,
              title: raw.isEmpty ? 'Açık ilan yok' : 'Sonuç bulunamadı',
              message: raw.isEmpty
                  ? 'İşverenler ilan açtıkça burada listelenir.'
                  : 'Arama veya gündelik filtresini gevşetin.',
            ),
          );
        }

        return ResponsiveCenter(
          maxWidth: 720,
          child: PullToRefresh(
            onRefresh: refresh,
            child: ListView.separated(
              physics: kPullRefreshPhysics,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: list.length + 1,
              separatorBuilder: (_, i) =>
                  SizedBox(height: i == 0 ? 10 : 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    '${list.length} ilan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                    ),
                  );
                }
                final n = list[i - 1];
                return StaffNeedCard(
                  need: n,
                  onContact: () => onContact(n),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WorkersList extends ConsumerWidget {
  const _WorkersList({
    required this.query,
    required this.dailyOnly,
  });

  final String query;
  final bool dailyOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final serverFilter = (
      province: null as String?,
      dailyOnly: dailyOnly ? true : null,
    );
    final async = ref.watch(openWorkersProvider(serverFilter));
    final filter = WorkerSearchFilter(query: query, dailyOnly: dailyOnly);

    return async.when(
      loading: () => const SkeletonList(count: 4),
      error: (_, _) => _Empty(
        icon: Icons.error_outline_rounded,
        title: 'Liste yüklenemedi',
        message: 'Bağlantınızı kontrol edip tekrar deneyin.',
        onRetry: () => ref.invalidate(openWorkersProvider(serverFilter)),
      ),
      data: (raw) {
        final list = filter.applyClientFilters(raw);
        Future<void> refresh() => awaitRefresh(() async {
              ref.invalidate(openWorkersProvider(serverFilter));
              await ref.read(openWorkersProvider(serverFilter).future);
            });

        if (list.isEmpty) {
          return RefreshableEmpty(
            onRefresh: refresh,
            child: _Empty(
              icon: Icons.person_off_outlined,
              title: raw.isEmpty ? 'Müsait eleman yok' : 'Sonuç bulunamadı',
              message: raw.isEmpty
                  ? 'Elemanlar profilini yayınladıkça burada görünür.'
                  : 'Arama veya gündelik filtresini gevşetin.',
            ),
          );
        }

        return ResponsiveCenter(
          maxWidth: 720,
          child: PullToRefresh(
            onRefresh: refresh,
            child: ListView.separated(
              physics: kPullRefreshPhysics,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    '${list.length} eleman',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                    ),
                  );
                }
                final w = list[i - 1];
                return StaffWorkerCard(
                  worker: w,
                  onTap: () =>
                      context.push(RoutePaths.staffWorkerDetail(w.id)),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: palette.inkFaint),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.inkMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}

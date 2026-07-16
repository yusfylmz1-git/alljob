import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/surface_app_bar.dart';
import '../../../core/widgets/pull_to_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/models/staffing.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../data/staffing_providers.dart';
import 'need_detailed_search_sheet.dart';
import 'need_search_filter.dart';

/// İŞ ARIYORUM tarafı — açık eleman ilanları.
class StaffNeedBrowseScreen extends ConsumerStatefulWidget {
  const StaffNeedBrowseScreen({super.key});

  @override
  ConsumerState<StaffNeedBrowseScreen> createState() =>
      _StaffNeedBrowseScreenState();
}

class _StaffNeedBrowseScreenState extends ConsumerState<StaffNeedBrowseScreen> {
  NeedSearchFilter _filter = const NeedSearchFilter();
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _applyQuery(String q) {
    setState(() => _filter = _filter.copyWith(query: q));
  }

  Future<void> _openDetailed() async {
    final result =
        await showNeedDetailedSearchSheet(context, initial: _filter);
    if (result != null && mounted) {
      setState(() => _filter = result.copyWith(query: _queryCtrl.text));
    }
  }

  void _clearAll() {
    _queryCtrl.clear();
    setState(() => _filter = const NeedSearchFilter());
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
    final serverFilter = (
      province: (_filter.province == null || _filter.province!.isEmpty)
          ? null
          : _filter.province,
      dailyOnly: _filter.dailyOnly ? true : null,
    );
    final async = ref.watch(openStaffNeedsProvider(serverFilter));
    final palette = context.palette;
    final detailCount = _filter.activeDetailCount;

    return Scaffold(
      appBar: SurfaceAppBar(
        title: 'Eleman · İşveren ilanları',
        icon: Icons.work_outline,
        actions: [
          if (_filter.query.trim().isNotEmpty || detailCount > 0)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (ref.read(currentUserProvider) == null) {
            context.push(RoutePaths.login);
            return;
          }
          context.push(RoutePaths.staffNeedNew);
        },
        icon: const Icon(Icons.add),
        label: const Text('İşveren ilanı'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ResponsiveCenter(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.infoSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ELEMAN · İşverenlerin açık ilanları — “başvur” yok, sohbetle yazın',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: _applyQuery,
                    onSubmitted: _applyQuery,
                    decoration: InputDecoration(
                      hintText: 'Başlık, işveren, il…',
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_queryCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _queryCtrl.clear();
                                _applyQuery('');
                              },
                            ),
                          IconButton(
                            icon: Badge(
                              isLabelVisible: detailCount > 0,
                              label: Text('$detailCount'),
                              child: const Icon(Icons.tune_rounded),
                            ),
                            onPressed: _openDetailed,
                          ),
                        ],
                      ),
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    avatar: Icon(
                      _filter.dailyOnly
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: const Text('Gündelik eleman arayışı'),
                    selected: _filter.dailyOnly,
                    onSelected: (v) => setState(() {
                      _filter = _filter.copyWith(dailyOnly: v);
                    }),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (_, _) => RefreshableEmpty(
                onRefresh: () => awaitRefresh(() async {
                  ref.invalidate(openStaffNeedsProvider(serverFilter));
                  await ref
                      .read(openStaffNeedsProvider(serverFilter).future);
                }),
                child: ErrorView(
                  message: 'İlanlar yüklenemedi.',
                  onRetry: () =>
                      ref.invalidate(openStaffNeedsProvider(serverFilter)),
                ),
              ),
              data: (raw) {
                Future<void> refresh() => awaitRefresh(() async {
                      ref.invalidate(openStaffNeedsProvider(serverFilter));
                      await ref
                          .read(openStaffNeedsProvider(serverFilter).future);
                    });
                final list = _filter.applyClientFilters(raw);
                if (list.isEmpty) {
                  return RefreshableEmpty(
                    onRefresh: refresh,
                    child: Center(
                      child: Text(
                        raw.isEmpty
                            ? 'Açık eleman ilanı yok.'
                            : 'Aramanıza uyan ilan yok.',
                        textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text('${list.length} sonuç',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.inkMuted));
                        }
                      final n = list[i - 1];
                      final date = n.workDate == null
                          ? null
                          : DateFormat('d MMM', 'tr_TR').format(n.workDate!);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.border),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                              '${n.employerName} · ${n.placeLabel}',
                              style: TextStyle(
                                  fontSize: 12, color: palette.inkMuted),
                            ),
                            const SizedBox(height: 6),
                            Text(n.detail,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Chip(
                                    label:
                                        Text('${n.neededCount} kişi')),
                                Chip(label: Text(n.rateLabel)),
                                if (n.isDaily)
                                  const Chip(label: Text('Gündelik')),
                                if (date != null)
                                  Chip(label: Text(date)),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonal(
                                onPressed: () => _contactEmployer(n),
                                child: const Text('İşverene yaz'),
                              ),
                            ),
                          ],
                        ),
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

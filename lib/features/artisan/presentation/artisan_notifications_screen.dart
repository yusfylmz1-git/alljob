import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/job_providers.dart';

/// Usta genel bildirimleri. Push bildirimleri (FCM) gelene dek mevcut
/// verilerden türetilen olaylar gösterilir: bölgedeki yeni ilanlar ve
/// seçildiğin işler.
class ArtisanNotificationsScreen extends ConsumerWidget {
  const ArtisanNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final nearby = ref.watch(nearbyJobsProvider).valueOrNull ?? const <Job>[];
    final assigned = user == null
        ? const <Job>[]
        : ref.watch(assignedJobsProvider(user.uid)).valueOrNull ?? const <Job>[];

    // Basit bildirim akışı: seçilme olayları + yeni ilanlar (en yeni üstte).
    final items = <_NotifItem>[
      for (final j in assigned.where((j) =>
          j.status == JobStatus.workerSelected ||
          j.status == JobStatus.inProgress))
        _NotifItem(
          icon: Icons.assignment_turned_in_outlined,
          color: AppColors.success,
          title: 'Bir iş için seçildin',
          body: j.title,
          date: j.createdAt,
          jobId: j.jobId,
        ),
      for (final j in nearby)
        _NotifItem(
          icon: Icons.work_outline,
          color: AppColors.info,
          title: j.isUrgent ? 'Acil yeni iş ilanı' : 'Bölgende yeni iş ilanı',
          body: '${j.title} — ${j.province} / ${j.district}',
          date: j.createdAt,
          jobId: j.jobId,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Bildirimler',
        icon: Icons.notifications_none_rounded,
      ),
      body: items.isEmpty
          ? const _EmptyNotifications()
          : ResponsiveCenter(
              maxWidth: 720,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NotifTile(item: items[i]),
              ),
            ),
    );
  }
}

class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.date,
    this.jobId,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final DateTime date;
  final String? jobId;
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item});
  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.jobId == null
            ? null
            : () => context.push(RoutePaths.jobDetail(item.jobId!)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('d MMM', 'tr_TR').format(item.date),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Henüz bildirimin yok', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Bölgende yeni iş ilanı çıktığında veya bir iş için '
              'seçildiğinde burada görünecek.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../../auth/application/auth_controller.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';

/// Müşterinin kendi iş ilanları (İlanlarım).
class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İlanlarım',
        icon: Icons.campaign_outlined,
      ),
      bottomNavigationBar: const MainBottomBar(current: MainTab.work),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newJob),
        icon: const Icon(Icons.add),
        label: const Text('Yeni İlan'),
      ),
      body: user == null
          ? const Center(child: Text('Oturum bulunamadı.'))
          : ref.watch(myJobsProvider(user.uid)).when(
                loading: () => const SkeletonList(),
                error: (e, _) => Center(child: Text('İlanlar yüklenemedi.\n$e')),
                data: (jobs) => jobs.isEmpty
                    ? const _EmptyJobs()
                    : ResponsiveCenter(
                        maxWidth: 720,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: jobs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _JobCard(job: jobs[i]),
                        ),
                      ),
              ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final status = job.effectiveStatus;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.jobDetail(job.jobId)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (job.isUrgent) ...[
                    const UrgentBadge(compact: true),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  JobStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${kProfessionNames[job.category] ?? job.category} • '
                '${job.district}${job.neighborhood != null ? ' / ${job.neighborhood}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status == JobStatus.open || status == JobStatus.expired)
                    OfferCountBadge(count: job.offerCount)
                  else
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: 'Usta seçildi',
                    ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined,
                  size: 34, color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Henüz ilanınız yok',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'İş ilanı verin, bölgenizdeki ustalar sizinle iletişime geçsin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

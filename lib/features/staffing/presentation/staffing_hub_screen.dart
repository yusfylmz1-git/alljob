import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/application/auth_controller.dart';

/// Eleman — net iki yol: iş arıyorum / eleman arıyorum.
class StaffingHubScreen extends ConsumerWidget {
  const StaffingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final palette = context.palette;
    final theme = Theme.of(context);

    void requireLoginThen(String path) {
      if (user == null) {
        context.push(RoutePaths.login);
        return;
      }
      context.push(path);
    }

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Eleman',
        icon: Icons.badge_outlined,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Ne yapmak istiyorsunuz?',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Başvuru formu yok. İş arayan müsait görünür; eleman arayan '
              'listeden bulur ve sohbeti başlatır.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 20),

            // —— Eleman (iş arayan) ——
            _PathCard(
              color: palette.info,
              surface: palette.infoSurface,
              icon: Icons.work_outline_rounded,
              badge: 'ELEMAN',
              title: 'İş arıyorum',
              body:
                  'Müsait profilinizi yayınlayın. İşverenler sizi bulur ve size '
                  'yazar. İsterseniz gündelik işlere de açık olun.',
              primaryLabel: 'Eleman profilim',
              onPrimary: () => requireLoginThen(RoutePaths.staffMyWorker),
              secondaryLabel: 'İşveren ilanlarına bak',
              onSecondary: () =>
                  requireLoginThen(RoutePaths.staffNeeds),
            ),
            const SizedBox(height: 14),

            // —— İşveren (eleman arayan) ——
            _PathCard(
              color: palette.primary,
              surface: palette.primaryContainer,
              icon: Icons.person_search_rounded,
              badge: 'İŞVEREN',
              title: 'Eleman arıyorum',
              body:
                  'Müsait eleman listesini gezin ve sohbeti siz başlatın. '
                  'Gündelik ihtiyaç için ilan da açabilirsiniz.',
              primaryLabel: 'Eleman ara',
              onPrimary: () =>
                  requireLoginThen(RoutePaths.staffWorkers),
              secondaryLabel: 'İşveren ilanı aç',
              onSecondary: () =>
                  requireLoginThen(RoutePaths.staffNeedNew),
            ),
            const SizedBox(height: 14),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border),
              ),
              leading: Icon(Icons.folder_open_outlined,
                  color: palette.primary),
              title: const Text('İşveren ilanlarım'),
              subtitle: const Text('Açtığınız eleman arama ilanları'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => requireLoginThen(RoutePaths.staffMyNeeds),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.color,
    required this.surface,
    required this.icon,
    required this.badge,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final Color color;
  final Color surface;
  final IconData icon;
  final String badge;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: color,
                        )),
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted, height: 1.4)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSecondary,
            child: Text(secondaryLabel),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart' show AppConstants;
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../membership/billing_config.dart';
import '../../membership/billing_service.dart';
import '../../membership/membership_access.dart';
import '../../membership/membership_package.dart';

/// Premium / Pro — plan durumu + (hazırsa) Play satın alma.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final plan = ref.watch(selectedMembershipPackageProvider) ??
        MembershipPackage.free;
    final unlocked = ref.watch(artisanProAccessProvider);
    final billing = ref.watch(billingServiceProvider);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Pro Üyelik',
        icon: Icons.workspace_premium_outlined,
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: palette.heroGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const BrandMark(size: 44),
                  const SizedBox(height: 14),
                  Text(
                    '${AppConstants.appName} Pro',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Müsait görünmek, iş ilanlarına ulaşmak ve müşterilere '
                    'çıkmak Pro kapsamındadır.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(
                    unlocked ? Icons.check_circle : Icons.lock_outline,
                    color: unlocked ? palette.success : palette.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktif plan: ${plan.titleTR}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          unlocked
                              ? 'Pro özellikler açık'
                              : 'Pro özellikler kilitli — plan yükseltin',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Benefit(
              icon: Icons.visibility_outlined,
              text: 'Müşteri aramalarında görünürsünüz',
            ),
            const _Benefit(
              icon: Icons.work_outline,
              text: 'Bölgenizdeki iş ilanlarını görüp iletişime geçersiniz',
            ),
            const _Benefit(
              icon: Icons.toggle_on_outlined,
              text: '"Müsait" durumunu istediğiniz an açıp kapatırsınız',
            ),
            const _Benefit(
              icon: Icons.workspace_premium_outlined,
              text: 'Öne çıkan Pro rozeti (yayın sonrası)',
            ),
            const SizedBox(height: 24),
            if (!unlocked) ...[
              FilledButton.icon(
                onPressed: () =>
                    context.push('${RoutePaths.packageSelect}?change=1'),
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Beta planına geç (ücretsiz)'),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.tonalIcon(
              onPressed: () async {
                if (!kBillingEnabled || kIsWeb) {
                  context.showInfo(
                    kBillingEnabled
                        ? 'Web’de abonelik yok; Android uygulamayı kullanın.'
                        : 'Play Billing henüz açılmadı (billing_config). '
                            'Şimdilik Beta planı ile Pro özellikler ücretsiz.',
                  );
                  if (!unlocked) {
                    context.push('${RoutePaths.packageSelect}?change=1');
                  }
                  return;
                }
                final ok = await billing.buyProMonthly();
                if (!context.mounted) return;
                if (!ok) {
                  context.showError(
                    'Satın alma başlatılamadı. Ürün kimliği Console’da '
                    'tanımlı mı? ($kProMonthlyProductId)',
                  );
                } else {
                  context.showInfo('Play ödeme penceresi açıldı…');
                }
              },
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                kBillingEnabled ? 'Pro abone ol (Play)' : 'Pro abone ol (yakında)',
              ),
            ),
            if (kBillingEnabled && !kIsWeb) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await billing.restore();
                  if (context.mounted) {
                    context.showInfo('Satın alımlar yenileniyor…');
                  }
                },
                child: const Text('Satın alımları geri yükle'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.push('${RoutePaths.packageSelect}?change=1'),
              child: const Text('Tüm planları gör'),
            ),
            const SizedBox(height: 16),
            Text(
              kBillingEnabled
                  ? 'Ödeme Google Play üzerinden alınır. Abonelik sunucuda '
                      'doğrulanır; Pro bayrağını yalnız sunucu yazar.'
                  : 'Play abonelik altyapısı hazır (sunucu doğrulama). '
                      'Ürün Console’da tanımlanınca billing açılır. '
                      'Şimdilik Beta planı ile Pro özellikler ücretsiz.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: palette.inkMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.premiumSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: palette.premium, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

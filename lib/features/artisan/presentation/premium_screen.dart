import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../application/my_profile_controller.dart';

/// Premium abonelik / ödeme sayfası. Usta "Müsait" olabilmek için Premium
/// üye olmalıdır (PRD §6). Gerçek ödeme entegrasyonu ileride; şimdilik
/// "Premium Ol" abonelği etkinleştirir ve ustayı müsait yapar.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final ctrl = ref.read(myProfileControllerProvider.notifier);
    final okPremium = await ctrl.setPremium(true);
    // Premium olunca ustayı otomatik "müsait" yap.
    final okAvail = okPremium && await ctrl.setAvailable(true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (okPremium && okAvail) {
      context.showSuccess('Premium etkinleştirildi. Artık müsait görünüyorsunuz.');
      if (context.canPop()) context.pop();
    } else {
      context.showError('İşlem tamamlanamadı. Tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Premium Üyelik',
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
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const BrandMark(size: 44),
                  const SizedBox(height: 14),
                  Text('Usta Cepte Premium',
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Müsait görünmek, iş ilanlarına ulaşmak ve müşterilere '
                    'çıkmak için Premium gerekir.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _Benefit(
                icon: Icons.visibility_outlined,
                text: 'Müşteri aramalarında görünürsünüz'),
            const _Benefit(
                icon: Icons.work_outline,
                text: 'Bölgenizdeki iş ilanlarını görüp iletişime geçersiniz'),
            const _Benefit(
                icon: Icons.toggle_on_outlined,
                text: '"Müsait" durumunu istediğiniz an açıp kapatırsınız'),
            const _Benefit(
                icon: Icons.workspace_premium_outlined,
                text: 'Öne çıkan Premium rozeti'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.premiumSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.premium.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text('İlk yıl ücretsiz',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.premium)),
                  const SizedBox(height: 4),
                  Text('Sonrasında aylık ₺99',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.premium)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Premium Ol ve Müsait Görün',
              icon: Icons.workspace_premium,
              isLoading: _busy,
              onPressed: _subscribe,
            ),
            const SizedBox(height: 8),
            Text(
              'Ödeme altyapısı yakında entegre edilecek. Şu an ilk yıl ücretsizdir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

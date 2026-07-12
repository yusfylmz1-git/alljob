import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';

/// Premium bilgi sayfası (PRD §6). Beta süresince tüm Premium özellikler
/// ücretsizdir ve `isPremium` alanı istemciden YAZILAMAZ (firestore.rules) —
/// bu yüzden burada etkinleştirme butonu YOK. Gerçek satın alma (Play
/// Billing + sunucu doğrulaması) beta sonrasında bu sayfaya eklenecek.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
                gradient: context.palette.heroGradient,
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
                    'çıkmak Premium kapsamındadır.',
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
                color: context.palette.premiumSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: context.palette.premium.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                      AppConstants.premiumFreeDuringBeta
                          ? 'Beta süresince ücretsiz'
                          : 'Yakında',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.palette.premium)),
                  const SizedBox(height: 4),
                  Text(
                      AppConstants.premiumFreeDuringBeta
                          ? 'Tüm Premium özellikler şu an tüm ustalara açık. '
                              'Yapmanız gereken tek şey profilinizden '
                              '"Müsait" olmak.'
                          : 'Ödeme altyapısı hazırlanıyor; Premium satın alma '
                              'çok yakında burada olacak.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.palette.premium)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ücretlendirme, beta süreci tamamlanırken uygulama içinden '
              'duyurulacak.',
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
              color: context.palette.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: context.palette.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

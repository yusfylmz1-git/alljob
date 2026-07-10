import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../onboarding_state.dart';

/// İlk açılışta gösterilen 3 sayfalık tanıtım akışı (yalnızca bir kez).
/// Değer önerisini müşteri ve usta gözünden anlatır; "Atla" her an çıkar.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _pages = [
    _PageData(
      icon: Icons.handyman_rounded,
      accentIcon: Icons.verified_rounded,
      title: 'Aradığın usta, bölgende',
      body: 'Tamirattan taşımaya, boyadan tesisata — mahallendeki '
          'ustaları puanlarıyla ve yorumlarıyla gör, güvenle anlaş.',
    ),
    _PageData(
      icon: Icons.campaign_rounded,
      accentIcon: Icons.bolt_rounded,
      title: 'İlanını ver, arkana yaslan',
      body: 'Ne yaptıracağını yaz, yeter. Bölgendeki doğru ustalar anında '
          'haberdar olur, seninle uygulama içinden iletişime geçer.',
    ),
    _PageData(
      icon: Icons.storefront_rounded,
      accentIcon: Icons.star_rounded,
      title: 'Usta mısın? Kazanmaya başla',
      body: 'Ücretsiz profilini aç, bölgendeki işleri anında gör. '
          'İyi işçilik + iyi yorumlar = daha çok müşteri.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (!mounted) return;
    ref.read(onboardingSeenProvider.notifier).state = true;
    context.go(RoutePaths.home);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _page.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Üst şerit: marka + Atla.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Usta Cepte',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Atla'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            // Nokta göstergesi: aktif sayfa hap şeklinde uzar.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? context.palette.primary
                          : context.palette.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: AppButton(
                label: last ? 'Hemen Başla' : 'Devam',
                icon: last ? Icons.rocket_launch_rounded : null,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.accentIcon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final IconData accentIcon;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Katmanlı ikon kompozisyonu: yumuşak halka + gradyan çekirdek +
          // sağ üstte küçük vurgu rozeti.
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: context.palette.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(data.icon, size: 64, color: Colors.white),
                ),
                Positioned(
                  top: 18,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: context.palette.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.palette.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A101828), blurRadius: 10),
                      ],
                    ),
                    child: Icon(data.accentIcon,
                        size: 20, color: context.palette.secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.palette.inkMuted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../legal/legal_docs.dart';
import '../../membership/membership_package.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// Giriş — yalnızca Google (e-posta/şifre kaldırıldı).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _consent = false;
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalTerms.id));
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalPrivacy.id));
  late final _kvkkTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalKvkk.id));

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _kvkkTap.dispose();
    super.dispose();
  }

  void _goAfterLogin() {
    final seen = ref.read(packageSelectionSeenProvider);
    context.go(seen ? RoutePaths.home : RoutePaths.packageSelect);
  }

  Future<void> _google() async {
    if (!_consent) {
      context.showInfo(
          'Devam etmek için kullanım koşulları ve KVKK metnini onaylayın.');
      return;
    }
    final ok =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      _goAfterLogin();
    } else {
      final error = ref.read(authControllerProvider).error;
      context.showError(
        error is AuthException ? error.message : AuthException.unknown.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(
                        color: Colors.white,
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(RoutePaths.home),
                      ),
                    ),
                    const BrandMark(size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Hoş geldiniz',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Google hesabınızla güvenli ve hızlı giriş',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveCenter(
                maxWidth: 440,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tek hesap, çift rol',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Müşteri olarak ilan verin veya usta olarak hizmet '
                            'verin. Hepsi aynı Google hesabıyla.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              side: BorderSide(
                                  color: theme.colorScheme.outlineVariant),
                            ),
                            icon: const _GoogleLogo(),
                            label: Text(
                              isLoading
                                  ? 'Giriş yapılıyor…'
                                  : 'Google ile devam et',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            onPressed: isLoading ? null : _google,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Checkbox(
                                  value: _consent,
                                  onChanged: isLoading
                                      ? null
                                      : (v) => setState(
                                          () => _consent = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(height: 1.35),
                                    children: [
                                      const TextSpan(
                                          text: 'Devam ederek '),
                                      TextSpan(
                                        text: 'Kullanım Koşulları',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: _termsTap,
                                      ),
                                      const TextSpan(text: ', '),
                                      TextSpan(
                                        text: 'Gizlilik',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: _privacyTap,
                                      ),
                                      const TextSpan(text: ' ve '),
                                      TextSpan(
                                        text: 'KVKK',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: _kvkkTap,
                                      ),
                                      const TextSpan(
                                          text: ' metinlerini kabul ediyorum.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'E-posta ve şifre ile kayıt kapatıldı. Yalnızca Google '
                      'ile giriş desteklenir.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Basit renkli "G" yerine Material tarzı dört renkli daire dilimleri.
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final colors = [
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF34A853),
      const Color(0xFF4285F4),
    ];
    for (var i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.35
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect.deflate(r * 0.18), i * 1.57, 1.4, false, paint);
    }
    final blue = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.12, r * 0.55, r * 0.28),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

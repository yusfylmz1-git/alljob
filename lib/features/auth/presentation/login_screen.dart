import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/responsive_center.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// Ekran B — Giriş. Rol, hesaptaki kayıtlı claim'den belirlenir;
/// yönlendirmeyi router otomatik yapar.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Başarılı girişten sonra ana ekrana git — usta ise router otomatik
  /// panele yönlendirir. (Yalnızca auth-dinleyicisine güvenmek Android'de
  /// ekranda takılı kalmaya yol açabiliyordu.)
  void _goAfterLogin() => context.go(RoutePaths.home);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(
          email: _email.text,
          password: _password.text,
        );
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

  Future<void> _google() async {
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

  Future<void> _forgotPassword() async {
    final emailError = Validators.email(_email.text);
    if (emailError != null) {
      context.showInfo('Önce geçerli bir e-posta adresi girin.');
      return;
    }
    await ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);
    if (!mounted) return;
    context.showSuccess('Şifre sıfırlama bağlantısı e-postanıza gönderildi.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: Column(
        children: [
          // Lacivert karşılama başlığı.
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
                      'Tekrar hoş geldiniz',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hesabınıza giriş yapın, kaldığınız yerden devam edin',
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
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
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                hintText: 'ornek@eposta.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) =>
                                  Validators.required(v, field: 'Şifre'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading ? null : _forgotPassword,
                                child: const Text('Şifremi unuttum'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppButton(
                              label: 'Giriş Yap',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: isLoading,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'veya',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Google ile giriş (#3). Yeni Google hesabı müşteri
                      // olarak açılır; mevcut hesabın rolü korunur.
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const _GoogleLogo(),
                        label: const Text('Google ile devam et'),
                        onPressed: isLoading ? null : _google,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Yeni Hesap Oluştur',
                        icon: Icons.person_add_alt_1_outlined,
                        variant: AppButtonVariant.outlined,
                        onPressed: isLoading
                            ? null
                            : () => context.go(RoutePaths.register),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google'ın çok renkli "G" logosu (paket gerektirmez).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final inner = rect.deflate(stroke / 2);

    // Dört renkli yay (kabaca Google "G" görünümü).
    paint.color = const Color(0xFFEA4335); // kırmızı (üst)
    canvas.drawArc(inner, -2.35, 1.55, false, paint);
    paint.color = const Color(0xFFFBBC05); // sarı (sol alt)
    canvas.drawArc(inner, 2.35, 1.55, false, paint);
    paint.color = const Color(0xFF34A853); // yeşil (alt)
    canvas.drawArc(inner, 0.8, 1.55, false, paint);
    paint.color = const Color(0xFF4285F4); // mavi (sağ) + yatay çubuk
    canvas.drawArc(inner, -0.35, 1.15, false, paint);
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, size.height * 0.5 - stroke / 2,
          size.width * 0.5, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

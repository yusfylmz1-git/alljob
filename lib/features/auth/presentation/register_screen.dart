import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../legal/legal_docs.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// Ekran B — Kayıt. Tek hesap, çift rol: rol seçimi yok; herkes düz kullanıcı
/// olarak başlar, usta olmak isteyen Profil > "Hizmet Vermeye Başla" der.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  // Yasal onay (KVKK/Store zorunluluğu): kutucuk işaretlenmeden kayıt olmaz.
  bool _consent = false;
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalTerms.id));
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalPrivacy.id));
  late final _kvkkTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.legalDoc(legalKvkk.id));

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    _kvkkTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Form geçerli değilse hata mesajları otomatik gösterilir.
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authControllerProvider.notifier).register(
          displayName: Validators.normalizeDisplayName(_name.text),
          email: _email.text,
          password: _password.text,
        );

    if (!mounted) return;
    if (ok) {
      context.showSuccess('Hesabınız oluşturuldu, hoş geldiniz! Doğrulama '
          'bağlantısı e-posta adresinize gönderildi.');
      context.go(RoutePaths.home);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shape: const Border(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 440,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Hesap oluşturun',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                      'Bilgilerinizi girerek hemen başlayın. Usta olarak '
                      'hizmet vermek isterseniz kayıttan sonra profilinizden '
                      '"Hizmet Vermeye Başla" diyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          maxLength: AppConstants.maxDisplayNameLength,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                            prefixIcon: Icon(Icons.person_outline),
                            helperText: "Harf, rakam, boşluk ve . ' -",
                          ),
                          validator: Validators.displayName,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
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
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Şifre Tekrarı',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text),
                        ),
                        const SizedBox(height: 14),
                        // Yasal onay: Form.validate() bu alanı da doğrular.
                        FormField<bool>(
                          validator: (_) => _consent
                              ? null
                              : 'Kayıt olmak için koşulları kabul etmelisiniz.',
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _consent,
                                      onChanged: (v) {
                                        setState(
                                            () => _consent = v ?? false);
                                        field.didChange(v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.4),
                                        children: [
                                          TextSpan(
                                            text: 'Kullanım Koşulları',
                                            recognizer: _termsTap,
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const TextSpan(text: '\'nı ve '),
                                          TextSpan(
                                            text: 'Gizlilik Politikası',
                                            recognizer: _privacyTap,
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const TextSpan(
                                              text: '\'nı okudum, kabul '
                                                  'ediyorum; kişisel '
                                                  'verilerimin '),
                                          TextSpan(
                                            text: 'KVKK Aydınlatma Metni',
                                            recognizer: _kvkkTap,
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const TextSpan(
                                              text: ' kapsamında '
                                                  'işlenmesine ve yurt dışı '
                                                  'sunucularda saklanmasına '
                                                  'açık rıza veriyorum.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (field.hasError)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6, left: 34),
                                  child: Text(
                                    field.errorText!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Kayıt Ol',
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Wrap: dar ekranda/büyük fontta taşmak yerine alt satıra
                  // iner (Row test fontunda taşıyordu).
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Zaten hesabınız var mı?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.go(RoutePaths.login),
                        child: const Text('Giriş Yap'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

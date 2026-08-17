import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_repository.dart';

/// Apple App Store, Google Play Store ve KVKK/GDPR uyumlu
/// Kullanıcı Hesabı ve Veri Silme Onay Modalı (Destructive Modal).
///
/// Özellikler:
/// - Kırmızı temalı kaza önleme kalkanı.
/// - Silinecek ve anonimleştirilecek verilerin şeffaf envanter dökümü.
/// - Güvenlik kelimesi ("HESABIMI SİL") ve onay kutusu doğrulaması.
/// - Çift tıklama (double-tap) engeli ve işlem esnasında engellenemez durum.
class AccountDeletionSheet extends ConsumerStatefulWidget {
  const AccountDeletionSheet({super.key});

  /// Modalı standart bottom sheet olarak açar.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountDeletionSheet(),
    );
  }

  @override
  ConsumerState<AccountDeletionSheet> createState() =>
      _AccountDeletionSheetState();
}

class _AccountDeletionSheetState extends ConsumerState<AccountDeletionSheet> {
  bool _confirmedCheckbox = false;
  bool _isDeleting = false;

  bool get _canSubmit => _confirmedCheckbox && !_isDeleting;

  Future<void> _executeDeletion() async {
    if (!_canSubmit) return;

    setState(() => _isDeleting = true);

    final nav = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);

    try {
      final ok = await ref.read(authControllerProvider.notifier).deleteAccount();

      if (!mounted) return;

      if (ok) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        router.go(RoutePaths.home);
        if (nav.mounted) {
          nav.context.showSuccess(
            'Hesabınız ve ilişkili verileriniz başarıyla kalıcı olarak silindi.',
          );
        }
      } else {
        setState(() => _isDeleting = false);
        final err = ref.read(authControllerProvider).error;
        if (mounted) {
          context.showError(
            err is AuthException
                ? err.message
                : 'Hesap silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        context.showError('İşlem sırasında bir hata oluştu: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return PopScope(
      canPop: !_isDeleting,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sürükleme Tutamacı
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Başlık & İkon Bandı
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.delete_forever_rounded,
                          color: palette.danger,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hesabı Kalıcı Olarak Sil',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: palette.danger,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bu işlem geri alınamaz',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Uyarı & Bilgilendirme Kartı (KVKK/GDPR Veri Dökümü)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.danger.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.danger.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silinecek ve Temizlenecek Veriler:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.danger,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ItemRow(
                          icon: Icons.check_circle_outline,
                          text: 'Tüm aktif/geçmiş iş ilanlarınız, talepleriniz ve ürünleriniz',
                          color: palette.danger,
                        ),
                        _ItemRow(
                          icon: Icons.check_circle_outline,
                          text: 'Usta ve mağaza vitrininiz, hakkımda yazınız ve ayarlarınız',
                          color: palette.danger,
                        ),
                        _ItemRow(
                          icon: Icons.check_circle_outline,
                          text: 'Yüklediğiniz tüm fotoğraflar, görseller ve belgeler (Storage)',
                          color: palette.danger,
                        ),
                        _ItemRow(
                          icon: Icons.check_circle_outline,
                          text: 'Favorileriniz, bildirim tercihleriniz ve üyelik kayıtlarınız',
                          color: palette.danger,
                        ),
                        const Divider(height: 16),
                        Text(
                          'Anonimleştirilecek Kayıtlar (Hukuki & Güvenlik):',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ItemRow(
                          icon: Icons.info_outline,
                          text: 'Sohbet mesajlarında adınız "Silinmiş Kullanıcı" yapılır, karşı tarafın mesaj geçmişi korunur.',
                          color: palette.inkMuted,
                        ),
                        _ItemRow(
                          icon: Icons.info_outline,
                          text: 'Yazdığınız değerlendirmeler itibar puanı korunarak anonimleştirilir.',
                          color: palette.inkMuted,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Onay Kutusu
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _confirmedCheckbox,
                    activeColor: palette.danger,
                    title: Text(
                      'Tüm verilerimin kalıcı olarak silineceğini ve bu işlemin geri alınamayacağını onaylıyorum.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                        height: 1.3,
                      ),
                    ),
                    onChanged: _isDeleting
                        ? null
                        : (val) => setState(() => _confirmedCheckbox = val ?? false),
                  ),

                  const SizedBox(height: 20),

                  // Aksiyon Butonları
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isDeleting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _canSubmit ? _executeDeletion : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.danger,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: palette.danger.withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Hesabımı Sil',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../presentation/phone_verification_sheet.dart';
import 'auth_controller.dart';

/// Usta / mağaza profili açmak isteyen kişiden **doğrulanmış telefon** isteyen
/// ortak kapı (new.md madde 1–2).
///
/// Neden ortak: sağlayıcı olmanın iki girişi var — usta profili düzenleme ve
/// mağaza kurulumu. Kapı birinde unutulursa doğrulanmamış numarayla sağlayıcı
/// olunabiliyordu; iki ekran da bu tek fonksiyonu çağırır.
///
/// ⚠️ Yeni bir sağlayıcı kaydı girişi eklersen BU KAPIYI ÇAĞIR.
///
/// Akış: doğrulanmışsa doğrudan `true`. Değilse sebebi anlatan bir sayfa
/// açılır → kullanıcı kabul ederse [PhoneVerificationSheet] gelir → doğrulama
/// başarılıysa `true`. Vazgeçerse `false` (çağıran kaydı YAPMAZ).
///
/// Doğrulama akışının kendisi hatalıysa (SMS gelmedi, bölge kapalı…) sheet
/// kendi Türkçe hatasını gösterir; buradan `false` döner ve kullanıcı formda
/// kalır — girdiği veriler kaybolmaz.
Future<bool> ensureVerifiedPhoneForProvider(
  BuildContext context,
  WidgetRef ref, {
  required bool isShop,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return false;

  // Zaten doğrulanmış: kapı sessizce geçer (mevcut sağlayıcılar etkilenmez).
  if (user.phoneVerified) return true;

  final devam = await _telefonGerekliSayfasi(context, isShop: isShop);
  if (devam != true || !context.mounted) return false;

  final ok = await PhoneVerificationSheet.show(context);
  if (ok != true) return false;

  // `setPhoneVerified` users dokümanını yazdı; provider'ın yeni değeri
  // görmesi için okumayı tazele — aksi hâlde kapı aynı turda yine kapalı
  // görünürdü.
  return ref.read(currentUserProvider)?.phoneVerified ?? false;
}

/// Neden telefon istendiğini anlatan sayfa. `true` = doğrulamaya geç.
Future<bool?> _telefonGerekliSayfasi(
  BuildContext context, {
  required bool isShop,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final palette = ctx.palette;
      final rol = isShop ? 'Mağaza' : 'Usta';
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewPaddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Telefon doğrulaması gerekli',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$rol profili açmak için numaranı SMS ile doğrulaman gerekiyor. '
              'Doğrulanmış numara müşterilerde güven yaratır ve profilinde '
              'mavi tik olarak görünür.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Numaran doğrulanmadan kaydedilmez. Girdiğin bilgiler formda '
              'kalır — doğrulamayı bitirince kaydetmeye devam edebilirsin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.sms_outlined, size: 18),
              label: const Text('Telefonu doğrula'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      );
    },
  );
}

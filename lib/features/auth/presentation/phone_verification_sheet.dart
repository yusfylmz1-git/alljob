import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/phone_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/my_profile_repository.dart';
import '../application/auth_controller.dart';
import '../data/phone_verification_repository.dart';

/// Telefon SMS doğrulama akışı (iki adım: numara → kod). Başarılıysa `true`
/// döner; hesaba `phoneVerified` işareti + (usta ise) "mavi tik" yazılır.
///
/// reCAPTCHA / Play Integrity gibi arka plan adımları kullanıcıya gösterilmez:
/// numara girilince yükleme ekranı, ardından doğrudan kod alanı açılır.
class PhoneVerificationSheet extends ConsumerStatefulWidget {
  const PhoneVerificationSheet._({this.isChange = false});

  /// Numara DEĞİŞTİRME akışı mı? (ilk doğrulama değil)
  /// Değiştirmede vitrin rızası yeniden sorulmaz: usta numarasını zaten
  /// gösteriyorsa yeni numara otomatik yerine geçer, göstermiyorsa kapalı
  /// kalır. Mavi tik her iki durumda korunur (yeni numara da SMS ile
  /// doğrulanmıştır).
  final bool isChange;

  /// Alttan açılır doğrulama sayfasını gösterir. Doğrulama tamamlandıysa `true`.
  /// [isChange] true iken metinler "numara değiştirme" diline geçer.
  static Future<bool?> show(BuildContext context, {bool isChange = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
        child: PhoneVerificationSheet._(isChange: isChange),
      ),
    );
  }

  @override
  ConsumerState<PhoneVerificationSheet> createState() =>
      _PhoneVerificationSheetState();
}

enum _Step { phone, code }

class _PhoneVerificationSheetState
    extends ConsumerState<PhoneVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _Step _step = _Step.phone;
  bool _loading = false;
  String? _error;
  PhoneVerificationSession? _session;
  String? _sentTo; // gösterim için E.164

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Ulusal girişten E.164 üretir (+90 önekli, baştaki 0 atılır).
  String _toE164(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+90$digits';
  }

  Future<void> _sendCode() async {
    final e164 = _toE164(_phoneCtrl.text);
    // TR cep: +90 + 10 hane.
    if (e164.length != 13) {
      setState(() => _error = 'Geçerli bir cep telefonu numarası girin.');
      return;
    }
    // Arka plan (reCAPTCHA vb.) kullanıcıya görünmesin: hemen kod adımına
    // geç, yükleme metni göster; oturum gelince alanı aç.
    setState(() {
      _loading = true;
      _error = null;
      _sentTo = e164;
      _step = _Step.code;
      _session = null;
      _codeCtrl.clear();
    });
    try {
      final session = await ref
          .read(phoneVerificationRepositoryProvider)
          .sendCode(e164);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
    } on PhoneVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _step = _Step.phone;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = PhoneVerificationException.unknown.message;
        _loading = false;
        _step = _Step.phone;
      });
    }
  }

  Future<void> _confirmCode() async {
    final session = _session;
    if (session == null) return;
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = '6 haneli kodu girin.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(phoneVerificationRepositoryProvider);
      final phone = await repo.confirmCode(
        session,
        _codeCtrl.text,
        replaceExisting: widget.isChange,
      );

      // Uygulama verisini yaz: herkese açık phoneVerified + (usta ise) mavi tik.
      final user = await ref
          .read(authRepositoryProvider)
          .setPhoneVerified(phone);
      if (user.hasArtisanProfile) {
        await ref.read(myProfileRepositoryProvider).markVerified(user.uid);
        ref.invalidate(myProfileControllerProvider);
      }

      if (!mounted) return;

      if (user.hasArtisanProfile) {
        if (widget.isChange) {
          // NUMARA DEĞİŞİMİ: rıza yeniden sorulmaz. Vitrin AÇIKSA yeni numara
          // eskisinin yerine geçer — aksi hâlde profilde artık kullanılmayan
          // eski numara kalır ve müşteri yanlış kişiyi arar. Kapalıysa kapalı
          // kalır (usta göstermek isterse profilden açar).
          final showing =
              ref
                  .read(myProfileControllerProvider)
                  .valueOrNull
                  ?.profile
                  .showPhoneOnProfile ??
              false;
          if (showing) {
            await ref
                .read(myProfileRepositoryProvider)
                .setPhoneVisibility(
                  uid: user.uid,
                  showOnProfile: true,
                  publicPhone: phone,
                );
            ref.invalidate(myProfileControllerProvider);
          }
        } else {
          // İLK doğrulama: şık diyalog — telefon vitrinde görünsün mü?
          final show = await _askShowPhoneOnProfile(context, phone);
          if (show != null) {
            await ref
                .read(myProfileRepositoryProvider)
                .setPhoneVisibility(
                  uid: user.uid,
                  showOnProfile: show,
                  publicPhone: show ? phone : null,
                );
            ref.invalidate(myProfileControllerProvider);
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PhoneVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = PhoneVerificationException.unknown.message;
        _loading = false;
      });
    }
  }

  /// Şık rıza diyaloğu. true = göster, false = gizle, null = atla.
  static Future<bool?> _askShowPhoneOnProfile(
    BuildContext context,
    String phoneE164,
  ) {
    final display = formatTrPhone(phoneE164);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final palette = ctx.palette;
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
                      Icons.phone_in_talk_outlined,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Telefon numaran görünsün mü?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'İstersen müşteriler vitrininde numaranı görüp tek dokunuşla '
                'arayabilir. Gizlersen yalnız sohbet üzerinden ulaşırlar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.call_rounded, color: palette.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Önizleme',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            display,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.visibility_outlined, size: 20),
                label: const Text('Evet, profilde görünsün'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.visibility_off_outlined, size: 20),
                label: const Text('Hayır, gizli kalsın'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final waitingSession = _step == _Step.code && _session == null && _loading;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 24),
              const SizedBox(width: 10),
              Text(
                widget.isChange ? 'Numaranı Değiştir' : 'Telefonunu Doğrula',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _step == _Step.phone
                ? (widget.isChange
                      ? 'Yeni numaranı gir; SMS ile doğrulayınca eskisinin '
                            'yerine geçer. Doğrulanmış rozetin korunur.'
                      : 'Numaranı doğrulayan hesaplar mavi tik (doğrulanmış) '
                            'rozeti alır.')
                : waitingSession
                ? 'SMS hazırlanıyor… Birkaç saniye sürebilir.'
                : '$_sentTo numarasına gönderilen 6 haneli kodu gir.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_step == _Step.phone)
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                labelText: 'Cep telefonu',
                hintText: '5xx xxx xx xx',
                prefixText: '+90 ',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loading ? null : _sendCode(),
            )
          else if (waitingSession)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 14),
                    Text('Kod gönderiliyor…'),
                  ],
                ),
              ),
            )
          else
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              enabled: !_loading && _session != null,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                hintText: '– – – – – –',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loading ? null : _confirmCode(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (!waitingSession) ...[
            const SizedBox(height: 20),
            AppButton(
              label: _step == _Step.phone ? 'Kod Gönder' : 'Doğrula',
              isLoading: _loading,
              icon: _step == _Step.phone ? Icons.sms_outlined : Icons.verified,
              onPressed: _step == _Step.phone
                  ? _sendCode
                  : (_session == null ? null : _confirmCode),
            ),
          ],
          if (_step == _Step.code && !waitingSession) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _step = _Step.phone;
                      _error = null;
                      _session = null;
                      _codeCtrl.clear();
                    }),
              child: const Text('Numarayı değiştir'),
            ),
          ],
        ],
      ),
    );
  }
}

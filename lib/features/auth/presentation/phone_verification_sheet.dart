import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../artisan/data/my_profile_repository.dart';
import '../application/auth_controller.dart';
import '../data/phone_verification_repository.dart';

/// Telefon SMS doğrulama akışı (iki adım: numara → kod). Başarılıysa `true`
/// döner; hesaba `phoneVerified` işareti + (usta ise) "mavi tik" yazılır.
///
/// Herkese açıktır (müşteri de doğrulayabilir); mavi tik yalnızca usta profili
/// olanlarda görünür.
class PhoneVerificationSheet extends ConsumerStatefulWidget {
  const PhoneVerificationSheet._();

  /// Alttan açılır doğrulama sayfasını gösterir. Doğrulama tamamlandıysa `true`.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 4),
        child: PhoneVerificationSheet._(),
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session =
          await ref.read(phoneVerificationRepositoryProvider).sendCode(e164);
      if (!mounted) return;
      setState(() {
        _session = session;
        _sentTo = e164;
        _step = _Step.code;
        _loading = false;
      });
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
      final phone = await repo.confirmCode(session, _codeCtrl.text);

      // Uygulama verisini yaz: herkese açık phoneVerified + (usta ise) mavi tik.
      final user = await ref.read(authRepositoryProvider).setPhoneVerified(phone);
      if (user.hasArtisanProfile) {
        await ref.read(myProfileRepositoryProvider).markVerified(user.uid);
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                'Telefonunu Doğrula',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _step == _Step.phone
                ? 'Numaranı doğrulayan hesaplar mavi tik (doğrulanmış) rozeti alır.'
                : '$_sentTo numarasına gönderilen 6 haneli kodu gir.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.black54),
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
          else
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
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
          const SizedBox(height: 20),
          AppButton(
            label: _step == _Step.phone ? 'Kod Gönder' : 'Doğrula',
            isLoading: _loading,
            icon: _step == _Step.phone ? Icons.sms_outlined : Icons.verified,
            onPressed: _step == _Step.phone ? _sendCode : _confirmCode,
          ),
          if (_step == _Step.code) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _step = _Step.phone;
                        _error = null;
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

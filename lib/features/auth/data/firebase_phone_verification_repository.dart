import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'phone_verification_repository.dart';

/// Firebase Authentication ile telefon doğrulama (SMS OTP) + numarayı mevcut
/// hesaba bağlama (linkWithCredential / linkWithPhoneNumber).
///
/// Platform ayrımı:
///  - Web: `user.linkWithPhoneNumber` → görünmez reCAPTCHA + `ConfirmationResult`.
///  - Mobil (Android/iOS): `verifyPhoneNumber` (codeSent → verificationId) →
///    `PhoneAuthProvider.credential` → `user.linkWithCredential`.
class FirebasePhoneVerificationRepository
    implements PhoneVerificationRepository {
  FirebasePhoneVerificationRepository({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  @override
  Future<PhoneVerificationSession> sendCode(String phoneE164) async {
    final user = _auth.currentUser;
    if (user == null) throw PhoneVerificationException.notSignedIn;

    try {
      if (kIsWeb) {
        // Web: reCAPTCHA doğrulayıcısı firebase_auth tarafından yönetilir.
        final confirmation = await user.linkWithPhoneNumber(phoneE164);
        return PhoneVerificationSession(
          phoneE164: phoneE164,
          webConfirmation: confirmation,
        );
      }

      // Mobil: callback tabanlı akışı Completer ile "kod gönderildi"ye indir.
      final completer = Completer<PhoneVerificationSession>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          // Android otomatik doğrulama: kodu yine de elle isteyeceğiz; burada
          // bir şey yapmaya gerek yok (confirmCode linkWithCredential yapar).
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.completeError(_map(e));
        },
        codeSent: (verificationId, _) {
          if (!completer.isCompleted) {
            completer.complete(PhoneVerificationSession(
              phoneE164: phoneE164,
              verificationId: verificationId,
            ));
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return completer.future;
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String> confirmCode(
      PhoneVerificationSession session, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw PhoneVerificationException.notSignedIn;

    try {
      if (session.webConfirmation != null) {
        // Web: linkWithPhoneNumber sonucu üzerinden onayla (bağlama olur).
        final confirmation = session.webConfirmation as fb.ConfirmationResult;
        await confirmation.confirm(smsCode.trim());
      } else {
        final credential = fb.PhoneAuthProvider.credential(
          verificationId: session.verificationId!,
          smsCode: smsCode.trim(),
        );
        await user.linkWithCredential(credential);
      }
      // Jetonu tazele → phone_number claim'i güncel (kural doğrulaması için).
      await user.getIdToken(true);
      return session.phoneE164;
    } on fb.FirebaseAuthException catch (e) {
      // Telefon zaten bu hesaba bağlıysa doğrulanmış say (idempotent).
      if (e.code == 'provider-already-linked') {
        await user.getIdToken(true);
        return session.phoneE164;
      }
      throw _map(e);
    }
  }

  PhoneVerificationException _map(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return PhoneVerificationException.invalidNumber;
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return PhoneVerificationException.invalidCode;
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return PhoneVerificationException.alreadyInUse;
      case 'too-many-requests':
        return PhoneVerificationException.tooManyRequests;
      case 'operation-not-allowed':
        return PhoneVerificationException.providerDisabled;
      default:
        return PhoneVerificationException(
            'Doğrulama başarısız (${e.code}). Lütfen tekrar deneyin.');
    }
  }
}

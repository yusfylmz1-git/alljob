import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/utils/app_log.dart';
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
        // NOT: bu `timeout` OTOMATİK KOD OKUMA süresidir (SMS Retriever),
        // isteğin kendi zaman aşımı DEĞİL. Aşağıdaki `.timeout(...)` ayrı
        // bir korumadır — bkz. sonraki yorum.
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
            completer.complete(
              PhoneVerificationSession(
                phoneE164: phoneE164,
                verificationId: verificationId,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );

      // ⏱️ SONSUZ BEKLEME KORUMASI (2026-08-10 kullanıcı bulgusu:
      // "Kod gönderiliyor" ekranında uzunca bekliyor).
      //
      // `verifyPhoneNumber` geri çağrı tabanlıdır: ne `codeSent` ne de
      // `verificationFailed` tetiklenmezse Completer SONSUZA KADAR bekler
      // ve kullanıcı dönüşü olmayan bir ekranda kalır. Bu, reCAPTCHA
      // akışı yarıda kalınca (tarayıcı sekmesi kapatıldı, doğrulama
      // tamamlanmadı) veya ağ sessizce düşünce gerçekten oluyor.
      //
      // 75 sn: Firebase'in kendi 60 sn'lik otomatik okuma penceresinden
      // uzun tutuldu ki normal akışı kesmesin.
      return completer.future.timeout(
        const Duration(seconds: 75),
        onTimeout: () => throw PhoneVerificationException.timedOut,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String> confirmCode(
    PhoneVerificationSession session,
    String smsCode, {
    bool replaceExisting = false,
  }) async {
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
        if (replaceExisting) {
          // DEĞİŞTİRME: hesapta zaten telefon var. link* burada
          // `provider-already-linked` verir ve numara ESKİ kalırdı;
          // updatePhoneNumber numarayı gerçekten değiştirir.
          await user.updatePhoneNumber(credential);
        } else {
          await user.linkWithCredential(credential);
        }
      }
      // Jetonu tazele → phone_number claim'i güncel (kural doğrulaması için).
      await user.getIdToken(true);
      return session.phoneE164;
    } on fb.FirebaseAuthException catch (e) {
      // İlk bağlamada telefon zaten bu hesaba bağlıysa doğrulanmış say
      // (idempotent). Değiştirmede bu dal çalışmamalı: sessizce eski numarayı
      // döndürmek "değişti" yanılgısı yaratırdı.
      if (e.code == 'provider-already-linked' && !replaceExisting) {
        await user.getIdToken(true);
        return session.phoneE164;
      }
      throw _map(e);
    }
  }

  PhoneVerificationException _map(fb.FirebaseAuthException e) {
    // TANI: gerçek Firebase hata kodunu terminale bas (catch bloğu yutmasın).
    AppLog.d(
      '[TANI][telefon] FirebaseAuthException: '
      'code=${e.code} message=${e.message}',
    );
    if (e.code == 'unknown') {
      AppLog.d(
        '[TANI][telefon] code=unknown → SMS ÖNCESİ cihaz doğrulaması düştü.\n'
        '  EN SIK SEBEP: uygulama henüz Play Store\'da YAYINLANMAMIŞ.\n'
        '  Play Integrity mağazada olmayan uygulamayı tanımaz:\n'
        '    "18002 Invalid PlayIntegrity token; app not Recognized by\n'
        '     Play Store" (logcat: adb logcat | grep FirebaseAuth)\n'
        '  → Bu bir kod hatası DEĞİL. Kapalı teste yüklenince düzelir.\n'
        '  → O zamana kadar Firebase TEST NUMARALARI ile test et\n'
        '    (5550000000 / kod 123456) — Play Integrity\'yi atlarlar.\n'
        '  Ayrıntı: docs/TELEFON_DOGRULAMA_TANI.md',
      );
    }
    switch (e.code) {
      case 'invalid-phone-number':
        return PhoneVerificationException.invalidNumber;
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return PhoneVerificationException.invalidCode;
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return PhoneVerificationException.alreadyInUse;
      case 'requires-recent-login':
        // updatePhoneNumber (numara değiştirme) hassas işlemdir; oturum
        // eskiyse Firebase yeniden kimlik doğrulama ister.
        return PhoneVerificationException.needsRecentLogin;
      case 'too-many-requests':
        return PhoneVerificationException.tooManyRequests;
      case 'unknown':
      case 'app-not-authorized':
      case 'missing-client-identifier':
        // Android: SMS ÖNCESİ cihaz doğrulaması (Play Integrity / SafetyNet)
        // düştü. `unknown` bu durumda SDK'nın ayırt edici kod üretemediği
        // hâldir — kullanıcıya "unknown" göstermek hiçbir şey anlatmıyordu.
        //
        // ⚠️ Ön koşul: Android API anahtarının "API kısıtlamaları" listesinde
        // `androidcheck.googleapis.com` BULUNMALI. Yoksa bu hata TÜM
        // cihazlarda çıkar ve hiç kimse telefonunu doğrulayamaz.
        // Ayrıntı: docs/TELEFON_DOGRULAMA_TANI.md
        return PhoneVerificationException.deviceCheckFailed;
      case 'operation-not-allowed':
        // Aynı kod iki farklı durumda döner: (a) Phone sağlayıcısı kapalı,
        // (b) SMS bölge politikası hedef ülkeye (+90) kapalı. Mesajdan ayırt et.
        // Kullanıcı sade metni görür; Console adımları yalnız loga düşer.
        if ((e.message ?? '').toLowerCase().contains('region')) {
          PhoneVerificationException.regionBlocked.logDevNote();
          return PhoneVerificationException.regionBlocked;
        }
        PhoneVerificationException.providerDisabled.logDevNote();
        return PhoneVerificationException.providerDisabled;
      default:
        return PhoneVerificationException(
          'Doğrulama başarısız (${e.code}). Lütfen tekrar deneyin.',
        );
    }
  }
}

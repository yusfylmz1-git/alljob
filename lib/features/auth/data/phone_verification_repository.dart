import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import 'auth_repository.dart';
import 'firebase_phone_verification_repository.dart';

/// Telefon SMS (OTP) doğrulaması soyutlaması.
///
/// Akış: [sendCode] SMS gönderir ve platforma özel bir [PhoneVerificationSession]
/// döndürür → kullanıcı gelen kodu girer → [confirmCode] kodu doğrular ve
/// telefonu MEVCUT hesaba BAĞLAR (linkWithCredential). Bağlama sonrası Firebase
/// kimlik jetonu `phone_number` claim'i taşır; böylece "mavi tik" (isVerified /
/// phoneVerified) yazımı Firestore kuralınca güvenle doğrulanabilir.
///
/// Not: uygulama verisini (phoneVerified / isVerified) BU repo yazmaz; onları
/// çağıran taraf [AuthRepository.setPhoneVerified] ve
/// [MyProfileRepository.markVerified] ile yazar. Burası yalnızca kimlik
/// (Auth) tarafını hâlleder.
abstract interface class PhoneVerificationRepository {
  /// [phoneE164] E.164 biçiminde olmalıdır (ör. `+905551112233`). SMS gönderir.
  Future<PhoneVerificationSession> sendCode(String phoneE164);

  /// Kullanıcının girdiği [smsCode]'u doğrular ve telefonu hesaba bağlar.
  /// Başarılıysa bağlanan numarayı (E.164) döner.
  Future<String> confirmCode(PhoneVerificationSession session, String smsCode);
}

/// [sendCode] ile [confirmCode] arasında taşınan, platforma özel oturum.
/// Mobilde `verificationId`, web'de bir `ConfirmationResult` tutulur (opak).
class PhoneVerificationSession {
  const PhoneVerificationSession({
    required this.phoneE164,
    this.verificationId,
    this.webConfirmation,
  });

  final String phoneE164;

  /// Mobil (Android/iOS): `verifyPhoneNumber` codeSent geri çağırımından gelir.
  final String? verificationId;

  /// Web: `linkWithPhoneNumber` sonucu `ConfirmationResult` (dynamic tutulur ki
  /// bu dosya firebase_auth'a bağımlı olmasın; Firebase impl cast eder).
  final Object? webConfirmation;
}

/// Kullanıcıya gösterilebilir Türkçe telefon-doğrulama hatası.
class PhoneVerificationException implements Exception {
  const PhoneVerificationException(this.message);
  final String message;
  @override
  String toString() => message;

  static const invalidNumber =
      PhoneVerificationException('Geçerli bir telefon numarası girin.');
  static const invalidCode =
      PhoneVerificationException('Doğrulama kodu hatalı. Tekrar deneyin.');
  static const alreadyInUse = PhoneVerificationException(
      'Bu telefon numarası başka bir hesaba bağlı.');
  static const tooManyRequests = PhoneVerificationException(
      'Çok fazla deneme yapıldı. Lütfen bir süre sonra tekrar deneyin.');
  static const providerDisabled = PhoneVerificationException(
      'Telefonla doğrulama henüz etkin değil. Firebase Console → Authentication '
      '→ Sign-in method → Phone sağlayıcısını etkinleştirin.');
  static const regionBlocked = PhoneVerificationException(
      'SMS gönderimi Türkiye (+90) için henüz açık değil. Firebase Console → '
      'Authentication → Settings → SMS region policy bölümünden Türkiye\'ye '
      'izin verin.');
  static const notSignedIn =
      PhoneVerificationException('Önce giriş yapmalısınız.');
  static const unknown =
      PhoneVerificationException('Doğrulama başarısız. Lütfen tekrar deneyin.');
}

/// Aktif telefon doğrulama sağlayıcısı ([useFirebaseBackend] ile mock/firebase).
final phoneVerificationRepositoryProvider =
    Provider<PhoneVerificationRepository>((ref) {
  if (useFirebaseBackend) return FirebasePhoneVerificationRepository();
  return MockPhoneVerificationRepository();
});

/// Bellek içi taklit: gerçek SMS göndermez. Test kodu `123456`.
class MockPhoneVerificationRepository implements PhoneVerificationRepository {
  static const mockCode = '123456';

  @override
  Future<PhoneVerificationSession> sendCode(String phoneE164) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!phoneE164.startsWith('+') || phoneE164.length < 8) {
      throw PhoneVerificationException.invalidNumber;
    }
    return PhoneVerificationSession(
        phoneE164: phoneE164, verificationId: 'mock');
  }

  @override
  Future<String> confirmCode(
      PhoneVerificationSession session, String smsCode) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (smsCode.trim() != mockCode) {
      throw PhoneVerificationException.invalidCode;
    }
    return session.phoneE164;
  }
}

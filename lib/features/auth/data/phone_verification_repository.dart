import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../core/utils/app_log.dart';
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
  ///
  /// [replaceExisting] true iken hesapta ZATEN bağlı bir telefon vardır ve
  /// yenisiyle DEĞİŞTİRİLİR (`updatePhoneNumber`). Varsayılan bağlama
  /// (`linkWithCredential`) bu durumda `provider-already-linked` verir ve
  /// numara sessizce eski kalırdı.
  Future<String> confirmCode(
    PhoneVerificationSession session,
    String smsCode, {
    bool replaceExisting = false,
  });
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
  const PhoneVerificationException(this.message, {this.devNote});

  /// Kullanıcıya gösterilen metin. Sade, suçlayıcı olmayan, ne yapacağını
  /// söyleyen Türkçe.
  final String message;

  /// Yalnız geliştirici için: yapılandırma hatalarında konsola düşer
  /// (bkz. [logDevNote]). Kullanıcı arayüzünde ASLA gösterilmez.
  final String? devNote;

  /// Yapılandırma hatasını debug derlemesinde loga yazar (release'te sessiz).
  void logDevNote() {
    final n = devNote;
    if (n != null) AppLog.d('[Telefon doğrulama — YAPILANDIRMA] $n');
  }

  @override
  String toString() => message;

  static const invalidNumber = PhoneVerificationException(
    'Geçerli bir telefon numarası girin.',
  );
  static const invalidCode = PhoneVerificationException(
    'Doğrulama kodu hatalı. Tekrar deneyin.',
  );
  /// Numara BAŞKA bir hesapta doğrulanmış. Firebase bir telefonu yalnız tek
  /// hesaba bağlar; bu kontrol sunucu tarafındadır ve atlatılamaz.
  static const alreadyInUse = PhoneVerificationException(
    'Bu numara başka bir hesapta doğrulanmış. Kendi numaranızsa o hesaba '
    'giriş yapın veya farklı bir numara kullanın.',
  );
  /// Firebase'in NUMARA BAZLI SMS kotası doldu (hesap engellenmedi).
  ///
  /// Kota kısa aralıkla tekrarlanan denemelerde devreye girer ve genelde
  /// 30–60 dakikada açılır. "Bir süre sonra" demek kullanıcıyı uygulamada
  /// tekrar tekrar denemeye itiyordu — bu da kotayı uzatıyor.
  static const tooManyRequests = PhoneVerificationException(
    'Bu numara için çok fazla deneme yapıldı. Güvenlik nedeniyle bir süre '
    'yeni kod gönderilemiyor — yaklaşık 1 saat sonra tekrar deneyin. '
    'Tekrar tekrar denemek bekleme süresini uzatır.',
  );
  // Aşağıdaki ikisi YAPILANDIRMA hatasıdır — sebebi kullanıcıda değil bizde.
  // Kullanıcıya Firebase Console adımları GÖSTERİLMEZ: ne anlar ne de
  // yapabilir, üstelik altyapı kurulumumuzu ifşa eder. Geliştirici talimatı
  // debugPrint ile loga düşer (aşağıdaki devNote), kullanıcı sade metni görür.
  static const providerDisabled = PhoneVerificationException(
    'Telefon doğrulama şu anda kullanılamıyor. Kısa süre sonra tekrar '
    'deneyin; sorun sürerse bize ulaşın.',
    devNote: 'Firebase Console → Authentication → Sign-in method → '
        'Phone sağlayıcısı KAPALI.',
  );
  static const regionBlocked = PhoneVerificationException(
    'Telefon doğrulama şu anda kullanılamıyor. Kısa süre sonra tekrar '
    'deneyin; sorun sürerse bize ulaşın.',
    devNote: 'Firebase Console → Authentication → Settings → SMS region '
        'policy: Türkiye (+90) izinli değil.',
  );
  static const notSignedIn = PhoneVerificationException(
    'Önce giriş yapmalısınız.',
  );

  /// Android'de `code=unknown`: SMS gönderilmeden ÖNCEKİ cihaz doğrulaması
  /// (Play Integrity / SafetyNet zinciri) başarısız oldu.
  ///
  /// **En sık sebep (2026-08-14'te cihaz logundan doğrulandı): uygulama
  /// henüz Play Store'da yayınlanmamış.**
  ///
  /// Logcat'teki gerçek satır:
  /// `18002 Invalid PlayIntegrity token; app not Recognized by Play Store`
  ///
  /// Play Integrity, mağazada olmayan bir uygulamayı tanımaz ve token'ı
  /// reddeder. Firebase reCAPTCHA yedeğine düşer; projede reCAPTCHA
  /// Enterprise site key yoksa o da başarısız olur ve SDK ayırt edici bir
  /// kod yerine `unknown` fırlatır.
  ///
  /// ⚠️ Bu bir KOD HATASI DEĞİLDİR. Kapalı teste (internal testing)
  /// yüklendiği anda kendiliğinden düzelir. O zamana kadar Firebase test
  /// numaralarıyla test edilir (Play Integrity'yi atlarlar).
  ///
  /// Diğer (daha nadir) sebepler: cihazda Google Play Services eksik/eski
  /// — emülatörde sık; ağın Google servislerini engellemesi.
  ///
  /// Ayrıntı: docs/TELEFON_DOGRULAMA_TANI.md
  static const deviceCheckFailed = PhoneVerificationException(
    'SMS gönderilemedi: cihaz doğrulaması tamamlanamadı. İnternet '
    'bağlantını kontrol edip tekrar dene. Sorun sürerse Google Play '
    'Hizmetleri güncel olmayabilir.',
  );

  /// Numara değiştirme gibi hassas işlemler yakın zamanlı oturum ister.
  static const needsRecentLogin = PhoneVerificationException(
    'Güvenlik için numara değişikliğinden önce yeniden giriş yapmalısınız. '
    'Çıkış yapıp tekrar giriş yaptıktan sonra deneyin.',
  );
  /// SMS isteği yanıtsız kaldı — `verifyPhoneNumber` geri çağrı tabanlıdır ve
  /// hiçbir geri çağrı gelmezse akış sonsuza kadar beklerdi. En sık sebep
  /// reCAPTCHA doğrulamasının yarıda kalması (tarayıcı sekmesi kapatıldı).
  static const timedOut = PhoneVerificationException(
    'Kod gönderilemedi — doğrulama tamamlanmadı. Numaranızı kontrol edip '
    'tekrar deneyin.',
  );
  static const unknown = PhoneVerificationException(
    'Doğrulama başarısız. Lütfen tekrar deneyin.',
  );
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
      phoneE164: phoneE164,
      verificationId: 'mock',
    );
  }

  @override
  Future<String> confirmCode(
    PhoneVerificationSession session,
    String smsCode, {
    bool replaceExisting = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (smsCode.trim() != mockCode) {
      throw PhoneVerificationException.invalidCode;
    }
    // Mock'ta bağlama ile değiştirme aynı sonucu verir: doğrulanan numara.
    return session.phoneE164;
  }
}

import '../../../data/models/app_user.dart';
import '../../../data/models/social_links.dart';
import '../../../data/models/user_role.dart';

/// Kimlik doğrulama soyutlaması.
///
/// Şu an `MockAuthRepository` ile bellek içi çalışır. Firebase entegrasyonu
/// geldiğinde sadece bu arayüzü uygulayan `FirebaseAuthRepository` yazılıp
/// provider değiştirilecek — UI ve controller katmanı hiç değişmeyecek.
abstract interface class AuthRepository {
  /// Mevcut oturum açmış kullanıcıyı yayınlar (null = oturum yok).
  Stream<AppUser?> authStateChanges();

  /// Anlık mevcut kullanıcı.
  AppUser? get currentUser;

  /// Yeni hesap oluşturur. Tek hesap, çift rol: herkes düz kullanıcı
  /// (müşteri modu) olarak başlar; usta profili sonradan [becomeArtisan] ile açılır.
  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<AppUser> login({required String email, required String password});

  /// Google hesabıyla giriş (#3). Kullanıcı ilk kez giriyorsa `users/{uid}`
  /// dökümanı düz kullanıcı (müşteri modu) olarak oluşturulur.
  Future<AppUser> signInWithGoogle();

  /// Profil > "Hizmet Vermeye Başla": kullanıcıya usta profili açar
  /// (hasArtisanProfile=true) ve usta moduna geçirir.
  Future<AppUser> becomeArtisan();

  /// Arayüz modunu değiştirir (Müşteri ⇄ Usta). Usta moduna geçiş
  /// hasArtisanProfile gerektirir; yoksa [AuthException] atar.
  Future<AppUser> setActiveMode(UserRole mode);

  Future<void> sendPasswordReset(String email);

  /// Oturum açmış kullanıcının şifresini değiştirir (e-posta/şifre hesabı).
  ///
  /// Güvenlik: [currentPassword] ile yeniden doğrulama gerekir. Google-only
  /// hesaplarda e-posta şifresi yoktur → [AuthException].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Oturum açmış kullanıcıya e-posta doğrulama bağlantısı gönderir.
  /// (Kayıtta otomatik gönderilir; bu, profildeki "yeniden gönder" için.)
  Future<void> sendEmailVerification();

  /// Auth kullanıcısını sunucudan tazeleyip e-postanın doğrulanıp
  /// doğrulanmadığını döndürür; değiştiyse auth akışına güncel kullanıcıyı
  /// yayınlar (UI kendiliğinden yenilenir).
  Future<bool> refreshEmailVerified();

  /// Telefon SMS doğrulaması başarıyla tamamlanıp numara hesaba bağlandıktan
  /// SONRA çağrılır: `users` dökümanına `phoneVerified=true` yazar ve numarayı
  /// yalnızca sahibin okuyabildiği `users/{uid}/private/contact` alanına kaydeder.
  /// (Mavi tik'in ArtisanProfile tarafı [MyProfileRepository.markVerified] ile.)
  Future<AppUser> setPhoneVerified(String phoneE164);

  /// Oturum açmış kullanıcının ORTAK profil alanlarını günceller.
  ///
  /// Ortak = usta/müşteri fark etmez; hepsi `users/{uid}` altında yaşar.
  /// Verilmeyen alan DEĞİŞMEZ. [publicPhone] alanını temizlemek için boş
  /// dize gönderin — null "değiştirme" demektir.
  Future<void> updateUserProfile({
    String? displayName,
    String? profilePhotoUrl,
    String? publicPhone,
    SocialLinks? socialLinks,
    String? aboutText,
  });

  Future<void> signOut();

  /// Başka bir kullanıcının HERKESE AÇIK profili (`users/{uid}`).
  /// Ad, fotoğraf, doğrulama rozeti ve sayaçlar döner; telefon/e-posta
  /// gibi hassas alanlar bu dokümanda ZATEN yoktur (ADR-11).
  /// Kullanıcı yoksa null.
  Future<AppUser?> fetchPublicUser(String uid);

  /// Yönetici erişimini etkinleştirir (yalnızca izinli e-postalar için).
  /// Sunucudaki `claimAdminAccess` CF, çağıranın e-postası izin listesinde ve
  /// doğrulanmışsa `admin:true` custom claim'i yazar; ardından token tazelenir
  /// ve auth akışına güncel kullanıcı yansıtılır. Şimdi yönetici mi döndürür.
  /// İstemci kendine keyfî yönetici olamaz — asıl karar sunucudadır.
  Future<bool> claimAdminAccess();

  /// Hesabı ve kişisel verileri KALICI olarak siler (Play zorunluluğu + KVKK).
  /// Firebase'de silme işini `deleteAccount` callable CF yapar (istemci tek
  /// tek koleksiyon silemez; kurallar da izin vermez); başarıda yerel oturum
  /// kapanır. Geri alınamaz — çağıran taraf kullanıcıdan açık onay almalıdır.
  Future<void> deleteAccount();
}

/// Kullanıcıya gösterilebilir, Türkçe mesajlı kimlik doğrulama hatası.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;

  // Yaygın senaryolar için hazır mesajlar (Firebase hata kodlarıyla eşleşir).
  static const emailInUse = AuthException(
    'Bu e-posta adresi ile zaten bir hesap var.',
  );
  static const userNotFound = AuthException(
    'Bu e-posta ile kayıtlı bir hesap bulunamadı.',
  );
  static const wrongPassword = AuthException('E-posta veya şifre hatalı.');
  static const weakPassword = AuthException(
    'Şifre çok zayıf, en az 6 karakter kullanın.',
  );
  static const requiresRecentLogin = AuthException(
    'Güvenlik için tekrar giriş yapıp şifre değiştirmeyi deneyin.',
  );
  static const noPasswordProvider = AuthException(
    'Bu hesap e-posta/şifre ile bağlı değil (ör. Google). '
    'Şifre sıfırlama e-postası yalnızca e-posta hesabında çalışır.',
  );
  static const cancelled = AuthException('Giriş iptal edildi.');
  static const providerDisabled = AuthException(
    'Google ile giriş henüz etkin değil. Firebase Console → Authentication '
    '→ Sign-in method bölümünden Google sağlayıcısını etkinleştirin.',
  );
  static const unauthorizedDomain = AuthException(
    'Bu alan adı Firebase\'de yetkili değil. Authentication → Settings → '
    'Authorized domains listesine ekleyin.',
  );
  static const notSignedIn = AuthException('Önce giriş yapmalısınız.');
  static const noArtisanProfile = AuthException(
    'Usta moduna geçmek için önce "Hizmet Vermeye Başla" adımını tamamlayın.',
  );
  static const unknown = AuthException(
    'Bir hata oluştu, lütfen tekrar deneyin.',
  );
}

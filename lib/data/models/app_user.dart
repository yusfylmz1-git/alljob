import 'social_links.dart';
import 'user_role.dart';

/// `users` koleksiyonundaki kullanıcı dökümanı.
/// Döküman ID'si = Firebase Auth UID.
///
/// Tek hesap, çift rol: [hasArtisanProfile] kullanıcının usta profili açıp
/// açmadığını (kalıcı yetenek), [activeMode] ise arayüzün hangi modda
/// gösterileceğini (istenildiğinde değiştirilebilir tercih) tutar.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.hasArtisanProfile = false,
    this.activeMode = UserRole.customer,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.isAdmin = false,
    this.adminRole,
    this.suspended = false,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.completedJobsAsCustomer = 0,
    this.reviewCountAsCustomer = 0,
    this.publicPhone,
    this.socialLinks = SocialLinks.empty,
    this.aboutText = '',
  });

  final String uid;
  final String displayName;

  /// E-posta. KAYNAĞI Firebase Auth — herkese açık `users` dökümanına
  /// YAZILMAZ (H2/KVKK). Repo Auth'tan doldurur; fromMap legacy için okuyabilir.
  final String email;
  final DateTime createdAt;

  /// "Hizmet Vermeye Başla" tamamlandı mı? Usta moduna geçişin ön şartı.
  final bool hasArtisanProfile;

  /// Aktif arayüz modu. Usta modu yalnızca [hasArtisanProfile] ise geçerlidir.
  final UserRole activeMode;

  /// Hesap telefon numarasıyla doğrulandı mı? (SMS OTP → hesaba bağlı telefon.)
  /// Ustalarda "mavi tik"in (ArtisanProfile.isVerified) ön şartıdır; müşteride
  /// "doğrulanmış hesap" göstergesi olarak kullanılır. Yalnızca gerçek doğrulama
  /// sonrası `true` yazılabilir (Firestore kuralı `token.phone_number` ister).
  final bool phoneVerified;

  /// E-posta adresi doğrulandı mı? KAYNAĞI Firebase Auth'tur (doğrulama
  /// bağlantısına tıklanınca Auth tarafında değişir) — `users` dökümanına
  /// YAZILMAZ/OKUNMAZ; repo katmanı Auth kullanıcısından doldurur.
  final bool emailVerified;

  /// Yönetici mi? KAYNAĞI Firebase Auth CUSTOM CLAIM'idir (`admin:true`) —
  /// yalnızca sunucu (CF) yazabilir, istemci kendine veremez. `users`
  /// dökümanına YAZILMAZ/OKUNMAZ; repo katmanı Auth token'ından doldurur.
  /// UI kapıları (yönetici paneli girişi) bunu kullanır; asıl güvenlik
  /// Firestore kurallarındaki `request.auth.token.admin == true` kontrolüdür.
  final bool isAdmin;

  /// Ayrıntılı yönetici rolü (RBAC): 'superadmin' | 'moderator' | … Kaynağı Auth
  /// custom claim `role`'dür (yalnız CF yazar). [isAdmin] kaba kapıdır; belirli
  /// yeteneklerin (ör. başka kullanıcıyı yönetici yapma) yalnız 'superadmin'e
  /// açılması için bu alan kullanılır. Null = yönetici değil.
  final String? adminRole;

  bool get isSuperAdmin => adminRole == 'superadmin';

  /// Hesap yönetici tarafından askıya alındı mı? Zorlama SUNUCUDADIR
  /// (`suspended:true` custom claim → Firestore kuralları içerik oluşturmayı
  /// reddeder); bu alan yalnız herkese açık `users` dökümanındaki bool aynadan
  /// okunur ve istemcide "hesabınız askıya alındı" kapısını tetikler. Askıya
  /// alma NEDENİ gizlilik için burada TUTULMAZ (yalnız denetim kaydında).
  final bool suspended;

  /// Yalnızca ustalar için; müşteriye asla gösterilmez (PRD §6).
  /// GÜVENLİK: herkese açık `users` dökümanına yazılmaz (bkz. toMap); yalnızca
  /// sahibin okuyabildiği `users/{uid}/private/*` alt-koleksiyonunda saklanır.
  final String? phoneNumber;
  final String? profilePhotoUrl;

  /// Müşteri olarak tamamlanan iş sayısı — profildeki sayaç.
  /// YALNIZ CF yazar (`onJobWritten`); kural istemciye kapatır (kural 3).
  final int completedJobsAsCustomer;

  /// Müşteri olarak alınan değerlendirme ADEDİ (puan değil).
  /// Puanın kendisi hassas: `users/{uid}/private/rating` altında, yalnız
  /// sahibi okur. Burada yalnız sayı paylaşılır — düşük puanlı müşteri
  /// teşhir edilmesin. YALNIZ CF yazar (`onReviewWritten`).
  final int reviewCountAsCustomer;

  // ─────────── ORTAK PROFİL ALANLARI (2026-08-08) ───────────
  //
  // Bu üçü eskiden YALNIZ `artisanProfiles` altındaydı; müşteri modunda
  // telefon/sosyal medya/hakkımda girilemiyordu. Artık `users` altında —
  // herkeste çalışır (usta olsun olmasın).
  //
  // Eski usta kayıtlarındaki kopyalar OKUNMAYA devam eder
  // (`FirebaseAuthRepository` boşsa oradan doldurur); ilk kaydetmede buraya
  // yazılır. Bkz. [[Profil-Ortak-Alanlar]].

  /// Profilde herkese görünen telefon (isteğe bağlı).
  ///
  /// [phoneNumber]'dan FARKLI: o hassas, `private/contact` altında yaşar.
  /// Bu alan kullanıcının BİLEREK yayınladığı numaradır — boşsa gösterilmez.
  final String? publicPhone;

  /// Sosyal medya + web sitesi (isteğe bağlı). Web sitesi ayrı alan değil,
  /// `socialLinks.website` — tek doğruluk kaynağı.
  final SocialLinks socialLinks;

  /// "Hakkımda" metni (isteğe bağlı). Usta vitrinindeki tanıtım yazısının
  /// her moda açılmış hâli.
  final String aboutText;

  /// Profilde gösterilecek herhangi bir ek bilgi var mı?
  bool get hasProfileDetails =>
      (publicPhone?.trim().isNotEmpty ?? false) ||
      aboutText.trim().isNotEmpty ||
      socialLinks.hasAny;

  /// Arayüz şu an usta modunda mı? (UI kapıları bunu kullanır.)
  bool get isArtisan => activeMode == UserRole.artisan;
  bool get isCustomer => activeMode == UserRole.customer;

  AppUser copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePhotoUrl,
    bool? hasArtisanProfile,
    UserRole? activeMode,
    bool? phoneVerified,
    bool? emailVerified,
    bool? isAdmin,
    String? adminRole,
    bool? suspended,
    bool clearAdmin = false,
    String? publicPhone,
    SocialLinks? socialLinks,
    String? aboutText,
    bool clearPublicPhone = false,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt,
      hasArtisanProfile: hasArtisanProfile ?? this.hasArtisanProfile,
      activeMode: activeMode ?? this.activeMode,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      isAdmin: clearAdmin ? false : (isAdmin ?? this.isAdmin),
      adminRole: clearAdmin ? null : (adminRole ?? this.adminRole),
      suspended: suspended ?? this.suspended,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      // Sayaçlar copyWith parametresi DEĞİL (istemci değiştiremez) ama
      // taşınmazsa her copyWith çağrısında 0'a düşerdi — B-19'daki tuzağın
      // aynısı. Mevcut değer korunur.
      completedJobsAsCustomer: completedJobsAsCustomer,
      reviewCountAsCustomer: reviewCountAsCustomer,
      // Telefonu SİLMEK için ayrı bayrak: `publicPhone: null` "değiştirme"
      // demek olduğundan alanı temizlemenin başka yolu yok.
      publicPhone:
          clearPublicPhone ? null : (publicPhone ?? this.publicPhone),
      socialLinks: socialLinks ?? this.socialLinks,
      aboutText: aboutText ?? this.aboutText,
    );
  }

  /// Herkese açık `users/{uid}` alanları. E-posta, FCM token, telefon YOK (H2).
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'hasArtisanProfile': hasArtisanProfile,
        'activeMode': activeMode.apiValue,
        // Geriye dönük uyum: eski istemciler `role` okur.
        'role': activeMode.apiValue,
        'phoneVerified': phoneVerified,
        'createdAt': createdAt.toIso8601String(),
        'profilePhotoURL': profilePhotoUrl,
        // Ortak profil alanları — herkese açık (kullanıcı bilerek yayınlar).
        'publicPhone': publicPhone,
        'socialLinks': socialLinks.toMap(),
        'aboutText': aboutText,
        // GÜVENLİK: phoneNumber / email / fcmTokens bu dökümana yazılmaz
        // (kural da engeller). Token: users/{uid}/private/push.
        //
        // SAYAÇLAR DA YAZILMAZ: completedJobsAsCustomer /
        // reviewCountAsCustomer yalnız CF'e aittir (kural 3). Buraya
        // eklenirse kural TÜM kaydı reddeder — bkz. B-04 dersi
        // ([[Bilinen-Tuzaklar]] "toMap() → Firestore: sunucuya ait alanları
        // çıkar").
      };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    // Eski kayıtlar: kalıcı `role` alanı → usta ise profil var + usta modu.
    final legacyRole = UserRole.fromString(map['role'] as String?);
    return AppUser(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      hasArtisanProfile: (map['hasArtisanProfile'] as bool?) ??
          (legacyRole == UserRole.artisan),
      activeMode: UserRole.fromString(map['activeMode'] as String?) ??
          legacyRole ??
          UserRole.customer,
      phoneVerified: (map['phoneVerified'] as bool?) ?? false,
      suspended: (map['suspended'] as bool?) ?? false,
      createdAt: _parseDate(map['createdAt']),
      phoneNumber: map['phoneNumber'] as String?,
      profilePhotoUrl: map['profilePhotoURL'] as String?,
      publicPhone: map['publicPhone'] as String?,
      socialLinks: SocialLinks.fromMap(
          (map['socialLinks'] as Map?)?.cast<String, dynamic>()),
      aboutText: (map['aboutText'] as String?) ?? '',
      // CF yazar; alan yoksa 0 (henüz iş bitirmemiş/değerlendirilmemiş).
      completedJobsAsCustomer:
          (map['completedJobsAsCustomer'] as num?)?.toInt() ?? 0,
      reviewCountAsCustomer:
          (map['reviewCountAsCustomer'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

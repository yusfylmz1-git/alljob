import 'geo_models.dart';
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
    this.savedPhone,
    this.socialLinks = SocialLinks.empty,
    this.aboutText = '',
    this.ortakAlanlarGocmus = false,
    this.hasShopProfile = false,
    this.shopCategories = const [],
    this.shopServiceAreas = const [],
    this.available = false,
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

  /// Hesap telefon numarasıyla doğrulandı mı?
  ///
  /// SMS doğrulama akışı 2026-08-18'de KALDIRILDI — uygulama artık kimseye
  /// numara doğrulatmaz. Alan yalnızca GEÇMİŞ veriyi taşır: daha önce
  /// numarasını bağlamış hesaplarda Auth'tan `true` gelmeye devam eder.
  /// Yeni hesaplarda her zaman `false`'tur; kod bu alana yeni değer YAZMAZ.
  ///
  /// Rozet için bakılacak yer artık `ArtisanProfile.adminVerified`
  /// (admin/CF onayı) — bkz. [ArtisanProfile.showVerifiedBadge].
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

  /// Kullanıcının KAYITLI numarası — görünürlükten BAĞIMSIZ (2026-08-23).
  ///
  /// Neden ayrı alan: eskiden tek alan ([publicPhone]) hem "kayıtlı numaram"
  /// hem "vitrinde yayınlanan numara" işini görüyordu. "Profilde göster"
  /// anahtarı kapatılınca yayın alanı temizleniyor ve numara TAMAMEN
  /// siliniyordu; kullanıcı anahtarı geri açmak istediğinde numarası yok
  /// olduğu için anahtar satırı bile ekrandan kayboluyordu (testçi bulgusu:
  /// "telefonu göster kapatınca telefon gidiyor").
  ///
  /// Artık ikisi ayrı:
  ///  - [savedPhone] kalıcıdır, `users/{uid}/private/contact.savedPhone`
  ///    altında yaşar (herkese açık dokümanda DEĞİL — kapalıyken numara
  ///    kimseye görünmemeli, kural 5).
  ///  - [publicPhone] yalnız anahtar AÇIKKEN doludur ve herkese açıktır.
  ///
  /// Anahtar kapanınca [publicPhone] temizlenir, [savedPhone] yerinde kalır;
  /// geri açıldığında numara buradan yeniden yayınlanır.
  final String? savedPhone;

  /// Kullanıcının girdiği numara — yayınlanmış olsun olmasın.
  /// Telefon formunun ve "profilde göster" anahtarının OKUDUĞU değer.
  String? get contactPhone {
    final s = savedPhone?.trim();
    if (s != null && s.isNotEmpty) return s;
    final p = publicPhone?.trim();
    return (p != null && p.isNotEmpty) ? p : null;
  }

  /// Numara kayıtlı mı (yayınlanmış olması gerekmez)?
  bool get hasContactPhone => contactPhone != null;

  /// Sosyal medya + web sitesi (isteğe bağlı). Web sitesi ayrı alan değil,
  /// `socialLinks.website` — tek doğruluk kaynağı.
  final SocialLinks socialLinks;

  /// "Hakkımda" metni (isteğe bağlı). Usta vitrinindeki tanıtım yazısının
  /// her moda açılmış hâli.
  final String aboutText;

  /// `users` kaydı ortak profil alanlarını HİÇ taşımış mı? (2026-08-08 göçü)
  ///
  /// "Alan yok" ile "alan var ama boş" ayrımı için gerekli. Kullanıcı bir
  /// bağlantıyı SİLDİĞİNDE `users` boş kalır; bu bayrak olmasaydı okuma
  /// tarafı boşluğu "henüz göç etmemiş" sanıp `artisanProfiles`'taki eski
  /// kopyaya düşer ve silinen bağlantı geri gelirdi.
  final bool ortakAlanlarGocmus;

  /// Mağaza (satıcı) profili açıldı mı? Usta profilinden bağımsız.
  final bool hasShopProfile;

  /// Satış kategorileri (`ProductCategory` kodları). Mağaza kurulumunda seçilir.
  final List<String> shopCategories;

  /// Mağaza hizmet bölgeleri (il/ilçe). Kurulumda seçilir; usta profili
  /// varsa oradaki bölgeler başlangıç değeri olarak kopyalanabilir.
  final List<ServiceArea> shopServiceAreas;

  /// Genel müsaitlik (Mağaza vitrini / talep mesajı; usta tarafı da aynalar).
  final bool available;

  /// Profilde gösterilecek herhangi bir ek bilgi var mı?
  bool get hasProfileDetails =>
      (publicPhone?.trim().isNotEmpty ?? false) ||
      aboutText.trim().isNotEmpty ||
      socialLinks.hasAny;

  /// Eski "aktif usta modu" (`activeMode`). Yetenek kapıları için KULLANMA —
  /// [hasArtisanProfile] / [hasShopProfile] / [available] kullan.
  /// Tema ve legacy setActiveMode hâlâ alan yazar; UI switch kaldırıldı.
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
    String? savedPhone,
    SocialLinks? socialLinks,
    String? aboutText,
    bool clearPublicPhone = false,
    bool clearSavedPhone = false,
    bool? hasShopProfile,
    List<String>? shopCategories,
    List<ServiceArea>? shopServiceAreas,
    bool? available,
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
      // Kayıtlı numara YAYINDAN bağımsızdır: `clearPublicPhone` onu SİLMEZ.
      // Anahtar kapatıldığında yalnız yayın düşer, numara kullanıcıda kalır.
      savedPhone: clearSavedPhone ? null : (savedPhone ?? this.savedPhone),
      socialLinks: socialLinks ?? this.socialLinks,
      aboutText: aboutText ?? this.aboutText,
      // Sayaçlarla aynı tuzak: copyWith parametresi değil, ama taşınmazsa
      // her çağrıda false'a düşer ve silinen bağlantı geri gelirdi.
      ortakAlanlarGocmus: ortakAlanlarGocmus,
      hasShopProfile: hasShopProfile ?? this.hasShopProfile,
      shopCategories: shopCategories ?? this.shopCategories,
      shopServiceAreas: shopServiceAreas ?? this.shopServiceAreas,
      available: available ?? this.available,
    );
  }

  /// Kaydı "ortak alanlar göç etti" diye işaretler.
  ///
  /// Firebase'de bu bilgi alanın VARLIĞINDAN gelir ([fromMap]); mock'ta
  /// döküman yok, o yüzden yazma anında elle işaretlenir. [copyWith]'e
  /// parametre olarak açılmaz — bayrağı yalnız yazan taraf koyar.
  AppUser markOrtakAlanlarGocmus() => AppUser(
        uid: uid,
        displayName: displayName,
        email: email,
        createdAt: createdAt,
        hasArtisanProfile: hasArtisanProfile,
        activeMode: activeMode,
        phoneVerified: phoneVerified,
        emailVerified: emailVerified,
        isAdmin: isAdmin,
        adminRole: adminRole,
        suspended: suspended,
        phoneNumber: phoneNumber,
        profilePhotoUrl: profilePhotoUrl,
        completedJobsAsCustomer: completedJobsAsCustomer,
        reviewCountAsCustomer: reviewCountAsCustomer,
        publicPhone: publicPhone,
        // Taşınmazsa kalıcı numara her ortak-alan yazımında düşerdi
        // (sayaçlardaki tuzağın aynısı): kullanıcı adını değiştirir,
        // gizlediği numarası sessizce kaybolurdu.
        savedPhone: savedPhone,
        socialLinks: socialLinks,
        aboutText: aboutText,
        ortakAlanlarGocmus: true,
        hasShopProfile: hasShopProfile,
        shopCategories: shopCategories,
        shopServiceAreas: shopServiceAreas,
        available: available,
      );

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
        'hasShopProfile': hasShopProfile,
        'shopCategories': shopCategories,
        'shopServiceAreas':
            shopServiceAreas.map((e) => e.toMap()).toList(),
        'available': available,
        // GÜVENLİK: phoneNumber / email / fcmTokens bu dökümana yazılmaz
        // (kural da engeller). Token: users/{uid}/private/push.
        //
        // `savedPhone` DE YAZILMAZ: kayıtlı numara görünürlükten bağımsız
        // saklanır ama anahtar KAPALIYKEN kimseye görünmemelidir. Yeri
        // `users/{uid}/private/contact.savedPhone` (kural 5). Buraya
        // eklenirse "gizle" dediği numara herkese açık dökümanda kalır.
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
      // Alanlardan biri BİLE varsa kayıt göç etmiştir; sonrasında boşluk
      // "kullanıcı sildi" demektir, "veri yok" değil.
      ortakAlanlarGocmus: map.containsKey('socialLinks') ||
          map.containsKey('publicPhone') ||
          map.containsKey('aboutText'),
      hasShopProfile: map['hasShopProfile'] == true,
      shopCategories: (map['shopCategories'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      shopServiceAreas: ((map['shopServiceAreas'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ServiceArea.fromMap(e.cast<String, dynamic>()))
          .where((a) => a.province.isNotEmpty && a.district.isNotEmpty)
          .toList(),
      available: map['available'] == true,
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

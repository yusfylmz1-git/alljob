/// Uygulamadaki tüm rota yolları. Tek kaynak — yazım hatası riskini önler.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';

  // İlk açılış tanıtımı (yalnızca bir kez, oturum yokken).
  static const String onboarding = '/onboarding';

  // Ana Sayfa (platform dashboard) — misafir + üye. Splash/login/onboarding
  // sonrası buraya gelinir. İstatistik, öne çıkanlar, hızlı erişim, duyuru.
  static const String home = '/';

  // Keşfet (usta arama ızgarası) — eski ana ekran.
  // Ana Sayfa eklenince '/' Ana Sayfa'ya, keşif buraya taşındı.
  static const String explore = '/explore';

  /// Keşfet'i belirli bir sekmeyle açar (Ana Sayfa "Tümünü Gör" bağlantıları).
  /// [tab]: artisans. Geçersiz/boş değer yok sayılır
  /// (Keşfet role göre varsayılan sekmeye düşer). [prof] verilirse (yalnız
  /// artisans sekmesi için anlamlı) Ustalar o meslek koduyla filtreli açılır.
  static String exploreTab(String tab, {String? prof}) {
    final p = (prof == null || prof.isEmpty)
        ? ''
        : '&prof=${Uri.encodeComponent(prof)}';
    return '$explore?tab=$tab$p';
  }

  // Kimlik doğrulama (yalnız Google; register → login)
  static const String login = '/login';
  static const String register = '/register';

  // İlk giriş plan seçimi (Ücretsiz / Beta / Pro).
  static const String packageSelect = '/package-select';

  // Hesap askıya alındığında gösterilen engelleme kapısı (oturum açık ama
  // suspended). Buradan yalnız çıkış yapılabilir.
  static const String suspended = '/suspended';

  // Platform bakım modu (adminConfig.maintenanceMode).
  static const String maintenance = '/maintenance';

  // Zorunlu güncelleme (adminConfig.minAppVersion > kClientVersion).
  static const String forceUpdate = '/force-update';

  // Usta paneli (yalnızca oturum açmış usta)
  static const String panel = '/panel';
  static const String panelEdit = '/panel/edit';

  /// Vitrin tamamlama funnel: düzenle ekranında ilgili bölüme kaydır.
  /// [stepId]: photo | about | profession | area | photos | hours
  static String panelEditFocus(String stepId) =>
      '$panelEdit?focus=${Uri.encodeComponent(stepId)}';

  // Sohbet (oturum açmış müşteri + usta)
  static const String chats = '/chats';
  static String chatThread(String chatId) => '/chats/$chatId';

  // Değerlendirme (oturum açmış müşteri)
  static const String reviewBase = '/review';
  static String review(String artisanUid, {String? jobId}) =>
      '/review/$artisanUid${jobId != null ? '?jobId=$jobId' : ''}';

  // İş ilanları (çift taraflı pazaryeri)
  static const String jobsBase = '/jobs';
  static const String newJob = '/jobs/new';

  /// İlan formu "Hemen Lazım" kategorisi seçili açılır (ana sayfa kısayolu).
  static const String newQuickSupportJob = '/jobs/new?kind=quick';

  static const String myJobs = '/jobs/mine';

  /// "Hemen Lazım" ilanları listesi (ana sayfadaki şeritten "Tümünü Gör").
  /// Misafir dâhil herkese açıktır — vitrin niteliğindedir.
  /// DİKKAT: `/jobs/:jobId` deseninden ÖNCE tanımlanmalı, yoksa "quick"
  /// bir ilan kimliği sanılır.
  static const String quickSupportJobs = '/jobs/quick';

  static String jobDetail(String jobId) => '/jobs/$jobId';

  // Favoriler (oturum açmış müşteri)
  // Takip ekranı — iki sekme (Takipçiler | Takip). Varsayılan: Takip.
  static const String favorites = '/favorites';

  /// Takipçiler sekmesi açık gelsin (profil "takipçi" sayacı buraya gider).
  static const String followers = '/favorites?tab=followers';

  // Müşteri profil sayfası (oturum açmış müşteri)
  static const String profile = '/profile';

  /// Hesap ayarları — telefon/e-posta doğrulama, üyelik, hesap silme.
  /// Profil ekranından ÇIKARILDI (sadeleştirme): profil artık içerik
  /// (ilanlar/işler/takip) gösterir; hesap işleri yan menüden buraya gelir.
  static const String accountSettings = '/profile/account';

  // Hesap profili (ad + foto) — müşteri ve usta ortak.
  static const String profileEdit = '/profile/edit';

  // Engellenen kullanıcılar yönetimi (Profil → Engellenen Kullanıcılar).
  static const String blockedUsers = '/profile/blocked';

  // Push bildirim tercihleri (Profil → Bildirim tercihleri).
  static const String notificationPrefs = '/profile/notification-prefs';

  // Yasal metinler (misafir dâhil herkese açık): hub + tek metin sayfası.
  static const String legal = '/legal';
  static String legalDoc(String id) => '/legal/$id';

  // Yardım / SSS (misafir dâhil herkese açık).
  static const String help = '/help';

  // Bildirim merkezi (oturum açmış herkes — iki rol tek ekran).
  // `/panel/notifications` eski bağlantılar için aynı ekrana gider.
  static const String notifications = '/notifications';

  // Usta: yakındaki işler + iletişimler + premium + bildirimler
  static const String panelJobs = '/panel/jobs';
  static const String panelPremium = '/panel/premium';
  static const String panelNotifications = '/panel/notifications';

  /// Herkese açık usta profil sayfası yolu.
  static String artisanProfile(String uid) => '/artisan/$uid';

  /// Genel kullanici profili - usta vitrini olmayanlar icin.
  /// Usta profili varsa ekran kendisi /artisan/:uid'e devreder.
  static String userProfile(String uid) => '/u/$uid';

  // NOT: "Usta Çantası" (PRD-007) araç seti — hesap makineleri, AR ölçüm, PDF
  // teklif — 2026-08-07'de üründen TAMAMEN KALDIRILDI (kullanıcı kararı).
  // Rotalar, ekranlar, testler ve `ar_flutter_plugin_plus` / `pdf` /
  // `printing` / `vector_math` / `share_plus` bağımlılıkları da silindi.
}

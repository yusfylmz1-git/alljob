/// Uygulamadaki tüm rota yolları. Tek kaynak — yazım hatası riskini önler.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';

  // İlk açılış tanıtımı (yalnızca bir kez, oturum yokken).
  static const String onboarding = '/onboarding';

  // Herkese açık keşif (misafir + müşteri) — uygulamanın ana ekranı.
  static const String home = '/';

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
  static const String myJobs = '/jobs/mine';
  static String jobDetail(String jobId) => '/jobs/$jobId';

  // Favoriler (oturum açmış müşteri)
  static const String favorites = '/favorites';

  // Müşteri profil sayfası (oturum açmış müşteri)
  static const String profile = '/profile';

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
  static const String panelOffers = '/panel/offers';
  static const String panelPremium = '/panel/premium';
  static const String panelNotifications = '/panel/notifications';

  /// Herkese açık usta profil sayfası yolu.
  static String artisanProfile(String uid) => '/artisan/$uid';

  // Eleman (işveren arar / iş arayan müsait görünür — başvuru formu yok).
  static const String staffing = '/staffing';
  static const String staffMyWorker = '/staffing/me';
  static const String staffNeedNew = '/staffing/needs/new';
  static const String staffMyNeeds = '/staffing/needs/mine';
  static const String staffWorkers = '/staffing/workers';
  static const String staffNeeds = '/staffing/needs';
  static String staffWorkerDetail(String id) => '/staffing/workers/$id';

  // Takip Merkezi (oturum açmış herkes; yerel-öncelikli kişisel takip).
  // Sıralama: /tracking/new ve /tracking/trash, /tracking/:id'den ÖNCE
  // tanımlanmalıdır (aksi halde :id onları da yakalar).
  static const String tracking = '/tracking';
  static const String trackingNew = '/tracking/new';
  static const String trackingTrash = '/tracking/trash';
  static const String trackingBackup = '/tracking/backup';
  static String trackDetail(String id) => '/tracking/$id';
  static String trackEdit(String id) => '/tracking/$id/edit';
}

/// Uygulamadaki tüm rota yolları. Tek kaynak — yazım hatası riskini önler.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';

  // İlk açılış tanıtımı (yalnızca bir kez, oturum yokken).
  static const String onboarding = '/onboarding';

  // Herkese açık keşif (misafir + müşteri) — uygulamanın ana ekranı.
  static const String home = '/';

  // Kimlik doğrulama (tek hesap, çift rol — kayıtta rol seçimi yok)
  static const String login = '/login';
  static const String register = '/register';

  // Usta paneli (yalnızca oturum açmış usta)
  static const String panel = '/panel';
  static const String panelEdit = '/panel/edit';

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
}

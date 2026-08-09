/// Uygulama genelinde kullanılan sabitler.
/// Tek bir yerden yönetilerek "sihirli sayı" hatalarının önüne geçilir.
class AppConstants {
  AppConstants._();

  /// Kullanıcıya görünen marka adı (launcher, splash, drawer, yasal metinler).
  static const String appName = 'İlanda Hizmet';
  static const String appSlogan = 'Bölgenizdeki en iyi ustalar cebinizde';

  // Form / içerik limitleri
  static const int minPasswordLength = 6;
  static const int maxAboutLength = 500;
  static const int maxDisplayNameLength = 60;
  /// Usta profili deneyim yılı üst sınırı (21331231 gibi abartı engellenir).
  static const int maxExperienceYears = 60;

  // Listeleme
  static const int artisanPageSize = 20;

  // İş ilanı (jobs) — çift taraflı pazaryeri
  /// Aynı anda AÇIK tutulabilecek ilan sayısı.
  ///
  /// `firestore.rules` → `openJobQuotaOk()` ve `functions/index.js` →
  /// `MAX_OPEN_JOBS` ile AYNI olmalı. Yayınlanan her ilan eşleşen tüm ustalara
  /// bildirim gönderdiği için limitsiz kullanıcı platform çapında spam
  /// üretebiliyordu.
  static const int maxOpenJobs = 5;

  /// Günlük ilan hakkı — sunucuda (`onJobCreated`) uygulanır.
  static const int maxJobsPerDay = 10;

  static const int maxJobPhotos = 5; // ilan başına en fazla fotoğraf (#9)
  static const int maxJobTitleLength = 80;
  static const int maxJobDescriptionLength = 600;
  static const int maxOfferNoteLength = 300;

  // Sohbet mesajı metin tavanı (firestore.rules ile hizalı).
  static const int maxMessageLength = 4000;

  /// Sohbet ekranında canlı dinlenen en fazla mesaj (en yeniler).
  /// Limitsiz snapshots uzun thread'lerde okuma + RAM şişiriyordu.
  static const int chatMessagesFetchCap = 120;

  /// İki metin/foto mesajı arası minimum süre (istemci spam koruması).
  static const Duration minMessageInterval = Duration(milliseconds: 1200);

  /// Son 60 sn içinde en fazla bu kadar mesaj (istemci tavanı).
  static const int maxMessagesPerMinute = 20;

  // Yeni ustaya tanınan görünürlük desteği süresi (PRD §3).
  // Bu süre boyunca "Yeni Usta" rozeti gösterilir; puana yansımaz.
  static const int newArtisanVisibilityDays = 15;

  // Gelir modeli faz bayrağı (PRD §6):
  //  - true  (BETA): tüm ustalar Premium özelliklerini (müsaitlik, iş ilanları)
  //    ücretsiz kullanır — `ArtisanProfile.hasPremiumAccess` hep true döner.
  //    `isPremium` alanını istemci HİÇBİR durumda yazamaz (firestore.rules).
  //  - false: Premium erişimi gerçek aboneliğe (hasActivePremium) bağlanır;
  //    Play Billing + sunucu doğrulaması geldiğinde kapatılacak.
  static const bool premiumFreeDuringBeta = true;

  // Puanlama kuralı: sohbet en az bu kadar süre aktif olmalı
  static const Duration reviewUnlockDuration = Duration(hours: 24);

  // Dosya yükleme
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  // Görsel yükleme optimizasyonu (Storage bant genişliği / fatura):
  // ham fotoğrafı Firebase'e göndermeden önce image_picker ile küçültüp
  // JPEG'e sıkıştırıyoruz. ~1080px + %70 kalite, 5 MB'lık bir fotoğrafı
  // tipik olarak ~150–300 KB'a indirir. Tüm pickImage çağrıları bunu kullanır.
  static const double imagePickMaxWidth = 1080;
  static const int imagePickImageQuality = 70;

  // Feed sunucu-tarafı okuma tavanı (Firestore doküman OKUMA faturası):
  // istemci filtresi/sıralaması uygulanmadan önce sunucudan en fazla bu kadar
  // ilan çekilir. Süresi dolan/coğrafi elenen ilanlar için bir miktar pay bırakır.
  static const int openJobsFetchCap = 60;
  static const int nearbyJobsFetchCap = 100;

  // Keşfet Ürünler (PRD-006)
  static const bool kAdminProductModerationEnabled = true;
  static const int maxProductPhotos = 8;
  static const int productTitleMin = 3;
  static const int productTitleMax = 80;
  static const int productDescMin = 10;
  static const int productDescMax = 2000;
  static const int maxProductTags = 8;
  static const int maxActiveProductsPerOwner = 50;
  static const int productDiscoverFetchCap = 60;
  static const int productSoftDeleteDays = 30;

  // Usta aramasında sunucudan çekilecek en fazla profil (istemci filtre/sıralama
  // öncesi tavan). Müsaitlik hesaplanmış alan olduğundan sıralama istemcide;
  // bu tavan patolojik okuma sayısını sınırlar (CF + areaKeys[] ölçeğine kadar).
  static const int artisanFetchCap = 300;

  // Mağaza (ürün vitrini) açık mı. Modül 2026-08-10'da geri getirildi;
  // bayrak, tamamlanmadan yayına çıkmasın diye bir kapı olarak duruyor.
  static const bool kProductsEnabled = true;

  // Asset yolları
  static const String provincesAsset = 'assets/data/provinces.json';
  static const String districtsAsset = 'assets/data/districts.json';
  static const String neighborhoodsAsset = 'assets/data/neighborhoods.json';
  static const String professionsAsset = 'assets/data/professions.json';
}

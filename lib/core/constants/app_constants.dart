/// Uygulama genelinde kullanılan sabitler.
/// Tek bir yerden yönetilerek "sihirli sayı" hatalarının önüne geçilir.
class AppConstants {
  AppConstants._();

  /// Kullanıcıya görünen marka adı (launcher, splash, drawer, yasal metinler).
  static const String appName = 'Ustasından';
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
  static const int maxJobPhotos = 5; // ilan başına en fazla fotoğraf (#9)
  static const int maxJobTitleLength = 80;
  static const int maxJobDescriptionLength = 600;
  static const int maxOfferNoteLength = 300;

  // Sohbet mesajı metin tavanı (firestore.rules ile hizalı).
  static const int maxMessageLength = 4000;

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

  // Usta aramasında sunucudan çekilecek en fazla profil (istemci filtre/sıralama
  // öncesi tavan). Müsaitlik hesaplanmış alan olduğundan sıralama istemcide;
  // bu tavan patolojik okuma sayısını sınırlar (CF + areaKeys[] ölçeğine kadar).
  static const int artisanFetchCap = 300;

  // Asset yolları
  static const String provincesAsset = 'assets/data/provinces.json';
  static const String districtsAsset = 'assets/data/districts.json';
  static const String neighborhoodsAsset = 'assets/data/neighborhoods.json';
  static const String professionsAsset = 'assets/data/professions.json';
}

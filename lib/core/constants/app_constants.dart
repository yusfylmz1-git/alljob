/// Uygulama genelinde kullanılan sabitler.
/// Tek bir yerden yönetilerek "sihirli sayı" hatalarının önüne geçilir.
class AppConstants {
  AppConstants._();

  /// Kullanıcıya görünen marka adı (launcher, splash, drawer, yasal metinler).
  static const String appName = 'İlanda Hizmet';
  static const String appSlogan = 'Bölgenizdeki en iyi ustalar cebinizde';

  /// Tanıtım sitesi — menü altındaki bağlantı ve künye için.
  ///
  /// ⚠️ YASAL METİN ADRESLERİ BURADA DEĞİL: onlar
  /// `features/legal/legal_docs.dart` → `kLegalBaseUrl` altındadır ve `www.`
  /// ön ekini taşır (store formlarına girilen kanonik adres odur). İkinci bir
  /// kaynak tanımlamak, biri değişince diğerinin sessizce eskimesi demektir.
  static const String siteUrl = 'https://ilandahizmet.com';

  /// Menüde/künyede gösterilen kısa biçim (şema ve `www.` olmadan).
  static const String siteLabel = 'ilandahizmet.com';

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

  /// Usta vitrin iş fotoğrafları (Storage + profil dizisi).
  static const int maxWorkPhotos = 10;

  /// Sertifika / belge görselleri.
  static const int maxCertificates = 5;

  // Görsel yükleme optimizasyonu (Storage bant genişliği / fatura):
  // ham fotoğrafı Firebase'e göndermeden önce image_picker ile küçültüp
  // JPEG'e sıkıştırıyoruz. ~1080px + %70 kalite, 5 MB'lık bir fotoğrafı
  // tipik olarak ~150–300 KB'a indirir. Tüm pickImage çağrıları bunu kullanır.
  static const double imagePickMaxWidth = 1080;
  static const int imagePickImageQuality = 70;

  // — GÖRSEL ORANLARI (2026-08-14 cihaz bulgusu: "resimler yarım çıkıyor,
  //   profil fotosu yayık görünüyor") —
  //
  // Kök neden: kırpma adımı YOKTU. Kullanıcı hangi oranda fotoğraf seçerse
  // seçsin, kart `AspectRatio` + `BoxFit.cover` ile onu zorla çerçeveye
  // sığdırıyordu; dikey fotoğrafın altı/üstü kesiliyordu ("yarım").
  //
  // Çözüm: yüklemeden ÖNCE kullanıcıya kırpma ekranı gösterilir — çerçeveyi
  // kendisi seçer. Kart oranı ile kırpma oranı AYNI olmalı; aksi hâlde
  // kırpma bir şey çözmez.

  /// Ürün / ilan görseli oranı — 4:5 dikey (modern Instagram varsayılanı).
  /// Telefonda kareye göre %25 daha büyük alan, ürün detayı daha net.
  static const double photoAspectWidth = 4;
  static const double photoAspectHeight = 5;

  /// Kart ızgarasında kullanılacak `childAspectRatio`.
  ///
  /// Görsel 4:5 (yani genişliğin 1.25 katı yükseklik) + altında ~92 px'lik
  /// metin şeridi (başlık 2 satır + fiyat + kategori + iç boşluk).
  ///
  /// 220 px genişlikte gereken oran ≈ 0.599; **0.55** güvenli pay bırakır:
  /// büyük yazı tipi ölçeği (erişilebilirlik ayarı) ve "ÖNE ÇIKAN" rozetinin
  /// eklediği satır da sığar.
  ///
  /// ⚠️ Bu değeri YÜKSELTME. 0.62'de kart taşıyor ve fotoğrafın altında
  /// sarı-siyah overflow şeridi çıkıyordu (2026-08-14 cihaz bulgusu).
  /// Kart daha kısa görünsün istiyorsan görsel oranını değiştir, bunu değil.
  static const double photoCardAspectRatio = 0.55;

  // Feed sunucu-tarafı okuma tavanı (Firestore doküman OKUMA faturası).
  // 2026-08-11: biraz düşürüldü — liste hâlâ dolu görünür, sayfa/scroll ile
  // yenileme zaten var; her açılışta fazla doc çekilmesin.
  static const int openJobsFetchCap = 50;
  static const int nearbyJobsFetchCap = 80;

  // Keşfet Ürünler (PRD-006)
  static const bool kAdminProductModerationEnabled = true;
  static const int maxProductPhotos = 8;
  static const int productTitleMin = 3;
  static const int productTitleMax = 80;
  static const int productDescMin = 10;
  static const int productDescMax = 2000;
  static const int maxProductTags = 8;
  static const int maxActiveProductsPerOwner = 50;

  /// Fiyat/bütçe üst sınırı (₺). Tavan olmadan kullanıcı "999999999999"
  /// yazabiliyordu: kart düzenini bozar, sıralamayı anlamsızlaştırır ve
  /// yanlışlıkla girilen basamak müşteriyi kaçırır. 100 milyon ₺ bir hizmet
  /// pazaryeri için fazlasıyla geniş; kural tarafında da aranır.
  static const double maxPriceAmount = 100000000;

  // — Canlı dinleyici tavanları (MALİYET) —
  //
  // Bu üç sorgu `limit()` olmadan çalışıyordu: dinleyici açık kaldığı sürece
  // koleksiyondaki HER döküman okunur ve her değişiklikte yeniden faturalanır.
  // Popüler bir usta binlerce takipçiye ulaştığında tek ekran açılışı binlerce
  // okuma demekti. Tavanlar UI'nin gösterebileceğinden geniş, faturayı
  // öngörülebilir kılacak kadar dar.
  static const int favoritesFetchCap = 200;
  static const int followersFetchCap = 200;
  static const int blockedFetchCap = 200;
  static const int chatThreadsFetchCap = 200;
  static const int productDiscoverFetchCap = 48;
  static const int productSoftDeleteDays = 30;

  // Usta aramasında sunucudan çekilecek en fazla profil (istemci filtre öncesi).
  // 300 → 180: ilk ekran için yeterli; "daha fazla"/yenile ile taze sorgu.
  static const int artisanFetchCap = 180;

  // Mağaza (ürün vitrini) açık mı. Modül 2026-08-10'da geri getirildi;
  // bayrak, tamamlanmadan yayına çıkmasın diye bir kapı olarak duruyor.
  static const bool kProductsEnabled = true;

  // Asset yolları
  static const String provincesAsset = 'assets/data/provinces.json';
  static const String districtsAsset = 'assets/data/districts.json';
  static const String neighborhoodsAsset = 'assets/data/neighborhoods.json';
  static const String professionsAsset = 'assets/data/professions.json';
}

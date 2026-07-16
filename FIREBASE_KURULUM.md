# 🔥 Firebase Kurulum Rehberi — Ustasından

Bu belge, uygulamayı bellek içi mock'tan **Firebase** backend'ine geçirmek için
adım adım yol gösterir. Kod tarafı **hazır**: tek yapman gereken CLI kurulumunu
tamamlayıp `useFirebaseBackend` bayrağını `true` yapmak.

> **Mimari:** Tüm veri erişimi arayüzler arkasında. Mock ↔ Firebase geçişi tek
> bayrakla olur: [`lib/core/config/backend_config.dart`](lib/core/config/backend_config.dart)
> → `useFirebaseBackend`. UI/controller katmanı hiç değişmez.

---

## 1. Ön koşullar (senin makinende — bir kez)

Şu an makinede **Node.js, Firebase CLI ve flutterfire kurulu değil.**

```bash
# 1) Node.js LTS kur (https://nodejs.org)  →  sonra doğrula:
node --version
npm --version

# 2) Firebase CLI
npm install -g firebase-tools
firebase --version
firebase login          # tarayıcıda Google ile oturum açar

# 3) FlutterFire CLI
dart pub global activate flutterfire_cli
#   (PATH uyarısı verirse: %USERPROFILE%\AppData\Local\Pub\Cache\bin ekle)
```

## 2. Firebase projesi oluştur

1. https://console.firebase.google.com → **Proje ekle** → ad: `usta-cepte` (veya istediğin).
2. **Authentication → Sign-in method → E-posta/Şifre**'yi etkinleştir.
   (Google ile giriş de istersen ayrıca etkinleştir — PRD §2.)
3. **Firestore Database → Veritabanı oluştur** (production mode, bölge: `eur3` veya `europe-west`).
4. **Storage → Başlat** (varsayılan bölge).

## 3. Uygulamayı Firebase'e bağla

Proje kökünde (`alljob/`):

```bash
flutterfire configure
```

- Az önce oluşturduğun projeyi seç.
- Platformları seç (Android / iOS / Web).
- Bu komut **`lib/firebase_options.dart`** dosyasını GERÇEK anahtarlarla
  otomatik üretir (şu an oradaki placeholder dosyanın üzerine yazar) ve
  Android için `google-services.json`, iOS için `GoogleService-Info.plist`
  ekler.

## 4. Bayrağı çevir

[`lib/core/config/backend_config.dart`](lib/core/config/backend_config.dart):

```dart
const bool useFirebaseBackend = true;   // false → mock
```

Ardından:

```bash
flutter pub get
flutter run
```

`main.dart` yalnızca bayrak `true` iken `Firebase.initializeApp()` çağırır.

## 5. Güvenlik kuralları ve indexler

Depoda hazır dosyalar var:

- [`firestore.rules`](firestore.rules) — katılımcı bazlı sohbet erişimi, profil
  sahipliği, puanlama alanlarının istemciden korunması (PRD §5).
- [`firestore.indexes.json`](firestore.indexes.json) — `reviews` ve `chats`
  sorguları için composite index.

Dağıtım (bir kez `firebase init firestore` ile `firebase.json` üretmen gerekebilir):

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

> Not: İlk gerçek sorguda Firestore, eksik index için konsolda tıklanabilir bir
> "create index" linki de verir.

---

## Firestore veri modeli (PRD §4 ile uyumlu)

| Koleksiyon | Döküman ID | Alanlar |
|---|---|---|
| `users` | Auth UID | displayName, email, role, hasArtisanProfile, activeMode, profilePhotoURL, createdAt, **fcmTokens[] (cihaz push token'ları)** |
| `artisanProfiles` | Auth UID | profession, experienceYears, aboutText, serviceAreas[], certificates[], workPhotos[], isVerified, isPremium, premiumExpiresAt, alwaysAvailable, manualPause, weeklySchedule, createdAt, **displayName/profilePhotoURL (denormalize)**, averageRating/totalReviews/totalRatingSum (yalnızca Cloud Functions yazar) |
| `chats` | `chat_{customerUid}__{artisanUid}` | participants[], customerUid, artisanUid, adlar/fotolar, lastMessage, lastMessageSenderUid, updatedAt, lastRead{uid: ts} |
| `chats/{id}/messages` | otomatik | senderUid, text (maskeli), imageHandle, createdAt |
| `reviews` | otomatik | artisanUID, customerUID, chatId, rating, tags[], createdAt |
| `neighborhoods` | otomatik | districtId, name (lazy loading) |

---

## Hazır olan kod (bu oturumda eklendi)

- Bayrak: `lib/core/config/backend_config.dart`
- Firebase implementasyonları (arayüzlerin arkasında):
  - `features/auth/data/firebase_auth_repository.dart`
  - `features/storage/firebase_storage_repository.dart`
  - `features/artisan/data/firebase_my_profile_repository.dart`
  - `features/artisan/data/firebase_artisan_repository.dart`
  - `features/chat/data/firebase_chat_repository.dart`
- Provider'lar bayrağa göre mock/Firebase seçer (auth/storage/myProfile/artisan/chat).
- `main.dart` bayrak açıkken `Firebase.initializeApp()` çağırır.

## Firebase'e taşınırken kalan işler (Cloud Functions / küçük refactor)

Bunlar mock'ta çalışıyor ama Firebase'de sunucu tarafı ister:

1. **Puan hesaplama (PRD §5):** Değerlendirme eklenince `artisanProfiles`'daki
   `averageRating/totalReviews/totalRatingSum` alanlarını bir **Cloud Function**
   (`reviews` onCreate) güncellemeli. Şu an bu alanlar istemciden korunuyor
   (kurallar engelliyor). Ayrıca [`review_screen.dart`](lib/features/review/presentation/review_screen.dart)
   değerlendirmeyi doğrudan `mockDatabaseProvider.addReview` ile yazıyor →
   Firebase modunda bunun yerine `reviews` koleksiyonuna yazan küçük bir
   `ReviewRepository` soyutlaması eklenmeli.
2. **Ustanın kendi yorumları (usta ana ekranı):**
   [`artisan_home_screen.dart`](lib/features/artisan/presentation/artisan_home_screen.dart)
   yorumları `mockDatabaseProvider`'dan okuyor → Firebase modunda `reviews`
   sorgusundan gelmeli (örn. `myReviewsProvider`).
3. **Okunmamış SAYISI (rozet):** `FirebaseChatRepository.unreadCount` şu an
   Cloud Functions olmadan 0/1 (ikili) gösterge veriyor. Kesin sayı için
   thread üzerinde `unread{uid: n}` alanını CF ile tutmak gerekir.
4. **Coğrafi arama ölçeklendirme:** `serviceAreas` map dizisi olduğundan geo
   filtre istemcide yapılıyor. Büyürken `areaKeys[]` (örn. `il|ilçe|mahalle`)
   denormalize edip `array-contains` + gerçek `startAfter` sayfalaması ekle.
5. ~~**Bildirimler (FCM):** yeni mesaj push'u~~ ✅ **YAPILDI (Oturum 22).**
   Aşağıdaki "Push bildirimleri" bölümüne bak.

Bu maddeler, mock ile Firebase arasında %100 eşdeğerliğe ulaşmak için kalan
işlerdir; temel akışlar (giriş, profil, arama, sohbet) bayrak açılınca çalışır.

---

## 🔔 Push bildirimleri (FCM) — Oturum 22

Yeni sohbet mesajı gelince alıcının cihazına push bildirimi gider.

**Akış:** kullanıcı giriş yapar → cihaz FCM token'ı `users/{uid}.fcmTokens`
dizisine eklenir → biri mesaj gönderince `onMessageCreated` Cloud Function'ı
alıcının token'larına bildirim yollar → geçersiz token'ları temizler. Çıkışta
token diziden çıkarılır.

### Kod tarafı (hazır)
- `functions/index.js` → **`onMessageCreated`** (chats/{id}/messages/{id} onCreate).
- `lib/features/notifications/data/push_service.dart` → izin, token kaydı/silme,
  ön plan SnackBar, bildirime dokununca sohbete gitme.
- `lib/main.dart` → arka plan mesaj işleyicisi (`onBackgroundMessage`).
- `lib/app.dart` → giriş olunca token kaydı; `auth_controller.dart` → çıkışta silme.
- `web/firebase-messaging-sw.js` → web arka plan bildirimleri için servis çalışanı.
- pubspec: `firebase_messaging`.

### ⚠️ KULLANICI AKSİYONLARI

1. **Cloud Function'ı deploy et** (yeni `onMessageCreated`):
   ```bash
   firebase deploy --only functions --project alljob1
   ```
   (Firestore kuralları DEĞİŞMEDİ — `users/{uid}` sahibi zaten `fcmTokens`
   yazabiliyor; ayrı rules deploy'u gerekmez.)

2. **Android:** Ek ayar YOK. `google-services.json` mevcut, `firebase_messaging`
   eklentisi `POST_NOTIFICATIONS` iznini otomatik ekler. Gerçek cihaz/emülatörde
   (Google Play Services'li) `flutter run` → izin iste → başka hesaptan mesaj at.

3. **Web (opsiyonel):** VAPID anahtarı gerekir. Firebase Console → Proje Ayarları
   → **Cloud Messaging** → "Web Push certificates" → anahtar çifti oluştur →
   kopyala →
   [`push_service.dart`](lib/features/notifications/data/push_service.dart)
   içindeki `kWebVapidKey` sabitine yapıştır. Boş kalırsa web'de push alınmaz
   (Android/iOS etkilenmez).

4. **iOS (Windows'ta yapılamaz):** APNs anahtarı Firebase Console → Cloud
   Messaging → Apple app configuration'a yüklenmeli + Xcode'da Push Notifications
   capability. Windows geliştirme ortamında iOS build zaten yapılamıyor.

### Test
Aynı projede iki hesap (A müşteri, B usta). A → B'ye mesaj at; B'nin cihazı arka
plandayken sistem bildirimi görmeli, ön plandayken SnackBar. Bildirime dokununca
ilgili sohbet açılmalı. B çıkış yapınca o cihaza artık bildirim gitmemeli.

---

## ☎️ Telefon doğrulama + Mavi tik (Oturum 24)

Kullanıcı telefonunu SMS ile doğrular → hesabına `phoneVerified` işareti; usta ise
profilinde **mavi tik** (`ArtisanProfile.isVerified`) görünür. Opsiyoneldir
(mavi tik ödülü); hem müşteri hem usta doğrulayabilir.

**Akış:** telefon mevcut hesaba **bağlanır** (`linkWithCredential` / web'de
`linkWithPhoneNumber`). Bağlandıktan sonra kimlik jetonu `phone_number` claim'i
taşır → Firestore kuralı `isVerified/phoneVerified=true` yazımına **yalnızca bu
claim varsa** izin verir (kimse doğrulamadan mavi tik alamaz, CF gerekmez).
Telefon numarası hassas veri → `users/{uid}/private/contact`'a yazılır (public
`users` dökümanına DEĞİL).

### Kod tarafı (hazır)
- `lib/features/auth/data/phone_verification_repository.dart` (+`firebase_*`,
  mock: test kodu `123456`).
- `lib/features/auth/presentation/phone_verification_sheet.dart` (numara→kod
  alttan açılır sayfa) + `verification_tile.dart` (müşteri profil + usta edit).
- `AppUser.phoneVerified`; `AuthRepository.setPhoneVerified` +
  `MyProfileRepository.markVerified`.
- `firestore.rules`: `users` (phoneVerified) + `artisanProfiles` (isVerified)
  yazımı `token.phone_number` şartına bağlandı.

### ⚠️ KULLANICI AKSİYONLARI
1. **Firestore kurallarını deploy et** (mavi tik guard'ları):
   ```bash
   firebase deploy --only firestore:rules --project alljob1
   ```
2. **Phone sağlayıcısını etkinleştir:** Firebase Console → Authentication →
   Sign-in method → **Phone** → Enable.
3. **Android:** telefon doğrulama SHA parmak izi ister. Debug için:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Çıkan **SHA-1 + SHA-256**'yı Firebase Console → Project Settings → Android
   uygulaması → "Add fingerprint"e ekle. (İstersen ben `signingReport`'u
   çalıştırıp değerleri veririm.)
4. **Ücretsiz test için:** Console → Authentication → Sign-in method → Phone →
   "Phone numbers for testing" bölümüne kurgusal numara + kod ekle (ör.
   `+90 555 000 0000` → `123456`) — gerçek SMS harcamadan denenir.
5. **Web:** `signInWithPhoneNumber`/`linkWithPhoneNumber` görünmez reCAPTCHA
   kullanır; `localhost` ve alan adın Authentication → Settings → Authorized
   domains'te olmalı (Google için zaten eklendiyse tamam). VAPID **gerekmez**
   (o yalnız FCM push için).
6. Gerçek SMS = Blaze (sende var). iOS APNs Windows'ta yapılamaz.

### Test
Giriş yap → Profil (müşteri) veya Usta Profili Düzenle → "Telefonu Doğrula" →
numara gir → gelen kodu (veya test kodunu) gir → doğrulanınca yeşil "Doğrulanmış"
kartı; usta kartlarında/profilinde mavi tik görünür.

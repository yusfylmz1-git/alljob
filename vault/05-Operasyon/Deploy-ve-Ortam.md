# Deploy ve Ortam

**Firebase projesi:** `alljob1` · **Bölge:** `europe-west1`
**Flutter:** 3.38.7 (stable) · **CF runtime:** firebase-functions 7 + admin 14

## Hosting siteleri

`firebase.json` iki site tanımlar:

| Site | Kaynak | İçerik |
|---|---|---|
| `alljob1` | `hosting/` | Tanıtım sitesi + yasal sayfalar (statik HTML) |
| `alljob1-admin` | `build/web` | **Admin paneli** (Flutter web) |

`hosting/` içinde: `index.html`, `gizlilik-politikasi.html`,
`kullanim-kosullari.html`, `kvkk-aydinlatma.html`, `hesap-silme.html`
(hesap silme sayfası mağaza şartı).

Admin sitesinde `index.html`, `flutter_bootstrap.js`,
`flutter_service_worker.js`, `main.dart.js` için **no-cache** başlıkları var —
yeni sürüm anında görünsün diye.

## Deploy komutları

```bash
# Kurallar (en sık)
firebase deploy --only firestore:rules --project alljob1
firebase deploy --only storage --project alljob1

# İndeksler
firebase deploy --only firestore:indexes --project alljob1

# Cloud Functions
firebase deploy --only functions --project alljob1
firebase deploy --only functions:onJobWritten --project alljob1   # tek fonksiyon

# Admin paneli
flutter build web -t lib/main_admin.dart
firebase deploy --only hosting:alljob1-admin --project alljob1

# Tanıtım sitesi
firebase deploy --only hosting:alljob1 --project alljob1
```

## ⚠️ Deploy tuzakları

### IPv4 / IPv6
Deploy ağ hataları uç noktaya göre IPv4 **ya da** IPv6 ister.

1. Önce `NODE_OPTIONS` olmadan dene
2. Hataya göre seç
3. **"service identity" hatası görürsen `NODE_OPTIONS`'u kaldır**

Tek bir doğru ayar yok — hataya bakarak karar ver.

### Android JDK 17
AR paketi Java 17 toolchain ister. `gradle.properties` içinde makineye özel
yolla tanımlı.

Belirti: `languageVersion=17 matching` hatası → JDK 17 yolunu kontrol et.

### iOS kaydı
`com.sepettehizmet.app` Firebase iOS app'i açık
(`1:839781526307:ios:af72f93e17f9bccc9aba96`).
`ios/Runner/GoogleService-Info.plist` + `firebase_options.dart` hizalı.
Eski `usta_cepte` iOS kaydı duruyor; kullanılmıyor.

### 🔴 R8 hataları YALNIZ release derlemede görünür
2026-08-15'te `minifyEnabled` + `shrinkResources` açıldı
(`android/app/build.gradle.kts`), koruma kuralları
`android/app/proguard-rules.pro` içinde.

R8 "kullanılmıyor" sandığı sınıfı **siler**. Yansımayla çağrılan her şey
korunmalıdır: Firebase modelleri, **Play Billing (para yolu)**, uCrop
(manifest'ten açılır), bildirim alıcıları, Flutter gömülü katmanı.

> [!warning] Debug derleme R8 çalıştırmaz
> Bir keep kuralı eksikse hata debug'da **asla** görünmez. Bağımlılık
> eklendiğinde/yükseltildiğinde `flutter build appbundle --release` ile
> derleyip **gerçek cihazda** satın alma + fotoğraf kırpma + bildirim
> akışlarını dene.

`build/app/outputs/mapping/release/mapping.txt` Crashlytics'in yığın izlerini
çözmesi için gerekir; sürüm başına saklanmalıdır.

### Cloud Functions lint kapısı
`firebase.json` → `functions.predeploy` artık `npm run lint` çalıştırır.
Lint **hata** verirse deploy durur (uyarılar durdurmaz). Kapıyı atlamak
gerekirse `--force` değil, önce hatayı düzelt.

## Yapılandırma anahtarları

`lib/core/config/backend_config.dart`:

```dart
const bool useFirebaseBackend = true;   // false → tüm uygulama mock'a düşer
const bool useFirebaseStorage = true;   // Blaze planı gerektirir
const String kAppCheckWebRecaptchaKey = '6Lf...';  // web reCAPTCHA v3
```

> [!note] App Check
> Site anahtarı gizli değildir (tarayıcı kaynağında görünür). Koruma kayıtlı
> **alan adlarından** gelir — yeni alan adı eklenirse reCAPTCHA yönetim
> panelinde de tanımlanmalı.

`lib/features/membership/billing_config.dart`:
```dart
const bool kBillingEnabled = true;
const String kProMonthlyProductId = 'sepette_hizmet_pro_monthly';  // ⚠ mağazada açıldıktan sonra değiştirilemez
```

## Uygulama kimlikleri

| Platform | Paket |
|---|---|
| Android | `com.sepettehizmet.app` (doğrulandı) |
| iOS | `com.sepettehizmet.app` (`…ios:af72f93e17f9bccc9aba96`) |

## Çalışma zamanı kontrolleri (deploy'suz)

Admin panelinden `adminConfig` üzerinden değiştirilir, uygulama yeniden
yayınlanmaz:

| Ayar | Etki |
|---|---|
| `minAppVersion` | Eski istemciler `/force-update`'e kilitlenir |
| `maintenanceMode` | Herkes `/maintenance` ekranına |

→ [[Admin-Paneli]]

## Deploy öncesi kontrol listesi

```bash
flutter analyze                    # "No issues found!" olmalı
flutter test                       # tümü geçmeli
npm --prefix functions run lint    # 0 hata (uyarı serbest)
```

Sonra değişikliğin türüne göre:

- [ ] **Play'e sürüm çıkılacaksa** — `pubspec.yaml` içindeki `versionCode`
      (`+N`) artırıldı mı? Play aynı sayıyı ikinci kez KABUL ETMEZ
- [ ] **Bağımlılık eklendi/yükseltildiyse** — `flutter build appbundle
      --release` + gerçek cihaz testi (R8 keep kuralı eksikse yalnız burada
      görünür) → [[Bilinen-Tuzaklar]]

- [ ] **Kural değiştiyse** — testi yok, elle doğrula. Ana akışları dene:
      ilan aç, ilgi bildir, mesaj yaz, usta seç, tamamla, değerlendir
- [ ] **CF değiştiyse** — testi yok. Deploy sonrası log izle
      (`firebase functions:log`)
- [ ] **Yeni sorgu eklendiyse** — index gerekir mi? Hata konsol bağlantısı
      verir ama **`firestore.indexes.json`'a da ekle**
- [ ] **Model alanı eklendiyse** — eski dokümanlar bu alansız; `fromMap`
      varsayılan veriyor mu?
- [ ] **Mimari değiştiyse** — ilgili kasa notunu güncelle → [[00-BASLA-BURADAN]]

---
İlgili: [[Test-Stratejisi]] · [[Bilinen-Tuzaklar]] · [[Cloud-Functions-Haritasi]] · [[Admin-Paneli]]

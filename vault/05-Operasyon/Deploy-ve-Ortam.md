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

### iOS appId eski
`firebase_options.dart` içinde iOS `appId` hâlâ eski kayda ait
(`com.ustacepte.ustaCepte`). iOS'a gerçekten çıkılacaksa yeniden
`flutterfire configure` gerekir.

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
const String kProMonthlyProductId = 'usta_cepte_pro_monthly';  // ⚠ değiştirilemez
```

## Uygulama kimlikleri

| Platform | Paket |
|---|---|
| Android | `com.sepettehizmet.app` (doğrulandı) |
| iOS | eski kayıt — güncellenmedi |

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
flutter analyze          # "No issues found!" olmalı
flutter test             # tümü geçmeli
```

Sonra değişikliğin türüne göre:

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

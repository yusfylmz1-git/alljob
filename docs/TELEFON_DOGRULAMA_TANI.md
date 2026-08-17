# 📱 Telefon Doğrulama — Tanı Rehberi

> Bu dosya 2026-08-14'te, cihazda alınan
> **"Doğrulama başarısız (unknown)"** hatasının kökü bulunduktan sonra
> yazıldı. Aynı belirtiyi bir daha baştan araştırmamak için.

---

## ✅ KESİN KÖK NEDEN — cihaz logundan doğrulandı (2026-08-14)

Uzun bir tahmin turundan sonra `adb logcat` gerçek sebebi verdi:

```
E FirebaseAuth: [SmsRetrieverHelper] SMS verification code request failed:
  unknown status code: 18002 Invalid PlayIntegrity token;
  app not Recognized by Play Store.

E zzb: Failed to initialize reCAPTCHA config:
  No Recaptcha Enterprise siteKey configured for tenant/project
```

**Uygulama henüz Play Store'da YAYINLANMADIĞI için Play Integrity onu
tanımıyor** (`app not Recognized by Play Store`) ve token'ı reddediyor.
Firebase reCAPTCHA yedeğine düşüyor, ama projede reCAPTCHA Enterprise site
key tanımlı olmadığından o da başarısız. İki doğrulama yolu da kapalı →
SDK `code=unknown` fırlatıyor.

> **Bu bir hata DEĞİL.** Yayınlanmamış bir uygulamada beklenen davranıştır.
> Kodda ve Firebase yapılandırmasında eksik yok.

### Ne zaman kendiliğinden düzelir

**Uygulama Play Console'a yüklenip kapalı test (internal testing) yayınına
alındığı anda.** Play Integrity uygulamayı tanır, gerçek numaralarla
doğrulama çalışır. Yayın sonrası gerçek kullanıcılarda da sorun olmaz.

### 📱 CİHAZA GÖRE DEĞİŞİR — doğrulandı (2026-08-14)

Aynı APK, aynı an, aynı Firebase projesi:

| Cihaz | Sonuç |
|---|---|
| Xiaomi (MIUI) | ❌ `unknown` — Play Integrity reddetti |
| Başka telefon | ✅ **Çalıştı, SMS geldi** |

**Yani kod ve yapılandırma sağlam.** Play Integrity'nin yayınlanmamış
uygulamaya verdiği yanıt cihazdan cihaza değişiyor; MIUI/Xiaomi bu konuda
daha katı (Play koruma durumu, MIUI optimizasyonları, Play Services sürümü).

> **Test ederken tek cihaza güvenme.** Bir cihazda `unknown` alman, kodun
> bozuk olduğu anlamına gelmez — ikinci bir cihazda dene. Bu, saatler
> süren yanlış teşhis turlarını önler.

### O zamana kadar nasıl test edilir

**Test numaralarıyla** (aşağıdaki bölüm) — Play Integrity'yi tamamen
atlarlar, gerçek SMS gitmez, ücret oluşmaz.

### Yayından ÖNCE gerçek numarayla test şart mı?

Hayır, mümkün de değil. Doğru sıra:
1. Test numarasıyla akışın uçtan uca çalıştığını doğrula (yapıldı).
2. Kapalı teste (internal testing) yükle.
3. **Kapalı testte gerçek numarayla dene** — asıl doğrulama burada yapılır.
4. Sonra üretim yayınına geç.

---

## 📌 Elenen şüpheliler (hepsi doğruydu, sorun bunlarda değildi)

Bu sorunun peşinde şunlar tek tek denetlendi ve **hepsi doğru çıktı**.
Aynı yolu tekrar yürümemek için:

- Phone provider açık, SMS bölge politikası TR izinli
- debug + release SHA-1/SHA-256 kayıtlı, yerel keystore'larla eşleşiyor
- `google-services.json` Firebase'dekiyle birebir
- API anahtarı kısıtlaması (Play Integrity eklendi — gerekliydi ama yetmedi)
- App Check UNENFORCED, debug token eklendi (`App attestation failed`
  düzeldi ama `unknown` sürdü — **ayrı mekanizma**)
- `androidcheck.googleapis.com` — bu API artık genel katalogda YOK
  (SafetyNet emekli); aranmasına gerek yok

> **Ders:** `code=unknown` görünce önce `adb logcat` ile gerçek hata
> satırını al (`grep FirebaseAuth`). Tahminle ilerlemek saatler yakıyor.

---

## 🔴 Eski teşhis notları (tarihsel)

**Android API anahtarının "API kısıtlamaları" listesinde
`androidcheck.googleapis.com` YOK.**

Firebase Auth, Android'de SMS göndermeden **önce** "bu istek gerçek
uygulamadan mı geliyor?" doğrulaması yapar ve bunun için
`androidcheck.googleapis.com`'a çağrı atar. Projedeki Android API anahtarı
**27 servise kısıtlanmış** durumda ve bu servis listede değil → çağrı
reddediliyor → SDK ayırt edici kod üretemiyor ve **`code=unknown`**
fırlatıyor. **SMS hiç gönderilmez.**

Belirti tam olarak buydu: numara giriliyor → "Kod Gönder" → anında
"Doğrulama başarısız (unknown)". Kod adımına hiç geçilmiyor.

### ✅ Çözüm — API anahtarı kısıtlamasını genişlet

1. <https://console.cloud.google.com/apis/credentials?project=alljob1>
2. **"Android key (auto created by Firebase)"** anahtarını aç.
3. **API restrictions** bölümünde **Restrict key** seçili; listeye şunları
   **ekle** (mevcutları silme):
   - `Android Device Verification` (`androidcheck.googleapis.com`)
   - `reCAPTCHA Enterprise API` (`recaptchaenterprise.googleapis.com`)
     — Play Integrity kullanılamayan cihazlarda yedek doğrulama yolu.
4. **Save** → 2–5 dakika bekle (yayılma) → uygulamayı **tamamen kapatıp** aç.

> **Alternatif (en hızlı test):** API restrictions'ı geçici olarak
> **"Don't restrict key"** yap. Çalışırsa kök neden kesinleşir; sonra
> yukarıdaki iki servisi ekleyip kısıtlamayı geri aç.

> CLI ile değiştirilemedi — proje güvenlik yapılandırması değiştirdiği için
> otomatik uygulama engellendi; Console'dan yapılmalı.

### ⚠️ Önceki hatalı teşhis (düzeltildi)

İlk incelemede "`androidcheck.googleapis.com` API'si kapalı, Console'dan
aç" denmişti. **Yanlıştı.** O API projenin servis kataloğunda hiç
görünmüyor (2400 servis kaydı tarandı, yok) — SafetyNet emekliye
ayrıldığından genel kütüphaneden kaldırılmış. Console'un
`/apis/library/androidcheck.googleapis.com` sayfasının "Failed to load"
vermesi de bundan. **Etkinleştirilecek bir API yok; sorun anahtar
kısıtlamasında.**

---

## ✅ Doğrulanmış olanlar (bunlarda sorun YOK)

2026-08-14'te canlı projeden (`alljob1`) API ile teyit edildi:

| Kontrol | Durum |
|---|---|
| Phone sign-in provider | ✅ `enabled: true` |
| SMS bölge politikası | ✅ `allowlistOnly: ["TR"]` — Türkiye izinli |
| Test numaraları | ✅ `+905550000000`, `+905555555555` → kod `123456` |
| SHA-1 / SHA-256 (debug) | ✅ Firebase'de kayıtlı, yerel keystore ile eşleşiyor |
| SHA-1 / SHA-256 (release) | ✅ Firebase'de kayıtlı, `upload-keystore.jks` ile eşleşiyor |
| App Check enforcement | ✅ Tümü `UNENFORCED` — telefon akışını **bloklamıyor** |
| `playintegrity.googleapis.com` | ✅ Açık |
| `identitytoolkit.googleapis.com` | ✅ Açık |
| `google-services.json` (yerel) | ✅ Firebase'dekiyle birebir — api_key ve SHA'lar eşleşiyor |
| reCAPTCHA / SMS kota kısıtı | ✅ Yok |
| **Android API anahtarı kısıtlaması** | ❌ **`androidcheck` listede yok ← sorun bu** |

**Not:** `com.sepettehizmet.app` dışında iki eski Android app kaydı daha
duruyor (`com.ustasindan.app`, `com.ustacepte.usta_cepte`). Zararsız ama
karışıklık yaratabilir; ileride Firebase Console'dan silinebilir.

---

## 🔍 "Kayıtlı numaraları nerede görürüm?"

Telefon numarası **iki ayrı yerde** tutulur — ikisini karıştırma:

### 1. Firebase Authentication (kimlik tarafı)

SMS ile doğrulanıp hesaba **bağlanan** numara burada.

**Console → Authentication → Users** sekmesi. Tabloda bir **"Phone"**
sütunu var; doğrulanmış numaralar orada görünür ve arama kutusundan
numarayla aratılabilir.

> Boş görünüyorsa: hiçbir hesapta doğrulama **tamamlanmamış** demektir.
> `unknown` hatası yüzünden akış hiç bitmediyse bu beklenen sonuçtur.

### 2. Firestore (uygulama verisi)

- `users/{uid}.phoneVerified` → `true/false` (rozet için, herkese açık)
- `users/{uid}.publicPhone` → kullanıcının **bilerek yayınladığı** numara
- `users/{uid}/private/contact` → hassas numara, **yalnız sahibi okur**

**Console → Firestore Database → `users` koleksiyonu.** Ham numara ana
dokümanda **yoktur** (bilinçli: Firestore alan bazlı okuma kısıtlaması
yapamaz, ana doküman herkese açık okunur).

---

## 📊 Hata koduna göre nerede olduğun

Belirtiler bir **ilerleme sırası** oluşturur — hangi hatayı aldığın, isteğin
ne kadar ilerlediğini söyler:

| Hata | Ne demek | Durum |
|---|---|---|
| `unknown` | İstek Firebase'e **hiç ulaşmadı** — cihaz doğrulaması düştü | ❌ Anahtar kısıtlaması / SHA / Play Services |
| `too-many-requests` | İstek **ulaştı**, numara kotası doldu | ✅ Yapılandırma ÇALIŞIYOR, sadece bekle |
| `invalid-verification-code` | SMS geldi, kod yanlış girildi | ✅ Akış tamamen çalışıyor |

> **`unknown` → `too-many-requests` geçişi bir başarıdır.** Kotaya
> takılabilmek için isteğin sunucuya varması gerekir; yani cihaz doğrulaması
> artık geçiyor demektir.

### `too-many-requests` alırsan

- Numara bazlıdır, **hesap engellenmez**.
- Genelde **30–60 dakika**, yoğun denemede birkaç saat.
- **Tekrar denemek süreyi uzatır** — bekle.
- Beklemeden test etmek için aşağıdaki test numaralarını kullan (kotaya
  takılmazlar).

---

## 🧪 SMS harcamadan test etme

Firebase'de tanımlı test numaraları var — gerçek SMS gitmez, ücret oluşmaz:

| Numara | Kod |
|---|---|
| `+90 555 000 00 00` | `123456` |
| `+90 555 555 55 55` | `123456` |

Uygulamada `5550000000` gir, kod olarak `123456` yaz. **Bu numaralar cihaz
doğrulamasını da atlar** — yani `androidcheck` kapalıyken bile çalışır.

> Bu yüzden test numarasıyla çalışıp gerçek numarayla çalışmaması, kök
> nedenin cihaz doğrulaması olduğunun kanıtıdır.

---

## 🩺 `code=unknown` görürsen sırayla bak

Kod artık bu durumu `deviceCheckFailed` olarak eşliyor ve kullanıcıya
anlamlı bir mesaj gösteriyor. Terminalde ayrıntılı tanı satırları basılır
(`[TANI][telefon]`).

1. **API anahtarı kısıtlaması** — en sık sebep (2026-08-14'te bu çıktı).
   Console → Credentials → "Android key" → API restrictions listesinde
   `androidcheck.googleapis.com` var mı? Yoksa ekle.
   Hızlı test için "Don't restrict key" yapıp dene.
2. **SHA-1 ve SHA-256 ikisi de kayıtlı mı?** Yalnız SHA-1 yetmez.
   ```bash
   # debug
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android
   # release
   keytool -list -v -keystore C:/Users/Okul/upload-keystore.jks -alias upload
   ```
   Çıkan parmak izleri Firebase → Proje ayarları → Android app → SHA
   listesinde olmalı.
3. **`google-services.json` güncel mi?** SHA ekledikten sonra dosyayı
   yeniden indirip `android/app/` altına koy ve **temiz derleme** yap
   (`flutter clean`).
4. **Cihazda Google Play Hizmetleri güncel mi?** Emülatörde "Google APIs"
   imajı olmayan sürümlerde bu doğrulama hiç çalışmaz — gerçek cihaz kullan.
5. **Play Console → App Integrity** — uygulama yayınlandıktan sonra Play
   App Signing devreye girer; oradaki **App signing key** SHA'sı da
   Firebase'e eklenmelidir. Aksi hâlde Play'den inen sürümde doğrulama
   çalışmaz (geliştirme sürümünde çalışsa bile).

---

## ⚠️ Yayın öncesi kritik hatırlatma

Telefon doğrulama artık **kayıt yolunun üstünde**: usta veya mağaza açmak
doğrulanmış numara istiyor (istemci kapısı + `firestore.rules` →
`providerFlagOk`).

**Doğrulama bozuksa hiç kimse sağlayıcı olamaz.** Bu yüzden yayından önce:

- [ ] `androidcheck.googleapis.com` açıldı
- [ ] **Gerçek cihazda, gerçek numarayla** uçtan uca doğrulama yapıldı
- [ ] Play App Signing SHA'sı Firebase'e eklendi (yayın sonrası ilk gün)

# 🔍 Yayın Öncesi Tam Denetim — 2026-08-14

Kapsam: oturum yönetimi, bildirim, telefon doğrulama, girdi güvenliği,
Firestore kuralları, maliyet ve Play Store hazırlığı.

**Durum:** `flutter analyze` 0 sorun · **712/712 test geçiyor** · release AAB
derlendi (59.3 MB) · yeni regresyon testi
`test/yayin_hazirlik_denetimi_test.dart` (14 test).

**Kurallar canlıda ✅** — `firebase deploy --only firestore:rules` yapıldı,
canlı ruleset doğrulandı (2026-08-14 15:25 UTC): `providerFlagOk`
`hasArtisanProfile` ve `hasShopProfile` için aktif. Telefon zorunluluğu
artık sunucu tarafında geçerli.

---

## 🔴 Bulunan ve düzeltilen kritik sorunlar

### 1. Çıkışta sahte çökme — "oturum kapatınca uygulama duruyor"

**Bu, bildirdiğin belirtinin doğrudan sebebiydi.**

`users/{uid}/...` kapsamlı canlı dinleyiciler çıkış anında bir an eski uid
ile açık kalır. Auth oturumu düşürdüğü an güvenlik kuralı onları tanımaz ve
akışa `permission-denied` **hatası** yayılır. Riverpod bunu `AsyncError`'a
çevirir, ekranlar hata görünümüne düşer — kullanıcı "çöktü" sanır. Oysa
hiçbir şey bozulmamıştır.

Koruma **yalnız sohbet deposunda** vardı; **10 dinleyici korumasızdı**:

| Dosya | Korunan akış |
|---|---|
| `notification_repository.dart` | bildirim listesi + zil rozeti |
| `notification_prefs.dart` | bildirim tercihleri |
| `firebase_favorite_repository.dart` | favoriler + takipçiler + favori durumu |
| `firebase_block_repository.dart` | engellenenler |
| `firebase_job_repository.dart` | ilanlarım |
| `firebase_product_repository.dart` | ürünlerim |
| `firebase_chat_repository.dart` | mesajlar + tek sohbet |

**Düzeltme:** ortak yardımcı `lib/core/utils/signout_safe_stream.dart` →
`.signOutSafe(etiket, uid)`. Sohbet deposundaki yerel kopya kaldırıldı
(tek doğruluk kaynağı).

> ⚠️ **Kural:** uid'e bağlı YENİ bir `snapshots()` eklersen `.signOutSafe()`
> çağır. Yoksa o ekran çıkışta hata verir.

Yalnız `permission-denied` yutulur. Ağ (`unavailable`) ve eksik indeks
(`failed-precondition`) **yutulmaz** — onlar gerçek arızadır, gizlenirse
kullanıcı boş ekrana bakar ve sebebini öğrenemez.

### 2. Bildirim: sessiz arıza (iki kusur)

**a) `notDetermined` durumunda token yazılıyordu.** Kod yalnız `denied`
kontrolü yapıyordu. Kullanıcı sistem izin penceresini kapattığında durum
`notDetermined` olur — token yazılıyor, Ayarlar "Bildirimler açık" diyor,
ama sistem bildirimi **hiç düşmüyordu**. Teşhisi en zor bildirim şikâyeti
budur. Artık ikisi de token yazımını engelliyor.

**b) Çıkışta token yenileme aboneliği iptal edilmiyordu.** `registerFor`
aboneliği `_tokenRefreshSub ??=` ile kuruyor. Çıkışta iptal edilmediği için
**ikinci hesapta yeniden kurulmuyordu** — o cihazda FCM token yenilendiğinde
hiçbir yere yazılmıyor ve kullanıcı sessizce bildirim almaz oluyordu.
Tanılama alanları (`_lastToken/_lastError/_lastStatus`) da sıfırlanmıyordu:
Ayarlar ekranı çıkıştan sonra eski hesabın durumunu gösteriyordu.

**Sağlam bulunanlar:** çıkış sırası doğru (token temizliği uid kaybolmadan
önce), 4 sn timeout ile ANR koruması, sunucuda geçersiz token temizliği,
manifest kanal/ikon/renk tanımları, arka plan işleyicisi, bildirime
dokununca yönlendirme.

### 3. Telefon doğrulama: sunucu tarafı zorunluluk YOKTU

Bu oturumda eklenen istemci kapısı (`ensureVerifiedPhoneForProvider`)
**atlatılabilirdi** — doğrudan SDK çağrısı yapan biri doğrulanmamış numarayla
usta/mağaza olabilirdi. `hasArtisanProfile` / `hasShopProfile` kuralda hiç
geçmiyordu.

**Düzeltme:** `firestore.rules` → `providerFlagOk()`. Bayrağı `true`ya
**çekerken** Auth jetonunda `phone_number` claim'i aranır.

Kritik ayrıntı: yalnız **açarken** aranır. Kapatma ve zaten açık profilin
diğer alanlarını güncelleme serbesttir — aksi hâlde telefonu doğrulanmamış
**mevcut ustalar profillerini hiç düzenleyemez** hâle gelirdi.

Mock depoya da aynı davranış eklendi (CLAUDE.md kural 1).

> 🚀 **DEPLOY GEREKLİ:** `firebase deploy --only firestore:rules`
> Bu yapılmadan sunucu koruması devrede değildir.

### 4. Fiyatta üst sınır yoktu

Ürün fiyatına `999999999999` yazılabiliyordu — kart düzenini bozar,
sıralamayı anlamsızlaştırır. `AppConstants.maxPriceAmount = 100.000.000 ₺`
eklendi ve doğrulayıcıya bağlandı.

### 5. Maliyet: 4 limitsiz canlı dinleyici

Limitsiz dinleyici, koleksiyon büyüdükçe **her açılışta ve her değişiklikte**
tüm dökümanları yeniden okur. Popüler bir ustanın takipçi listesi tek ekran
açılışında binlerce okuma üretebilirdi (üstelik `watchFollowers` her takipçi
için ek bir `users` okuması yapıyor).

Tavanlar: `favoritesFetchCap` · `followersFetchCap` · `blockedFetchCap` ·
`chatThreadsFetchCap` = 200.

### 6. Çift gönderim açığı (yeni kapıda)

Telefon doğrulama sayfası açıkken "Kaydet" / "Mağazayı aç" düğmeleri etkin
kalıyordu — ikinci basış ikinci bir doğrulama sayfası açardı. Usta ekranına
`_phoneGateBusy` bayrağı eklendi; mağaza ekranında `_busy` kapıdan **önce**
açılacak şekilde taşındı.

---

## ✅ Denetlenip sağlam bulunanlar

| Alan | Sonuç |
|---|---|
| Firestore kuralları | Güçlü — `phoneVerified` claim'e bağlı, sayaçlar/premium/`lockedAt` istemciye kapalı, hassas veri `private/*` altında |
| Hassas veri loglama | **Temiz** — telefon/e-posta/şifre hiçbir yerde loglanmıyor; FCM token'ın yalnız ilk 12 karakteri (kimlik değil) |
| Bellek sızıntısı | 70 controller / 125 dispose — sızıntı yok |
| Çift tıklama | 148 yerde `isLoading`/`_busy` koruması |
| Telefon girdisi | `digitsOnly` + uzunluk sınırı (numara ve SMS kodu) |
| Hata karşılama | Release'te `AppErrorFallback` (teknik stacktrace gösterilmiyor) + Crashlytics |
| App Check | Firestore/Storage ENFORCED, Play Integrity |
| İmza | `key.properties` + `.jks` gitignore'da |
| Auth dinleyicisi | `onError` korumalı, çıkışta iptal ediliyor — doğru yazılmış |

---

## ⚠️ Yayın öncesi SENİN yapman gerekenler

### 1. Kuralları deploy et (ZORUNLU)

```bash
firebase deploy --only firestore:rules --project alljob1
```

Yapılmazsa telefon doğrulama sunucu tarafında zorunlu değildir.

### 2. Firebase Console — telefon doğrulama (ZORUNLU)

Kapı artık kayıt yolunun üstünde: doğrulama çalışmazsa **hiç kimse
usta/mağaza olamaz**.

- Authentication → Sign-in method → **Phone** etkin mi?
- Authentication → Settings → **SMS region policy** → Türkiye (+90) izinli mi?
- Release SHA-256 parmak izi Firebase'e ekli mi? (Play Integrity / reCAPTCHA
  için; yoksa `verifyPhoneNumber` sessizce timeout'a düşer)

> **Gerçek cihazda uçtan uca bir telefon doğrulaması yap.** Bu adım
> atlanırsa yayın sonrası ilk şikâyet bu olur.

### 3. Keystore yedeği (EN KRİTİK)

`.jks` + `key.properties` repo dışında, şifreli iki ayrı yerde saklanmalı.
Kaybolursa uygulama **bir daha güncellenemez**. Play Console'da
**Play App Signing**'i aç.

### 4. Sürüm numarası

`pubspec.yaml` → `1.0.0+1`. İlk yayın için doğru. Her yeni yüklemede `+2`,
`+3`… olmalı — aynı versionCode ikinci kez kabul edilmez.

### 5. Play Console beyanları

Ayrıntı `docs/PLAY_STORE_YAYIN.md` içinde. Özellikle:
`ACCESS_ADSERVICES_AD_ID` (Analytics) → "Reklam kimliği kullanıyoruz"
işaretlenmeli. Konum: **il/ilçe seçimi, GPS değil**.

---

## ✅ 11 kırık test — incelendi ve kapatıldı

Tek tek doğrulandı: **hiçbiri işlev kaybı değildi.** Hepsi kaynak dosyayı
metin olarak tarayan ve yeniden yazım sonrası eskiyen testlerdi. Kod doğru,
testler yanlış yerde arıyordu. Her biri davranış iddiası korunarak
güncellendi (gevşetilerek değil):

| Test | Neden kırıktı | Gerçek durum |
|---|---|---|
| `profile_simplify` ×3 · `unified_profile` · `test_bulgulari_09` | `label: 'İlanlarım'` → `label: const Text('İlanlarım')` | Düğme ve hedef (`RoutePaths.myJobs`) yerinde |
| `profile_common_fields` ×3 | `_AvailabilitySwitch` imzası `(user:, draft:)` oldu; 2600 karakterlik pencere kaydı | Anahtar, metin ve sönük renk mantığı yerinde |
| `artisan_login` | "Usta modu" anahtarını arıyordu | Anahtar bilinçli kaldırıldı; müsaitlik anahtarı ile değiştirildi |
| `direct_contact` | `!profile.isAvailable` satır içi kontrolünü arıyordu | **Güvenlik kaybı yok** — kapı ortak `artisanAvailabilityAllowsNewChat()`'e taşınmış |
| `test_bulgulari_10` | `manualPause` kelimesinin varlığını yasaklıyordu | **Eleme yok** — `manualPause` yalnız SIRALAMA skorunda; müsait olmayan usta bildirimi alıyor |

**`otherModeUnreadProvider` şüphesi kapandı:** işlev kaybı yok. Provider
bilinçli olarak her zaman 0 döndürüyor (`chat_providers.dart` içinde
belgeli) — mod switch'i kalkınca "karşı mod" kavramı da kalktı. Okunmamış
mesaj sayacı alt bardaki Mesajlar sekmesinde `totalUnreadProvider` ile
çalışıyor. İlgili testler artık gerçek göstergeyi doğruluyor.

İki testin kapsamı bu sırada **genişletildi**: müsaitlik kapısının yalnız
çağrıldığı değil, içinin de dolu olduğu (`availability_gate.dart`); ve
bildirim fan-out'unda müsaitliğin *eleme* olarak kullanılmadığı (regex ile
`return`/`continue` deseni aranıyor).

---

## 📋 Yayını engellemeyen açık işler
- **R8/ProGuard kapalı.** APK küçültme ve kod karartma etkin değil.
  Etkinleştirmek Firebase/Riverpod için ek ProGuard kuralları ister;
  yayın öncesi test edilmemiş değişiklik risklidir. Yayın sonrası ölçülü
  şekilde açılabilir.
- **Mesaj hız sınırı sunucuda yok.** İstemcide `minMessageInterval` ve
  `maxMessagesPerMinute` var; CF tarafında yok. Kötüye kullanım büyürse
  maliyet riski.
- **Rules unit testi yok.** `@firebase/rules-unit-testing` ile iskelet
  önerilir — kural regresyonu şu an yalnız elle yakalanıyor.
- **Web App Check yok** (admin paneli web'de).

---

## 📎 Not: `docs/gemini-code-*.md` hakkında

O belge **SINIFCEPTE** adlı BAŞKA bir proje için yazılmış (öğrenci, sınıf,
not, veli telefonu, T.C. kimlik). Bu proje bir hizmet pazaryeri; oradaki
alan bazlı kurallar (sınıf/şube formatı, not sınırları, mükerrer öğrenci)
buraya **doğrudan uygulanamaz**.

Yine de içindeki genel ilkeler bu denetimde ölçüt olarak kullanıldı:
girdi temizleme, uzunluk sınırları, çift tıklama, bellek temizliği, hassas
veri loglama yasağı, yumuşak hata karşılama. Sonuçları yukarıdaki tabloda.

İki ilke bu projede **bilinçli olarak uygulanmıyor**:

- **Yerel AES-256 şifreleme:** bu uygulama hassas veriyi cihazda tutmuyor;
  telefon numarası sunucuda `users/{uid}/private/contact` altında ve yalnız
  sahibine açık. Yerel şifreli veritabanı gereksiz karmaşıklık olurdu.
- **Offline-first kuyruk:** hizmet pazaryeri canlı veriye dayanır (ilan
  durumu, teklif, mesaj). Çevrimdışı yazma kuyruğu, kullanıcıya kabul
  edilmiş sanılan ama sunucuda reddedilecek işlemler gösterirdi. Firestore'un
  kendi çevrimdışı önbelleği okuma tarafında zaten çalışıyor.

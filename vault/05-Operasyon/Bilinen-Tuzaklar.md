# Bilinen Tuzaklar

> [!danger] Kasadaki en değerli not
> Buradaki her madde **gerçekten yaşanmış** bir hatadır. Kod okuyarak
> anlaşılmayan, ancak bir kez kırılınca öğrenilen şeyler. Dokunacağın alanla
> ilgili maddeyi işe başlamadan oku.

---

## 🔴 ASLA DEĞİŞTİRİLMEYECEK sabitler

Bunlar kozmetik görünür ama değiştirmek **kullanıcı verisi kaybettirir**.

| Sabit | Dosya | Değiştirilirse |
|---|---|---|
| `kProMonthlyProductId = 'sepette_hizmet_pro_monthly'` | `membership/billing_config.dart` | Play / App Store'da ürün açıldıktan sonra **asla** değiştirilemez |
| Firestore enum `apiValue`'ları | `data/models/*.dart` | Mevcut dokümanlar eski adı taşır → veri göçü gerekir |

Görünen marka İlanda Hizmet; paket ve IAP kimliği `sepettehizmet`. Mağaza
kaydı yokken `usta_cepte_*` buraya çekildi — ürün açıldıktan sonra kilit.

---

## 🔴 Çıkışta "uygulama çöktü" — canlı dinleyiciler

**Yaşanan belirti:** kullanıcı çıkış yapıyor, ekranlar hata görünümüne
düşüyor, "uygulama durdu" deniyor. Oysa hiçbir şey bozulmamıştır.

**Sebep:** `users/{uid}/...` kapsamlı bir `snapshots()` dinleyicisi, çıkış
anında bir an **eski uid** ile canlı kalır. Auth oturumu düşürdüğü an
güvenlik kuralı onu tanımaz → akışa `permission-denied` **hatası** yayılır →
Riverpod `AsyncError` → ekran hata görünümü.

**Kural:** uid'e (veya chatId'ye) bağlı YENİ bir `snapshots()` eklersen
sonuna `.signOutSafe('etiket', uid)` koy.

```dart
// lib/core/utils/signout_safe_stream.dart
return _col(uid).snapshots().map(...).signOutSafe('bildirimler', uid);
```

> Yalnız `permission-denied` yutulur. Ağ (`unavailable`) ve eksik indeks
> (`failed-precondition`) **yutulmamalı** — onlar gerçek arızadır; yutulursa
> kullanıcı boş ekrana bakar ve sebebini asla öğrenemez.

2026-08-14 denetiminde 10 dinleyici korumasız bulundu (bildirimler,
tercihler, favoriler, takipçiler, engellenenler, ilanlarım, ürünlerim,
mesajlar, sohbet). Sözleşme testi:
`test/yayin_hazirlik_denetimi_test.dart`.

---

## 🔴 Bildirim sessizce çalışmayı bırakır

İki gerçek kusur (2026-08-14'te düzeltildi) — ikisi de **hata vermeden**
bildirimleri kesiyordu:

1. **`notDetermined` ≠ izin var.** `requestPermission()` yalnız `denied`
   diye kontrol edilirse, kullanıcı sistem penceresini kapattığında durum
   `notDetermined` olur: token yazılır, Ayarlar "Bildirimler açık" der, ama
   sistem bildirimi **hiç düşmez**. İkisini de kontrol et.
2. **Çıkışta `_tokenRefreshSub` iptal edilmeli.** `registerFor` aboneliği
   `??=` ile kurar; çıkışta iptal edilmezse **ikinci hesapta yeniden
   kurulmaz** ve token yenilendiğinde hiçbir yere yazılmaz.

Ayrıca çıkışta `_lastToken/_lastError/_lastStatus` sıfırlanmazsa Ayarlar
ekranı yeni kullanıcıya **eski hesabın** durumunu gösterir.

---

## 🟠 Sağlayıcı olmak doğrulanmış telefon ister

`hasArtisanProfile` / `hasShopProfile` bayrağını `true`ya çekmek, Auth
jetonunda `phone_number` claim'i ister (`firestore.rules` →
`providerFlagOk`). İstemci kapısı
(`features/auth/application/provider_phone_gate.dart`) tek başına yeterli
**değildir** — atlatılabilir.

> Kural yalnız **AÇARKEN** arar. Kapatma ve zaten açık profilin diğer
> alanlarını güncelleme serbest olmalı; aksi hâlde telefonu doğrulanmamış
> mevcut ustalar profillerini hiç düzenleyemez.

### 🔴 Kapının DÖRT girişi var — biri unutulursa "Bir hata oluştu"

2026-08-15 cihaz bulgusu: *"Hizmet vermeye başla"* → kırmızı şerit
**"Bir hata oluştu, lütfen tekrar deneyin"**. Tekrar denemek çözmüyor,
sebep de görünmüyor.

Sağlayıcı bayrağını açan **dört** giriş vardır:

| Giriş | Dosya |
|---|---|
| Usta profili düzenleme | `artisan_profile_edit_screen.dart` |
| Mağaza kurulumu | `shop_setup_screen.dart` |
| Profil > Usta sekmesi | `profile_screen.dart` → `_becomeArtisan` |
| Yan menü | `app_menu_drawer.dart` → `_becomeArtisan` |

İlk ikisinde kapı vardı, **son ikisinde yoktu**. `becomeArtisan()` doğrudan
`hasArtisanProfile: true` yazıyor, kural reddediyor, hata
`AsyncValue.guard` içinde yutulup "bilinmeyen hata"ya düşüyordu.

> [!warning] Sunucu kuralını deploy etmeden önce İSTEMCİ kapılarını say
> Kural çalışma ağacında commit'lenmemiş bekliyordu; deploy edilince düğme
> ilk kez kurala çarptı. **Yeni bir sunucu kısıtı canlıya alınırken, o
> kısıta çarpan tüm istemci yollarının kapısı olduğu doğrulanmalıdır.**

İki koruma eklendi: kapı dört girişte de var **ve**
`becomeArtisan` `permission-denied`'i ne yapılacağını söyleyen Türkçe
mesaja çeviriyor (ham hata bir daha "bilinmeyen"e düşmesin).

> [!info] 2026-08-18: TELEFON KAPISI KALDIRILDI
> SMS doğrulaması tamamen kaldırıldı — `provider_phone_gate.dart`,
> `phone_verification_*` ve `verification_tile.dart` **silindi**;
> `firestore.rules` içindeki `providerFlagOk` / `phoneClaimOkFor` /
> `verifiedClaimOk` kapıları da gitti. Usta/mağaza olmak artık doğrulama
> istemez.
>
> Yukarıdaki "dört giriş" tablosu **hâlâ geçerli**: sağlayıcı bayrağını
> açan yollar bunlar. Kapı değil ama yeni bir kısıt eklenirse yine
> dördünde birden düşünülmeli.
>
> Kalkarken alınan önlem: `isVerified` (mavi tik) istemciye **kapatıldı**
> — kapı kalkınca herkes kendine rozet verebilirdi. Rozet artık yalnız
> admin/CF (`adminVerified`) tarafından verilir.
>
> Regresyon: `test/saglayici_telefon_kapisi_test.dart` → "SMS doğrulama ·
> tamamen kaldırıldı".

---

## 🟠 Müsaitlik: satıcı kapalıysa vitrini de kapalı

"Müsait değil" yalnız mesajı değil **görünürlüğü** de etkiler. Kapalı bir
satıcının ürünü listede durursa müşteri ilgilenir ama yazamaz — ölü ilan.

| Yer | Davranış |
|---|---|
| Keşfet ürün ızgarası | `availableDiscoverProductsProvider` eler |
| Mağaza vitrini (profil) | `dukkan_bolumu.dart` gizler |
| Ürün talepleri (Keşfet) | mağazası/müsaitliği olmayan sınırlı görür |
| **Kendi ürünlerim** | **her zaman görünür** — sahibi "silindi" sanmasın |

İki kural:

1. **Sahibi hariç tut.** Kendi ürünü/vitrini kaybolan satıcı hata sanır.
2. **Satıcı yüklenmeden gizleme.** `satici == null` iken göster; yükleme
   sırasında liste boşalıp dolarsa titreme olur.

> Süzme **istemci tarafında**: müsaitlik sık değişir, her açma/kapamada
> 50 ürüne CF yazmak fatura ve gecikme demekti. Maliyet ürün başına değil
> **benzersiz satıcı** başına bir okuma (`publicUserProvider` önbellekli).
> Doğrudan rotayla detaya ulaşan yine mesaj atamaz — asıl kapı
> `availability_gate.dart`.

---

## 🟠 Fotoğraf: kırpma ZORUNLU, oranlar eşleşmeli

**Yaşanan belirti:** "resimler yarım çıkıyor", "profil fotoğrafı yayık".

**Sebep:** kırpma adımı yoktu; kart `AspectRatio` + `BoxFit.cover` ile
kullanıcının fotoğrafını zorla kesiyordu.

**İki kural:**

1. **Yeni foto yükleme yeri = `PhotoPicker` kullan.**
   ```dart
   final bytes = await PhotoPicker.pickPhoto(context,
       source: source, shape: PhotoShape.portrait);
   ```
   Doğrudan `ImagePicker().pickImage()` çağırırsan kırpma atlanır.

2. **Kırpma oranı ile kart oranı AYNI olmalı.** Kırpma 4:5 ama kart 1.15
   ise kırpma hiçbir şey çözmez — kart yine keser. İkisi de
   `AppConstants.photoAspectWidth/Height` sabitinden okumalı.

| Yer | Şekil |
|---|---|
| Profil fotoğrafı | `square` (1:1 kilitli — avatar yuvarlak) |
| Ürün / ilan / vitrin | `portrait` (4:5) |
| Sertifika / belge | `free` (zorunlu oran metni keser) |
| Sohbet fotoğrafı | kırpma YOK (bilinçli — WhatsApp da dayatmaz) |

Android'de `UCropActivity` manifest'te kayıtlı olmalı; yoksa kırpıcı
açılmaz ve fotoğraf sessizce kırpılmadan yüklenir.

---

## 🔴 `phoneNumber` Firestore'da DEĞİL, Auth'ta

Hassas numara kural gereği `users/{uid}` dokümanına **yazılamaz**
(`notSettingPublicPii`). Sunucu kaydı `users/{uid}/private/contact`
altındadır ama orası **okunmuyor**.

`AppUser.phoneNumber` değerini **Firebase Auth'tan** al:

```dart
phoneNumber: fbUser.phoneNumber,   // link/updatePhoneNumber sonrası dolu
```

2026-08-14'te bu eksikti: numara yalnız doğrulama ANINDA bellekte
doluyordu, uygulama yeniden açılınca kayboluyordu ve "telefonumu profilde
göster" anahtarı *"Telefon numarası bulunamadı"* hatası veriyordu.

> Numarayı `users` dokümanına taşıyarak çözme — orası herkese açık okunur
> ve Firestore alan bazlı gizleme yapamaz. Kullanıcının **yayınlamayı
> seçtiği** numara ayrı bir alandır: `publicPhone`.

**Üç ayrı alan, karıştırma:**

| Alan | Yer | Kim görür |
|---|---|---|
| `phoneNumber` | Firebase Auth (+ `private/contact` kaydı) | yalnız sahibi |
| `publicPhone` | `users/{uid}` | herkes (kullanıcı bilerek yayınladı) |
| `showPhoneOnProfile` | `artisanProfiles/{uid}` | vitrin anahtarı |

---

## 🟠 Aynı adlı alan İKİ dokümanda olabilir

`publicPhone` hem `users/{uid}` hem `artisanProfiles/{uid}` içinde var.
2026-08-14'te `setPhoneVisibility` yalnız ikincisine yazıyordu, profil
başlığı ise **birincisini** okuyordu → "göster" işaretlense de numara
görünmüyordu.

> Bir alanı yazarken **okuyan tarafın hangi dokümana baktığını** doğrula.
> Ayrıca mağaza sahibinin `artisanProfiles` dokümanı **olmayabilir**:
> `if (!snap.exists) return` ile başlayan yazımlar onları sessizce atlar.

---

## 🔴 Play token doğrulaması ≠ token sahipliği

`verifyPlaySubscription` **"bu abonelik aktif mi?"** sorusunu yanıtlar.
**"Bu aboneliği çağıran kişi mi aldı?"** sorusunu YANITLAMAZ.

2026-08-15 denetiminde bulundu: `grantArtisanPremium` `tokenHash`'i
hesaplayıp `membershipPurchases/{uid}` içine yazıyordu ama **hiçbir yerde
okumuyordu**. Doküman anahtarı `uid` olduğu için aynı `purchaseToken` ile
farklı hesaplardan çağrı yapmak sınırsız premium veriyordu — tek ödeme,
sınırsız hesap. Doğrudan gelir kaybı.

**Kural:** token hash'i **sahibiyle** ayrı bir dokümanda tutulur
(`membershipTokens/{hash}` → `{uid}`) ve yazım `runTransaction` içindedir
(iki eşzamanlı istek yarıştırılamasın). Farklı uid gelirse
`permission-denied`.

> Hesap silmede bu kayıt da silinmelidir: uid taşır (KVKK) **ve** kalırsa
> kullanıcı hesabını silip yeniden açtığında kendi aboneliği "başkasına ait"
> diye reddedilir.

Regresyon: `test/yayin_hazirlik_denetimi_test.dart` → "Üyelik · satın alma
token'ı tekrar kullanılamaz".

---

## 🔴 "Cannot determine backend specification. Timeout after 10000"

**Belirti:** `firebase deploy --only functions` şu hatayla düşer:

```
Error: User code failed to load. Cannot determine backend specification.
Timeout after 10000.
```

**Sebep:** Firebase CLI, hangi fonksiyonların var olduğunu öğrenmek için
`index.js`'i **çalıştırır**. Bu adımın **10 saniyelik sabit** bütçesi vardır
ve modül tepesindeki her `require` bu bütçeden yer.

Suçlu genelde tek bir ağır paket olur. 2026-08-15'te `googleapis`
(**110 MB**, ~1 sn) modül tepesinde yükleniyordu — üstelik ona yalnız
`verifyMembershipPurchase` ihtiyaç duyuyordu. Aynı maliyet **tüm**
fonksiyonların soğuk başlangıcına da biniyordu.

**Çözüm — tembel (lazy) require + önbellek:**

```javascript
let _androidPublisher = null;              // modül tepesinde YALNIZ değişken
async function getAndroidPublisherClient() {
  if (_androidPublisher) return _androidPublisher;
  const {google} = require("googleapis");  // ← ilk çağrıda yüklenir
  ...
}
```

Ölçüm: modül yüklemesi **1551 ms → 566 ms**.

> [!tip] Önce ölç, sonra suçlu ara
> ```bash
> cd functions
> node -e "const t=Date.now(); require('./index.js'); console.log(Date.now()-t)"
> ```
> Hata veren kod değil, **yavaş** koddur. Yükleme yerelde 1 sn sürüyorsa
> soğuk deploy makinesinde 10 sn'yi bulabilir.

Başka olası sebepler (bu sırayla bak):
1. Modül tepesinde ağır `require` (yukarıdaki) — en sık.
2. Modül tepesinde `await`/ağ çağrısı (Firestore okuması, secret çekme).
3. `node_modules` eksik/bozuk → `npm ci --prefix functions`.
4. `engines.node` ile yerel Node sürümü uyuşmazlığı.

Sözleşme testi: `test/yayin_hazirlik_denetimi_test.dart` → "ağır paketler
modül tepesinde require EDİLMİYOR".

---

## 🔴 App Check web'de ALAN ADINA bağlıdır — panel kilitlenir

**Yaşanan (2026-08-15):** Admin callable'larına `enforceAppCheck: true`
eklendi, deploy edildi, panel **anında erişilemez** oldu:

```
Yönetici erişimi etkinleştirilemedi (unauthenticated).
```

**Sebep:** reCAPTCHA v3 anahtarı yalnız `alljob1.web.app`,
`alljob1.firebaseapp.com` ve `localhost` için kayıtlıydı. Panel ise **özel
alan adından** (`admin.ilandahizmet.com`) açılıyor. Kayıtlı olmayan alanda
reCAPTCHA jeton üretmez → App Check jetonu yok → her çağrı `unauthenticated`.

> [!danger] Kod tek başına yetmez
> `enforceAppCheck: true` yazmak kolay; asıl iş **reCAPTCHA yönetim
> panelinde alan adını kaydetmektir**. Kayıt yoksa kod doğru olsa da panel
> kilitlenir ve geri almak için yeniden deploy gerekir.

**Açma sırası:**
1. `google.com/recaptcha/admin` → v3 anahtarına `admin.ilandahizmet.com` ekle
2. Firebase Console → App Check → web kaydını doğrula
3. Panelden işlem yap, metriklerde "doğrulanmış" istek gör (MONITOR modu)
4. **Ancak o zaman** `ADMIN_CALL_OPTS`'a `enforceAppCheck: true` ekle

Yetki kaybı yoktur: `assertCap` / `assertSuperadmin` kapıları zaten
çalışıyor. App Check ek katmandır, tek başına yetki sınırı değildir.

Sözleşme testi: `test/yayin_hazirlik_denetimi_test.dart` → admin
callable'ları tek sabitten beslenmeli (açma anında biri atlanmasın).

---

## 🔴 Kural motoru transaction yapamaz — sayaç limitleri yarışır

`firestore.rules` içindeki `openJobQuotaOk()` "aynı anda 5 açık ilan"
kısıtını denormalize sayaçtan (`jobStats.openCount`) okur. Ama sayacı
`onJobCreated` ilan yazıldıktan **sonra** tazeler. Arka arkaya gönderilen
istekler aynı eski değeri okur ve **hepsi kuraldan geçer** (TOCTOU).

Kural motorunda `count()` de transaction da yoktur; tek atomik yer Cloud
Function'dır. 2026-08-15'te eşzamanlılık kapısı `onJobCreated` içindeki
günlük limit transaction'ına eklendi (`openReserved` rezervasyon sayacı).

> [!warning] Rezervasyon damgası SAYISAL olmalı
> `jobStats.updatedAtMs` yazılmazsa rezervasyon hep "taze" sayılır ve limit
> yanlış tarafa kayar. ISO dizesi karşılaştırması kırılgandır.

**Genel kural:** kuralda okunan bir sayaç CF tarafından *sonradan*
yazılıyorsa, o limit tek başına kuralla uygulanamaz.

---

## 🔴 `debugPrint` release'te de yazar

Adı yanıltıcıdır: `debugPrint` yalnız **profile** modunda susar, release'te
`logcat`'e yazmaya devam eder. 2026-08-15 denetiminde 40 çağrı uid, chatId
ve FCM token öneki basıyordu.

Tanılama satırı için `AppLog.d()` kullan (`lib/core/utils/app_log.dart`) —
gövdesi `kDebugMode` ile sarılıdır. Sözleşme testi doğrudan `debugPrint`
kullanımını yakalar; istisnalar `main.dart` / `main_admin.dart`.

> Kullanıcının görmesi gereken arıza `context.showError(...)`, geliştiricinin
> canlıda görmesi gereken arıza Crashlytics'tir — ikisi de günlük değildir.

---

## 🟠 PowerShell dosyayı yeniden kodlar — UTF-8 kaynağa DOKUNMA

`Get-Content -Raw` + `Set-Content -Encoding utf8` zinciri, zaten UTF-8 olan
bir dosyayı **ikinci kez** kodlar: `ı` → `Ä±`, `—` → `â€"`. 2026-08-15'te
`functions/index.js` bu şekilde 1150 yerden bozuldu; üstüne BOM da eklendi.

**Kural:** Türkçe içeren kaynak dosyalarda toplu değişiklik için PowerShell
kullanma. `Edit` aracı ya da Node (`fs.readFileSync/writeFileSync`) baytları
korur.

> Bozulma geri alınabilir (bilgi kaybı yok): her karakter bir cp1252 baytıdır,
> tabloyla bayta çevrilip yeniden UTF-8 okunur. Ama BOM ve emoji (`👤` →
> `ğŸ‘¤`) elle ele alınmalıdır.

---

## 🟠 `git stash` çalışma ağacındaki BAŞKA işi de alır

`git stash push -- dosya` yalnız o dosyayı alır ama **tüm** değişikliklerini
alır — sizin bu oturumda yazdıklarınızı da, önceki oturumlardan kalan
commit'lenmemiş işi de. 2026-08-15'te bir kodlama hatasını geri almak için
kullanıldı ve ~350 satırlık commit'lenmemiş CF işi (fan-out toplu okuma,
ürün talebi bildirimleri) birlikte gitti; testler yakaladı.

> Düşürülen stash bile kurtarılabilir: `git stash drop` çıktısındaki SHA ile
> `git show <sha>:yol`. Ama en iyisi stash'ten önce commit almaktır.

---

## 🟠 Firestore kuralları

### `.get()` olmadan claim okuma her şeyi çökertir
```javascript
request.auth.token.suspended          // ❌ claim yoksa "undefined" hatası
request.auth.token.get('suspended', false)  // ✅
```
Hata tüm `create` kurallarını reddeder — ilan, teklif, mesaj, yorum topluca
çöker. Belirti: her yerde `permission-denied`.

### Filtresiz sorgu komple reddedilir
Kural `customerId == auth.uid` istiyorsa sorgu o filtreyi **taşımalıdır**:
```dart
.where('jobId', isEqualTo: jobId)
.where('customerId', isEqualTo: uid)   // ← kural ispatı, süs değil
```

### 🔴 `toMap()` → Firestore: sunucuya ait alanları ÇIKAR

Model `toMap()`'i **tüm** alanları üretir; bunların bir kısmını istemci
yazamaz. Yazımdan çıkarılmazsa kural **tüm kaydı** reddeder — tek bir alan
yüzünden hiçbir değişiklik kaydedilmez.

İki ayrı grup var (`artisanProfiles` örneği):

| Grup | Alanlar | Neden |
|---|---|---|
| Sayaç / premium / moderasyon | `averageRating`, `totalReviews`, `totalRatingSum`, `topTags`, `completedJobs`, `isPremium`, `premiumExpiresAt` | Yalnız CF yazar (kural 3) |
| **Doğrulama aynaları** | `isVerified`, `emailVerified` | Kural bunları **Auth token'ıyla** karşılaştırır |

İkinci grup sinsi: `verifiedClaimOk()` / `emailVerifiedMirrorOk()` alanın
`true` olmasını token'daki `phone_number` / `email_verified` ile eşleştirir.
Profilde `true` yazılı ama token'da karşılığı yoksa **kayıt reddedilir** —
üstelik kullanıcı o alana hiç dokunmamıştır.

**Gerçek vaka (B-04):** Usta profili hiç kaydedilemiyordu. Hata
`AsyncValue.guard` içinde yutulduğu için sebep de görünmüyordu; ekran
"Kaydetme başarısız" diyordu. `saveMyProfile` bu iki aynayı `remove()`
etmiyordu.

**Kural:** Yeni bir alan `toMap()`'e eklenirken sor — *"bunu istemci yazabilir
mi?"* Yazamıyorsa repository'de `..remove('alan')` ekle.
Regresyon: `test/profile_save_fields_test.dart`.

### Doküman yokken `get()`
`resource == null` dalı yoksa `startChat`'in var-mı kontrolü
`permission-denied` alır ve **sohbet hiç oluşmaz**. Alt koleksiyonlarda önce
`exists(path)` kontrol et — yoksa `get().data` kural motorunu hataya düşürür.

→ [[Guvenlik-Kurallari]]

---

## 🟠 Riverpod / async yarışlar

### `ref.read(...).valueOrNull` stream hazır olmadan `null` döner
```dart
final job = ref.read(jobProvider(id)).valueOrNull;   // ❌ ilk karede null
final job = await ref.read(jobProvider(id).future);  // ✅ bekler
```

**Gerçek vaka:** Değerlendirme ekranı müşteri uid'ini böyle okuyordu; `null`
gelince "önce sohbet gerekiyor" deyip kullanıcıyı geri çeviriyordu. Ekran hiç
açılmıyordu. → [[Degerlendirme-Sistemi]]

### Bellek önbelleği derin bağlantıda boştur
`getThread()` / `hasChatBetween()` **yalnız bellekteki** sohbetlere bakar.
Kullanıcı sohbet listesine hiç girmediyse önbellek boştur ve bunlar
yanlışlıkla "sohbet yok" der.

| İhtiyaç | Kullan |
|---|---|
| Canlı izleme (ekran) | `watchThread(chatId)` |
| Tek seferlik sunucu okuması | `fetchThread(chatId)` |
| Yalnız önbellek (liste açıkken) | `getThread(chatId)` |

### 🔴 Çıkış/oturum akışında `await` = ANR riski

`signOut` gibi UI'yı bekleten akışlarda **süre sınırsız ağ çağrısı olmamalı**.
Firestore yazımları çevrimdışıyken kuyrukta askıda kalır (hata da vermez);
ana iş parçacığı beklerse Android **"yanıt vermiyor"** uyarısı verir.

Bu gerçek bir hataydı (B-17): `signOut` → `unregisterFor` zinciri art arda
**4 ağ çağrısı** yapıyor, hiçbirinde timeout yoktu.

**Kural:** Oturum kapanışındaki temizlik işleri *en iyi çaba*dır — başarısız
olsalar da akış tamamlanmalı. `push_service.unregisterFor` deseni:

```dart
await _unregisterBody(uid).timeout(_unregisterTimeout);  // 4 sn
// aşılırsa: logla, ÇIKIŞA DEVAM ET
```

> Geliştirici makinesinde hızlı ağla **hiç görünmez**; yalnız gerçek cihazda
> ve kötü bağlantıda ortaya çıkar.

### Oturum kapanışında `permission-denied` BEKLENEN durumdur

Hesap değişiminde eski uid'e ait canlı `snapshots()` dinleyicileri bir an
reddedilir — kural artık o uid'i tanımaz. Bu bir hata değil, normal yaşam
döngüsü. Yakalanmazsa debugger durur / UI hata durumuna düşer.

uid'e bağlı stream'lerde:
```dart
.handleError((e) => debugPrint(…), test: _isPermissionDenied)
```

> Kod tabanında **36 `snapshots()`** var; B-17'de yalnız uid'e doğrudan bağlı
> ikisine (`watchUnreadMeta`, `watchThreads`) eklendi. Yeni uid-bağlı stream
> yazarken bunu unutma.

---

## 🔴 Sohbet & iş akışı — bu oturumda düzeltilenler

### `customerStarted` işi verirken yazılmalı
Müşteri sohbete hiç yazmadan doğrudan "Bu Ustayı Seç" diyebilir. Bayrak
`false` kalıyordu ve **seçilen usta kendi işinin sohbetinde yazamıyordu** —
kullanıcı bunu "mesaj yazma izniniz yok" olarak görüyordu.

Çözüm: `selectArtisanForJob` içinde `markCustomerStarted(chatId)`.
İşi vermek, iletişimi başlatmaktan güçlü bir niyettir.

### `jobByChatIdProvider` ilan bazlı sohbette güvenilmez
İlanın `chatId` **alanını** sorgular; o alan yalnız `selectOffer` içinde
yazılır. Eşleşmezse `job == null` → "Değerlendir" şeridi **hiç çizilmez**,
kullanıcı değerlendirmeye ulaşamaz.

```dart
thread.jobId → jobProvider(jobId)     // ✅ ilan bazlı sohbette
jobByChatIdProvider(chatId)           // yalnız genel sohbetlerde yedek
```

### `rated` durumu unutulursa karşılıklı değerlendirme kopar
İlk taraf puan verince `markRated` ilanı `rated` yapar. Şerit yalnız
`completed` arıyorsa **ikinci taraf için tam o anda kaybolur** ve karşılıklı
değerlendirme hiçbir zaman tamamlanamaz.

```dart
if (job.status == JobStatus.completed || job.status == JobStatus.rated)
```

> [!note] Geriye dönük etki
> Bu düzeltmeler yeni akışlar için çalışır. `customerStarted: false` takılı
> kalmış **mevcut** sohbetler kendiliğinden düzelmez — müşteri o sohbete bir
> mesaj yazınca açılırlar. Toplu düzeltme için tek seferlik CF migration
> gerekir.

---

## 🟡 Navigasyon

### Rota sırası
`/jobs/new`, `/jobs/mine`, `/jobs/quick` mutlaka `/jobs/:jobId`'den **önce**
tanımlanmalı — yoksa `:jobId` "new" dizesini ilan kimliği sanar. Aynısı
`/products` için de geçerli.

### `ResponsiveCenter` / `Align` yasak bölgeleri
`bottomNavigationBar` ve bazı form alanlarında kullanılamaz — `Align`
sonsuz yükseklik talep edip düzeni bozar. İlgili yerlerde kod yorumu var
(`create_job_screen.dart:243`, `track_edit_screen.dart:527`).

---

## 🟡 Cloud Functions

### Döngü güvenliği
`onJobWritten` kendi yazdığı alanla **tekrar tetiklenir**. Yeni yazım
eklerken koşulla ele (`if (!after.completedAt)` gibi), yoksa sonsuz döngü ve
fatura.

### Batch 500'de dolar
Döngüler 450'de bir commit'ler. Teklif sayısı yüksek ilanlarda şart.

### Idempotanlık damgası
Zamanlanmış görevler işlediklerini damgalar (`chatsArchivedAt`,
`autoCompleteRemindedAt`). Yeni zamanlanmış görev yazarken aynısını yap.

### 🟡 "CF çalışmıyor, log boş" — önce tetikleyiciye bak
Bir CF hata vermeden hiç ateşlenmiyorsa, çoğu zaman **onu tetikleyen durum
geçişi artık üretilmiyordur**. Log'un boş olması CF'in bozuk olduğu
anlamına gelmez.

Bu tam olarak 2026-08-08'de yaşandı: iş akışı UI'dan kaldırılınca
`autoCompleteJobs`, `remindJobAutoComplete`, `onOfferWritten`,
`archiveCompletedChats` ve `onJobWritten`'ın 3 dalı sessizce ölü kaldı —
bir gün sonra silindiler. → [[Is-Akisi-Durum-Makinesi]]

Bugün `jobs` üstünde üretilen tek geçişler: ilan doğar (`open`), süresi
dolar (`expired`), sahibi kaldırır (`cancelled`).

---

## 🟡 Ortam & derleme

### Firebase deploy — IPv4/IPv6
Deploy ağ hataları uç noktaya göre IPv4 **ya da** IPv6 ister. Önce
`NODE_OPTIONS` olmadan dene; hataya göre seç. "service identity" hatası
görürsen `NODE_OPTIONS`'u **kaldır**.

### Android JDK 17
AR paketi Java 17 toolchain ister. `gradle.properties` içinde makineye özel
yolla tanımlı. "languageVersion=17 matching" hatası → JDK 17 yolunu kontrol et.

### `firebase_options.dart` iOS appId
~~iOS `appId` hâlâ eski kayda ait.~~ **ÇÖZÜLDÜ** (2026-08-15 denetimi):
`iosBundleId` artık `com.sepettehizmet.app` ve iOS `appId` alljob1 projesinin
kendi kaydı. Paket kimliği bir daha değişirse burası yeniden üretilmelidir.

### 🔴 `<queries>` olmadan hiçbir harici bağlantı açılmaz (Android 11+)
API 30'dan itibaren paket görünürlüğü kısıtlıdır. `AndroidManifest.xml`
içindeki `<queries>` bloğunda `VIEW`/`https` beyanı **yoksa**
`canLaunchUrl` false döner ve `launchUrl` **sessizce** başarısız olur —
istisna da yoktur, kullanıcı düğmenin "çalışmadığını" görür.

`url_launcher` eklentisi bu bloğu kendi manifest'inde **taşımaz** (yalnız
örnek uygulamasında vardır); tanımlamak uygulamanın sorumluluğudur.
Yeni bir şema kullanacaksan (`tel:`, `mailto:`, özel şema) manifest'e onu da
ekle. Sözleşme testi: `test/yayin_hazirlik_denetimi_test.dart`.

→ [[Deploy-ve-Ortam]]

---

## 🟡 Mock/Firebase paritesi

Arayüze metot eklerken **her iki uygulamayı da** yaz. Mock'u boş bırakmak
testleri sessizce yanıltır: test geçer, canlı çöker.

Mock, **kuralların davranışını da** taklit etmelidir. Örnek: `MockChatRepository`
içinde usta mesajı `customerStarted` açmaz — çünkü Firestore kuralı da açmaz.

→ [[Repository-Deseni]]

---

## 🟡 `isAvailable` bir Firestore alanı DEĞİL

`ArtisanProfile.isAvailable` **hesaplanan** bir getter'dır; Firestore'da öyle
bir alan yoktur. Sırayla bakar:

1. **Premium erişimi** (`hasPremiumAccess`) — yoksa müsait değil
2. `manualPause` — açıksa müsait değil
3. `alwaysAvailable` → açıksa müsait
4. `weeklySchedule.isOpenAt(now)`

Bunun iki sonucu var:

- **"Tüm ustaların müsaitliğini kapat" bir toplu yazma değildir.** Ücretsiz
  dönem bayrağını (`premiumFreeDuringBeta`) kapatmak yeter — premium olmayan
  herkes aynı anda müsait olmaktan çıkar, hiçbir doküman yazılmaz ve bayrak
  geri açılırsa herkes eski hâline döner. Toplu yazma
  (`adminBulkPlanUpdate`) son çaredir; geri alınamaz.
- **Müsaitlik sunucuda zorlanmaz.** `isAvailableAt` yalnız istemcide çalışır;
  Cloud Functions bu hesabı yapmaz. Filtre listeleme/sıralama içindir, güvenlik
  sınırı değildir. Gerçek yetki kapıları `firestore.rules` ve CF'lerdedir.

> [!warning] Bir "an" alan hesaplar `now`'u AŞAĞI taşımalı
> `isAvailableAt(now)` içindeki premium kontrolü de aynı `now`'u kullanır
> (`hasActivePremiumAt`). Eskiden `DateTime.now()` çağırıyordu: tek çağrı
> içinde iki zaman kaynağı olduğu için sabit tarihli testler ve geçmiş/gelecek
> hesapları tutarsızlaşıyordu.

→ [[Degerlendirme-Sistemi]] · [[Admin-Paneli]]

## Donmuş kopyaya geri düşme — "kaydetmiyor" bulgusunun kaynağı

Ortak profil alanları (telefon / sosyal medya / hakkımda) 2026-08-08'de
`users/{uid}` altına taşındı. `artisanProfiles`'taki kopya **okunmaya devam
ediyor ama artık YAZILMIYOR** — yani donmuş durumda.

Okuma tarafı şöyleydi:

```dart
// YANLIŞ — boşluğu her durumda "veri yok" sayar
socialLinks: user.socialLinks.hasAny ? user.socialLinks : profile.socialLinks,
```

Kullanıcı bağlantısını **silince** `users` boşalır, koşul donmuş kopyaya
düşer ve silinen değer geri gelir. Kullanıcıya bu "kaydetmiyor" gibi görünür;
oysa yazma doğrudur, hata geri okumadadır.

> [!warning] "Alan YOK" ile "alan var ama BOŞ" aynı şey değildir
> Göç dönemindeki her geri düşmede bu ayrım gerekir. Firestore'da bilgi
> alanın **varlığındadır** (`map.containsKey`); modele ulaştığında
> `?? ''`/`?? null` ile düzleştirilirse ayrım **kaybolur**.
> `AppUser.ortakAlanlarGocmus` bunu taşır: alanlardan biri bile varsa kayıt
> göç etmiştir, sonrasında boşluk "kullanıcı sildi" demektir.

İki ek tuzak aynı yerde:
- **Bayrağı `copyWith` taşımalı.** Taşınmazsa her çağrıda `false`'a düşer —
  sayaçlardaki (B-19) tuzağın aynısı.
- **`copyWith(publicPhone: null)` "değiştirme" demektir.** Temizlemek için
  `clearPublicPhone` bayrağı şart, yoksa silinen numara geri gelir.

Regresyon: `test/sosyal_medya_silme_test.dart` (silinen geri gelmemeli **ve**
göç etmemiş kayıt hâlâ geri düşmeli).

## Rozet sayacı: yazan CF, düşüren istemci

Okunmamış rozeti `users/{uid}/private/chatMeta` içindeki **tek dökümanlık**
sayaçtır (tüm sohbet listesini dinlememek için). Üç ayrı yazar vardır ve
üçü de aynı birimi kullanmak zorundadır:

| Kim | Ne zaman | Ne yapar |
|---|---|---|
| `bumpChatUnreadMeta` (CF) | her yeni mesaj | sohbet başına **bir kez** +1 |
| `markRead` (istemci) | sohbet açılınca | −1 |
| `_healUnreadMeta` (istemci) | sohbet listesi açıkken | listeden yeniden hesap |

> [!warning] Birim: SOHBET adedi, mesaj adedi DEĞİL
> Tek sohbetteki 3 okunmamış mesaj rozete **1** yazar. `unreadCount` thread
> başına 0/1 döner. Mock'ta `unreadCount` gerçek mesaj adedini verir, bu
> yüzden `_unreadMetaFor` orada **1'e sıkıştırır** — yoksa mock "3", canlı
> "1" derdi.

> [!warning] `markRead` önbelleğe güvenemez
> `_lastMsgMeta` / `_threads` yalnız `watchThreads` tarafından doldurulur.
> **Bildirimden doğrudan sohbete girmek** en sık akıştır ve orada sohbet
> listesi hiç açılmaz → önbellek boş → `unreadCount` 0 → düşürme atlanır ve
> CF'in +1'i takılı kalır. Önbellek soğuksa sohbet dökümanı okunmalıdır
> (`lastMessageSenderUid`).

Regresyon: `test/test_bulgulari_2026_08_10_test.dart`.

## `BulkWriter.update` olmayan dokümanda PATLAR

`update()` var olmayan bir dokümanda **NOT_FOUND** fırlatır (`set(...,
{merge:true})` fırlatmaz). BulkWriter'ın varsayılan işleyicisi yalnız
UNAVAILABLE/ABORTED'ı yeniden dener; NOT_FOUND yutulmaz ve hata
`await writer.close()` üzerinden **çağıran fonksiyona** çıkar.

`deleteAccount` bunu 2026-08-10'da yaşadı: anonimleştirme adımları
(`supportTickets`, `reports`) çoğu kullanıcıda hiç doküman bulamıyor,
NOT_FOUND `close()`tan çıkıyor ve **Auth kaydı silinmeden** fonksiyon
düşüyordu. Kullanıcı "hesabım silinmiyor" diyordu; istemci ise `internal`
kodunu "Güvenlik doğrulaması geçilemedi" diye çevirdiği için herkes App
Check'i suçluyordu.

> [!warning] Temizlik ile ön koşulu ayır
> Bir adım **temizlikse** (anonimleştirme, sayaç, log) hatası ana işlemi
> DÜŞÜRMEMELİ — `try/catch` + `logger.warn`. Ön koşulsa düşürmeli. Silme
> akışında anonimleştirme temizliktir: kaybolan tek şey bir isim maskesidir,
> ama hesabın silinmemesi KVKK talebini karşılıksız bırakır.

Üç koruma birlikte durur: `onWriteError` NOT_FOUND'u yutar · `close()`
try/catch içindedir · Auth kaydı zaten yoksa (yarıda kalmış önceki deneme)
başarı sayılır. Regresyon: `test/hesap_silme_kapsami_test.dart`.

---

## 🟠 Mock'taki yapay gecikme uzun listede "donma" gibi görünür

2026-08-16: Keşfet'te filtre "Tümü"ye alınınca arayüz donuyor sanıldı.

`MockArtisanRepository.searchArtisans` her çağrıda `Future.delayed(400ms)`
uyguluyordu — "ağ hissi" için. Filtre boşken liste **900 tohumlanmış ustaya**
kadar büyüdüğü için sonsuz kaydırma 45 sayfa demek: 45 × 400 ms ≈ **18 saniye**
bekleme. Kullanıcı bunu donma olarak algılar.

> [!warning] Önce ölç, sonra düzelt
> İlk teşhis yanlıştı: sorunun `loadMore`'daki yarış durumundan geldiği
> sanıldı ve senkron bir kilit eklendi. Kilit kaldırılınca testler **yine
> geçti** — yani kilit gerçek sebebi çözmüyordu. Ölçüm gerçeği gösterdi:
> 45 kez tam sıralama toplam **9 ms**, ama her sayfa sabit **~410 ms**.
> Darboğaz hesaplama değil, yapay gecikmeydi.

Düzeltme: gecikme yalnız **ilk sayfada** 400 ms (iskelet/yükleniyor durumu
görünsün), sayfalamada 60 ms. Tüm listeyi gezme süresi 18.2 sn → **3.3 sn**.

Genel kural: mock gecikmeleri tek çağrıda makul görünür ama **N kez tekrar
eden akışlarda** (sonsuz kaydırma, toplu işlem) çarpılır. Sayfalama yolunda
gecikmeyi ayrı tut. Regresyon: `test/artisan_search_sayfalama_test.dart`.

---

## 🔴 Eksik indeks = SESSİZ arıza (kural kapısı fiilen kapanır)

2026-08-17 denetiminde iki eksik bileşik indeks bulundu. İkisi de **hata
göstermeden** çalışıyordu, en tehlikeli sınıf.

**`jobs(customerId + status)` yoktu → 5 ilan limiti FİİLEN KAPALIYDI.**
Zincir şöyle: `refreshOpenJobCount` iki eşitlik filtresi kullanır → bileşik
indeks şart → indeks yok → sorgu `catch`'e düşer ve `logger.warn` ile yutulur
→ `private/jobStats.openCount` **hiç yazılmaz** → `firestore.rules`
`openJobQuotaOk()` her zaman `0` okur → limit yok. Bir kullanıcı sınırsız ilan
açabilirdi ve her ilan bölgedeki tüm ustalara bildirim gönderiyor.

**`reviews(customerUID + createdAt)` yoktu** → profil başlığındaki yorum
bloğu canlıda hiç görünmezdi (`Future.wait` içinde patlıyor).

> [!danger] Denormalize sayaca dayanan her kural kapısı çift bağımlıdır
> Kural sayacı okur, sayacı CF yazar, CF sorgusu indekse muhtaçtır. Zincirin
> ortasındaki indeks eksikse **kapı sessizce açılır**. Yeni bir kota kapısı
> eklerken üçünü birlikte ekleyin: indeks + CF sayacı + kural.

Genel kural: `firestore.indexes.json`'a **iki eşitlik filtresi** veya
`where + orderBy` içeren her yeni sorgu için indeks ekleyin. Mock'ta indeks
aranmadığı için testler bunu YAKALAMAZ — `test/yayin_denetimi_2026_08_17_test.dart`
indeks dosyasını okuyarak bu boşluğu kapatıyor.

## 🟠 Storage'da kurallar OR'lanır — dar kural geniş kuralı kapatmaz

Sertifikaları (`certificate/{uid}/{dosya}`) sahibi+admin'e kapatmak için özel
bir `match` yazmak **yetmez**: genel `{folder}/{uid}/{fileName}` deseni aynı
yola uyar ve içindeki `allow read: if true` erişimi geri açar. Firestore ve
Storage'da eşleşen tüm kurallar OR'lanır — bir kuralın "hayır" demesi diğerinin
"evet"ini iptal etmez.

Doğru çözüm: genel kuralın okumasını da klasör listesiyle sınırla ve korunan
klasörü listeden çıkar.
```
allow read: if folder in ['profile', 'work', 'job', 'chat', 'product'];
```

Aynı tuzak eski düz yol (`{folder}/{fileName}`) için de geçerlidir.

## 🟠 Ham `status` ile efektif durum aynı şey değil

`jobs.status` sonsuza kadar `open` kalır — **süresi dolan ilanı `expired`
yapan zamanlanmış görev YOKTUR**. Süre yalnız `expiresAt`/`expiresAtMs`
alanlarında yaşar ve istemci `Job.effectiveStatus` ile hesaplar.

Kullanıcıya kapı açan her kontrol (mesaj gönderme, teklif, düzenleme)
`effectiveStatus` kullanmalı. `job_detail_screen.dart` ham `status`e baktığı
için aylar önce dolmuş ilana "Mesaj gönder" düğmesi çıkıyordu.

Firestore **sorguları ve kuralları** ham `status`e bakar; bu bilinçli kabul
(kural motoru zaman hesabı yapamaz) ama sorgu sonucunu istemcide efektif
duruma göre elemek gerekir.

## 🟠 Denormalize aynada bayat önbellek kapısı

`users` → `artisanProfiles` ad/foto aynası `_cached.hasArtisanProfile == true`
koşuluna bağlıydı. Önbellek oturum tazelenmeden güncellenmediği için ayna
sessizce atlanıyor, iki koleksiyon ayrışıyordu: kullanıcı kendi profilinde
yeni fotoğrafı, Keşfet/Ana Sayfa (bunlar `artisanProfiles` okur) eskisini
gösteriyordu. Kullanıcı bunu *"profil fotoğrafım bozuk geliyor"* diye tarif
eder ve sebebi bulunamaz.

Kapı **önbelleğe değil dokümanın kendisine** bakmalı (`snap.exists`).
`set(merge: true)` olmayan dokümanı oluşturduğu için varlık kontrolü şart —
yoksa usta olmayan kullanıcıya boş vitrin kaydı doğar.

---
İlgili: [[Mimari-Kararlar]] · [[Guvenlik-Kurallari]] · [[Sohbet-Mimarisi]] · [[Deploy-ve-Ortam]] · [[Demo-Veri-Seti]]

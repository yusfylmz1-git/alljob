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
| `_dbName = 'usta_cepte_tracking.db'` | `tracking/data/sqflite_tracking_repository.dart` | Uygulama **boş** veritabanı açar; kullanıcıların tüm Takip Merkezi kayıtları kaybolmuş görünür (dosya diskte durur, okunmaz) |
| `kProMonthlyProductId = 'usta_cepte_pro_monthly'` | `membership/billing_config.dart` | Play Console'da ürün kimliği oluşturulduktan sonra **asla** değiştirilemez |
| Firestore enum `apiValue`'ları | `data/models/*.dart` | Mevcut dokümanlar eski adı taşır → veri göçü gerekir |

Marka adı iki kez değişti ("Usta Cepte" → "Sepette Hizmet" → "İlanda Hizmet") ama bu kimlikler
**bilerek** eski adında bırakıldı. Kullanıcıya görünmezler.

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
iOS `appId` hâlâ **eski** kayda ait (`com.ustacepte.ustaCepte`). iOS'a
gerçekten çıkılacaksa yeniden `flutterfire configure` gerekir.

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
İlgili: [[Mimari-Kararlar]] · [[Guvenlik-Kurallari]] · [[Sohbet-Mimarisi]] · [[Deploy-ve-Ortam]]

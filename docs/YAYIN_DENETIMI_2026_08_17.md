# Play Store Öncesi Denetim — 2026-08-17

| Alan | Değer |
|---|---|
| Kapsam | Ölçek/maliyet · güvenlik/KVKK · kullanıcı akışları |
| Yöntem | 3 paralel kod analizi + elle doğrulama + regresyon testleri |
| Sonuç | `flutter analyze` 0 · **935 test** (öncesi 912) · CF lint 0 hata |
| Önceki denetim | `docs/YAYIN_DENETIMI_2026_08_14.md` |

---

## Düzeltilenler

### 🔴 Yayını engelleyen (canlıda sessizce bozulurdu)

**1 · `reviews(customerUID+createdAt)` indeksi yoktu**
`review_repository.dart:197` bu sorguyu **her profil başlığı çizildiğinde**
çalıştırıyor (`profile_header.dart` → `reviewsForUserProvider`). `Future.wait`
içinde olduğu için patlayınca puan/yorum bloğu tamamen kayboluyordu. Mock'ta
indeks aranmadığı için testlerde hiç görünmedi.
→ `firestore.indexes.json`'a eklendi.

**2 · `jobs(customerId+status)` indeksi yoktu → 5 ilan limiti FİİLEN KAPALIYDI**
En sinsi bulgu. `refreshOpenJobCount` (`functions/index.js:795`) iki eşitlik
filtresi kullanıyor → bileşik indeks şart. İndeks olmayınca sorgu `catch`'e
düşüyor (`logger.warn`), sayaç **hiç güncellenmiyor**, `firestore.rules`
içindeki `openJobQuotaOk()` her zaman `0` okuyor ve limit devre dışı kalıyordu.
Yani bir kullanıcı **sınırsız ilan açabilirdi** — her ilan bölgedeki tüm
ustalara bildirim gönderdiği için platform çapında spam demek.
→ İndeks eklendi **ve** sorguya `.limit(50)` konuldu (limitsiz `.get()`
10.000 ilanı olan hesapta her yazımda 10.000 doküman okuyordu).

**3 · Bildirim TTL politikası tanımsızdı**
`saveNotification` her bildirime `expireAt` yazıyor ama
`firestore.indexes.json` → `fieldOverrides` **boştu**, yani alan anlamsızdı ve
hiçbir şey silinmiyordu. Aktif kullanıcı yılda ~2000 bildirim biriktirir.
→ `notifications.expireAt` için `ttl: true` eklendi.

> ⚠️ TTL'in Firebase Console'da da etkinleştiğini deploy sonrası doğrulayın.

### 🟠 Kullanıcının bildirdiği + akış hataları

**4 · Profil fotoğrafı Keşfet'te ESKİ kalıyordu** (kullanıcı şikâyeti)
`firebase_auth_repository.dart:665` — ayna yazımı `_cached?.hasArtisanProfile
== true` koşuluna bağlıydı ve önbellek bayat kalabiliyordu. Sonuç: `users`
yeni fotoğrafı, `artisanProfiles` eskisini taşıyordu. Kullanıcı **kendi
profilinde yeni**, Ana Sayfa "Haftanın Ustası" / Keşfet / öne çıkanlarda
(hepsi `artisanProfiles` okur) **eski** fotoğrafı görüyordu.
→ Kapı artık önbelleğe değil **dokümanın gerçekten var olup olmadığına**
bakıyor (`snap.exists`).

**5 · Süresi dolmuş ilana hâlâ mesaj atılabiliyordu**
Sunucuda ilanı `expired` yapan zamanlanmış görev **yok** — doküman sonsuza
kadar `open` kalıyor. `job_detail_screen.dart:782` ham `status`e baktığı için
aylar önce dolmuş ilanda "Mesaj gönder" düğmesi çıkıyordu.
→ `job.effectiveStatus` (süreyi hesaba katar) kullanılıyor, mesaj da netleşti:
*"Bu ilanın süresi doldu, artık mesaj gönderilemiyor."*

### 🔒 Güvenlik / KVKK

**6 · `reviews` create'te alan allowlist'i ve boyut tavanı yoktu**
Tüm diğer koleksiyonlarda `hasOnly()` var, `reviews`'ta yoktu. İki sömürü:
istemci ilk yazımda `hiddenByAdmin: false` enjekte edip admin gizlemesini
atlatabiliyordu; ve `reviews` **herkese açık okunduğu** için tek yoruma
yüzlerce KB metin konup her profil görüntüleyene indirtilebiliyordu.
→ 8 alanlık allowlist + `tags` ve `customerDisplayName` boyut tavanı.

**7 · Sertifika/belge fotoğrafları HERKESE AÇIKTI**
`storage.rules` tüm klasörlerde `read: if true` diyordu. Usta buraya ustalık
belgesi, diploma, hatta kimlik fotokopisi yükleyebiliyor — KVKK'da **özel
nitelikli veri**. Yol tahmin edilebilir (`certificate/{uid}/...`) ve uid
herkese açık olduğu için "URL'yi kimse bilmez" savunması geçersizdi.
→ `certificate/` okuması **sahibi + admin** ile sınırlandı.

> Buradaki asıl tuzak: Storage'da eşleşen **tüm kurallar OR'lanır**. Genel
> `{folder}/{uid}/{file}` deseni sertifika yoluna da uyduğu için `read: if
> true` bırakılsaydı özel kural hiçbir işe yaramazdı. Genel kuralın okuması
> da klasör listesiyle sınırlandırıldı ve `certificate` listeden çıkarıldı.

Müşteri güven sinyalini **kaybetmedi**: belge görseli yerine
*"Belgeleri onaylı — belgeler gizlilik gereği paylaşılmaz"* bölümü gösteriliyor.

**8 · Firebase Console talimatları son kullanıcıya gösteriliyordu**
`phone_verification_repository.dart` — `providerDisabled` ve `regionBlocked`
mesajları kullanıcıya *"Firebase Console → Authentication → Sign-in method…"*
yazıyordu. Hem anlaşılmaz hem altyapı yapılandırmasını ifşa ediyor.
→ Kullanıcı sade metin görüyor; Console adımı `devNote` alanında `AppLog.d`
ile **yalnız debug derlemesinde** loga düşüyor.

**9 · KVKK tutarsızlığı: silinen kullanıcının yorumu**
`reports`'ta `reporterUid: null`, `supportTickets`'ta `uid: null` yapılıyordu
ama `reviews`'ta yalnız ad anonimleşiyordu.
→ `authorDeleted: true` işareti eklendi. `customerUID` **bilinçli olarak
korundu**: doküman kimliği (`rev_{yazan}__{hedef}`) zaten o uid'i taşıyor ve
kural motoru yazar kontrolünü bu alandan yapıyor — null'lanırsa yorum
"sahipsiz" kalır ve düzenleme kuralı kilitlenir.

### 📈 Ölçek

**10 · Ürün taslağı oluşturmada hiçbir kota yoktu**
Yayınlama iyi korunuyordu (10/gün + 50 aktif ürün) ama **taslak** yazımı
doğrudan Firestore'a gidiyor ve adet sınırı yoktu. Doğrulanmış e-postalı bir
hesap SDK ile yüz binlerce taslak yazıp hem koleksiyonu şişirebilir hem her
yazımda `onProductWritten` tetikleyip CF faturası üretebilirdi.
→ `jobs`taki `jobStats` deseninin aynısı: `private/productStats.draftCount`
sayacı (yalnız CF yazar) + `productDraftQuotaOk()` kural kapısı, tavan **100**.
Normal kullanıcı bu tavana hiç yaklaşmaz.

**11 · Usta aramasında il filtresi istemcideydi → 181. usta görünmüyordu**
`artisanFetchCap = 180`. Meslek seçilmemişken koleksiyonun ilk 180 profili
çekilip il/ilçe Dart'ta eleniyordu. Sonuçlar: 180'den sonraki hiçbir usta
aramada **görünmüyordu** ("profilim listede yok"), ve İstanbul araması için
Türkiye genelinden 180 doküman okunup 12'si gösteriliyordu.
→ `serviceProvinces` alanı (zaten yazılıyordu ama hiç sorguda
kullanılmıyordu) `arrayContains` ile sunucuya taşındı. Önbellek anahtarına
il eklendi — yoksa Bursa araması İstanbul sonuçlarını döndürürdü.

> Firestore tek sorguda **iki `arrayContains` kabul etmez**: meslek seçiliyken
> o hak `professions` için harcanıyor, il elemesi istemcide kalıyor. Meslek
> seçili değilken (asıl sorunlu durum) il sunucuda filtreleniyor.

---

## Düzeltilmedi — bilinçli kabul

| Konu | Neden |
|---|---|
| İlçe kırılımı istemcide | Firestore iki `arrayContains` kabul etmiyor; il çok daha fazla eleme yapıyor, ilçe kalıntısı küçük |
| Gerçek `startAfter` sayfalaması | 180 tavanı il filtresiyle birlikte lansman ölçeğinde yeterli; **150 ustaya yaklaşınca müdahale şart** |
| `maxInstances: 10` global tavan | `butceBekcisi` zaten maliyet freni; lansman trafiğinde izlenmeli, gerekirse `onMessageCreated`'a ayrı tavan |
| `adminStats/global` sıcak nokta | Saniyede 1+ yazma olayında `CONTENTION` başlar, sayaçlar sürüklenir. `adminRebuildStats` elle düzeltiyor |
| Storage çöpü (silinen ilan fotoğrafları) | Yol kullanıcı bazlı (`job/{uid}/`), ilan bazlı değil. Hesap silmede temizleniyor ama ilan silmede kalıyor |
| `ContactMasker` ölü kod | Maskeleme ürün kararıyla kaldırılmış; sınıf duruyor. Gizlilik politikası bunu açıklamalı |
| Mesaj hız sınırı sohbet başına | Kullanıcı 100 sohbet açıp saniyede 100 mesaj gönderebilir |
| Uygunsuz içerik otomatik filtresi | Reaktif moderasyon var (şikayet/engelleme/admin). Play zorunlu tutmuyor |

---

## Yayın öncesi ELLE yapılacaklar

Bunlar kodla çözülemez, konsoldan doğrulama ister:

1. **`firebase deploy --only firestore:indexes`** — yeni 3 indeks canlıya
   gitmeli. İndeksler oluşana kadar (birkaç dakika) ilgili sorgular hata verir.
2. **`firebase deploy --only storage`** — sertifika kuralı canlıya gitmeli.
3. **`firebase deploy --only functions`** — taslak sayacı + limitler.
4. **App Check gerçek durumunu doğrula.** Üç belge çelişiyor:
   `SECURITY_AUDIT.md` ve `YAYIN_DENETIMI_2026_08_14.md` "ENFORCED" diyor,
   `OPS_BILLING_APPCHECK.md` "UNENFORCED" diyor. Konsoldan bakılmalı.
   Admin callable'larında `enforceAppCheck` **kapalı** (`ADMIN_CALL_OPTS`).
5. **Bootstrap admin e-postalarında 2FA aç** — 2 Gmail hesabı tek savunma hattı.
6. **Firestore Console → TTL** → `notifications` / `expireAt` aktif mi kontrol et.
7. **Play Data Safety formu:**
   - Telefon: **toplanır + herkese açık** (`publicPhone` public dokümanda)
   - Konum: **toplanmaz** (GPS izni yok, yalnız il/ilçe seçimi — doğrulandı)
   - Reklam kimliği: **evet** (`ACCESS_ADSERVICES_AD_ID`)
   - Hedef kitle: **18+** (yasal metinler bunu söylüyor)
8. **IAP ürünü Play Console'da tanımlı mı** doğrula (`kProMonthlyProductId`).

---

## Regresyon testleri

`test/yayin_denetimi_2026_08_17_test.dart` — **23 test**. Her biri canlıda
*sessizce* bozulan bir arıza sınıfını koruyor: eksik indeksler, ham/efektif
durum karışması, bayat önbellek kapısı, allowlist kaldırılması, sertifika
kuralının genel kuralca geri açılması, kota kapısının kalkması, il filtresinin
istemciye geri dönmesi.

Ayrıca `test/artisan_search_sayfalama_test.dart` (8 test, 2026-08-16) sonsuz
kaydırma yığılmasını koruyor.

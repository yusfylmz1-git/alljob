# 👥 PLAN · Instagram tarzı takip sistemi

> **Karar:** 2026-08-08. *"Güzel bir takip sistemi Instagram gibi olsun."*

---

## Mevcut durumun analizi

Altyapı var ama **usta-merkezli** kurulmuş. Faz 4'te modeli yönsüzleştirdik
(takma adlar), ama sistem hâlâ tek yönlü çalışıyor.

### 🔴 Kırık: usta olmayan takip edilemiyor

`FavoriteButton` **yalnızca `artisan_profile_screen`'de** var — yani sadece
usta profillerinde. Müşteri profiline girip takip etmek **imkânsız**.

Dahası `Favorite` kaydı usta-özel alanlar zorunlu tutuyor:
`professionNameTR` · `rating` · `totalReviews`. Müşteri takip edilirse bu
alanlar anlamsız/boş kalır.

### 🔴 Kırık: "Takipçilerim" ekranı YOK

`followersProvider` var ve profil sayacı onu okuyor — ama dokununca
`/favorites` açılıyor, o da **"Takip Ettiklerim"** listesi. Yani:

| Sayaç | Dokununca açılan | Doğru mu? |
|---|---|---|
| takip | Takip Ettiklerim | ✅ |
| **takipçi** | **Takip Ettiklerim** | ❌ **yanlış liste** |

### 🟠 Eksik: karşılıklı takip görünmüyor
Instagram'da "seni takip ediyor" rozeti var. Burada yok.

### 🟠 Eksik: takip bildirimi yok
Biri seni takip edince haber gelmiyor.

### 🟠 Eksik: profil sayfası herkes için yok
`/artisan/:uid` yalnız usta profili çiziyor. Müşterinin herkese açık
profili **yok** — takip edilecek sayfa yok.

---

## Yapılacaklar

### Faz A · Model: usta-özel alanları isteğe bağlı yap
`professionNameTR` / `rating` / `totalReviews` → varsayılanlı.
Takip edilen usta değilse boş kalır, UI zaten gizler.
**Firestore alan adları DEĞİŞMEZ** (Faz 4 kararı, veri göçü yok).

### Faz B · Takipçiler ekranı
`/followers` rotası + ekran. Profil sayacı buraya bağlanır.
Tek ekran, iki sekme: **Takipçiler | Takip Edilenler** (Instagram düzeni).

### Faz C · Takip düğmesi her profilde
- `FavoriteButton` → `FollowButton` (ad da düzelsin)
- Usta profilinde zaten var
- **Herkese açık kullanıcı profili** gerekiyor → `/u/:uid`
  (usta profili olan `/artisan/:uid`'e yönlensin)

### Faz D · Karşılıklı takip rozeti
`watchIsFollowedBy(otherUid)` → "Seni takip ediyor" etiketi.
Takipçiler listesinde ve profilde görünür.

### Faz E · Takip bildirimi (CF)
`onFollowCreated` → takip edilene bildirim.
⚠️ Spam riski: aynı kişi takip-bırak-takip yaparsa tekrar bildirim gitmeli
mi? Instagram göndermez. **Debounce gerekir** (aynı çift için 24 saat).

---

## Sıra ve risk

| Faz | İş | Durum |
|---|---|---|
| A | Model alanları isteğe bağlı | ✅ |
| B | Takipçiler ekranı + rota | ✅ |
| C | Takip düğmesi yönsüz | ✅ |
| D | Karşılıklı rozet | ✅ |
| E | Takip bildirimi | ✅ **deploy edildi** |

---
İlgili: [[PLAN-Sadelestirme]] · [[Firestore-Semasi]]


---

## ✅ Sonuç (2026-08-08)

### Düzeltilen kırıklar
1. **Takipçi sayacı yanlış listeye gidiyordu.** Profildeki "takipçi"ye
   dokununca *Takip Ettiklerim* açılıyordu. Artık `/favorites?tab=followers`.
2. **Usta olmayan takip edilemiyordu.** `Favorite` modeli
   `professionNameTR`/`rating`/`totalReviews` alanlarını ZORUNLU tutuyordu.
   İsteğe bağlı yapıldı; `hasArtisanInfo` ile UI kendini ayarlıyor.
3. **"Takipçilerim" ekranı yoktu.** Tek ekran iki sekme oldu
   (Takipçiler | Takip) — aynı liste gövdesi, `followers` bayrağıyla
   karşı tarafı seçiyor.

### Eklenenler
- **Karşılıklı takip rozeti**: "Seni takip ediyor" (`isFollowedByProvider`).
  Yeni repo metodu GEREKMEDİ — `watchIsFavorite` ters yönde çağrıldı,
  kayıt zaten deterministik kimlikte duruyor.
- **Takip bildirimi** (`onFollowCreated`): uygulama içi + push, dokununca
  takip edenin profili açılır.

### Tasarım kararları
> **Spam koruması deterministik kimlikle.** Bildirim dokümanı
> `follow_{followerUid}` — takip-bırak-takip yapan biri AYNI dokümanı ezer,
> alıcının listesinde tek satır kalır. Instagram da tekrar bildirim
> göstermez. Ayrı bir debounce tablosu gerekmedi.

> **Push kategorisi `chat`.** `pushCategoryFromData` bilinmeyen tipi
> `jobUpdates`'e düşürüyordu; takip bildirimi "iş güncellemeleri" tercihine
> bağlansaydı kullanıcı iş bildirimlerini kapatınca takipçi haberi de
> susardı. Takip sosyal bir olay → `chat` kategorisiyle yönetiliyor.

### ✅ Genel kullanıcı profili (`/u/:uid`) — eklendi

Usta vitrini olmayan kişiler için yeni ekran: `PublicUserScreen`.

**Devretme mantığı:** ekran `users/{uid}` dokümanını okur; `hasArtisanProfile`
true ise `/artisan/:uid`'e **pushReplacement** yapar. Böylece iki ayrı gerçek
kaynak oluşmaz — usta vitrini tek yerde çizilir.

**Veri yolu:** `AuthRepository.fetchPublicUser(uid)` (Firebase + Mock, kural 1).
`users/{uid}` herkese açık okunur; e-posta/telefon o dokümanda ZATEN yok
(ADR-11), yani ekran hassas veri sızdıramaz.

**Gösterilenler:** avatar · ad + doğrulama rozeti · "Seni takip ediyor" ·
takip/takipçi/tamamlanan sayaçları · Takip Et + Mesaj Gönder.

**Yönlendirmeler `/u/:uid`'e çevrildi:** takip listesi satırı · uygulama içi
takip bildirimi · push bildirimi. Öncesinde üçü de doğrudan
`/artisan/:uid`'e gidiyordu → usta olmayan kişide **boş ekran**.

> Regresyon testi bu hatayı yakaladı: değişikliklerden biri sessizce
> uygulanmamıştı (metin eşleşmesi tutmadı), test kırıldı ve fark edildi.

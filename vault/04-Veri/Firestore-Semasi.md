# Firestore Şeması

Proje: `alljob1` · Bölge: `europe-west1`

## Koleksiyon ağacı

```
users/{uid}                        herkese açık profil (ad, foto) ⚠ hassas veri YOK
├── private/{doc}                  telefon, chatMeta — yalnız sahibi
├── blocked/{otherUid}             engellenenler
├── notifications/{notifId}        bildirim kutusu
└── trackBackup/{docId}            takip merkezi yedeği

artisanProfiles/{uid}              usta vitrini, puan, meslek, sertifika
jobs/{jobId}                       iş ilanları
chats/{chatId}                     id: chat_{müşteri}__{usta}
└── messages/{msgId}
reviews/{reviewId}                 id: {chatId} (c2a) | {chatId}__a2c
favorites/{favId}                  id: {müşteri}__{usta}
products/{productId}               ürün ilanları
staffWorkers/{docId}               iş arayan profilleri
staffNeeds/{needId}                eleman ilanları
reports/{reportId}                 şikayetler
neighborhoods/{id}                 mahalle referans verisi
supportTickets/{ticketId}
membershipPurchases/{uid}
premiumOverrides/{entryId}
scheduledCampaigns/{id}

── admin ──
adminRoles/{uid} · adminInvites/{id} · adminAuditLogs/{logId}
adminStats/{docId}/** · adminConfig/{docId} · adminRateLimits/{uid}
adminUserNotes/{noteId}
```

## Deterministik kimlikler

Rastgele kimlik yerine hesaplanabilir kimlik kullanılır — tekillik ve yetki
ispatı bedava gelir.

| Koleksiyon | Kimlik | Kazanç |
|---|---|---|
| `chats` | `chat_{müşteri}__{usta}` | Kişi başına TEK kutu; kural kimliği doğrular |
| `reviews` | `{chatId}` / `{chatId}__a2c` | İş başına tek puan, yön ayrı |
| `favorites` | `{müşteri}__{usta}` | Çift favori olamaz |

## Denormalize alanlar — neden var?

Firestore kuralları **sorgu yapamaz** ve **join yoktur**. Bu yüzden bazı
gerçekler kopyalanır. Kopyayı kim yazıyorsa **tek yazan o olmalıdır**.

| Alan | Nerede | Kim yazar | Neden |
|---|---|---|---|
| `customerStarted` | `chats` | Müşteri (kural sınırlı) | Kural "müşteri mesajı var mı" sorgulayamaz |
| `jobTitle` | `chats` | CF/istemci | Liste her sohbet için ilan okumasın |
| `jobId` | `chats` | Oluşturucu | CF ilanın sohbetlerini tek eşitlikle bulur |
| ortalama puan | `artisanProfiles` | **Yalnız CF** (`onReviewWritten`) | Kendi puanını yazamasın |
| `unreadTotal/Customer/Artisan` | `users/{uid}/private/chatMeta` | CF | Rozet tüm listeyi dinlemesin |
| `openJobCount` | `users` | CF `refreshOpenJobCount` | 5 ilan limiti |
| `completedJobsAsCustomer` | `users` | **Yalnız CF** (`onJobWritten`) | Müşteri profili sayacı |
| `reviewCountAsCustomer` | `users` | **Yalnız CF** (`onReviewWritten`) | Müşteri profili sayacı — **ADET**, puan değil |

> [!note] Müşteri puanı neden herkese açık DEĞİL?
> `reviewCountAsCustomer` yalnız **kaç** değerlendirme aldığını söyler.
> Ortalama/toplam puan `users/{uid}/private/rating` altında kalır (yalnız
> sahibi okur) — düşük puanlı müşteri herkese teşhir edilmesin. Ustada
> durum farklı: usta profili **vitrindir**, puanı satış argümanıdır.

> [!warning] Denormalizasyon eklerken
> 1. Tek yazan kim? 2. Kural o alanı başkasına kapatıyor mu?
> 3. Bayatlarsa ne olur? Bunlara cevabın yoksa ekleme.

## `jobs` — alan listesi

**Zorunlu:** `customerId`, `customerName`, `title`, `description`, `category`,
`province`, `district`, `photos`, `priceType`, `status`, `createdAt`,
`expiresAt`, `expiresAtMs`

**Opsiyonel:** `customerPhotoURL`, `neighborhood`, `budget`, `cancelReason`,
`moderationHidden`

**CF'ye ait (istemci yazamaz):** `moderatedBy`, `moderatedAt`,
`adminModerationNote`

> [!warning] Eski dokümanlarda ölü alanlar olabilir
> `offerCount`, `selectedOfferId`, `selectedArtisanId`, `chatId`,
> `customerConfirmedDone`, `artisanConfirmedDone`, `autoCompleteAt`,
> `completedAt`, `dispute*` — iş akışı kalkınca (2026-08-08/09) hepsi
> düştü. `Job.fromMap` bunları **okumaz**; Firestore'da durabilirler,
> modele girmezler. Create allowlist'i de yazılmalarını engeller.
> → [[Is-Akisi-Durum-Makinesi]]

## Zaman damgaları: ISO string

Zamanlar **ISO 8601 string** olarak yazılır, Firestore `Timestamp` değil.

> [!note] Neden?
> Tek alanlı aralık sorgusu composite index gerektirmez:
> ```javascript
> .where("autoCompleteAt", "<=", nowIso)
> .where("completedAt", "<=", cutoff)
> ```
> ISO string sözlük sırası = kronolojik sıra olduğu için `<=` doğru çalışır.
> **UTC** yazmak şart — yerel saatle karışırsa sıralama bozulur.

## İndeksler

`firestore.indexes.json` — composite index'i olan koleksiyonlar:
`jobs`, `chats`, `products`, `reviews`, `users`, `artisanProfiles`,
`adminInvites`, `scheduledCampaigns`, `supportTickets`

> [!tip] "The query requires an index" hatası
> Konsol bağlantısı verir ama **`firestore.indexes.json`'a da ekle** — yoksa
> sonraki deploy'da kaybolur.

---
İlgili: [[Veri-Modelleri]] · [[Guvenlik-Kurallari]] · [[Cloud-Functions-Haritasi]]

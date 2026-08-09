# Cloud Functions Haritası

**Tek dosya:** `functions/index.js` — 5.127 satır, 51 fonksiyon
**Bölge:** `europe-west1` (sabit `REGION`)
**Runtime:** firebase-functions 7 + firebase-admin 14 (2. nesil)

## Dağılım

| Tetikleyici | Adet |
|---|---|
| `onCall` (istemci çağırır) | 37 |
| `onDocumentWritten` | 9 |
| `onDocumentCreated` | 4 |
| `onSchedule` | 6 |

> [!important] CF'ler neden var?
> Üç iş istemciye **asla** bırakılmaz:
> 1. **Güvenilir sayaçlar** — ortalama puan, `offerCount`, `completedJobs`.
>    İstemci yazabilseydi kendi puanını şişirirdi.
> 2. **Ayrıcalıklı yazımlar** — kilit, askı, rol, sistem mesajı. Kurallar bu
>    alanları istemciye tamamen kapatır.
> 3. **Çapraz kullanıcı işlemler** — push, başkasının dokümanını güncelleme.

---

## Doküman tetikleyicileri

| Fonksiyon | Doküman | Görevi |
|---|---|---|
| `onJobCreated` | `jobs/{jobId}` | Uygun ustalara yeni ilan push'u |
| `onJobWritten` | `jobs/{jobId}` | Açık ilan sayacını tazeler (tek işi) ↓ |
| `onMessageCreated` | `chats/{chatId}/messages/{msgId}` | Alıcıya push + okunmamış sayacı |
| `onReviewWritten` | `reviews/{reviewId}` | Ustanın ortalama puanı + yorum sayısı |
| `onUserWritten` | `users/{uid}` | Kullanıcı türevleri |
| `onArtisanProfileWritten` | `artisanProfiles/{uid}` | Profil türevleri |
| `onProductWritten` | `products/{productId}` | Ürün türevleri |
| `onReportWritten` | `reports/{reportId}` | Şikayet kuyruğu |
| `onProductReportWritten` | `reports/{reportId}` | Ürün şikayeti |
| `onStaffNeedCreated` | `staffNeeds/{needId}` | Eleman ilanı bildirimi |

### `onJobWritten` — tek dal kaldı

Durum değişiminde (ve silmede) `refreshOpenJobCount` → ilan limiti sayacı.

> [!warning] Eskiden 5 dal vardı
> Tamamlanma sayacı, tek taraflı onay + `autoCompleteAt`, usta seçildi
> push'u + sohbet kilitleme, seçim iptali. İş akışı kalkınca bu geçişler
> **üretilmemeye başladı** — dallar sessizce hiç ateşlenmiyordu, 2026-08-09'da
> silindi. → [[Is-Akisi-Durum-Makinesi]]

## Zamanlanmış görevler

| Fonksiyon | Sıklık | Görevi |
|---|---|---|
| `processScheduledCampaigns` | 5 dakika | Zamanlanmış duyuruları gönderir |
| `purgeRemovedProducts` | 24 saat | Kaldırılan ürünleri temizler |

Saat dilimi: `Europe/Istanbul`.

## Çağrılabilir (onCall)

### Kullanıcı
| Fonksiyon | İş |
|---|---|
| `deleteAccount` | Hesap silme (KVKK) — [politika](#hesap-silme-kapsamı) |
| `createSupportTicket` | Destek talebi |
| `verifyMembershipPurchase` | Üyelik satın alma doğrulaması |
| `publishProduct` · `updateProductContent` | Ürün yayını |
| `claimAdminAccess` | İlk admin kurulumu |
| `adminAcceptInvite` | Admin daveti kabul |

### Admin (30 fonksiyon)
| Alan | Fonksiyonlar |
|---|---|
| Rol/yetki | `adminSetRole`, `adminSetCapabilities`, `adminCreateInvite`, `adminRevokeInvite` |
| Kullanıcı | `adminLookupUser`, `adminUserSummary`, `adminSetUserSuspended`, `adminBulkSuspend`, `adminAddUserNote`, `adminListUserNotes` |
| Moderasyon | `adminModerateMessage`, `adminModerateJob`, `adminModerateProduct`, `adminModerateStaffing`, `adminHideReview` |
| Şikayet | `adminResolveReport`, `adminAssignReport` |
| Usta | `adminSetArtisanFlags`, `adminGrantPremium`, `adminReviewCertificates`, `adminBulkPlanUpdate` |
| Sistem | `adminUpdateConfig`, `adminRebuildStats`, `adminLogExport`, `adminGetChatTranscript` |
| Duyuru | `adminBroadcastNotification`, `adminScheduleCampaign`, `adminCancelCampaign` |
| Destek | `adminUpdateSupportTicket` |

Hepsi başta yetki doğrular (`assertAdmin` / `assertSuperadmin`) ve denetim
kaydı bırakır. → [[Admin-Paneli]]

> [!warning] `adminBulkPlanUpdate` son çaredir
> Ücretsiz dönem bitince müsaitliğin kapanmasını sağlayan asıl mekanizma bu
> CF **değil**, istemcideki premium kapısıdır: `ArtisanProfile.isAvailableAt`
> premium erişimi yoksa `false` döner. O kapı hiçbir veri yazmaz — ücretsiz
> döneme dönülürse (`premiumFreeDuringBeta = true`) herkes eski hâline
> kendiliğinden döner.
>
> Bu CF ise **kalıcı yazma** yapar (`isPremium` / `manualPause`) ve geri alma
> düğmesi yoktur. Yalnız kampanya bitişi / toplu düzeltme gibi veriyi gerçekten
> değiştirmek gerektiğinde kullanılır. `dryRun: true` ile önce sayım alınır;
> `onlyWithoutActivePremium` (varsayılan true) ödemeli aktif aboneleri atlar.

## Ortak yardımcılar

| Fonksiyon | İş |
|---|---|
| `postSystemMessage(chatId, text)` | Sohbete sistem şeridi yazar |
| `saveNotification(uid, key, payload)` | Bildirim dokümanı |
| `sendPushToUid(uid, title, body, data)` | FCM push |
| `jobChatDocs(jobId)` | İlanın tüm sohbetleri (`jobId` alanı üstünden) |
| `refreshOpenJobCount(customerId)` | Açık ilan sayacı |

## Yazma kalıpları

**Batch sınırı.** Firestore batch 500 yazımda dolar; döngüler 450'de bir
commit'ler. Teklif sayısı yüksek ilanlarda gerekli.

**Idempotanlık.** Zamanlanmış görevler işlediklerini damgalar
(`chatsArchivedAt`, `autoCompleteRemindedAt`) — ikinci kez işlemez.

**Hata yutma.** Yan etkiler (`try/catch` + `logger.warn`) ana işlemi
düşürmez. Örnek: profil yoksa `completedJobs` artışı atlanır.

**Döngü güvenliği.** `onJobWritten` kendi yazdığı alanla tekrar tetiklenir —
kod bunu koşullarla eler (`if (!after.completedAt)` gibi). Yeni yazım
eklerken bunu düşün.

## Hesap silme kapsamı

`deleteAccount` KVKK **ve** Play zorunluluğudur. Ölçüt iki yönlüdür: kişisel
veriyi silmek zorundayız, ama kötüye kullanım kaydını tutma hakkımız var.
Bu yüzden her koleksiyon üç kovadan birine düşer.

| Kova | Koleksiyonlar | Gerekçe |
|---|---|---|
| **SİL** | `jobs`, `favorites` (iki yön), `staffNeeds`, `staffWorkers`, `products`, hakkındaki `reviews`, `users/**` (recursive), `artisanProfiles`, `membershipPurchases`, Storage 6 klasör, Auth | Kişisel veri; saklamanın meşru gerekçesi yok |
| **ANONİMLEŞTİR** | `chats` (ad/foto), yazdığı `reviews`, `supportTickets` (uid/email), `reports` (yalnız `reporterUid`) | Kayıt iki taraflı ya da kanıt; kimlik düşer, gövde kalır |
| **DOKUNMA** | `reports` gövdesi, `reportedUid`, `adminUserNotes`, `premiumOverrides`, `adminAuditLogs` | Denetim izi / kötüye kullanım kaydı |

> [!warning] Şikayet kaydını silme
> `reports` silinirse **"şikayet edilince hesabı sil, temize çık"** açığı
> doğar. Şikayet EDENİN kimliği düşer; EDİLENİN kimliği kaydın kendisidir,
> düşerse kayıt anlamsızlaşır.

> [!note] Şikayet doküman kimliği uid içerir
> ID formatı `{tip}_{hedef}__{reporterUid}`; kural "hedef başına şikayetçi
> başına TEK kayıt" tekilliğini buna dayandırır. Anonimleştirmek için
> dokümanı **taşıma** — tekillik garantisi bozulur. Alan boşaltılır, kimlik
> yerinde kalır.

Sıra önemlidir: **Auth kaydı en sonda** silinir; bir adım yarıda kalırsa
kullanıcı tekrar deneyebilir. Yeni koleksiyon eklerken uid taşıyor mu diye
bak — taşıyorsa üç kovadan birine yerleştir.
Regresyon: `test/hesap_silme_kapsami_test.dart`.

> [!warning] Deploy
> `firebase deploy --only functions --project alljob1`.
> Ağ hatalarında IPv4/IPv6 tuzağı var → [[Deploy-ve-Ortam]]

---
İlgili: [[Guvenlik-Kurallari]] · [[Firestore-Semasi]] · [[Is-Akisi-Durum-Makinesi]] · [[Admin-Paneli]]

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
| `onJobWritten` | `jobs/{jobId}` | **En kritik CF.** Durum geçişlerinin tümü ↓ |
| `onOfferWritten` | `offers/{offerId}` | `offerCount` yeniden hesap + müşteriye ilgi bildirimi |
| `onMessageCreated` | `chats/{chatId}/messages/{msgId}` | Alıcıya push + okunmamış sayacı |
| `onReviewWritten` | `reviews/{reviewId}` | Ustanın ortalama puanı + yorum sayısı |
| `onUserWritten` | `users/{uid}` | Kullanıcı türevleri |
| `onArtisanProfileWritten` | `artisanProfiles/{uid}` | Profil türevleri |
| `onProductWritten` | `products/{productId}` | Ürün türevleri |
| `onReportWritten` | `reports/{reportId}` | Şikayet kuyruğu |
| `onProductReportWritten` | `reports/{reportId}` | Ürün şikayeti |
| `onStaffNeedCreated` | `staffNeeds/{needId}` | Eleman ilanı bildirimi |

### `onJobWritten` — içindeki dallar

Sırayla:

1. `completed`/`rated`'a ilk geçiş → ustanın `completedJobs` +1
   (`disputed`'dan dönüşte tekrar artmaz), sohbete "🎉 İş tamamlandı" sistem
   mesajı, `completedAt` damgası
2. **Tek taraflı onay** → karşı tarafa sistem mesajı + `autoCompleteAt`
   (3 gün) + push
3. `open` → `workerSelected` → seçilen ustaya push, **`lockOtherJobChats`**,
   seçilen sohbete sistem mesajı
4. `workerSelected` → `open` (seçim iptali) → **`unlockJobChats`**,
   `selectionCancelCount` +1 (3. iptalde ilan kapanır)
5. Durum değişiminde `refreshOpenJobCount` (ilan limiti sayacı)

→ [[Is-Akisi-Durum-Makinesi]]

## Zamanlanmış görevler

| Fonksiyon | Sıklık | Görevi |
|---|---|---|
| `autoCompleteJobs` | 6 saat | `autoCompleteAt` dolan tek taraflı onayları `completed` yapar, `autoCompletedBySystem` izi bırakır |
| `remindJobAutoComplete` | 6 saat | Son 24 saate girenlere bir kez hatırlatma |
| `processScheduledCampaigns` | 5 dakika | Zamanlanmış duyuruları gönderir |
| `archiveCompletedChats` | 24 saat | 7 gün geçmiş işlerin sohbetlerini arşivler → [[Sohbet-Mimarisi]] |
| `purgeRemovedProducts` | 24 saat | Kaldırılan ürünleri temizler |

Saat dilimi: `Europe/Istanbul`.

## Çağrılabilir (onCall)

### Kullanıcı
| Fonksiyon | İş |
|---|---|
| `deleteAccount` | Hesap silme (KVKK) |
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
| Şikayet/anlaşmazlık | `adminResolveReport`, `adminAssignReport`, `adminResolveDispute` |
| Usta | `adminSetArtisanFlags`, `adminGrantPremium`, `adminReviewCertificates` |
| Sistem | `adminUpdateConfig`, `adminRebuildStats`, `adminLogExport`, `adminGetChatTranscript` |
| Duyuru | `adminBroadcastNotification`, `adminScheduleCampaign`, `adminCancelCampaign` |
| Destek | `adminUpdateSupportTicket` |

Hepsi başta yetki doğrular (`assertAdmin` / `assertSuperadmin`) ve denetim
kaydı bırakır. → [[Admin-Paneli]]

## Ortak yardımcılar

| Fonksiyon | İş |
|---|---|
| `postSystemMessage(chatId, text)` | Sohbete sistem şeridi yazar |
| `saveNotification(uid, key, payload)` | Bildirim dokümanı |
| `sendPushToUid(uid, title, body, data)` | FCM push |
| `jobChatDocs(jobId)` | İlanın tüm sohbetleri (`jobId` alanı üstünden) |
| `lockOtherJobChats` / `unlockJobChats` | Kilit yönetimi |
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

> [!warning] Deploy
> `firebase deploy --only functions --project alljob1`.
> Ağ hatalarında IPv4/IPv6 tuzağı var → [[Deploy-ve-Ortam]]

---
İlgili: [[Guvenlik-Kurallari]] · [[Firestore-Semasi]] · [[Is-Akisi-Durum-Makinesi]] · [[Admin-Paneli]]

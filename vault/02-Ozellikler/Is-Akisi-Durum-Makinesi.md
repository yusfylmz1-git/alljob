# İş Akışı — Durum Makinesi

> [!warning] BU AKIŞ ARTIK ÇALIŞMIYOR (2026-08-08, oturum 82–83)
> Teklif topla → "Ustayı Seç" → tamamlama onayı zinciri **UI'dan kaldırıldı**.
> Usta ilan sahibine **doğrudan mesaj atar**; anlaşma taraflar arasındadır.
> Bu not artık **tarihsel/veri referansı** — canlı davranışı anlatmaz.
>
> **Bugün gerçekte olan:** ilan `open` doğar, süresi dolunca `expired` olur,
> müşteri isterse `cancelled` yapar. Diğer beş durum canlıda **üretilmiyor**;
> yalnızca eski kayıtlar okunabilsin diye enum'da duruyorlar.
>
> Ne silindi (oturum 83): `select_artisan.dart`, `job_completion.dart`.
> Ne duruyor ve neden: aşağıdaki "Kalıntılar" bölümü.

Model: `lib/data/models/job.dart` → `enum JobStatus`

## Durumlar

```
                    ┌──────────────────────────────┐
                    ▼                              │ (iptal)
   [oluştur] → open ──────────→ workerSelected ────┘
                 │                    │
      (süre dolar)│                   │ (usta işe başlar)
                 ▼                    ▼
             expired              inProgress
                                      │
                    ┌─────────────────┤
                    │  iki taraf da onaylar
                    ▼                 │
               completed ←────────────┘
                    │
       (taraflardan biri puan verir)
                    ▼
                  rated

   workerSelected / inProgress / completed  ──(sorun bildirilir)──→ disputed
   open / workerSelected                    ──(müşteri iptal)─────→ cancelled
```

| Durum | Anlamı | Kullanıcıya görünen (`simpleLabelTR`) |
|---|---|---|
| `open` | Teklif topluyor | "Teklif toplanıyor" |
| `workerSelected` | Usta seçildi, iş başlamadı | "İş yürüyor" |
| `inProgress` | İş sürüyor | "İş yürüyor" |
| `completed` | İki taraf da onayladı | "Tamamlandı" |
| `rated` | Puanlandı | "Tamamlandı · değerlendirildi" |
| `disputed` | Sorun bildirildi — döngü donar | "Sorun — beklemede" |
| `cancelled` | Müşteri iptal etti | "İptal edildi" |
| `expired` | Süresi doldu | "Süresi doldu" |

> [!important] İki dil vardır
> `labelTR` teknik/admin dilidir (8 ayrı durum). `simpleLabelTR` kullanıcı
> dilidir ve durumları **3 evreye** indirir (teklif → yürüyor → kapandı).
> Backend enum'u asla sadeleştirme; yalnız UI metni birleşir.
> `simpleStepIndex` stepper içindir: 0/1/2, istisnalarda `null`.

## Yardımcı sorgular (`JobStatus` üstünde)

| Getter | Doğru olduğu durumlar |
|---|---|
| `isActiveForOffers` | `open` — usta feed'inde görünür, teklif alır |
| `isAssigned` | workerSelected, inProgress, completed, rated, disputed |
| `canDispute` | workerSelected, inProgress, completed |
| `isInWork` | workerSelected, inProgress |
| `isClosedHappy` | completed, rated |

`effectiveStatus` — alan `open` olsa bile süresi dolmuşsa `expired` sayar.
Seçim kapısı bunu kullanır (`canSelectArtisanFor`).

## Kalıntılar — duruyor ama çağrılmıyor (oturum 83 envanteri)

Aşağıdakiler koddadır, derlenir, testleri geçer — ama **üründen hiçbir yol
onlara ulaşmaz**. Silmek veri göçü gerektirdiği için bekletiliyorlar.

| Ne | Nerede | Neden duruyor |
|---|---|---|
| `JobStatus` 6 değer (`workerSelected`, `inProgress`, `completed`, `rated`, `disputed` …) | `job.dart` | Kural 6: enum değeri silmek veri göçü. Canlıda o durumda ilan varsa **okunamaz** olur. Önce sayım şart. |
| `offers` koleksiyonu + `Offer` modeli + 2 repo | `jobs/data/*offer*` | Yazan UI yok; eski kayıtlar duruyor. CF `onOfferWritten` hâlâ dinliyor. |
| `selectOffer`, `cancelSelection`, `markStarted`, `confirmDone`, `reportDispute`, `withdrawDispute`, `markRated` | `job_repository.dart` (+ Firebase/Mock) | Arayüzde ve iki uygulamada duruyor; **yalnız kendi testleri çağırıyor**. |
| `customerConfirmedDone` / `artisanConfirmedDone` alanları | `job.dart` | Yazan yok; okunuyor. |
| Admin ihtilaf modülü | `features/admin/` | `disputed` üretilmiyor → pratikte boş liste. |
| ~56 CF referansı (`autoCompleteJobs`, `remindJobAutoComplete`, `onOfferWritten`, `lockOtherJobChats` …) | `functions/index.js` | Tetikleyen durum geçişi olmadığı için **sessizce hiç ateşlenmiyor**. |

> [!danger] Silmeden önce SAYIM
> `jobs` koleksiyonunda status dağılımı ve `offers` boyutu ölçülmeden hiçbiri
> silinmemeli. Sayım için canlı Firestore okuma erişimi gerekir
> (Firebase konsolu ya da servis hesabı anahtarı + `firebase-admin`).

## Geçişler: kim yazar? (TARİHSEL — bu geçişler artık tetiklenmiyor)

| Geçiş | Yazan | Nasıl |
|---|---|---|
| → `open` | İstemci | İlan oluşturma |
| `open` → `workerSelected` | İstemci (müşteri) | `selectOffer` |
| `workerSelected` → `open` | İstemci (müşteri) | Seçim iptali |
| → `completed` | İstemci (iki onay) **veya** CF | `autoCompleteJobs` |
| → `rated` | İstemci | `markRated`, değerlendirme sonrası |
| → `disputed` | İstemci | Sorun bildir |
| → `expired` | CF | Zamanlanmış |
| `completedAt` damgası | **Yalnız CF** | Kural istemciye kapatır |

## Tam akış — adım adım (TARİHSEL: 2026-08-08 öncesi)

> Aşağıdaki 7 adım **artık yaşanmıyor**. Eski kayıtları yorumlamak ve
> CF'lerin neden yazıldığını anlamak için saklanıyor.

### 1. İlan oluşur
Müşteri ilan açar. **Limit: aynı anda en çok 5 açık ilan**
(`AppConstants.maxOpenJobs`). CF `refreshOpenJobCount` sayacı tazeler.
`onJobCreated` uygun ustalara push gönderir.

### 2. Usta ilgi bildirir
Usta **teklif vermez, ilgi bildirir** — `offers` koleksiyonuna `pending` kayıt.
Teklif kimliği deterministiktir: `Offer.idFor(jobId, artisanId)` = `{jobId}__{artisanId}`
→ aynı usta ikinci kez yazarsa **günceller**, ikinci kayıt açılmaz.
`onOfferWritten` `offerCount`'u yeniden hesaplar (istemci sayaç yazmaz).

### 3. Müşteri sohbet açar
İletişimi **müşteri başlatır**. → [[Sohbet-Mimarisi]]

### 4. Müşteri ustayı seçer
`selectArtisanForJob()` (`jobs/application/select_artisan.dart`) — tek giriş
noktası, iki yerden çağrılır (ilan detayı + sohbet şeridi). Sırası:

1. Onay diyaloğu
2. `startChat()` — sohbet dokümanı hazır olmalı
3. `selectOffer()` — ilan `workerSelected`, seçilen teklif `accepted`,
   diğerleri `rejected`, `chatId` ilana yazılır
4. `markCustomerStarted()` — sohbeti ustaya açar

Ardından CF `onJobWritten`:
- Seçilen ustaya push
- **Diğer ustaların sohbetlerini kilitler** (`lockOtherJobChats`)
- Seçilen sohbete sistem mesajı düşer

> [!warning] Seç–iptal döngüsü freni
> 3. iptalden sonra ilan kapanır (`selectionCancelCount`). İstemci bu sayacı
> yazamaz; CF tutar.

### 5. İş yürür, taraflar onaylar
İki bayrak: `customerConfirmedDone`, `artisanConfirmedDone`.
İkisi de `true` → `completed`.

**Tek taraflı onay → 3 günlük sayaç.** CF `autoCompleteAt` yazar
(`AUTO_COMPLETE_DAYS = 3`) ve karşı tarafa push atar. `remindJobAutoComplete`
son 24 saatte bir kez hatırlatır. Süre dolarsa `autoCompleteJobs` işi
`completed` yapar ve `autoCompletedBySystem: true` denetim izi bırakır.

### 6. İş tamamlanır
CF `onJobWritten`:
- Ustanın `completedJobs` sayacı +1 (disputed'dan dönüşte tekrar artmaz)
- Sohbete sistem mesajı: "🎉 İş tamamlandı. Karşılıklı değerlendirme yapabilirsiniz."
- `completedAt` damgası

> [!important] Sohbet tamamlanınca KİLİTLENMEZ
> Taraflar teslim sonrası konuşabilmeli. Kapanma 7 gün sonra
> `archiveCompletedChats` ile olur. → [[Sohbet-Mimarisi]]

### 7. Değerlendirme
İki taraf da puanlar. İlk puan ilanı `rated` yapar. → [[Degerlendirme-Sistemi]]

## Anlaşmazlık

`canDispute` durumlarında taraflardan biri sorun bildirir → `disputed`,
yaşam döngüsü **donar**. Yalnız admin çözer (`adminResolveDispute`).
Alanlar: `disputeParty` (kim), `disputeReason` (neden).
→ [[Admin-Paneli]]

---
İlgili: [[Sohbet-Mimarisi]] · [[Degerlendirme-Sistemi]] · [[Cloud-Functions-Haritasi]] · [[Veri-Modelleri]]

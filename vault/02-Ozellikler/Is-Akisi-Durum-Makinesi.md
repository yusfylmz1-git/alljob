# İlan Yaşam Döngüsü

> [!info] Bu not eskiden "İş Akışı — Durum Makinesi"ydi
> Teklif topla → "Ustayı Seç" → tamamlama onayı → puanla zinciri
> **2026-08-08'de (oturum 82) kaldırıldı**, kalıntıları **2026-08-09'da
> (oturum 83) silindi.** Usta ilan sahibine doğrudan mesaj atar; anlaşma
> taraflar arasındadır. Eski akışın anlatımı için git geçmişine bak.

Model: `lib/data/models/job.dart` → `enum JobStatus`

## Durumlar — ÜÇ tane

```
   [oluştur] → open ──(süre dolar)──→ expired
                 │
                 └──(sahibi kaldırır)──→ cancelled
```

| Durum | Anlamı | Kullanıcıya görünen (`simpleLabelTR`) |
|---|---|---|
| `open` | Yayında, mesaj alabilir | "Yayında" |
| `cancelled` | Sahibi kaldırdı | "Kaldırıldı" |
| `expired` | Süresi doldu | "Süresi doldu" |

**İlan bir DUYURUDUR, iş takip aracı değil.** Bir ilana "usta atanmaz",
"tamamlandı" denmez, puanlama ilana değil KİŞİYE yapılır
(→ [[Degerlendirme-Sistemi]]).

## Bilinmesi gerekenler

`isActiveForOffers` — yalnız `open`. Usta feed'inde görünme koşulu.

`effectiveStatus` — alan `open` olsa bile süresi dolmuşsa `expired` sayar.
Süre dolumu **okuma anında** hesaplanır; ayrıca CF de yazar.

`canDelete` — her zaman `true`. Sahibi ilanını istediğinde siler; sohbetler
ilandan bağımsız yaşar, silme mesaj geçmişini götürmez.

`canEditAt(now)` — yalnız `open` + süresi dolmamış + yayından sonraki
**1 saat** içinde (`Job.editWindow`). Kural tarafında yalnız `open`
doğrulanır (createdAt ISO string; kural zaman aritmetiği yapamaz).

## Geçişleri kim yazar?

| Geçiş | Yazan |
|---|---|
| → `open` | İstemci (ilan oluşturma) |
| → `cancelled` | İstemci (sahibi) **veya** CF (`adminModerateJob` force_cancel) |
| → `expired` | CF · ayrıca istemci okuma anında hesaplar |
| `openCount` sayacı | **Yalnız CF** (`onJobWritten` → `refreshOpenJobCount`) |

> [!important] Açık ilan limiti (5)
> Kural motoru `count()` yapamaz → sayaç
> `users/{uid}/private/jobStats.openCount` içinde denormalize tutulur ve
> **yalnız CF yazar**. Neden gerekli: yayınlanan her ilan eşleşen TÜM
> ustalara bildirim gönderir; limitsiz kullanıcı platform çapında spam
> üretebilirdi. Günlük hak (10) CF'te kesilir — kural gün bilgisi tutamaz.

## Ne SİLİNDİ (oturum 83, 2026-08-09)

Kullanıcı canlı verinin test verisi olduğunu bildirdi → göç gerekmedi,
kalıntıların tamamı temizlendi.

| Katman | Silinen |
|---|---|
| Model | `JobStatus` 8 → **3** değer · 13 alan (`offerCount`, `selected*`, `chatId`, `*ConfirmedDone`, `autoCompleteAt`, `dispute*`) · `JobDisputeParty` · `JobDisputeReason` |
| Repo | `offers` katmanının tamamı (model + arayüz + 2 uygulama) · 9 metot (`selectOffer`, `cancelSelection`, `markStarted`, `confirmDone`, `markRated`, `reportDispute`, `withdrawDispute`, `watchAssignedJobs`, `watchJobByChatId`) |
| UI | `MyOffersScreen` · `/panel/offers` rotası · "İlgilendiğim" sekmesi · `_DisputeSheet` · admin hakemlik ekranı |
| Kural | `match /offers` bloğu · jobs bloğundaki 6 doğrulama fonksiyonu (1278 → 823 satır) |
| CF | `onOfferWritten` · `autoCompleteJobs` · `remindJobAutoComplete` · `adminResolveDispute` · `archiveCompletedChats` · `lockOtherJobChats` · `unlockJobChats` · `onJobWritten`'ın 3 dalı |

**Geriye uyum:** `JobStatus.fromString` tanımadığı değeri `open` sayar —
canlıda `workerSelected` yazan doküman kalmışsa ilan görünür kalır, çökmez.
`jobStatsBucket` eski durumları `jobsOther` kovasına atar (sayımdan
kaybolmasınlar). İkisinin de regresyon testi var.

**Bugün `onJobWritten`'ın tek işi:** açık ilan sayacını tazelemek
(`users/{uid}/private/jobStats.openCount` → kural MAX_OPEN_JOBS kapısı).

---
İlgili: [[Sohbet-Mimarisi]] · [[Degerlendirme-Sistemi]] · [[Cloud-Functions-Haritasi]] · [[Veri-Modelleri]]

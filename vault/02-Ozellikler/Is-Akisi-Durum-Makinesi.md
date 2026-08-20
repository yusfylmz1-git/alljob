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

## İlan feed'i — DÖRT ayrı yol, aynı elemeler

`jobs` koleksiyonu iş ilanını ve **ürün talebini** birlikte tutar; ayıran tek
şey `category == kProductRequestCategory`. Bu yüzden "açık ilanları getir"
demek yetmez, her tüketici süzmelidir.

| Yol | Süzen | İl | Meslek | Kendi ilanı | Talep |
|---|---|---|---|---|---|
| Push bildirimi | `onJobCreated` (CF) | ✅ | ✅ | ✅ | ✅ |
| "Yakındaki İşler" | `nearbyJobsProvider` → `matchesArtisan` | ✅ | ✅ | ✅ | ✅ |
| Ana sayfa + Keşfet | `visibleJobFeedProvider` | filtre | filtre | ✅ | ✅ |
| İlanlarım / Taleplerim | `MyJobsScreen._visible` | — | — | (yalnız kendi) | ayrık |

> [!warning] `openJobsProvider` HAM akıştır — ekrana bağlama
> İçinde ürün talepleri ve kullanıcının kendi ilanları durur. Ekranların
> beklediği süzülmüş liste `visibleJobFeedProvider`'dır. Ham akış yalnız
> türetilmiş provider'ların ortak kaynağıdır (tek sorgu, tek dinleyici) ve
> `.when` ile yükleme/hata durumu göstermek için okunur.
>
> 2026-08-20 kapalı test bulgusu: elemeler yalnız ilk iki satırda vardı. Ana
> sayfa şeridi ile Keşfet paneli ham akışa bağlıydı → testçi bölgesini
> tanımlamadan başka ilin ilanını gördü, kendi ürün talebi iş ilanları
> arasında listelendi. Regresyon: `test/ilan_feed_suzme_test.dart`.

**İl neden feed'de değil, filtrede?** Kullanıcının değiştirebilmesi gerekiyor
(komşu ilde çalışan usta mağdur olmasın). İl, Keşfet panelinde filtrenin
**varsayılan** değeri olarak tohumlanır (`myFeedProvinceProvider`, tek
seferlik `_provinceSeeded` bayrağıyla); kullanıcı başka il seçebilir veya
temizleyip hepsini görebilir.

**Meslek neden yalnız bildirimde?** Telefonu boş yere titretmemek için push
dardır; liste geniştir — usta kendi ilindeki piyasayı mesleği tutmasa da
görebilmeli. Daraltmak isteyen Keşfet'teki kategori filtresini kullanır.

**Talepler nerede görünür?** İki yer:

| Yer | Kim görür |
|---|---|
| Keşfet > Mağaza > **Talepler** sekmesi | Mağaza + müsait → **tamamı**; eksikse 3 örnek + davet kartı |
| Yan menü > **Taleplerim** | Yalnız kendi talepleri (`RoutePaths.myProductRequests`) |

Keşfet'in **İlanlar** sekmesinde talep YOKTUR; kitlesi satıcılardır.

## Ana sayfa — dört durum

Gövde herkeste aynıdır (2026-08-08: tek ürün, tek ana sayfa) ve müşteri
gözüyle kuruludur. `HomeForYou` (`home_for_you.dart`) üzerine **role duyarlı**
bir şerit ekler:

| Durum | Ana sayfada ek olarak |
|---|---|
| Müşteri | — (bölüm kendini gizler) |
| Müşteri + usta | "Sana Uygun İlanlar" — `nearbyJobsProvider` |
| Müşteri + mağaza | "İlindeki Talepler" — `productRequestsProvider` |
| Müşteri + usta + mağaza | ikisi de, ilanlar üstte |

> [!warning] Şerit HAM akıştan beslenmez
> `nearbyJobsProvider` kullanılır, `openJobsProvider` değil — yoksa usta ana
> sayfada başka ilin ilanını görür. Yenilemeye de eklenmelidir
> (`home_screen.dart` → `_refresh`), aksi hâlde aşağı çekmek bu bölümü
> tazelemez.

2026-08-20 kullanıcı bulgusu: usta ana sayfayı açtığında yalnız "İş İlanı Ver"
ve "usta bul" görüyordu; işini bulmak için Keşfet'e geçmesi gerekiyordu.
Regresyon: `test/rol_bazli_gorunum_test.dart`.

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

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
| Ana sayfa + Keşfet | `visibleJobFeedProvider` | — (vurgu) | — (vurgu) | ✅ | ✅ |
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

### Listede ELEME yok, VURGU var (2026-08-23)

Ana sayfa şeridi ve Keşfet > İlanlar **tüm ilanları** gösterir. Ustanın
mesleğine + bölgesine uyanlar ayrışır:

| Parça | Nerede |
|---|---|
| Ölçüt | `jobMatchesMeProvider` → `Job.matchesArtisan` (push ile **AYNI**) |
| Sıralama | `sortJobMatchesFirst` — uyanlar başa, grup içi sıra korunur |
| Görsel | `NearbyJobCard(matchesMe:)` → yeşil çerçeve + "Sana uygun" rozeti |

> [!warning] Otomatik il filtresi GERİ ALINDI
> 2026-08-20'de ustanın ili Keşfet filtresine **varsayılan** olarak
> tohumlanıyordu (`myFeedProvinceProvider` + `_provinceSeeded`). Bir sonraki
> turda kaldırıldı: usta piyasayı göremiyor, filtrenin kendiliğinden
> dolduğunu **fark etmiyor** ve "ilan yok" sanıyordu. Provider da silindi.
>
> Kullanıcının koymadığı daraltma, kullanıcının anlamadığı boşluk üretir.
> Regresyon: `test/ilan_uygunluk_vurgusu_test.dart`.

Rozet çakışması: kart tek rozet taşır. `isNearby` (aynı **ilçe**) daha
özeldir ve "Sana uygun"u zaten ima eder → önceliklidir.

`sortJobMatchesFirst` bağı kaynak indeksiyle çözer: `List.sort` kararlı
değildir, eşit grupta kartlar her çizimde yer değiştirir ve liste zıplar.

### Görmek ≠ yazabilmek (2026-08-23)

Liste herkese açık, **mesaj kapısı değil**. Usta tüm ilanları görür ama
yalnız kendi ilinde ve kendi mesleğinde olanlara yazabilir.

| Durum | Listede | Mesaj yazabilir |
|---|---|---|
| İl ✅ meslek ✅ | yeşil çerçeve | ✅ |
| İl ✅ meslek ❌ | düz kart | ❌ "… mesleği profilinizde yok" |
| İl ❌ | düz kart | ❌ "Bu ilan X ilinde; siz Y ilinde…" |
| **Ürün talebi** | Mağaza sekmesi | ✅ **bölge şartı YOK** |

**Sebep AYRI söylenir.** Eskiden tek satır "meslek veya hizmet bölgenizle
eşleşmiyor" yazıyordu; kullanıcı hangi alanı düzelteceğini bilmiyordu. İki
sorun tamamen farklı çözüm ister: biri **il değiştirmek** (tek il kuralı
yüzünden yıkıcı), diğeri **meslek eklemek** (zararsız). Uyarı ilanın ilini
de yazar — kullanıcı kendi ilini bilir, ilanınkini bilmez.

Uyarı **tıklamadan önce** de kartta durur ve çözüme götüren bir düğme taşır.

`Job.matchesArtisan` artık iki yarıdan TÜRETİLİR
(`matchesArtisanProfession` && `matchesArtisanArea`) — mantık kopyalanırsa
feed vurgusu, push bildirimi ve mesaj kapısı birbirinden ayrışır.

> [!note] Ürün talepleri bölgeden MUAF — bilinçli
> Hizmet fiziksel olarak yerinde verilir: usta Bursa'daki musluğu Ankara'dan
> tamir edemez. Ürün ise **kargoyla** gider. Bölge kapısını talebe koymak
> satıcının pazarını kendi iline hapsederdi. Talepte tek şart mağaza
> sahipliğidir.

**Meslek neden yalnız bildirimde eler?** Telefonu boş yere titretmemek için
push dardır; liste geniştir — usta piyasayı mesleği tutmasa da görebilmeli.
Daraltmak isteyen Keşfet'teki kategori/il filtresini **kendi eliyle** kullanır.

**Talepler nerede görünür?** İki yer:

| Yer | Kim görür |
|---|---|
| Keşfet > Mağaza > **Talepler** sekmesi | Mağaza + müsait → **tamamı**; eksikse 3 örnek + davet kartı |
| Yan menü > **Taleplerim** | Yalnız kendi talepleri (`RoutePaths.myProductRequests`) |

Keşfet'in **İlanlar** sekmesinde talep YOKTUR; kitlesi satıcılardır.

### Kapı ekranları — önizleme + davet

İki sekme "kapalı" durumda **boş uyarı göstermez**; birkaç gerçek kayıt +
davet kartı gösterir. Sayı ortaktır: `AppConstants.kapiOnizlemeSayisi` (3).

| Sekme | Kapı koşulu | Kapalıyken |
|---|---|---|
| Keşfet > İlanlar (misafir) | oturum | 3 ilan + **"Giriş yap"** |
| Keşfet > İlanlar (üye) | `hasArtisanProfile` | 3 ilan + "Usta profili aç" |
| Keşfet > Mağaza > Talepler | mağaza **ve** müsaitlik | 3 talep + davet |

Misafir daveti İKİ ADIMLIDIR: önce giriş, sonra usta profili. Kart yalnız bir
sonraki adımı gösterir — misafire "meslek ve bölge ekleyin" demek, henüz
hesabı yokken anlamsız bir talimattır.

> [!note] Neden boş uyarı değil?
> 2026-08-20: İlanlar kapısı yalnız "usta profili açın" yazan boş bir ekrandı.
> Kullanıcı **ne kaçırdığını göremediği** için profil açmak soyut bir talimat
> olarak kalıyordu. Talepler tarafında örnek gösterme deseni zaten vardı ve
> çalışıyordu; İlanlar sekmesi ona hizalandı.
>
> Sayı sıfır olamaz (değer görünmez), yüksek de olamaz (kapı anlamsızlaşır).
> Gizli sayı 0 ise kartta sayı YAZILMAZ — yanlış vaat olmasın.

> [!note] Misafir neden boş duvar görmüyor?
> Misafir aynı ilanları ana sayfa "Son İş İlanları" şeridinde ve "Hemen Lazım"
> listesinde ZATEN görebiliyor. Keşfet'te gizlemek bir şey korumuyor, yalnız
> aynı verinin iki yerde iki farklı davranışını üretiyordu.

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

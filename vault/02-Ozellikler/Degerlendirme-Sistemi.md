# Değerlendirme Sistemi

Çift taraflı: iş tamamlanınca **müşteri ustayı**, **usta müşteriyi** puanlar.

Model: `lib/data/models/review.dart` · Ekran: `features/review/presentation/review_screen.dart`

## Yön (`ReviewDirection`)

| Yön | Ek | Anlamı | Görünürlük |
|---|---|---|---|
| `customerToArtisan` | `c2a` | Müşteri → usta | **Herkese açık** — usta profilinde |
| `artisanToCustomer` | `a2c` | Usta → müşteri | **Yalnız ustalara** |

> [!important] Neden a2c gizli?
> Müşteri profili bir vitrin değildir. Düşük puanlı müşterinin hizmet alamaz
> hale gelmesi istenmiyor — puan ustalara bir sinyal, müşteriye bir damga
> değil.

## Doküman kimliği

```
reviews/{chatId}          → c2a (eski, yönsüz kayıtlarla aynı biçim)
reviews/{chatId}__a2c     → a2c
```

`ReviewDirection.docIdFor(chatId, dir)` üretir.

> [!note] Geriye uyumluluk
> Çift yönlü şemadan önce yalnız müşteri→usta vardı ve kimlik düz `chatId`'ydi.
> `fromString(null)` → `customerToArtisan`, yani **alan eksikse eski kayıt**
> sayılır. Bu yüzden c2a'ya ek verilmez.

`chatId` ilan bazlıdır (`..__{jobId}`) → aynı çift her iş için ayrı puan
verebilir. → [[Sohbet-Mimarisi]]

## İçerik

1–5 yıldız + hazır etiketler (olumlu/olumsuz). **Serbest metin yorum yoktur**
(PRD §3) — moderasyon yükünü ve hakaret riskini kaldırır.

## Açılma koşulu

`ReviewScreen` içinde:

```dart
final iAmParty = job.customerId == user.uid || job.selectedArtisanId == user.uid;
final jobDone  = job.status == completed || job.status == rated;
final unlocked = _isUpdate || (iAmParty && jobDone && job.selectedArtisanId == widget.artisanUid);
```

- **`_isUpdate` her zaman açar** — verilmiş puan düzeltilebilmeli
- `rated` de kabul edilir: ilk taraf puan verince ilan `rated` olur; yalnız
  `completed` aransaydı ikinci taraf değerlendirme yapamazdı

## Rota tuzağı

```
/review/:uid?jobId=...
```

`uid` **her iki yönde de USTANIN uid'idir**. Ekran kendisi çözer:

```dart
bool get _iAmArtisan => currentUser.uid == widget.artisanUid;
```

`_iAmArtisan` ise yön `a2c`'ye döner ve hedef müşteri olur. Müşterinin uid'i
**ilandan** okunur (`job.customerId`) — tek kaynak.

> [!warning] Bu ekran iki kez kırıldı
> 1. Müşteri uid'i `ref.read` ile sohbetten okunuyordu; stream ilk değerini
>    yaymadan `null` dönüyor, ekran "önce sohbet gerekiyor" deyip kullanıcıyı
>    geri çeviriyordu. → Artık `await ref.read(jobProvider(id).future)`.
> 2. Sohbetteki "Değerlendir" düğmesi yanlış provider'a bağlıydı ve hiç
>    çizilmiyordu; kullanıcı ekrana ulaşamıyordu.
>
> Ayrıntı: [[Bilinen-Tuzaklar]]

## Giriş noktaları

| Yer | Koşul |
|---|---|
| Sohbet — `_JobCompletionChatBar` | İş `completed` veya `rated` |
| İlan detayı | `job_detail_screen.dart` |

## Gönderim sonrası

1. `addReview(...)` — mevcut kayıt varsa **günceller** (form ön-dolu gelir)
2. `markRated(jobId)` — ilan `rated` olur (kritik değil, hata yutulur)
3. `ref.invalidate(artisanDetailProvider)` + `artisanReviewsProvider`
4. CF `onReviewWritten` — ustanın ortalama puanını ve yorum sayısını yeniden
   hesaplar (istemci ortalama yazmaz)

## Alan adı tuzağı

a2c kayıtlarında `customerDisplayName` alanı **yazan ustanın** adını taşır —
kayıt sahibinin görünen adıdır, hedefin değil. İsim şemadan miras; anlamı yöne
göre değişir.

---
İlgili: [[Is-Akisi-Durum-Makinesi]] · [[Sohbet-Mimarisi]] · [[Veri-Modelleri]]

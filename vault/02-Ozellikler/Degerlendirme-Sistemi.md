# Değerlendirme Sistemi

**KİŞİ BAZLI** (2026-08-08): herkes herkesi değerlendirebilir. Müşteri ustayı,
usta müşteriyi. İlan ya da sohbet ön koşulu **yoktur**.

Model: `lib/data/models/review.dart` · Ekran: `features/review/presentation/review_screen.dart`
Ortak blok: `features/review/presentation/widgets/review_cta.dart`

## Bir kişiye bir değerlendirme

```
reviews/rev_{yazan}__{hedef}
```

Kimlik çifte çakılıdır → aynı kişiye ikinci yazım **yeni kayıt açmaz, mevcut
kaydın üzerine gider**. Kısıtı kimliğin kendisi taşır; "daha önce yazmış mı"
diye sorgu gerekmez. Ekran da dilini buna göre kurar:
"Değerlendir" ↔ "Değerlendirmeyi Güncelle".

`reviewDocId(authorUid:, targetUid:)` üretir.

> [!note] Eski kayıtlar
> Kimlik önce `chatId` tabanlıydı (`{chatId}` / `{chatId}__a2c`). O kayıtlar
> Firestore'da **durmaya devam eder ve okunur**; yalnız yeni yazımlar `rev_`
> biçimini alır. `ReviewDirection.docIdFor` geriye uyum için duruyor.

## Yön (`ReviewDirection`)

| Yön | Ek | Anlamı |
|---|---|---|
| `customerToArtisan` | `c2a` | Müşteri → usta |
| `artisanToCustomer` | `a2c` | Usta → müşteri |

Yön artık **yalnızca "kim kimi puanladı"** bilgisidir; görünürlük ayrımı
YAPMAZ. Hangi alana hangi uid'in yazılacağını belirler (`artisanUID` /
`customerUID` şemadan miras).

> [!important] Görünürlük değişti
> Eskiden a2c (müşteri puanı) **yalnız ustalara** görünürdü — "müşteri profili
> vitrin değildir" gerekçesiyle. 2026-08-08'den beri **her profil aynı dili
> konuşur**: müşteri de aldığı puanı herkese açık gösterir.
> CF `ratingAsCustomer` + `reviewCountAsCustomer` alanlarını `users/{uid}`
> altına yazar (ikisi de yalnız CF'e ait — kural 3).

## İçerik

1–5 yıldız + hazır etiketler (olumlu/olumsuz). **Serbest metin yorum yoktur**
(PRD §3) — moderasyon yükünü ve hakaret riskini kaldırır.

## Açılma koşulu

**YOK.** Giriş yapmış, askıya alınmamış herkes yazabilir. İki kısıt kalır:
- kendini değerlendiremezsin (`customerUID != artisanUID`)
- kimlik senin uid'inle başlamalı (`rev_{benim_uid}__{hedef}`)

> [!warning] Kaldırılan koşul
> Kural eskiden `job.status in ['completed','rated']` istiyordu. İş akışı
> kaldırılınca (2026-08-08) hiçbir ilan o duruma geçmez oldu → değerlendirme
> **fiilen kilitlenmişti**. Kimse puan yazamıyordu.

## Giriş noktaları

| Yer | Not |
|---|---|
| Usta profili | `ReviewCta` — puan özeti + düğme |
| Müşteri profili (`/u/:uid`) | `ReviewCta` + `ReviewList` |

Rota: `/review/:uid` — `uid` puanı **ALAN** kişidir (usta ya da müşteri).
`jobId` sorgu parametresi KALKTI.

## Gönderim sonrası

1. `addReview(...)` — kimlik deterministik, varsa üzerine yazar
2. `ref.invalidate` → `artisanDetailProvider` · `artisanReviewsProvider` ·
   `reviewsForUserProvider` · `myReviewForProvider`
3. CF `onReviewWritten` — ortalamayı ve sayıyı yeniden hesaplar
   (istemci ortalama yazmaz — kural 3)

## Alan adı tuzağı

`customerDisplayName` alanı **yazanın** adını taşır (a2c'de bile). İsim
şemadan miras; `Review.authorDisplayName` getter'ı anlamı okunur kılar.
Yeniden adlandırmak veri göçüdür (kural 6).

---
İlgili: [[Sohbet-Mimarisi]] · [[Veri-Modelleri]] · [[Guvenlik-Kurallari]]

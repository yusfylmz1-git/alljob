# Ops: Maliyet duvarı (bütçe uyarısı + otomatik kesme)

Güncelleme: 2026-08-15 — CF yazıldı, Console adımları bekliyor.

Proje: `alljob1` · Bölge: `europe-west1`

---

## 0) Neden gerekli

Blaze planında **bütçe uyarıları harcamayı durdurmaz** — yalnız e-posta
gönderir. Google'ın hazır bir "100 $'da dur" düğmesi yoktur. Gerçek duvar
elle kurulur:

```
Cloud Billing bütçesi → Pub/Sub konusu → butceBekcisi (CF) → faturalandırmayı ayır
```

> [!warning] Kesme SERT bir durdurmadır
> Faturalandırma ayrılınca proje **tamamen durur**: Firestore okuma/yazma
> reddedilir, Auth çalışmaz, uygulama kullanıcılar için ölür. Geri açmak
> **manueldir** (Console → Billing → hesabı yeniden bağla) ve servislerin
> toparlanması dakikalar alır.
>
> Bu bir fren değil, **imdat frenidir**. Eşik bu yüzden normal faturanın çok
> üstünde (bu ölçekte beklenen fatura 0–5 $/ay).

## 1) Eşikler

| Kademe | Tutar | Ne olur |
|---|---|---|
| Uyarı | 5 $ | E-posta. Normal fatura 0–5 $ olduğu için bu "anormal bir şey var" sinyalidir. |
| Uyarı | 25 $ | E-posta. |
| Uyarı | 50 $ | E-posta. Müdahale için son rahat nokta. |
| **Kesme** | **100 $** | `butceBekcisi` faturalandırmayı ayırır. Uygulama durur. |

Kod tarafındaki eşik: `BILLING_KILL_USD = 100` (`functions/index.js`).
Bu sayı Console'daki bütçeden **bağımsız ikinci emniyettir** — bütçe
yanlışlıkla düşük kurulsa bile bu tutarın altında kesme yapılmaz.

## 2) Kurulum

Aşağıdaki adımlar **Console/gcloud** işidir; faturalandırma yetkisi ister.

### 2.1 Pub/Sub konusunu oluştur

Konu adı koddaki `BILLING_TOPIC` ile **birebir** aynı olmalı:

```bash
gcloud pubsub topics create butce-uyarilari --project alljob1
```

### 2.2 Bütçeyi oluştur

Console → **Billing → Budgets & alerts → Create budget**

1. **Scope:** yalnız `alljob1` projesi
2. **Amount:** `100` — **para birimi USD olmalı** (kod USD dışında kesme
   yapmaz, yalnız uyarır)
3. **Threshold rules:** `5%`, `25%`, `50%`, `100%` (actual spend)
   → 100 $'lık bütçede bunlar 5/25/50/100 $ demektir
4. **Manage notifications → Connect a Pub/Sub topic:**
   `projects/alljob1/topics/butce-uyarilari`

### 2.3 Servis hesabına faturalandırma yetkisi ver

CF'nin faturalandırmayı kapatabilmesi için runtime servis hesabına
**Billing Account Administrator** rolü gerekir.

Servis hesabı: `alljob1@appspot.gserviceaccount.com`

Console → **Billing → Account management → Permissions** → yukarıdaki
servis hesabını ekle → rol: **Billing Account Administrator**

> [!caution] Bu rol ne demek
> Projenin kendi faturalandırmasını kapatabilmesi demektir. Rol verilmezse
> kesme **sessizce başarısız olur** — o yüzden 2.5'teki testi mutlaka yap.

### 2.4 Cloud Billing API'sini aç

```bash
gcloud services enable cloudbilling.googleapis.com --project alljob1
```

### 2.5 Deploy

```bash
firebase deploy --only functions:butceBekcisi --project alljob1
```

DNS IPv6 sorunu çıkarsa (bkz. `OPS_BILLING_APPCHECK.md` §4):

```bat
set NODE_OPTIONS=--dns-result-order=ipv4first
```

## 3) Test — kesmeden

Gerçek kesmeyi tetiklemeden yolu doğrula. Eşiğin **altında** bir mesaj
yayınla; fonksiyon çalışmalı ama kesme yapmamalı:

```bash
gcloud pubsub topics publish butce-uyarilari --project alljob1 ^
  --message "{\"costAmount\":7,\"budgetAmount\":100,\"currencyCode\":\"USD\",\"alertThresholdExceeded\":0.05}"
```

Beklenen log (Console → Functions → butceBekcisi → Logs):

```
[bütçe] harcama=7 USD / bütçe=100 (eşik=0.05)
```

Kesme satırı **görünmemeli**. Görünüyorsa eşik yanlış.

> [!warning] Tam testi (costAmount ≥ 100) canlı projede yapma
> Faturalandırmayı gerçekten keser. Yetki doğrulaması gerekiyorsa test
> projesinde yap.

## 4) Kesme olduysa — geri açma

1. Console → **Billing → Manage billing account** → `alljob1` projesine
   faturalandırma hesabını yeniden bağla
2. Servislerin toparlanması birkaç dakika sürer
3. **Sebebi bul** — kesme boşuna olmadı. `adminBillingEvents`
   koleksiyonunda kesme kaydı vardır (`tur: kesme_denemesi`, harcama tutarı)
4. Sebep giderilmeden yeniden bağlamak aynı faturayı tekrar üretir

Kesme başarısız olduysa log şunu der:

```
[bütçe] KESME BAŞARISIZ — harcama sürüyor: ...
```

En sık sebep: 2.3'teki rol verilmemiş.

## 5) Maliyet riski — bu projedeki gerçek durum

2026-08-15'te kod tarandı. İki klasik risk incelendi:

| Risk | Bulgu |
|---|---|
| **Firestore sonsuz döngüsü** | **Yok.** 11 tetikleyici CF tarandı. Kendi koleksiyonuna yazan tek CF (`onArtisanProfileWritten`, `artisanProfiles`) idempotent çıkışla korunmuş: `if (a.certificateStatus === nextStatus) return`. `reports` yolunda iki tetikleyici var (`onReportWritten` + `onProductReportWritten`) — maliyeti 2× yapar ama döngü değil, ikisi de `reports`'a yazmıyor. |
| **SMS/OTP suistimali** | **Düşük.** Telefon doğrulama giriş yöntemi DEĞİL; `sendCode` oturum yoksa atar (`notSignedIn`) ve numarayı mevcut hesaba bağlar. Önünde ayrıca Play Integrity cihaz doğrulaması, Firebase'in numara-bazlı kotası ve "bir numara tek hesap" kuralı var. Bot akını için önce binlerce hesap açılması gerekir. |

Mevcut kod freni: `setGlobalOptions({maxInstances: 10})` — tüm CF'ler için
ortak ölçekleme tavanı. Ölçeklenme hızını sınırlar, toplam harcamayı değil.

## 6) Ek koruma: SMS bölge kısıtı (ayrı iş)

Ucuz ve uygulamayı hiç durdurmayan bir önlem:

Console → **Authentication → Settings → SMS region policy** → yalnız
**Türkiye (+90)** izinli.

Kodda karşılığı hazır: `PhoneVerificationException.regionBlocked`
(`phone_verification_repository.dart`) — bölge kapalıyken kullanıcıya net
Türkçe mesaj gösterilir.

## 7) Durum

| Madde | Durum |
|---|---|
| `butceBekcisi` CF (kod) | ✅ Yazıldı |
| Pub/Sub konusu | ⏳ Console — sizde |
| Bütçe + eşikler | ⏳ Console — sizde |
| SA faturalandırma rolü | ⏳ Console — sizde |
| `cloudbilling.googleapis.com` | ⏳ Sizde |
| Deploy | ⏳ Yetkiler sonrası |
| SMS bölge kısıtı | ⏳ Console — sizde |

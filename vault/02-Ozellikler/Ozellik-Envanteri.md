# Özellik Envanteri

`lib/features/` altındaki 21 modül. Hangi işi hangi klasörde arayacağını
bulmak için.

## Çekirdek pazaryeri

### `jobs` (21 dosya) — iş ilanları
Uygulamanın merkezi. İlan oluşturma, keşif, detay, ilgi bildirme, usta seçimi,
tamamlama onayı, anlaşmazlık.
- `application/select_artisan.dart` — usta seçiminin **tek** giriş noktası
- `presentation/job_detail_screen.dart` (1966 st)
- → [[Is-Akisi-Durum-Makinesi]]

### `chat` (5 dosya) — mesajlaşma
İlan bazlı sohbet, kilit, iletişim maskeleme, okunmamış sayacı.
- `chat_screen.dart` (2077 st) — projenin en büyük dosyası
- → [[Sohbet-Mimarisi]]

### `review` (2 dosya) — değerlendirme
Çift taraflı puanlama. → [[Degerlendirme-Sistemi]]

### `offers` — `jobs` içinde
Ayrı modül değil; `jobs/data/offer_repository.dart`.

## Kullanıcı & kimlik

### `auth` (15 dosya)
Google girişi, e-posta doğrulama, askı
kapısı, hesap silme.

### `artisan` (11 dosya)
Usta profili düzenleme (`artisan_profile_edit_screen.dart`, 1601 st), meslek
seçimi, hizmet alanı, müsaitlik takvimi, sertifika.

### `customer` (6 dosya)
Müşteri gösterge paneli, usta profili görüntüleme (1335 st).

### `profile` (2 dosya)
Birleşik profil sayfası (1457 st). **Tek hesap iki rol** — müşteri ve usta
görünümü aynı sayfada.

## Yan modüller

### `products` (10 dosya) — ürün satışı
Usta ikinci el / malzeme satar. Yayın CF üzerinden (`publishProduct`), durum
makinesi ayrı, moderasyon var.

### `staffing` (17 dosya) — eleman bulma
İki taraf: iş arayan (`staffWorkers`) ve eleman arayan (`staffNeeds`).
Pazaryerinden bağımsız akış.

### ~~`toolkit` — usta çantası~~ · KALDIRILDI (2026-08-07)
Hesap makineleri (alan, boya, fayans, maliyet, kâr, teklif, birim, süre),
AR ölçüm ve PDF teklif üretimi içeriyordu — 19 dosya / 3.537 satır.
**Üründen tamamen çıkarıldı** (kullanıcı kararı): rotalar, ekranlar, testler
ve `ar_flutter_plugin_plus` · `vector_math` · `share_plus` · `pdf` ·
`printing` bağımlılıkları silindi. Ana Sayfa'daki "Usta Araçları" bölümü ve
SSS kategorisi de kalktı.

### `tracking` (21 dosya) — takip merkezi
Kişisel iş/hatırlatma takibi. **Yerel SQLite** (`sqflite`), buluta yedekleme
opsiyonel (`users/{uid}/trackBackup`). Tekrarlayan kayıtlar, öncelik, etiket,
ek dosya, çöp kutusu.

> [!danger] `_dbName` sabitine dokunma → [[Bilinen-Tuzaklar]]

### `membership` (5 dosya) — Pro abonelik
Google Play IAP. Doğrulama CF `verifyMembershipPurchase` ile.
Ürün kimlikleri **eski marka adında** — değiştirilemez.

## Destek modülleri

| Modül | Dosya | İş |
|---|---|---|
| `admin` | 36 | Yönetim paneli → [[Admin-Paneli]] |
| `home` | 8 | Ana ekran, keşfet, vitrin |
| `notifications` | 5 | Bildirim kutusu, FCM push, tercihler |
| `safety` | 7 | Engelleme + şikayet |
| `favorites` | 6 | Favori ustalar / takip |
| `storage` | 2 | Firebase Storage sarmalayıcı |
| `onboarding` | 2 | İlk açılış tanıtımı (cihazda bir kez) |
| `legal` | 2 | Yasal metinler |
| `help` | 2 | Yardım / SSS |

## Modül seçim rehberi

| Aradığın | Bak |
|---|---|
| "İlan neden görünmüyor?" | `jobs` + [[Is-Akisi-Durum-Makinesi]] |
| "Mesaj gönderilemiyor" | `chat` + [[Guvenlik-Kurallari]] |
| "Puan güncellenmedi" | `review` + `onReviewWritten` CF |
| "Push gelmedi" | `notifications` + [[Cloud-Functions-Haritasi]] |
| "Giriş yapamıyor / askıda" | `auth` + claim'ler |
| "Foto yüklenmiyor" | `storage` + `storage.rules` |
| "Panel açılmıyor" | `admin` + yetenek sistemi |

---
İlgili: [[Katman-Mimarisi]] · [[Navigasyon-ve-Rotalar]] · [[Is-Akisi-Durum-Makinesi]]

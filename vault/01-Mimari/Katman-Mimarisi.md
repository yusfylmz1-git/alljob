# Katman Mimarisi

Özellik-öncelikli (feature-first) düzen. Katmanlar özelliğin **içinde** yaşar,
üstünde değil — böylece bir özelliği okumak için tek klasör yeter.

```
lib/
├── main.dart          → kullanıcı uygulaması girişi (Firebase init, push, hata kancası)
├── main_admin.dart    → admin paneli girişi (AYRI derleme hedefi)
├── app.dart           → MaterialApp + router + tema bağlama
├── firebase_options.dart
├── core/              → özelliğe bağlı olmayan ortak altyapı
├── data/              → paylaşılan modeller + mock veritabanı
└── features/          → 21 özellik modülü
```

## core/ — ortak altyapı

| Klasör | İçerik |
|---|---|
| `analytics/` | `app_analytics.dart` — olay kaydı sarmalayıcı |
| `config/` | çalışma zamanı yapılandırması, sürüm, backend seçimi |
| `constants/` | uygulama sabitleri (kategoriler, limitler) |
| `router/` | `app_router.dart` (506 satır) + `route_paths.dart` → [[Navigasyon-ve-Rotalar]] |
| `theme/` | renk paleti, aksan rengi, açık/koyu tema durumu |
| `utils/` | `contact_masker` (iletişim maskeleme), telefon biçimi, doğrulayıcılar |
| `widgets/` | 18 paylaşılan widget: buton, iskelet, hata görünümü, alt bar… |

> [!note] `contact_masker.dart`
> PRD §5 gereği sohbette telefon/e-posta/sosyal medya otomatik maskelenir.
> Platform dışına çıkışı engelleyen ticari kural — dokunmadan önce
> [[Mimari-Kararlar]] oku.

## data/ — paylaşılan katman

- `models/` — 20 model dosyası. Özelliğe değil **alana** ait oldukları için
  burada. → [[Veri-Modelleri]]
- `local/mock_database.dart` (563 satır) — bellek içi sahte veritabanı;
  Mock repository'lerin ortak deposu. → [[Repository-Deseni]]

## features/ — modül iç düzeni

Her modül aynı üç katmanı kullanır (hepsinde üçü birden olmayabilir):

```
features/<ad>/
├── data/           → repository arayüzü + Firebase/Mock uygulamaları + provider'lar
├── application/    → iş mantığı; UI'dan bağımsız, controller ve akış fonksiyonları
└── presentation/   → ekranlar
    └── widgets/    → yalnız o ekrana ait parçalar
```

**Bağımlılık yönü tek yönlüdür:**

```
presentation  →  application  →  data  →  (Firebase | Mock)
```

`data`, `presentation`'ı asla import etmez. Bu kural bozulursa test edilebilirlik
gider — `data` katmanı Flutter widget'larından bağımsız kalmalıdır.

### `application/` ne zaman gerekir?

Yalnız mantık birden çok ekranda paylaşıldığında veya birden çok repository'yi
sıraya dizdiğinde. Örnek:
`features/jobs/application/select_artisan.dart` — usta seçimi iki ayrı ekrandan
(ilan detayı + sohbet şeridi) çağrılır; onay diyaloğu → sohbet hazırlama →
`selectOffer` → `markCustomerStarted` sırası tek yerde durur.

Tek ekranın kullandığı basit mantık `presentation` içinde kalabilir.

## Modül büyüklükleri

| Modül | Dosya | Modül | Dosya |
|---|---|---|---|
| admin | 36 | products | 10 |
| jobs | 21 | home | 8 |
| tracking | 21 | safety | 7 |
| toolkit | 19 | customer | 6 |
| staffing | 17 | favorites | 6 |
| auth | 15 | chat | 5 |
| artisan | 11 | membership | 5 |
| | | notifications | 5 |

Kalanlar (help, legal, onboarding, profile, review, storage) 2'şer dosya.

> [!warning] Şişmiş dosyalar
> `chat_screen.dart` 2077 satır, `job_detail_screen.dart` 1966 satır.
> Bunlar tek ekran + o ekrana ait özel widget'ları barındırır. Değişiklik
> yaparken `grep` ile ilgili `class _` tanımını bul, dosyayı baştan okuma.

## İki giriş noktası

| Hedef | Giriş | Derleme |
|---|---|---|
| Kullanıcı uygulaması | `lib/main.dart` | `flutter build apk` / `web` |
| Admin paneli | `lib/main_admin.dart` | `flutter build web -t lib/main_admin.dart` |

İkisi aynı Firebase projesini kullanır; ayrım yetki katmanındadır.
→ [[Admin-Paneli]], [[Deploy-ve-Ortam]]

`main.dart` başlangıç sırası: Firebase init → App Check → Crashlytics kancası →
Türkçe tarih verisi → push arka plan işleyicisi → `runApp`.

---
İlgili: [[Repository-Deseni]] · [[Durum-Yonetimi]] · [[Ozellik-Envanteri]]

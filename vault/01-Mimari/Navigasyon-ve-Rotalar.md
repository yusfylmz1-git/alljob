# Navigasyon ve Rotalar

`go_router` kullanılır. İki dosya:

- `lib/core/router/route_paths.dart` — **tüm yollar sabit olarak burada**
- `lib/core/router/app_router.dart` (506 satır) — rota ağacı + `redirect` kapıları

> [!important] Kural
> Rota dizesini asla elle yazma. `RoutePaths.jobDetail(id)` kullan.
> Yeni rota eklerken önce `route_paths.dart`'a sabit/fonksiyon ekle.

## Yönlendirme kapıları (`redirect`) — sıra önemlidir

`app_router.dart` içindeki `redirect` her gezinmede çalışır ve **yukarıdan aşağı**
değerlendirilir. Sıra bir davranış sözleşmesidir:

1. **Splash** → `/` (ana ekran)
2. **Zorunlu güncelleme** — admin `minAppVersion` > yüklü sürüm ise her şey
   kilitlenir. Config henüz yüklenmediyse *fail-open* (ağ takılırsa kullanıcı
   splash'te asılı kalmasın).
3. **Onboarding** — cihazda bir kez, oturumdan bağımsız.
4. **Eski rota göçleri** — `/register` → `/login`, `/panel` → `/profile`
5. **Oturum kapısı** — `needsLogin` bölgeleri misafiri `/login`'e atar
6. **Bakım modu** — misafir için de geçerli (giriş açık kalır, admin girebilsin)
7. **Askıya alınmış hesap** — `user.suspended` ise `/suspended` dışına çıkılamaz

### Misafir neyi görebilir?

| Açık (misafir) | Kapalı (oturum ister) |
|---|---|
| Ana ekran, keşfet | `/panel/**`, `/profile/**` |
| Usta profilleri `/artisan/:uid` | `/chats/**`, `/review/**` |
| Ürün **detayı** `/products/:id` | `/jobs/**` (istisna: `/jobs/quick` vitrini açık) |
| Kolay İş vitrini `/jobs/quick` | `/favorites`, `/notifications`, `/tracking` |
| Yasal metinler, yardım | `/products/new`, `/products/mine`, `/products/:id/edit` |

## Rota tablosu

### Oturum & sistem
`/splash` · `/onboarding` · `/login` · `/register`→login · `/package-select` ·
`/suspended` · `/maintenance` · `/force-update`

### Ana akış
| Yol | Ekran |
|---|---|
| `/` | Ana ekran |
| `/explore` · `/explore?tab=&prof=` | Keşfet (sekmeli) |
| `/profile` · `/profile/edit` | Birleşik profil |
| `/profile/blocked` | Engellenenler |
| `/profile/notification-prefs` | Bildirim tercihleri |
| `/notifications` | Bildirim listesi |
| `/favorites` | Favoriler |

### İlan (jobs)
| Yol | Not |
|---|---|
| `/jobs/new` · `/jobs/new?kind=…` | `kind=quick` → Kolay İş · `kind=product` → **Ürün Talebi** |
| `/jobs/mine` | İlanlarım |
| `/jobs/quick` | Kolay İş vitrini (misafire açık) |
| `/jobs/:jobId` | İlan detayı |

### Mağaza (products)

Modül 2026-08-08'de kaldırılmış, **2026-08-10'da geri getirilmiştir**.
Plan: `vault/06-Test/PLAN-Magaza.md`.

| Yol | Not |
|---|---|
| `/products/new` · `/products/mine` | **Oturum ister** |
| `/products/:id/edit` | Oturum ister |
| `/products/:id` | Ürün detayı — **misafire açık** |
| `/artisan/:uid/products` | Bir kişinin vitrini (usta şartı yok) |

> Okuma misafire açık, yazma oturum ister. "Herkes satabilir" kararı satıcı
> *rolünü* kaldırdı, oturum şartını değil.

> [!warning] Rota sırası tuzağı
> `/jobs/new`, `/jobs/mine`, `/jobs/quick` mutlaka `/jobs/:jobId`'den **önce**
> tanımlanmalıdır. Aksi halde `:jobId` "new" dizesini ilan kimliği sanar.
> Aynısı `/products` için de geçerli. Bu, kodda da yorumla işaretlidir.

### Sohbet & değerlendirme
| Yol | Not |
|---|---|
| `/chats` | Sohbet listesi |
| `/chats/:chatId` | Sohbet ekranı |
| `/review/:uid?jobId=` | Değerlendirme. `uid` = **ustanın** uid'i, iki yönde de. → [[Degerlendirme-Sistemi]] |

### Usta paneli
`/panel/edit` · `/panel/edit?focus=<stepId>` · `/panel/jobs` · `/panel/offers` ·
`/panel/premium` · `/panel/notifications`

### Diğer modüller
| Alan | Yollar |
|---|---|
| Usta profili | `/artisan/:uid`, `/artisan/:uid/products` |
| Ürünler | `/products`, `/new`, `/mine`, `/:id`, `/:id/edit` |
| Eleman | `/staffing`, `/me`, `/needs/new`, `/needs/mine`, `/workers`, `/workers/:id`, `/needs` |
| Takip | `/tracking`, `/new`, `/trash`, `/backup`, `/:id`, `/:id/edit` |
| Yasal / yardım | `/legal`, `/legal/:id`, `/help` |

## Yeni rota eklerken

1. `route_paths.dart` → sabit veya üretici fonksiyon
2. `app_router.dart` → `GoRoute`. Parametreli kardeşi varsa **statik olanı öne** koy
3. Oturum gerekiyorsa `needsLogin` ifadesine ekle
4. Derin bağlantı hedefiyse: veriyi `getX()` (önbellek) ile değil `watchX()`
   (canlı akış) ile oku — önbellek boş olabilir. → [[Repository-Deseni]]

---
İlgili: [[Katman-Mimarisi]] · [[Durum-Yonetimi]] · [[Ozellik-Envanteri]]

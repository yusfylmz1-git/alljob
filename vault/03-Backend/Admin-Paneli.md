# Admin Paneli

**Ayrı bir uygulamadır.** Kullanıcı uygulamasıyla aynı kod tabanını ve aynı
Firebase projesini paylaşır, farklı giriş noktasından derlenir.

```bash
flutter build web -t lib/main_admin.dart
```

Kod: `lib/features/admin/` — 36 dosya (projenin en büyük modülü).

## Yetki modeli — üç katman

### 1. Rol (custom claim)
| Rol | Claim |
|---|---|
| Süper yönetici | `admin: true` + `role: 'superadmin'` |
| Moderatör | `admin: true` |

Claim'leri yalnız CF `adminSetRole` yazar. → [[Guvenlik-Kurallari]]

### 2. Yetenek (capability) — ince ayar
`AdminCapabilities` (`admin/data/admin_capabilities.dart`). Moderatörün ne
yapabileceği yetenek dizesi kümesiyle belirlenir:

```
reports.manage · users.read · users.suspend
jobs.read · jobs.moderate · artisans.read · artisans.moderate
reviews.moderate · stats.read · products.read · products.moderate
(+ superadmin/opt-in: products.purge · chats.read · audit.read ·
 staff.manage · config.manage · export.run · finance.manage)
```

Bu küme `DEFAULT_MODERATOR_CAPABILITIES` olarak **CF tarafında da** tanımlıdır.
İkisi paritede kalmalıdır — birine yetenek eklerken diğerini de güncelle.

Süper yönetici tüm yeteneklere sahiptir.

### 3. `enforceMode`
`false` = log-only geçiş dönemi (menü tam açık, ihlal yalnız loglanır).
`true` = yetenek zorlanır. Yeni yetenek eklerken önce log-only ile yayına
alıp gerçek kullanımı gözlemlemek için var.

`capsFieldMissing` — eski admin kayıtlarında yetenek alanı yok; varsayılan
moderatör kümesi uygulanır.

## Operatör zihinsel modeli (v3 UX)

| Öncelik | Sekme | Ne için |
|---|---|---|
| 1 | **Kullanıcılar** | Ana kişi dizini. Kart → **kişi hub** (kimlik, aktivite, not, usta vitrin araçları, askı) |
| 2 | **Şikayetler** | Günlük kuyruk; şikayet edilen/eden → kişi hub |
| 3 | **Usta vitrini** | Keşfet profilleri; kişi adı + vitrin kısayolları (asıl dosya hub'da) |
| 4 | İlanlar / Ürünler | İçerik moderasyonu |
| 5 | Destek / Bildirim / Platform | Operasyon |
| 6 | Kadro / Denetim / Sistem | Superadmin |

**Kişi hub:** `admin_person_hub.dart` → `showAdminUserActions`. Rol atama **yok**
(yalnız Kadro). Usta bayrakları + premium + belge burada ve vitrin listesinde.

**Yorumlar sekmesi yok.** Üründe serbest metin yorum yoktur (yıldız + etiket);
ayrı moderasyon kuyruğu menüde tutulmaz. Kod: `admin_reviews_screen.dart`
(devre dışı bırakıldı).

**Hesabım:** `admin_account_sheet.dart` — her admin kendi şifresini değiştirir
veya sıfırlama e-postası ister (`AuthRepository.changePassword`).

**Denetim:** `AuditEntry.actionLabelTR` + `detailSummary` + kısa UID; kategoriler
Kullanıcı / İçerik / Şikayet / Kadro / Sistem.

**Ürün kuyruğu:** `status + createdAt` indeksi yoksa istemci süzmeli fallback.

## Ekranlar

| Ekran | Dosya |
|---|---|
| Kabuk + yönlendirme | `admin_app.dart`, `admin_chrome.dart` |
| Gösterge paneli | `admin_dashboard_screen.dart` — kuyruklar + KPI + **dağılım içgörüleri** |
| İçgörü toplama | `admin_insights_repository.dart` — son ~400 job/usta/ürün/user örneklemi |
| **Kullanıcılar** (ana dizin) | `admin_users_screen.dart` + **`admin_person_hub.dart`** |
| 360° özet + notlar | `admin_user_overview.dart` (hub içine gömülü) |
| Şikayetler | `admin_reports_screen.dart` |
| Usta vitrini | `admin_artisans_screen.dart`, `admin_certificate_sheet.dart`, `admin_premium_sheet.dart` |
| İlanlar | `admin_jobs_screen.dart` |
| **Ürünler (Mağaza)** | `admin_products_screen.dart` — `pending_review` kuyruğu, `adminModerateProduct` |
| Değerlendirmeler | `admin_reviews_screen.dart` |
| ~~Anlaşmazlıklar~~ | **Kaldırıldı** (Tur B) |
| Duyuru | `admin_broadcast_screen.dart` |
| Destek | `admin_support_screen.dart` |
| Admin kadrosu | `admin_roster_screen.dart` |
| Denetim kaydı | `admin_audit_screen.dart` + `admin_audit_repository.dart` |
| Platform / ayarlar | `admin_platform_screen.dart`, `admin_settings_screen.dart` |
| Toplu plan (ücretsiz dönem bitişi) | `admin_bulk_plan_screen.dart` — yalnız superadmin |

Sayfalama: `paged_footer.dart` ortak bileşen.

## Repository deseni

10 admin repository, **hepsi yalnız Firebase** — mock yoktur, panel yalnız
canlı veriyle anlamlıdır. → [[Repository-Deseni]]

Provider deseni her alan için tekrarlar:
```
xRepositoryProvider  →  xProvider (Stream)  →  xFilterProvider (State)
                                             →  xControllerProvider
```

## Çalışma zamanı yapılandırması

`adminConfig` koleksiyonu → `AdminRuntimeConfig`. Uygulamayı **yeniden
yayınlamadan** değiştirilebilen ayarlar:

| Ayar | Etkisi |
|---|---|
| `minAppVersion` | Altındaki istemciler `/force-update` ekranına kilitlenir |
| `maintenanceMode` | Tüm kullanıcılar `/maintenance` ekranına (giriş açık kalır) |
| `premiumFreeDuringBeta` | Premium beta ücretsiz |
| `productsEnabled` | Mağaza ürün vitrini kill-switch |
| `productsForceReview` | Her yayın `pending_review` |

Kullanıcı uygulaması bunu `appRuntimeConfigProvider` ile canlı dinler ve
router `redirect` uygular. → [[Navigasyon-ve-Rotalar]]

> [!warning] Fail-open
> Config henüz yüklenmediyse zorunlu güncelleme **uygulanmaz**. Ağ takılırsa
> kullanıcı splash'te asılı kalmasın diye bilinçli seçim.

## Denetim kaydı

Her admin eylemi `adminAuditLogs`'a yazılır. Yazımı CF yapar; panel yalnız
okur. `adminLogExport` dışa aktarma da kendini loglar.

## Güvenlik notları

- Admin CF'leri **başta** yetki doğrular (`assertAdmin` / `assertSuperadmin`)
- `adminRebuildStats` 10 dakikalık kilit taşır (`_rebuildLock`) — pahalı işlem
- `adminRateLimits` koleksiyonu kötüye kullanımı sınırlar
- `adminGetChatTranscript` sohbet okuma yetkisi verir; arşivlenen (silinmeyen)
  sohbetler bu yüzden değerlidir → [[Sohbet-Mimarisi]]
- Davet PII'si yalnız süper yöneticiye açıktır

---
İlgili: [[Cloud-Functions-Haritasi]] · [[Guvenlik-Kurallari]] · [[Repository-Deseni]]

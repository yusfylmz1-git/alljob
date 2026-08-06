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
reports.manage · disputes.manage · users.read · users.suspend
jobs.read · jobs.moderate · artisans.read · artisans.moderate
reviews.moderate · stats.read · products.read · products.moderate
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

## Ekranlar

| Ekran | Dosya |
|---|---|
| Kabuk + yönlendirme | `admin_app.dart` (1051 st), `admin_chrome.dart` |
| Gösterge paneli | `admin_dashboard_screen.dart` |
| Şikayetler | `admin_reports_screen.dart` (1007 st) |
| Kullanıcılar | `admin_users_screen.dart` (839 st), `admin_user_overview.dart` |
| Ustalar | `admin_artisans_screen.dart`, `admin_certificate_sheet.dart` |
| İlanlar | `admin_jobs_screen.dart` |
| Anlaşmazlıklar | `admin_disputes_screen.dart` |
| Değerlendirmeler | `admin_reviews_screen.dart` |
| Duyuru | `admin_broadcast_screen.dart` (512 st) |
| Destek | `admin_support_screen.dart` |
| Admin kadrosu | `admin_roster_screen.dart` |
| Denetim kaydı | `admin_audit_screen.dart` |
| Platform / ayarlar | `admin_platform_screen.dart`, `admin_settings_screen.dart` |

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

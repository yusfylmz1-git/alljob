# PLAN — Mağaza modülü (ürün vitrini + ürün talebi)

Durum: 2026-08-10, plan aşaması. Kod yazılmadı.
Kaynak: eski ürün modülü `5513f23` · kaldırma `4476326` + `b6940ec`.

---

## Kullanıcı kararları

| Konu | Karar |
|---|---|
| Modül adı | **Mağaza** ("Ürünler" değil) |
| İki bölüm | 1) **Ürünler** (vitrin) · 2) **İlan Ver** (talep) |
| Kim satabilir | **Herkes** — usta olma şartı yok |
| Talep bildirimi | Aynı il + aynı kategori: **o kategoride yayında ürünü olanlar** + **tercih edenler** |
| Talep ömrü | **Tek sabit süre: 7 gün** (seçim yok) |

---

## Çekirdek karar: talep ayrı koleksiyon DEĞİL

Ürün talebi `productRequests` diye yeni bir koleksiyon olarak değil, mevcut
altyapının üzerine kurulur. Sebep: limit, süre dolumu, fan-out, moderasyon,
şikayet ve admin paneli `jobs` için zaten yazılmış ve **canlıda test edilmiş**.
Ayrı koleksiyon bunların hepsini ikinci kez yazmak demek.

**"Kolay İş" tam olarak böyle yapıldı** — ayrı sistem değil, `jobs` içinde
özel bir kategori. Aynı desen izlenir.

> Karar noktası (Aşama 3'te netleşecek): talep `jobs` içinde özel kategori mi,
> yoksa `products` yanında ince bir `productRequests` mi? İlki ucuz ama `jobs`
> semantiğini genişletir ("iş" değil "ürün" arıyor). Kod yazmadan önce
> `job.dart` ve `onJobCreated` okunup son karar verilir.

---

## Aşama 0 — Geri getirme (mekanik, düşük risk)

`5513f23`'ten birebir dönen 13 dosya, 4.964 satır:

```bash
git checkout 5513f23 -- lib/features/products lib/data/models/product.dart \
  test/products_lifecycle_test.dart docs/PRD_006_URUN_YASAM_DONGUSU.md
```

| Dosya | Satır |
|---|---|
| `docs/PRD_006_URUN_YASAM_DONGUSU.md` | 1366 |
| `product_edit_screen.dart` | 949 |
| `products_explore_panel.dart` | 484 |
| `product.dart` (model) | 473 |
| `firebase_product_repository.dart` | 320 |
| `product_detail_screen.dart` | 305 |
| `my_products_screen.dart` | 302 |
| `mock_product_repository.dart` | 300 |
| kalan 5 dosya | ~465 |

Sunucu tarafı `b6940ec`'ten alınır: 8 CF (~550 satır) + kurallar (~286 satır).
Bunlardan **ürüne ait olanlar**: `onProductWritten` · `publishProduct` ·
`updateProductContent` · `adminModerateProduct` · `onProductReportWritten` ·
`purgeRemovedProducts`. (Diğer 2'si staffing, GERİ GELMEZ.)

**Bu aşamada derleme YEŞİL OLMAZ** — Aşama 1 bitmeden analyze temizlenmez.

---

## Aşama 1 — Mimari uyum (asıl iş)

Modül silindikten sonra ürünün yarısı değişti. Sırayla kapatılacak sapmalar:

### 1.1 Sohbet kimliği — ⚠️ en kritik
`product_detail_screen.dart:50` `chatRepo.startChat(...)` çağırıyor.
Kimlik artık **rol bazlı değil, alfabetik** (`chatIdFor`, oturum 84).
Ürün detayından açılan sohbet, aynı kişiyle olan mevcut kutuya düşmeli —
ayrı kutu açarsa oturum 84'te kapatılan hata geri gelir.

### 1.2 `shop_completion.dart` SİLİNMİŞ
Eski kod "yayın öncesi vitrin doluluğu" kontrolü için bunu kullanıyordu
(PRD-006 §K9). Dosya artık yok.
→ **Karar: "herkes satabilir" olduğu için bu kontrol tamamen KALKAR.**
Vitrin doluluğu usta kavramıydı; satıcı rolü olmayan bir modelde anlamsız.

### 1.3 Ortak alanlar `users`'a taşındı
Ürün `ownerName` / `ownerPhotoUrl` denormalize ediyor. Kaynak artık
`artisanProfiles` değil `users`. `onProductWritten` denormalizasyonu buna
göre düzeltilir. (Sohbet balonlarında aynı desen zaten var: addan sohbet
dokümanına bakılıyor.)

### 1.4 Keşfet sekme çubuğu kaldırılmış
`_ExploreView` enum ve `ExploreTabBar` `4476326`'da silindi — Keşfet tek liste
oldu. Mağaza artık Keşfet'in içinde bir sekme DEĞİL, **kendi giriş noktası**.
→ Yan menü + alt bar yerleşimi kararı gerekiyor (Aşama 4).

### 1.5 Profil ekranı birleşti
"Dükkân" bölümü (`_ShopSection`/`_ShopThumb`) eski profil ekranına aitti.
Yeni ortak `core/widgets/profile_header.dart`'a yeniden bağlanır.
"Herkes satabilir" olduğu için bu bölüm **usta profilinde değil, her
kullanıcının profilinde** görünür.

### 1.6 Mock paritesi (CLAUDE.md kural 1)
`MockProductRepository` (300 st) geri geliyor; yeni talep metotları eklenirse
mock'a da yazılır ve **güvenlik kurallarının davranışını taklit etmeli**.

---

## Aşama 2 — "Herkes satabilir" sonuçları

Bu karar eski sistemin varsayımını değiştiriyor (eski: yalnız usta satar).

| Ne | Sonuç |
|---|---|
| Kural (`firestore.rules`) | Ürün oluşturma `isArtisan` şartından çıkar; `isEmailVerified` + `!isSuspended` kalır |
| Moderasyon yükü | **ARTAR** — 6 ürün CF'inin hepsi gerekli, kısılamaz |
| Şikayet | `ReportTarget.product` **bilerek silinmemiş**, yerinde ✅ |
| Admin yetki | `products.*` capability sabitleri geri gelir (`b6940ec`'te silinmişti) |
| Sahtecilik riski | En yüksek model. Ürün başına limit + günlük limit şart (`adminRateLimits` deseni hazır) |

---

## Aşama 3 — Talep ("İlan Ver") — YENİ KOD

Eski sistemde bu YOK. Tamamen yeni yazılacak tek parça.

### Fan-out alıcı listesi
`onJobCreated` (`functions/index.js:843`) deseni birebir kopyalanır.
Bugün ne yapıyor: `artisanProfiles`'ta `professions array-contains <kategori>`
→ `serviceAreas` içinde `province` eşleşenler → 500 limit → ilan sahibi hariç.

Mağaza karşılığı — **iki kaynağın birleşimi (union)**:
1. O kategoride **`status == active` ürünü olanlar** (davranıştan türer)
2. `users/{uid}` altında **talep bildirimi tercihi** o kategoriyi içerenler

> ⚠️ 500 limiti ve "kendi talebine bildirim gitmesin" kuralı korunur.
> Union alınırken uid tekilleştirilir (`Map` deseni `onJobCreated`'da hazır).

### Ömür
Sabit 7 gün. Mevcut süre dolumu mantığı kullanılır; kullanıcıya seçim
sunulmaz (Kolay İş'in 1 gün yaklaşımının aynısı).

### Tercih ekranı
Kullanıcı "şu kategorilerde talep bildirimi almak istiyorum" diyebilmeli.
Yeri: **Bildirim tercihleri ekranı** (`notification_prefs_screen.dart` —
`_PushDiagnosticsCard` zaten orada, ekran mevcut).

---

## Aşama 4 — Gezinme / yerleşim

Karar bekliyor: Mağaza'ya nereden girilecek?
- Alt bar 5 sekme dolu — altıncı eklenmez
- Seçenekler: yan menü satırı · Keşfet üst barında ikon (Yeni İlan ikonu gibi)
- İki bölüm (Ürünler | İlan Ver) Mağaza içinde sekme

---

## Aşama 5 — Doğrulama

- `flutter analyze` → 0
- `flutter test` → mevcut **586** + geri gelen 194 satır ürün testi + talep
  fan-out regresyon testi
- Regresyon şartı (CLAUDE.md kural 7): talep bildiriminin **yanlış kişiye
  gitmediğini** kanıtlayan test — alıcı listesi il+kategori dışına taşarsa
  test kırılmalı
- Kasa güncellemesi: `Cloud-Functions-Haritasi` · `Guvenlik-Kurallari` ·
  `Firestore-Semasi` · `Veri-Modelleri` · `Mevcut-Akislar`

---

## Riskler

| Risk | Önlem |
|---|---|
| **Bildirim yorgunluğu** — ürün talebi spam olursa kullanıcı push'u tamamen kapatır, **iş ilanı bildirimlerini de kaçırır** | Kategori+il kısıtı; günlük talep limiti; tercih ekranından çıkabilme |
| **"Herkes satabilir"** sahte/dolandırıcı ilan | 6 moderasyon CF'i tam gelir; rate limit; şikayet hattı hazır |
| `ProductStatus` 7 değerli — `JobStatus` 8→3 sadeleştirmesinin tersi | Tur B dersi: kullanılmayan durum eklenmesin. `pendingReview` gerçekten kullanılacak mı, karar ver |
| Eski PRD (1366 st) bugünkü mimariyi bilmiyor | Kanonik değil **referans** sayılır; çelişkide bugünkü kod kazanır |
| `product` apiValue'ları Firestore'a yazılmış olabilir | Enum sabitleri **değiştirilmez** (kural 6) |

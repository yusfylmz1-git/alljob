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
| Talep bildirimi | **GÜNLÜK ÖZET** (Yol 4) — anlık push YOK. Bkz. Aşama 3 |
| Talep ömrü | **Tek sabit süre: 7 gün** (seçim yok) |
| Yerleşim | Keşfet'te **üçüncü sekme**: Ustalar \| İlanlar \| Mağaza |

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

### 1.4 Keşfet sekme çubuğu — DÜZELTME
İlk planda "sekme çubuğu kaldırılmış" yazmıştım, **yanlış**. `4476326`'da
eski çubuk (`_ExploreView`/`ExploreTabBar`) silindi ama **2026-08-08'de yeni
bir `TabController` geldi**: `customer_dashboard_screen.dart:55` — bugün
Keşfet'te **Ustalar | İlanlar** iki sekmesi var (satır 109-124).

→ Mağaza **üçüncü sekme** olarak eklenir. Yeni yapı kurulmuyor, mevcut
`TabController(length: 2)` → `3` oluyor. Aşama 4'e bak.

### 1.5 Profil ekranı birleşti
"Dükkân" bölümü (`_ShopSection`/`_ShopThumb`) eski profil ekranına aitti.
Yeni ortak `core/widgets/profile_header.dart`'a yeniden bağlanır.
"Herkes satabilir" olduğu için bu bölüm **usta profilinde değil, her
kullanıcının profilinde** görünür.

### 1.6 Mock paritesi (CLAUDE.md kural 1)
`MockProductRepository` (300 st) geri geliyor; yeni talep metotları eklenirse
mock'a da yazılır ve **güvenlik kurallarının davranışını taklit etmeli**.

---

## Aşama 2 — TAMAMLANDI (2026-08-10)

Sunucu tarafı toplu geri geldi. **6 CF + 134 satır kural + 3 yetki.**

| Ne | Sonuç |
|---|---|
| 6 ürün CF'i | `functions/index.js`, export 41 → **47** |
| `cascadeProductsHideBits` | Tanım + **2 çağrı** (askı, profil gizleme) |
| Firestore kuralları | 840 → **973 satır**, dry-run derlendi ✅ |
| `products.read/moderate` | Varsayılan moderatör setinde |
| `products.purge` | **Varsayılan DIŞINDA** (geri dönüşsüz) |
| Hesap silme + storage | Zaten kapsıyordu, ek iş çıkmadı |

Kural bloğu **usta şartı içermiyordu** — `isSignedIn` + `isEmailVerified` +
`!isSuspended`. "Herkes satabilir" kararıyla uyumlu, olduğu gibi kondu.

### 🔴 DEPLOY BEKLİYOR

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions:onProductWritten,functions:publishProduct,\
functions:updateProductContent,functions:adminModerateProduct,\
functions:onProductReportWritten,functions:purgeRemovedProducts
```

Yalnız **ekleme** var, silme yok → etkileşimsiz ortamda takılmaz.
`adminSetUserSuspended` ve `adminSetArtisanFlags` de değişti (cascade
çağrısı eklendi) — onlar da yeniden deploy edilmeli.

> ⚠️ Modül kullanıcıya hâlâ **kapalı**: rotalar router'a bağlanmadı,
> Keşfet sekmesi yok (Aşama 4). Deploy güvenli — canlıda kimse ürün
> ekranına ulaşamaz.

---

## Aşama 2 notları — "Herkes satabilir" sonuçları

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

### 🔑 Bildirim modeli: GÜNLÜK ÖZET (Yol 4) — anlık push YOK

**Kullanıcı kararı.** Talep oluştuğunda push GİTMEZ. Günde bir kez
zamanlanmış CF çalışır ve kişi başına **tek** bildirim gönderir:

> *"Bursa'da bugün 4 yeni ürün talebi var"*

**Neden bu seçildi:** talep sayısı ne olursa olsun kişi başına bildirim
tavanı **günde 1**. Spam matematiksel olarak imkânsız — dolayısıyla ürün
talebi, iş ilanı bildirimlerinin değerini yiyemez. Risk tablosundaki
"bildirim yorgunluğu" maddesi bu kararla büyük ölçüde kapanır.

**Bedeli:** acil talepte geç kalır. Ürün talebi iş ilanı kadar acil
olmadığı için kabul edilebilir.

**Altyapı hazır:** `onSchedule` deseni canlıda çalışıyor —
`processScheduledCampaigns` (`functions/index.js:3471`, `every 5 minutes`).
Yeni CF aynı deseni kullanır, günlük periyotla.

#### Alıcı listesi
Anlık fan-out olmadığı için `onJobCreated` **kopyalanmaz**; onun yerine
özet CF'i gün içinde biriken talepleri toplar. Alıcı seçimi yine
**il + kategori**:

- O kategoride **`status == active` ürünü olanlar** (davranıştan türer,
  ekstra ayar gerekmez)
- Kendi talebini sayma; uid tekilleştir (`Map` deseni `onJobCreated`'da hazır)
- 500 alıcı tavanı korunur

> **Ertelendi:** "tercih edenler" ikinci kaynağı (eski Yol 3) şimdilik YOK.
> Varsayıma dayanıyor ("ürünü olmayan satıcı da bildirim ister") ve şu an
> test edilemez. Modül canlıya çıkıp "talep var ama satıcı az" denirse
> alıcı listesine ikinci kaynak eklenir — union yapısı buna hazır.

#### Kapatma
Kullanıcı özet bildirimini kapatabilmeli: **Bildirim tercihleri ekranı**
(`notification_prefs_screen.dart`) — tek anahtar satırı yeter.

### Ömür
Sabit 7 gün. Mevcut süre dolumu mantığı kullanılır; kullanıcıya seçim
sunulmaz (Kolay İş'in 1 gün yaklaşımının aynısı).

---

## Aşama 4 — Gezinme / yerleşim (KARAR VERİLDİ)

Mağaza, Keşfet'te **üçüncü sekme**:

```
KEŞFET:  [ Ustalar ]  [ İlanlar ]  [ Mağaza ]
                                      └─ Ürünler | İlan Ver
```

`customer_dashboard_screen.dart:55` — `TabController(length: 2)` → `3`.
Sekme çubuğu satır 109-124'te duruyor, üçüncü `Tab` eklenir.

**Dikkat — kelime çakışması:** alt barda zaten "İlanlar" sekmesi, Keşfet'te
de "İlanlar" sekmesi var. Mağaza içindeki bölüme de "İlan Ver" denirse
kullanıcı aynı kelimeyi üç yerde üç anlamda görür. Alt bölüm adı
netleştirilmeli — öneri: **"Ürünler | Talepler"** (eylem adı "İlan Ver"
düğmede kalır).

**Erişim kapısı:** İlanlar sekmesi bugün giriş + usta modu istiyor
(satır 658, 672). Mağaza'da böyle bir kapı **olmamalı** — herkes satabilir,
herkes bakabilir. Misafir de ürünleri görebilmeli (Ustalar sekmesi gibi).

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
| ~~**Bildirim yorgunluğu**~~ — büyük ölçüde KAPANDI | Günlük özet (Yol 4): kişi başına tavan **günde 1 bildirim**, talep sayısından bağımsız. Ek olarak il+kategori kısıtı, günlük talep limiti, tercihlerden kapatma |
| **Özet CF sessizce durursa** kimse fark etmez (anlık push olsa hemen belli olurdu) | `processScheduledCampaigns` gibi `logger` ile izlenir; talep var + özet gitmedi durumu loglanır |
| **"Herkes satabilir"** sahte/dolandırıcı ilan | 6 moderasyon CF'i tam gelir; rate limit; şikayet hattı hazır |
| `ProductStatus` 7 değerli — `JobStatus` 8→3 sadeleştirmesinin tersi | Tur B dersi: kullanılmayan durum eklenmesin. `pendingReview` gerçekten kullanılacak mı, karar ver |
| Eski PRD (1366 st) bugünkü mimariyi bilmiyor | Kanonik değil **referans** sayılır; çelişkide bugünkü kod kazanır |
| `product` apiValue'ları Firestore'a yazılmış olabilir | Enum sabitleri **değiştirilmez** (kural 6) |

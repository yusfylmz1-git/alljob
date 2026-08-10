# İlanda Hizmet — Play Store Öncesi Proje Analiz Raporu

| Alan | Değer |
|---|---|
| **Rapor tarihi** | 2026-08-10 |
| **Analiz eden** | Grok (proje yöneticisi + kullanıcı gözü) |
| **Dal** | `hemen-lazim` (origin'e göre **27 commit önde**) |
| **Paket kimliği** | `com.sepettehizmet.app` |
| **Sürüm** | `1.0.0+1` |
| **Marka** | İlanda Hizmet |
| **Backend** | Firebase (`alljob1`, `europe-west1`) |

> Bu rapor kod, mimari kasa (`vault/`), ilerleme notları ve Mağaza planından
> türetilmiştir. Cihaz üzerinde koşulmuş bir test değildir; **canlı cihaz
> doğrulaması hâlâ sizin sorumluluğunuzdadır.**

---

## 1. Yönetici özeti

**İlanda Hizmet**, Türkiye pazarına yönelik çift taraflı bir hizmet
pazaryeridir: müşteri ilan verir / usta arar; usta doğrudan mesaj atar;
anlaşma taraflar arasındadır. Tek hesap iki rol taşır.

Son iki haftada ürün **radikal sadeleşti** (iş akışı/teklif/usta seçimi
kalktı) ve ardından **Mağaza** modülü geri eklendi (Ürünler + Talepler).
Teknik omurga olgun; birim testleri geniş. Ancak Play Store'a çıkmak için
kritik **operasyonel, yasal ve moderasyon** boşlukları var.

### Play Store'a hazır mı?

| Boyut | Durum | Not |
|---|---|---|
| Çekirdek akış (giriş, ilan, sohbet, profil) | 🟡 | Kod hazır; **cihaz testi tam koşulmadı** |
| Mağaza (Ürünler + Talepler) | 🟡 | Aşama 0–4 kodda tamam; **CF/kural deploy + cihaz testi bekliyor** |
| Backend / CF / kurallar | 🔴 | Mağaza CF'leri + `adminBulkPlanUpdate` **canlıda eksik olabilir** |
| Yasal metinler | 🔴 | Hesap silme anlatımı **eski davranış** kalıntısı taşıyor |
| Admin / moderasyon | 🟡 | Ürün yetkisi var; **ayrı ürün moderasyon ekranı yok** |
| Yardım / onboarding | 🔴 | Mağaza **SSS'de yok**, onboarding'de yok |
| Store mağaza varlıkları | 🔴 | Play listing, Data Safety, ekran görüntüleri, imza AAB — süreç |
| Kalite (analyze / unit test) | 🟢 | Son not: 586 test · analyze 0 (oturum 84) |

**Sonuç:** *“Hemen yükle”* seviyesinde **değil**.  
**Hedef:** deploy → tam cihaz testi → yasal/metin düzeltmeleri → Play Console
paketi → closed testing → production.

---

## 2. Proje nedir? (baştan harita)

### 2.1 Tek cümle

Bölge + meslek ile ustayı bul; ilan ver; uygulama içi sohbetle anlaş; iş
bitince karşılıklı değerlendir. Yanında **Mağaza** (ürün sat / ürün talep et).

### 2.2 Teknoloji

| Katman | Seçim |
|---|---|
| İstemci | Flutter 3.38 / Dart 3.10 · Riverpod · go_router |
| Backend | Auth · Firestore · Storage · Cloud Functions · FCM · App Check · Crashlytics · Analytics |
| Faturalama | Play IAP (`usta_cepte_pro_monthly` — **asla değiştirilmez**) |
| Admin | Ayrı binary: `lib/main_admin.dart` → `alljob1-admin` |
| Tanıtım | Statik site `hosting/` → `www.ilandahizmet.com` |

### 2.3 Kullanıcı halleri

| Hal | Nasıl | Ne değişir |
|---|---|---|
| Misafir | Giriş yok | Keşfet + vitrin; yazma → login |
| Müşteri | Giriş (varsayılan) | İlan, mesaj, değerlendirme |
| Usta | Profilde usta vitrini | + İşler sekmesi (yakın ilanlar) + ilana mesaj |

### 2.4 Alt bar (5 sekme)

Ana Sayfa · Keşfet · İşler · Mesajlar · Profil

### 2.5 Keşfet (3 sekme) — Mağaza buraya eklendi

| Sekme | İçerik | Kapı |
|---|---|---|
| Ustalar | Usta arama | Yok |
| İlanlar | İş ilanları | Giriş + usta modu |
| **Mağaza** | **Ürünler \| Talepler** | **Yok** (misafir dahil bakabilir) |

### 2.6 Bilinçli ürün kararları (kritik)

1. **İlan = duyuru.** Usta atanmaz; “tamamlandı” denmez. Durum: `open` /
   `cancelled` / `expired`.
2. **Sohbet kişi başına TEK kutu.** Kimlik uid’leri alfabetik sıralar; `jobId`
   taşımaz.
3. **Değerlendirme kişi bazlı.** `rev_{yazan}__{hedef}` — ikinci kez
   günceller. **Şu an sohbet şartı yok** (sahte puan riski bilinçli açık).
4. **Premium beta ücretsiz** (`premiumFreeDuringBeta = true`).
5. **Mağaza: herkes satabilir** (usta şartı yok). Talepler günlük özet
   bildirimi alır (anlık push yok), süre sabit 7 gün.

---

## 3. Son büyük değişiklikler (zaman çizgisi)

| Dönem | Ne oldu |
|---|---|
| Oturum 82 | İş akışı (teklif/usta seç/tamamla) UI’dan kalktı; tek sohbet; kişi bazlı puan; marka “İlanda Hizmet”; Kolay İş; birleşik profil |
| Oturum 83 | Tur B: `JobStatus` 8→3; `offers` silindi; kurallar 1278→823; 5 CF silindi; tanıtım sitesi + admin yenilendi; test defteri v3 (395 adım) |
| Oturum 84 | Cihaz bulguları: sohbet tekilliği (alfabetik), müsaitlik kapısı, meslek kategorileri, hesap silme, Haftanın Ustası rotasyonu… |
| 2026-08-10 Mağaza | Plan + Aşama 0–4: ürün modülü geri, CF/kural, talep+digest, Keşfet 3. sekme |
| **Şu an (uncommitted)** | Ürün kategorileri meslek listesinden ayrılıyor (`product_category.dart`, 14 kategori) — **henüz commit edilmemiş** |

---

## 4. Mağaza modülü — derin inceleme

### 4.1 Tasarım

```
Keşfet → Mağaza
            ├─ Ürünler   → vitrin (products koleksiyonu)
            └─ Talepler  → “şu ürüne ihtiyacım var”
                           (jobs içinde category = product_request)
```

| Karar | Uygulama |
|---|---|
| Kim satar? | Herkes (e-posta doğrulu + askıda değil) |
| Talep nerede? | Ayrı koleksiyon YOK → `jobs` + `product_request` |
| Talep bildirimi | `sendProductRequestDigest` — her gün 19:00 TR, il+aktif ürün sahibi |
| Talep ömrü | Sabit 7 gün |
| Yayın | İstemci `draft→active` yazamaz → `publishProduct` CF |
| Limit | En fazla 50 aktif ürün / sahip |
| Sohbet | Ürün detayından `startChat` — alfabetik kimlik (tek kutu) |
| Profil | “Dükkân” bölümü her kullanıcı profilinde |

### 4.2 Kod envanteri

| Yol | Rol |
|---|---|
| `lib/features/products/` | Repo, ekranlar, kart, Mağaza sekmesi |
| `lib/data/models/product.dart` | 7 durumlu yaşam döngüsü |
| `lib/data/models/product_category.dart` | **Yeni** 14 ürün kategorisi (untracked) |
| `test/products_lifecycle_test.dart` | Durum / fiyat parse |
| `test/magaza_mimari_uyum_test.dart` | Sohbet tekilliği + mimari çiviler |
| `functions/index.js` | 6 ürün CF + digest (export toplamı **48**) |

### 4.3 Sunucu fonksiyonları (Mağaza)

| Fonksiyon | Tür | Görev |
|---|---|---|
| `onProductWritten` | trigger | `productsTotal` sayacı |
| `publishProduct` | callable | Taslak → yayında (limit + opsiyonel force review) |
| `updateProductContent` | callable | Yayındaki içerik güncelleme |
| `adminModerateProduct` | callable | Moderasyon / purge |
| `onProductReportWritten` | trigger | 3 şikayette auto-hide |
| `purgeRemovedProducts` | schedule | Soft-delete temizliği (~30 gün) |
| `sendProductRequestDigest` | schedule | Günlük talep özeti |

### 4.4 Mağaza — güçlü yanlar

- Mimari karar temiz: talep için tekerlek yeniden icat edilmedi (`jobs` reuse).
- Bildirim spam’i matematiksel olarak sınırlı (günde 1 özet / kişi).
- Yayın CF üzerinden → istemci “kendini yayına alamaz”.
- Sohbet tekilliği için özel test (`magaza_mimari_uyum_test`).
- Misafir okuyabilir; yazma router’da oturum ister.
- Kategori ayrımı (meslek ≠ ürün) doğru ürün kararı — **bitirilmeli**.

### 4.5 Mağaza — zayıf yanlar / riskler

| # | Risk | Seviye | Açıklama |
|---|---|---|---|
| M1 | **Deploy yok / eksik** | 🔴 | Mağaza CF + kurallar kodda; canlıda yoksa ürün oluşturma/yayın `permission-denied` / callable fail |
| M2 | **Admin ürün ekranı yok** | 🔴 | `products.moderate` yetkisi var ama panoda ayrı “Ürünler” kuyruğu yok; yalnız şikayet yolu |
| M3 | **“Herkes satabilir” sahtecilik** | 🔴 | UGC + mal satışı; Play “User-generated content” + dolandırıcılık riski yüksek |
| M4 | **Yardım/SSS Mağaza bilmiyor** | 🟠 | Kullanıcı “nasıl ürün satarım?” diye bakınca boş |
| M5 | **Onboarding Mağaza bilmiyor** | 🟠 | Yeni kullanıcı Mağazayı keşfetmek zorunda |
| M6 | **Tanıtım sitesi Mağaza demiyor** | 🟠 | Landing hâlâ yalnız hizmet dili |
| M7 | **pendingReview / forceReview** | 🟡 | 7 durumlu makine; force review admin/config’e bağlı — operasyon prosedürü net değil |
| M8 | **Kategori uncommitted** | 🟡 | 14 kategori değişikliği commit + deploy öncesi kilitlenmeli (apiValue göç riski) |
| M9 | **Digest sessizce ölürse** | 🟡 | Anlık push olmadığı için bozulma fark edilmez; log izleme şart |
| M10 | **Ödeme yok** | ℹ️ | Bilinçli; dolandırıcılık uyarısı SSS’de var, Mağaza için tekrarlanmalı |

### 4.6 Uncommitted çalışma (analiz anı)

```
M  searchable_select_field.dart
M  product_detail_screen.dart
M  product_edit_screen.dart
M  product_card.dart
M  products_explore_panel.dart
?? product_category.dart   ← 14 ürün kategorisi (meslek listesinden ayrıldı)
```

Bu değişiklik **doğru yönde**. Commit + test yeşili olmadan Play paketine
girmemeli.

---

## 5. Play Store çıkışı — profesyonel kontrol listesi

### 5.1 🔴 Bloklayıcılar (çıkmadan önce şart)

| # | Madde | Neden bloklar |
|---|---|---|
| P0-1 | **Mağaza CF + firestore.rules + indexes deploy** | Canlıda ürün akışı kırık olur |
| P0-2 | **`adminBulkPlanUpdate` deploy** (oturum 84 bakiyesi) | Admin “Toplu Plan” çalışmaz |
| P0-3 | **Yasal metinleri koda hizala** | `legal_docs.dart` hesap silmeyi **eski** anlatıyor (aktif iş iptal / anonimleştirme). Tur B’de ilanlar **siliniyor**. Play + KVKK riski |
| P0-4 | **Yasal URL tutarlılığı** | Kodda `kLegalBaseUrl = https://alljob1.web.app`; site `www.ilandahizmet.com`. Store’a verilecek URL tek ve 200 dönmeli |
| P0-5 | **Hesap silme uçtan uca** | Play zorunlu “Account deletion”. App Check + CF zinciri sahada kırılmıştı; debug token / prod App Check doğrulanmalı |
| P0-6 | **Release imzalı AAB** | `key.properties` var; Play debug imza reddeder. Upload key / Play App Signing doğrula |
| P0-7 | **Data Safety formu** | Kamera, bildirim, konum/il, Auth, Analytics, Crashlytics, IAP — doğru beyan |
| P0-8 | **Gizlilik politikası URL** | Canlı, marka uyumlu, silme prosedürü doğru |
| P0-9 | **Cihaz testi (en az kritik yollar)** | 395 adımlık defter hiç tam koşulmamış; Mağaza adımı defterde de **yok** |
| P0-10 | **UGC / Mağaza politikası** | Kullanıcı ürün ilanı = UGC. Şikayet + engelle + moderasyon yolu Play’de açıklanmalı; “herkes satar” riskini yönet |

### 5.2 🟠 Yüksek öncelik (1. hafta / closed test)

| # | Madde |
|---|---|
| H1 | Mağaza SSS + Yardım (nasıl satarım, talep nedir, ödeme yok, şikayet) |
| H2 | Admin: ürün moderasyon kuyruğu veya en azından `adminModerateProduct` UI |
| H3 | Onboarding’e Mağaza + Kolay İş slaytları |
| H4 | Tanıtım sitesine Mağaza cümlesi + Play badge (yayın sonrası link) |
| H5 | `RECORD_AUDIO` izni — Takip Merkezi kaldırıldı; hâlâ manifestte. Kullanılmıyorsa **kaldır** (Data Safety + inceleme sorusu) |
| H6 | Değerlendirme manipülasyonu: en az “sohbet şartı” v2 planı (şimdilik bilinçli açık) |
| H7 | Push: ürün digest tercih anahtarı sahada çalışıyor mu? |
| H8 | Force-update + maintenance runtime config smoke test |
| H9 | Crashlytics / Analytics prod’da olay görüyor mu? |
| H10 | `version: 1.0.0+1` — her store yüklemesinde versionCode artmalı |

### 5.3 🟡 Orta öncelik

| # | Madde |
|---|---|
| M-a | Eski Firestore `offers` / ölü alan temizliği (opsiyonel) |
| M-b | Eski sohbet kimlikleri göçü (liste üyelikle çalışır; temizlik opsiyonel) |
| M-c | iOS: `firebase_options` eski appId — iOS çıkışı yoksa ertele |
| M-d | Küfür/NSFW tarama (büyüme) |
| M-e | Özellik envanteri kasası güncel değil (staffing/tracking hâlâ yazıyor) |
| M-f | `kLegalUpdated = 15 Temmuz 2026` — içerik değişince güncelle |
| M-g | Closed testing grubu (iç ekip + 10–20 dış) |

### 5.4 🟢 İyi durumda olanlar

- Feature-first mimari + repository (Firebase/Mock) deseni
- Geniş birim test seti (586) ve regresyon disiplini
- Açılış kapıları: force-update, bakım, onboarding, askı
- İletişim maskeleme (sohbet)
- App Check + callable koruması (doğru yapılandırılınca)
- Tanıtım sitesi yasal sayfaları var (içerik doğruluğu ayrı konu)
- Hesap silme CF envanteri genişletilmiş
- Premium ürün kimliği bilinçli dondurulmuş
- Sohbet tek kutusu + müsaitlik kapısı son turda güçlendirilmiş

---

## 6. Yönetici gözü (admin / operasyon)

### 6.1 Admin paneli kapsamı

Özet · Şikayetler · Kullanıcılar · Ustalar · İlanlar · Yorumlar · Destek ·
Bildirim · Platform · (superadmin) Kadro · Denetim · Sistem · Toplu Plan

**Eksik:**

1. **Ürün moderasyon sekmesi** — yetenekler (`products.read/moderate/purge`)
   var; operatörün tıklayacağı kuyruk zayıf (şikayet üzerinden).
2. Mağaza metrikleri: `productsTotal` sayacı var; talep (`product_request`)
   ayrı KPI yok.
3. Digest CF sağlık paneli yok — “dün kaç özet gitti?” bilinmiyor.

### 6.2 Operasyon prosedürleri (yazılmalı)

- [ ] Sahte ürün / dolandırıcı satıcı: askıya al + ürün purge
- [ ] Toplu şikayet eşiği (3) sonrası inceleme SLA
- [ ] `productsForceReview = true` ne zaman açılır?
- [ ] Beta Premium kapanınca müsaitlik davranışı (kapı istemcide)
- [ ] App Check prod token / Play Integrity
- [ ] Olay iletişimi: `ilandahizmet@gmail.com`

### 6.3 Güvenlik / uyumluluk notları

| Konu | Değerlendirme |
|---|---|
| Sayaçları istemci yazmıyor | ✅ doğru |
| `lockedAt` CF | ✅ |
| Kural testleri | ❌ yok (bilinçli boşluk — en büyük teknik risk) |
| CF testleri | ❌ yok |
| Değerlendirme koşulsuz | ⚠️ ürün kararı; kötüye kullanıma açık |
| Herkes ürün satar | ⚠️ moderasyon yükü artar |
| Marka / paket eski adlar | ✅ bilinçli (veri kaybı engeli) |

---

## 7. Kullanıcı gözü (UX / algı)

### 7.1 İlk 5 dakika senaryosu

1. Store’dan indir → onboarding (Kolay İş / Mağaza **anlatılmıyor**).
2. Google ile gir → Keşfet: Ustalar | İlanlar | **Mağaza**.
3. Mağaza’ya girerse iki alt sekme net: **Ürünler | Talepler** — isimlendirme
   bilinçli iyi (üç yerde “İlanlar” çakışması engellenmiş).
4. “İlan Ver” (talep) oturum ister; misafir login’e düşer — beklenen.
5. Ürün satmak için nereden? Profil Dükkân / “Ürünlerim” / Mağaza FAB —
   **cihazda yol keşfedilebilir mi?** (test listesinde var).

### 7.2 Sürtünme noktaları

| Sürtünme | Etki |
|---|---|
| “İşler” sekmesi role göre farklı hedef | Yeni kullanıcıda kafa karışıklığı |
| İlanlar sekmesi usta ister; Mağaza istemez | Tutarlı ama öğrenme maliyeti |
| Ödeme yok | Güven + dolandırıcılık korkusu; metin net olmalı |
| Ürün talebi 7 gün, anlık bildirim yok | Acil alıcı için yavaş hissedebilir |
| Değerlendirme herkese açık + koşulsuz | Erken dönemde puan enflasyonu |
| Beta’da herkes Premium | Gerçek abonelik açılınca “neden kapandı?” şoku |
| Marka “İlanda Hizmet”, paket `sepettehizmet` | Kullanıcıya görünmez; destekte kafa karıştırabilir |

### 7.3 Güven algısı (Play incelemesi de buna bakar)

- Uygulama içi sohbet + iletişim maskeleme → iyi sinyal.
- Şikayet / engelle → var.
- Hesap silme → var (App Check doğru olmalı).
- Ürün satışı → **ek güvenlik vaadi gerekir** (ödeme yok, yüz yüze, dikkat).
- Yasal metin ile gerçek silme davranışı **çelişirse** güven kırılır.

---

## 8. Deploy durumu (kritik)

Kodda **48** Cloud Function export’u var. Son tam deploy notu (oturum 83):
**40** fonksiyon + kurallar.

Mağaza ile eklenenler (canlıda doğrulanmalı):

```
onProductWritten
publishProduct
updateProductContent
adminModerateProduct
onProductReportWritten
purgeRemovedProducts
sendProductRequestDigest
adminBulkPlanUpdate          ← oturum 84, Mağaza dışı
(+ askı/flag cascade dokunuşları)
```

**Sizin doğrulama komutları:**

```bash
firebase functions:list --project alljob1
# 48 (veya en az Mağaza 7 + bulk plan) görünmeli

firebase deploy --only firestore:rules,firestore:indexes --project alljob1
firebase deploy --only functions --project alljob1
# silme onayı isterse önce functions:delete ile planlı sil; --force kör kullanma
```

> Uyarı: CF deploy silme gerektirirse etkileşimsiz ortamda **durur**.

---

## 9. Test borcu

| Katman | Durum |
|---|---|
| Unit (Mock) | Güçlü (~586) · Mağaza mimari testleri var |
| Widget | Sınırlı |
| Firestore rules | **Yok** |
| Cloud Functions | **Yok** |
| Cihaz defteri v3 | 395 adım · **koşulmamış** · **Mağaza bölümü yok** |
| Admin / site | Defterde var · koşulmamış |

---

## 10. Karar matrisi — “ne zaman Play?”

| Aşama | Ne zaman | Ne yapılır |
|---|---|---|
| **A — Kapalı kapı** | Bugün | Deploy + yasal düzeltme + commit kategori + imza AAB |
| **B — Internal / closed** | A bittikten sonra | 2 hesapla uçtan uca + Mağaza + silme + şikayet |
| **C — Open testing** | B’de P0 bulgu kalmayınca | Listing + Data Safety + ekran görüntüleri |
| **D — Production** | C stabil + moderasyon operasyonu hazır | Soft launch (tek bölge opsiyonel) |

**Öneri:** Mağaza **açık** çıkılacaksa moderasyon UI veya en az şikayet
SLA’sı olmadan production’a **girmeyin**. Alternatif: ilk sürümde
`kProductsEnabled = false` ile Mağazayı kapatıp hizmet çekirdeğini çıkarmak
(bayrak kodda mevcut).

---

## 11. Sizin için yapılacaklar listesi (test + operasyon)

Aşağıdaki liste **sizin elinizle** işaretlenecek şekilde yazıldı.
Sıra öncelik sırasıdır.

### A. Operasyon (kod yazmadan)

- [ ] **A1.** `git status` — uncommitted kategori işini commit et veya bilerek bekle
- [ ] **A2.** Origin’e 27 commit push kararı (yedek / CI)
- [ ] **A3.** `firebase functions:list` → Mağaza CF’leri var mı?
- [ ] **A4.** Yoksa deploy: rules + indexes + functions
- [ ] **A5.** `adminBulkPlanUpdate` canlıda mı?
- [ ] **A6.** Release keystore ile `flutter build appbundle` → imzalı AAB
- [ ] **A7.** Play Console: uygulama kaydı, paket `com.sepettehizmet.app`, imza
- [ ] **A8.** Data Safety taslağı doldur
- [ ] **A9.** Gizlilik / KVKK / kullanım / hesap silme URL’lerini tarayıcıda aç (200 + doğru marka)
- [ ] **A10.** App Check: release build’de hesap silme denemesi (debug token’a güvenme)
- [ ] **A11.** `RECORD_AUDIO` gerçekten kullanılıyor mu? Hayırsa kaldırma işi aç
- [ ] **A12.** İletişim: `ilandahizmet@gmail.com` yanıt alıyor mu?

### B. Cihaz — çekirdek (kritik yol, ~45 dk)

İki hesap önerilir: **Hesap M** (müşteri) · **Hesap U** (usta).

- [ ] **B1.** Temiz kurulum: `flutter clean && flutter run` (release tercihen)
- [ ] **B2.** İlk açılış: splash → onboarding → login
- [ ] **B3.** Google giriş + e-posta doğrulama akışı
- [ ] **B4.** Misafir: Keşfet / Mağaza görünür; yazma login ister
- [ ] **B5.** Profil düzenle: ad, telefon, Instagram, web → kaydet → geri oku
- [ ] **B6.** Usta modu aç: meslek + il → kaydetmeden geri → mod kapanmalı (boşsa)
- [ ] **B7.** Müsaitlik anahtarı + (beta’da) Premium algısı
- [ ] **B8.** İlan ver (normal) → listede görün → detay → düzenle (1 saat penceresi)
- [ ] **B9.** Kolay İş ilanı → 1 gün süre
- [ ] **B10.** Usta eşleşen ilana mesaj → tek sohbet kutusu
- [ ] **B11.** Aynı kişiye profilden mesaj → **aynı kutu** (çift kutu YOK)
- [ ] **B12.** Müsaitlik kapalıyken ilanlar görünür, yeni sohbet engelli
- [ ] **B13.** Okunmamış rozet: mesaj gelince alt bar; okuyunca düşer
- [ ] **B14.** Bildirimler: liste + Temizle (onaylı)
- [ ] **B15.** Değerlendirme: yaz → tekrar gir → “Güncelle” + form dolu
- [ ] **B16.** Engelle / şikayet sheet
- [ ] **B17.** Favori / takip
- [ ] **B18.** İlan sil → sohbet **kalmalı**
- [ ] **B19.** Hesap sil (ikincil test hesabı) → Auth + veri; şikayet kaydı korunmalı
- [ ] **B20.** Force-update / bakım bayrakları (admin config) smoke

### C. Cihaz — Mağaza (yeni, ~40 dk)

- [ ] **C1.** Keşfet → **Mağaza** sekmesi var (3. sekme)
- [ ] **C2.** Alt sekmeler: **Ürünler | Talepler**
- [ ] **C3.** Misafir ürün listesini görür
- [ ] **C4.** “Ürün ekle / sat” yolu bulunur (boş durum CTA veya profil Dükkân)
- [ ] **C5.** Ürün formu: **14 ürün kategorisi** (meslek listesi DEĞİL); arama çalışır
- [ ] **C6.** Foto ekle (kamera + galeri izinleri)
- [ ] **C7.** Taslak kaydet → “Ürünlerim”de taslak
- [ ] **C8.** Yayınla → `publishProduct` başarılı → status **Yayında**
- [ ] **C9.** Keşfet Ürünler’de kart görünür (il/kategori filtre)
- [ ] **C10.** Başka hesap: ürün detay → “İletişime geç” → sohbet + şablon mesaj
- [ ] **C11.** Aynı satıcıyla daha önce sohbet varsa **tek kutu**
- [ ] **C12.** Duraklat / stok yok / satıldı / kaldır geçişleri
- [ ] **C13.** Ürün şikayet et → admin/report tarafı
- [ ] **C14.** Talepler → **İlan Ver** → kategori ürün talebi, süre 7 gün sabit
- [ ] **C15.** Talep usta “İlanlar” feed’ine **düşmez**
- [ ] **C16.** Talep Mağaza → Talepler’de görünür
- [ ] **C17.** (Ertesi gün 19:00 sonrası) digest bildirimi — mümkünse CF log ile
- [ ] **C18.** Bildirim tercihlerinde ürün özeti kapatılabiliyor mu?
- [ ] **C19.** Profilde **Dükkân** bölümü (kendi + başkasının)
- [ ] **C20.** 50 aktif ürün tavanı (mümkünse mock/unit; cihazda spot)
- [ ] **C21.** E-posta doğrulanmadan yayın / mesaj engeli
- [ ] **C22.** Askıdaki hesap ürün yazamaz

### D. Admin paneli (tarayıcı)

- [ ] **D1.** `main_admin` build + hosting erişimi
- [ ] **D2.** Özet sayaçlar mantıklı (jobs / products)
- [ ] **D3.** Şikayet: ürün tipi rozeti
- [ ] **D4.** Kullanıcı özeti: ürün sayısı
- [ ] **D5.** İlan moderasyonu
- [ ] **D6.** Kullanıcı askıya al → ürünler cascade gizlenir mi?
- [ ] **D7.** Toplu Plan (superadmin) kuru çalışma
- [ ] **D8.** Broadcast / kampanya
- [ ] **D9.** Runtime config: maintenance / min version
- [ ] **D10.** Ürün moderasyon **callable**’ı UI’dan tetiklenebiliyor mu? (hayırsa bulgu)

### E. Tanıtım sitesi / yasal

- [ ] **E1.** https://www.ilandahizmet.com açılır, logo doğru
- [ ] **E2.** Gizlilik / kullanım / KVKK / hesap silme sayfaları
- [ ] **E3.** Hesap silme metni **güncel kodla birebir** mi? (silinen ilanlar vb.)
- [ ] **E4.** Store’a verilecek URL’ler `alljob1.web.app` mı `ilandahizmet.com` mu — **tek seç**
- [ ] **E5.** “Android yakında Play’de” notu — yayın sonrası güncelle
- [ ] **E6.** Mağaza özelliği sitede anlatılacak mı? (karar)

### F. Kod / ürün işleri (geliştirme backlog — test değil)

Öncelik sırasıyla:

1. [ ] Uncommitted `ProductCategory` işini bitir + test + commit  
2. [ ] Mağaza CF/rules/indexes deploy  
3. [ ] `legal_docs.dart` + hosting HTML: hesap silme **gerçek** davranış  
4. [ ] `kLegalBaseUrl` / canonical tek domain  
5. [ ] Yardım SSS: Mağaza + talep + “ödeme yok”  
6. [ ] Admin ürün moderasyon UI (veya ilk sürümde `kProductsEnabled=false`)  
7. [ ] Onboarding slaytları (Mağaza + Kolay İş)  
8. [ ] `RECORD_AUDIO` temizliği  
9. [ ] Test defterine **13-Magaza.md** ekle (cihaz adımları C1–C22)  
10. [ ] Kasa notları: Özellik-Envanteri (staffing/tracking stale), CF haritası  

---

## 12. Hızlı bulgu özeti (tek bakışta)

### 🔴 Kritik

1. Mağaza sunucu tarafı **deploy doğrulanmadı**  
2. Yasal hesap silme metni **eski akış** anlatıyor  
3. Yasal base URL / domain **çift gerçeklik** riski  
4. Cihaz testi (çekirdek + Mağaza) **tamamlanmadı**  
5. Admin ürün moderasyon operasyonu **eksik**  
6. UGC ürün satışı + herkes satabilir → Play politika hazırlığı şart  

### 🟠 Yüksek

7. SSS / onboarding / landing Mağaza bilmiyor  
8. App Check prod hesabı silme  
9. Kullanılmayan `RECORD_AUDIO`  
10. 27 commit remote’a itilmemiş + uncommitted kategori  

### 🟡 Bilinçli kabul / sonra

11. Değerlendirme koşulsuz  
12. Premium beta herkese açık  
13. Rules/CF otomatik test yok  
14. Digest gecikmeli bildirim  

---

## 13. Sonuç ve tavsiye

Proje, **hizmet pazaryeri çekirdeği** açısından mimari olarak olgun ve son
sadeleştirme turları (Tur B, sohbet tekilliği, profil birliği) bilinçli ve
tutarlı. **Mağaza** planlı geri geldi; mimari kararlar (talep=`jobs`, günlük
özet, herkes satar, tek sohbet) profesyonel.

Play Store için asıl engel “kod yokluğu” değil:

1. **Canlıya alınmamış / doğrulanmamış sunucu yüzeyi**  
2. **Yasal metin sapması**  
3. **UGC + moderasyon operasyonu**  
4. **Koşulmamış cihaz testi**  
5. **Store paket süreci** (AAB, Data Safety, listing)

**Tavsiye edilen yol:**

> Önce A (deploy + yasal + commit) → B (internal test, özellikle C bloğu) →  
> moderasyon kararı (UI veya Mağazayı v1.0’da kapat) → closed testing →  
> production.

Bu dosya: `Grok/GrokTest.md`  
Cihaz bulgularınızı işaretledikçe `vault/06-Test/99-BULGULAR.md` ile
senkron tutmanız önerilir.

---

*Rapor sonu — 2026-08-10 · Grok analiz oturumu*

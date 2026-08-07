# Sepette Hizmet — Ajan Talimatları

Flutter + Firebase hizmet pazaryeri. 64K satır Dart, 5.1K satır Cloud Functions,
1.3K satır güvenlik kuralı.

## ⚡ ÖNCE KASAYA BAK

Kod tabanını taramadan önce **`vault/` mimari kasasını oku**. Kasa tam bir
analizden türetilmiştir; aynı bilgiyi yeniden çıkarmak için dosya taramak
gereksiz maliyettir.

**Giriş noktası:** `vault/00-BASLA-BURADAN.md` — görev tipine göre hangi notu
okuyacağını söyleyen bir tablo içerir.

Hızlı eşleme:

| Görev | Not |
|---|---|
| Sohbet / mesajlaşma | `vault/02-Ozellikler/Sohbet-Mimarisi.md` |
| İlan, teklif, usta seçimi | `vault/02-Ozellikler/Is-Akisi-Durum-Makinesi.md` |
| Değerlendirme / puan | `vault/02-Ozellikler/Degerlendirme-Sistemi.md` |
| Yeni ekran / rota | `vault/01-Mimari/Navigasyon-ve-Rotalar.md` |
| Veri okuma/yazma | `vault/01-Mimari/Repository-Deseni.md` |
| Cloud Function | `vault/03-Backend/Cloud-Functions-Haritasi.md` |
| Yetki / güvenlik | `vault/03-Backend/Guvenlik-Kurallari.md` |
| Firestore alanları | `vault/04-Veri/Firestore-Semasi.md` |
| **Hata ayıklama** | `vault/05-Operasyon/Bilinen-Tuzaklar.md` ← en değerli |

> Kasa koddan **türetilmiştir**, kodun yerine geçmez. Bir not dosya/fonksiyon
> adı veriyorsa, değiştirmeden önce o dosyayı aç ve hâlâ orada olduğunu
> doğrula.

**Kaldığımız yer:** `ILERLEME_NOTLARI.md` → "Son Durum" bölümü.

## 📍 Dosya konumları — ARAMA YAPMA, buradan bak

Bunlar sık gereken yollar. Grep/Glob turu açmadan önce bu tabloya bak.

| Ne | Yol |
|---|---|
| Rotalar | `lib/core/router/route_paths.dart` · `app_router.dart` |
| Backend anahtarı (mock/Firebase) | `lib/core/config/backend_config.dart` |
| Sabitler (`maxOpenJobs=5` vb.) | `lib/core/constants/app_constants.dart` |
| İletişim maskeleme | `lib/core/utils/contact_masker.dart` |
| Tema / renk | `lib/core/theme/app_palette.dart` |
| **Modeller (20 dosya)** | `lib/data/models/` |
| İş modeli + `JobStatus` | `lib/data/models/job.dart` |
| Sohbet modeli + `canSend()` | `lib/data/models/chat.dart` |
| Değerlendirme + `ReviewDirection` | `lib/data/models/review.dart` |
| Sohbet ekranı (2077 st) | `lib/features/chat/presentation/chat_screen.dart` |
| Sohbet repo (Firebase) | `lib/features/chat/data/firebase_chat_repository.dart` |
| Sohbet provider'ları | `lib/features/chat/data/chat_providers.dart` |
| İlan detayı (1966 st) | `lib/features/jobs/presentation/job_detail_screen.dart` |
| İlan provider'ları | `lib/features/jobs/data/job_providers.dart` |
| **Usta seçimi (tek giriş)** | `lib/features/jobs/application/select_artisan.dart` |
| Değerlendirme ekranı | `lib/features/review/presentation/review_screen.dart` |
| Kimlik doğrulama | `lib/features/auth/application/auth_controller.dart` |
| **Tüm CF'ler (51 adet)** | `functions/index.js` (tek dosya, 5127 st) |
| Güvenlik kuralları | `firestore.rules` (1278 st) |
| Admin girişi | `lib/main_admin.dart` · `lib/features/admin/` |

**Modül → klasör:** admin · artisan · auth · chat · customer · favorites · help ·
home · jobs · legal · membership · notifications · onboarding ·
profile · review · safety · storage
→ hepsi `lib/features/<ad>/{data,application,presentation}/`

## 💰 Token tasarrufu — çalışma biçimi

1. **Önce kasa/tablo, sonra kod.** Yukarıdaki tabloda yol varsa doğrudan
   `Read` et; `Glob`/`Grep` turu açma.
2. **Büyük dosyaları parça oku.** `chat_screen.dart` ve `job_detail_screen.dart`
   2000 satır — `offset`/`limit` ile ilgili bölümü oku, baştan sona okuma.
   İlgili sınıfı bulmak için `grep -n "class _AdiniBildigim"` yeterli.
3. **Alt ajan (Task/Agent) açma** — kullanıcı açıkça istemedikçe. Her ajan
   bağlamı sıfırdan kurar; bu plandaki en pahalı yoldur.
4. **Doğrulama tek komutta.** `flutter analyze` + `flutter test` çıktısını
   `tail` ile kısalt; tüm test listesini bağlama alma.
5. **Tekrar okuma yok.** Edit ettiğin dosyayı "kontrol için" yeniden `Read`
   etme — Edit başarısız olsaydı hata verirdi.

## Komutlar

```bash
flutter analyze          # değişiklikten sonra: "No issues found!" olmalı
flutter test             # 319 test, ~35 sn
flutter test test/jobs_test.dart
```

Deploy komutları ve tuzakları: `vault/05-Operasyon/Deploy-ve-Ortam.md`

## Değişmez kurallar

1. **Mock paritesi.** Repository arayüzüne metot eklersen `Firebase*` **ve**
   `Mock*` uygulamalarının ikisini de yaz. Mock ayrıca güvenlik kurallarının
   davranışını taklit etmelidir.
2. **Kural + istemci birlikte.** `ChatThread.canSend()` ile `firestore.rules`
   içindeki `senderMayWrite()` aynı mantığı uygular; biri değişirse diğeri de
   değişir.
3. **Sayaçları istemci yazmaz.** Ortalama puan, `offerCount`, `completedJobs`,
   okunmamış sayacı — hepsi Cloud Function'a aittir.
4. **`lockedAt` istemciye kapalı.** Kilidi yalnız CF koyar.
5. **Hassas veri `users/{uid}/private/` altına.** Ana kullanıcı dokümanı
   herkese açık okunur; Firestore alan bazlı gizleme yapamaz.
6. **Enum `apiValue` = Firestore değeri.** Enum sabitini yeniden adlandırmak
   veri göçüdür.
7. **Regresyon testi.** Hata düzeltince testini yaz — hem düzeltmenin
   çalıştığını hem de fazlasını yapmadığını doğrulayan çift test.

## Asla değiştirilmeyecek sabitler

| Sabit | Dosya |
|---|---|
| `kProMonthlyProductId = 'usta_cepte_pro_monthly'` | `membership/billing_config.dart` |

Marka "Usta Cepte" → "Sepette Hizmet" değişti; bu kimlikler bilerek eski
adında. Değiştirmek kullanıcı verisi/satın alma kaybettirir.

## Dil

Kod yorumları, test adları, kullanıcıya görünen metinler **Türkçe**. Enum
`labelTR` getter'ları modelde durur, UI'da değil.

## Kasayı güncel tutma

Mimari bir değişiklik yaptığında (yeni koleksiyon, yeni CF, durum makinesi
değişikliği, yeni katman kuralı) ilgili kasa notunu **aynı commit'te**
güncelle. Ölçüt: *"bu değişikliği bilmeyen biri yanlış kod yazar mı?"*

Oturum bazlı ilerleme kaydı kasada değil, kökteki `ILERLEME_NOTLARI.md`
dosyasındadır.

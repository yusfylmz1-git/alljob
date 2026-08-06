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
| `_dbName = 'usta_cepte_tracking.db'` | `tracking/data/sqflite_tracking_repository.dart` |
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

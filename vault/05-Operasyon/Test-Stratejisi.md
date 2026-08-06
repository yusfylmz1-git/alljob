# Test Stratejisi

**319 test, 33 dosya.** Hepsi Mock repository üzerinden koşar — emulator, ağ,
kimlik doğrulama gerekmez.

```bash
flutter test                    # tümü (~35 sn)
flutter test test/jobs_test.dart
flutter analyze                 # önce bu
```

## Kapsam dağılımı

| Dosya | Test | Alan |
|---|---|---|
| `admin_test.dart` | 54 | Yetenek sistemi, moderasyon, denetim |
| `jobs_test.dart` | 48 | **İş akışı, sohbet kimliği, seçim, değerlendirme** |
| `toolkit_test.dart` | 39 | Hesap makineleri (saf fonksiyon) |
| `tracking_test.dart` | 28 | Takip merkezi, tekrarlama, yedekleme |
| `artisan_search_test.dart` | 14 | Arama ve filtre |
| `chat_list_test.dart` | 12 | Sohbet listesi |
| `products_lifecycle_test.dart` | 11 | Ürün durum makinesi |
| `my_profile_test.dart` · `staffing_test.dart` · `dual_role_test.dart` · `chat_review_test.dart` · `widget_test.dart` | 9'ar | — |
| Kalan 21 dosya | 1–6 | Nokta atışı |

Ortak yardımcı: `test/helpers/mock_backend.dart`

## Neyi test ediyoruz?

✅ **İyi kapsanan**
- İş akışı durum geçişleri ve kapıları (`canSelectArtisanFor`, `canSend`)
- Deterministik kimlik üretimi (sohbet, teklif, değerlendirme)
- Model serileştirme roundtrip (`toMap`/`fromMap`)
- Sayaç tutarlılığı (`offerCount` artar/azalır)
- Geriye uyumluluk (eksik alan → varsayılan)
- Saf hesaplama (toolkit, tarih hesapları, sürüm karşılaştırma)
- Admin yetenek mantığı

⚠️ **Kapsanmayan — bilinçli**
- **Firestore güvenlik kuralları.** Test edilmiyor; emulator + `@firebase/rules-unit-testing`
  gerekir. Kural değişikliği **elle** doğrulanmalı → en büyük risk alanı
- **Cloud Functions.** 5.127 satır, sıfır test
- **Gerçek Firebase entegrasyonu.** Mock parite varsayımına dayanıyoruz
- Çoğu ekranın widget testi (büyük ekranlar test edilmiyor)

> [!danger] En büyük boşluk
> Kural + CF birlikte 6.400 satır ve **hiç testi yok**. Bu katmanlarda
> değişiklik yaparken elle doğrulama şart. Yanlış kural sessizce her şeyi
> `permission-denied` yapabilir. → [[Bilinen-Tuzaklar]]

## Test yazma deseni

```dart
test('davranışın Türkçe tarifi', () async {
  final db = MockDatabase();
  final jobs = MockJobRepository(db);
  final chats = MockChatRepository();

  final jobId = await jobs.createJob(_sampleJob());
  // ... eylem
  expect(sonuç, beklenen);
});
```

Kurallar:
- **Test adı Türkçe ve davranış anlatır** — "canSend: usta müşteri başlatmadan
  yazamaz" gibi. Metot adı değil, kural.
- `_sampleJob()` / `_sampleOffer()` fabrikaları kullan, elle model kurma.
- Grup adı alanı tarif eder: `group('İlan bazlı sohbet kimliği', ...)`

## Regresyon testi ne zaman şart?

Bir hata düzeltince **o hatanın testini yaz**. Örnek çift:

```dart
test('markCustomerStarted: müşteri hiç yazmadan işi verirse seçilen usta
      yine de yazabilir', ...)      // düzeltmenin çalıştığını doğrular

test('markCustomerStarted kilidi AÇMAZ: kilitli sohbette kimse yazamaz', ...)
                                    // düzeltmenin fazlasını yapmadığını doğrular
```

> [!tip] İkinci test önemlidir
> Bir izni açan düzeltme, açmaması gereken kapıyı da açmış olabilir. Pozitif
> testin yanına **negatif** testi de yaz.

## Mock paritesi — testin geçerlilik şartı

Testler Mock'a güvenir; Mock canlıdan saparsa test yanlış güven verir.

Mock, **kuralların davranışını taklit etmelidir**. Örnek: `MockChatRepository`
içinde usta mesajı `customerStarted` açmaz — çünkü Firestore kuralı da açmaz.
Bu davranış `jobs_test.dart` içinde açıkça test edilir ("Usta yazsaydı bayrak
açılmamalı (kural zaten reddeder; mock paritesi)").

→ [[Repository-Deseni]]

## Bilinen gürültü

Test çıktısında görülür, zararsız:
```
PushService.registerFor hatası: [core/no-app] No Firebase App '[DEFAULT]'
```
Test ortamında Firebase başlatılmaz; push servisi zarifçe başarısız olur.

---
İlgili: [[Repository-Deseni]] · [[Bilinen-Tuzaklar]] · [[Deploy-ve-Ortam]]

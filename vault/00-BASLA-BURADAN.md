# 🏠 Sepette Hizmet — Mimari Kasa

> **Bu kasanın amacı:** kod tabanını her oturumda yeniden taramadan çalışabilmek.
> 64.000 satır Dart + 5.100 satır Cloud Functions + 1.300 satır güvenlik kuralı
> var. Tümünü okumak her seferinde büyük bir maliyet; bu kasa o maliyeti bir
> kereye indirir.

**Son tam analiz:** 2026-08-06 · commit `60a84e1` (`hemen-lazim` dalı)

---

## ⚡ Ajan için: nereden okumalı?

Görevin tipine göre **yalnız ilgili notu** aç. Hepsini okuma.

| Görev | Önce oku | Sonra |
|---|---|---|
| Sohbet / mesajlaşma | [[Sohbet-Mimarisi]] | [[Is-Akisi-Durum-Makinesi]] |
| İlan, teklif, usta seçimi | [[Is-Akisi-Durum-Makinesi]] | [[Sohbet-Mimarisi]] |
| Değerlendirme / puan | [[Degerlendirme-Sistemi]] | [[Is-Akisi-Durum-Makinesi]] |
| Yeni ekran / rota | [[Navigasyon-ve-Rotalar]] | [[Katman-Mimarisi]] |
| Veri okuma/yazma | [[Repository-Deseni]] | [[Firestore-Semasi]] |
| Cloud Function | [[Cloud-Functions-Haritasi]] | [[Guvenlik-Kurallari]] |
| Yetki / güvenlik | [[Guvenlik-Kurallari]] | [[Cloud-Functions-Haritasi]] |
| Admin paneli | [[Admin-Paneli]] | [[Guvenlik-Kurallari]] |
| Hata ayıklama, "neden böyle?" | [[Bilinen-Tuzaklar]] | [[Mimari-Kararlar]] |
| Deploy / sürüm | [[Deploy-ve-Ortam]] | — |

> [!tip] Kural
> Bir notta yazan şey koddan **türetilmiştir**, kodun yerine geçmez.
> Not bir dosya/fonksiyon adı veriyorsa, değiştirmeden önce o dosyayı aç ve
> hâlâ orada olduğunu doğrula. Kasa eskiyebilir; kod eskimez.

---

## 📁 Kasa haritası

### 01-Mimari — sistemin şekli
- [[Katman-Mimarisi]] — presentation / application / data ayrımı, klasör düzeni
- [[Repository-Deseni]] — arayüz + Firebase/Mock çifti, neden böyle
- [[Durum-Yonetimi]] — Riverpod provider kataloğu ve kuralları
- [[Navigasyon-ve-Rotalar]] — go_router, tüm rota tablosu, yönlendirme kapıları
- [[Mimari-Kararlar]] — ADR: verilen kararlar ve gerekçeleri

### 02-Ozellikler — iş mantığı
- [[Is-Akisi-Durum-Makinesi]] — ilanın doğumundan kapanışına tam yaşam döngüsü
- [[Sohbet-Mimarisi]] — ilan bazlı sohbet, kilit, yazma izni
- [[Degerlendirme-Sistemi]] — çift taraflı puanlama
- [[Ozellik-Envanteri]] — 21 modülün ne yaptığı, tek satırlık özet

### 03-Backend
- [[Cloud-Functions-Haritasi]] — 51 fonksiyon: tetikleyici, görev, dokunduğu veri
- [[Guvenlik-Kurallari]] — Firestore/Storage kuralları, yetki modeli
- [[Admin-Paneli]] — ayrı web uygulaması, rol ve yetenek sistemi

### 04-Veri
- [[Firestore-Semasi]] — koleksiyonlar, alanlar, denormalizasyonlar
- [[Veri-Modelleri]] — Dart modelleri ve enum'lar

### 05-Operasyon
- [[Deploy-ve-Ortam]] — build, deploy, ortam tuzakları
- [[Test-Stratejisi]] — 319 test, neyi kapsıyor neyi kapsamıyor
- [[Bilinen-Tuzaklar]] — tekrar tekrar ısıran şeyler ⚠️ **en değerli not**

---

## 🎯 Proje bir cümlede

Türkiye pazarına yönelik, müşteriyi hizmet ustasıyla buluşturan çift taraflı
pazaryeri. Flutter (mobil + web) istemci, Firebase backend. Tek hesap iki rol
taşır (müşteri ↔ usta). Yan modüller: ürün satışı, eleman bulma, usta çantası
(hesap makineleri), takip merkezi.

## 🔑 Bilinmesi gereken 5 şey

1. **Sohbet ilan bazlıdır.** Kimlik `chat_{müşteri}__{usta}__{jobId}`. Aynı çift
   her iş için ayrı odada konuşur. → [[Sohbet-Mimarisi]]
2. **İletişimi müşteri başlatır.** Usta ancak `customerStarted` sonrası yazar.
   Bu bayrak denormalize tutulur çünkü kural motoru mesaj sayamaz.
3. **Kilidi yalnız Cloud Function koyar.** İstemci `lockedAt` yazamaz — yazsaydı
   seçilmeyen usta kendi kilidini açardı.
4. **Repository her zaman arayüz ardında.** Firebase ve Mock ikizdir; testler
   Mock üzerinden koşar, Firebase'e hiç dokunmaz. → [[Repository-Deseni]]
5. **Admin ayrı bir uygulamadır.** `main_admin.dart` ile derlenir, kullanıcı
   uygulamasıyla aynı Firebase projesini paylaşır. → [[Admin-Paneli]]

---

## 🔄 Kasa nasıl güncel tutulur?

Kasa kodla birlikte yaşamazsa zararlıdır — yanlış bilgi, bilgisizlikten kötüdür.

**Mimari bir değişiklik yaptığında** (yeni koleksiyon, yeni CF, durum makinesi
değişikliği, yeni katman kuralı) ilgili notu **aynı commit'te** güncelle.

Sıradan işler (bir widget'ın rengi, bir metin düzeltmesi) kasayı ilgilendirmez.

> [!warning] Ölçüt
> "Bu değişikliği bilmeyen biri yanlış kod yazar mı?" — evetse kasaya yaz.

Oturum bazlı ilerleme kaydı kasada **değil**, kökteki `ILERLEME_NOTLARI.md`
dosyasındadır. Kasa *kalıcı yapıyı*, o dosya *zaman çizgisini* tutar.

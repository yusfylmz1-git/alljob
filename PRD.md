# USTA CEPTE — Ürün Gereksinim Dokümanı (PRD) v4.0

> **Sürüm:** v4.0 (güncel / son sürüm) · **Tarih:** 2026-07-01

## 1. Projenin Amacı ve Kapsamı

Usta Cepte, evinde veya iş yerinde tamirat, tadilat veya teknik hizmete ihtiyaç
duyan müşteriler ile güvenilir zanaatkârları buluşturan dijital bir pazaryeri
platformudur.

Platformun temel amacı;
- Müşterilerin hızlı ve güvenilir şekilde doğru ustaya ulaşmasını sağlamak,
- Ustaların daha fazla iş almasına yardımcı olmak,
- Güvenilir ve sürdürülebilir bir dijital hizmet ekosistemi oluşturmaktır.

Platformun en önemli farklılaştırıcı özelliği **canlı müsaitlik sistemi** olacaktır.
Müşteriler yalnızca o anda hizmet vermeye hazır ustaları görecek, böylece gereksiz
aramalar ve zaman kaybı ortadan kalkacaktır.

İlk sürüm (MVP) kullanıcı kitlesini oluşturmayı hedefleyecek, gelir modeli ise
**Premium üyelik** üzerine kurulacaktır.

## 2. Kullanıcı Rolleri

### Misafir
Giriş yapmadan;
- Türkiye genelinde usta arayabilir.
- Filtreleme yapabilir.
- Usta profillerini inceleyebilir.
- Sertifikaları görebilir.
- İş fotoğraflarını inceleyebilir.
- Puan ve değerlendirme etiketlerini görebilir.

Ancak;
- Sohbet başlatamaz.
- Değerlendirme yapamaz.

### Müşteri
Google veya e-posta ile giriş yapan kullanıcıdır. Yapabilecekleri;
- Ustalarla sohbet başlatmak
- Fotoğraf göndermek
- İş tamamlandıktan sonra değerlendirme yapmak

Müşteri tarafı tamamen ücretsizdir.

### Usta
Kendi dijital dükkânını yöneten kullanıcıdır. Yönetebileceği bilgiler;
- Profil
- Meslek
- Deneyim yılı
- Hizmet bölgeleri
- Hakkımda
- Sertifikalar
- İş fotoğrafları
- Çalışma takvimi
- Premium üyelik

## 3. Ekranlar

### EKRAN A — Keşfet

Uygulama açıldığında kullanıcı doğrudan ana sayfaya gelir. Hiçbir giriş zorunluluğu
bulunmaz.

**Filtreleme** — Bağımsız çalışan filtreler: İl, İlçe, Mahalle, Meslek.
**Hiçbiri zorunlu değildir.** Örneğin `Bursa + Çilingir` veya `Nilüfer + Elektrikçi`
şeklinde tek başına kullanılabilir.

**Konum Verisi**
- Uygulama içinde: `provinces.json`, `districts.json`
- Firestore (Lazy Loading): Mahalleler uygulama içinde tutulmaz. Kullanıcı ilçe
  seçtiğinde yalnızca ilgili ilçeye ait mahalleler Firestore'dan çekilir. Böylece
  uygulama boyutu küçülür, RAM tüketimi azalır, sorgular hızlanır.

**Arama Sonuçları — İlk 1 Yıl**
Tüm ustalar Premium özelliklerinden ücretsiz yararlanır. Sıralama:
1. Çalışma takvimine göre şu anda müsait olan ustalar (puan sırasına göre)
2. Müsait olmayan ustalar (puan sırasına göre)

Yeni kayıt olan ustalar ilk **15 gün** boyunca algoritmik görünürlük desteği alır.
Bu destek puan olarak gösterilmez; profilde yalnızca **"Yeni Usta" rozeti** görünür.

**Arama Sonuçları — 1. Yıldan Sonra**
Arama sonuçlarında yalnızca o anda müsait olan Premium ustalar gösterilir.
Sıralama: Premium + Müsait (puan sırasına göre).

### EKRAN B — Kimlik Doğrulama

Misafir kullanıcı **Sohbet Başlat** veya **Değerlendir** butonuna bastığında giriş
ekranı açılır.

**Giriş:** Google veya E-posta. Google hesabından ad, soyad, e-posta ve profil
fotoğrafı otomatik alınır.

**İlk Giriş:** Kullanıcı yalnızca bir kez rol seçimi yapar: *Hizmet Almak İstiyorum*
veya *Ustayım*. Rol, Firebase Authentication üzerinde saklanır.

### EKRAN C — Usta Profili

Profilde gösterilir: profil fotoğrafı, galeri, meslek, deneyim yılı, hizmet
bölgeleri, sertifikalar, hakkımda, ortalama puan, değerlendirme etiketleri.

Kimliği doğrulanan ustalarda **✅ Doğrulanmış Usta** rozeti bulunur.

Telefon numarası ve e-posta hiçbir şekilde gösterilmez. İletişim yalnızca uygulama
içerisindeki sohbet üzerinden sağlanır.

### EKRAN D — Usta Paneli

Usta şu alanları yönetebilir: Profil, Fotoğraflar, Sertifikalar, Hizmet bölgeleri,
Çalışma takvimi.

**Çalışma Takvimi** — Usta çalışma düzenini bir kez belirler; sistem buna göre
müsaitlik durumunu otomatik yönetir.

- **Seçenek 1 — Her Zaman Müsait:** Usta haftanın her günü ve her saati hizmete
  hazır görünür.
- **Seçenek 2 — Gün ve Saat Planlaması:** Usta haftanın istediği günlerini seçer
  (örn. Pzt–Cuma açık, hafta sonu kapalı) ve her gün için saat aralığı belirler
  (örn. 08:00–17:00). Saat geldiğinde sistem ustayı otomatik **Müsait**, saat
  bitince otomatik **Müsait Değil** yapar.
- **Seçenek 3 — Geçici Olarak Müsait Değilim:** Usta tek dokunuşla kendini geçici
  pasif yapar (tatil, hastalık, yoğunluk). Bu durumda çalışma saatleri gelse bile
  müşteriye gösterilmez.

**Premium Sistemi**
- İlk 1 yıl: Tüm ustalar çalışma takvimini ücretsiz kullanabilir.
- 1. yıldan sonra: Çalışma takvimini kullanmak için Premium gerekir. Premium
  olmayan ustalar takvimi aktifleştiremez ve arama sonuçlarında gösterilmez.

### EKRAN E — Sohbet

Gerçek zamanlı mesajlaşma. Desteklenen içerikler: yazı, fotoğraf.

**Güvenlik:** Telefon numarası, WhatsApp, Telegram, Instagram, e-posta vb. iletişim
bilgileri paylaşılmaya çalışıldığında sistem bunları otomatik algılar, **maskeler**
ve kullanıcıları uyarır. Platform dışına yönlendirme engellenir.

### EKRAN F — İş Sonu Değerlendirme

Yalnızca ilgili usta ile sohbet geçmişi bulunan müşteriler değerlendirme yapabilir.

**Puan:** ⭐ 1–5 yıldız.

**Hazır Etiketler** (bir veya birden fazla seçilebilir):

*Olumlu:* Temiz işçilik · Zamanında geldi · Profesyonel · Güler yüzlü · Hızlı çözüm ·
Kaliteli işçilik · Güvenilir · Uygun fiyat

*Olumsuz:* Geç geldi · Kötü işçilik · Eksik iş yaptı · İletişimi zayıf · Pahalı ·
Randevuya gelmedi · Sorun çözülmedi · Tavsiye etmiyorum

**Serbest metin yorumu bulunmaz.** Böylece değerlendirmeler standartlaşır ve
moderasyon yükü önemli ölçüde azalır.

## 4. Firestore Veri Modeli

**users** — uid, displayName, email, role, profilePhotoURL, createdAt

**artisanProfiles** — uid, professionCode, experienceYears, aboutText,
certificates[], workPhotos[], isVerified, averageRating, isPremium, serviceAreas[]

**Çalışma Takvimi** (artisanProfiles içinde):
```json
{
  "alwaysAvailable": false,
  "manualPause": false,
  "weeklySchedule": {
    "monday":    { "enabled": true,  "start": "08:00", "end": "17:00" },
    "tuesday":   { "enabled": true,  "start": "08:00", "end": "17:00" },
    "wednesday": { "enabled": false },
    "thursday":  { "enabled": true,  "start": "10:00", "end": "18:00" },
    "friday":    { "enabled": true,  "start": "08:00", "end": "17:00" },
    "saturday":  { "enabled": false },
    "sunday":    { "enabled": false }
  }
}
```

**neighborhoods** — id, districtId, name. Mahalleler yalnızca ilgili ilçe
seçildiğinde sorgulanır.

**reviews** — artisanUID, customerUID, chatId, rating (1–5), tags[] (hazır
etiketler; serbest metin yok), createdAt

## 5. Güvenlik ve Moderasyon

- Telefon numarası ve e-posta hiçbir kullanıcıya gösterilmez.
- Platform dışına yönlendiren mesajlar otomatik maskelenir.
- Değerlendirme yapabilmek için müşteri ile usta arasında sohbet geçmişi bulunmalıdır.
- Kimlik ve sertifikalar yönetici onayından geçer.
- Puan hesaplamaları Cloud Functions üzerinde yapılır.
- Yeni ustalara ilk 15 gün algoritmik görünürlük desteği sağlanır; destek puanı
  kullanıcıya gösterilmez.

## 6. Gelir Modeli

**İlk 1 Yıl:** Tüm ustalar Premium özellikleri ücretsiz kullanır. Amaç platformu
hızlı büyütmektir.

**1. Yıldan Sonra:** Premium üyelik uygulamanın temel gelir modelidir.

Premium aboneler:
- Çalışma takvimini kullanabilir.
- Müşteri aramalarında görüntülenebilir.
- Çalışma saatleri içinde otomatik "Müsait" görünür.
- Puan sıralamasına göre listelenir.

Premium olmayan ustalar:
- Profillerini düzenlemeye devam edebilir.
- Çalışma takvimini kullanamaz.
- Arama sonuçlarında gösterilmez.

## Genel Değerlendirme

Bu sürümle Usta Cepte, klasik bir "usta rehberi" olmaktan çıkarak aktif hizmet
veren ustaların yer aldığı canlı bir dijital pazar yerine dönüşmektedir. Müşteriler
yalnızca hizmet vermeye hazır ustaları görürken, ustalar çalışma takvimlerini bir
kez tanımlayarak sürekli uygulamayı açık tutmak zorunda kalmaz. İlk yıl ücretsiz
Premium modeli sayesinde güçlü bir kullanıcı kitlesi oluşturulurken, sonraki dönemde
Premium üyelik doğrudan görünürlük ve iş alma fırsatına dönüşerek sürdürülebilir bir
gelir modeli oluşturur. Bu yapı, Flutter ve Firebase ile geliştirilebilecek
ölçeklenebilir, performanslı ve ticari açıdan güçlü bir MVP sunmaktadır.

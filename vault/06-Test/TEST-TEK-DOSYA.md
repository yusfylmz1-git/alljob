# 📱 Cihaz Testi — TEK DOSYA (v3 · 395 adım)

> Bütün adımlar sırayla burada. Bölüm bölüm ayrı dosyalar da duruyor
> ([[00-TEST-PLANI]]) — bu dosya baştan sona tek oturumda gitmek içindir.
>
> **Üretildiği tarih:** 2026-08-09 · Dayanak: [[Mevcut-Akislar]]

**Cihaz:** ______________ **Sürüm:** ______________ **Başlangıç:** ________

---

## ⚠️ ÖNCE OKU

### Uygulama şu an ne?

**Kullanıcı ilan verir ya da usta arar; iki taraf doğrudan mesajlaşıp
anlaşır.**

**Rol ayrımı YOK.** Aynı hesap hem müşteri hem usta olabilir; "usta modu"
profil doldurulunca açılır.

> [!warning] İlan bir DUYURUDUR
> Usta **atanmaz**, iş "tamamlandı" **denmez**. Durum üç tane:
> **Yayında · Kaldırıldı · Süresi doldu**.
> Ekranda "Teklif toplanıyor" / "İş yürüyor" / "Ustayı Seç" görürsen
> **eski kod geri gelmiş** → bulgu yaz.

### Hazırlık

**1. Deploy edildi mi?** ✅ Evet — kural, 40 CF ve iki site 2026-08-09'da
canlıya alındı. *(Emin değilsen: `firebase functions:list` → 40 fonksiyon.)*

**2. Temiz kurulum — `clean` ŞART:**
```bash
flutter clean && flutter run
```
Logo ve launcher ikonu derleme önbelleğinde kalır; `clean` yapmazsan
değişmemiş gibi görünür.

**3. İki hesap gerekli.** Kendi ilanına mesaj atamazsın.

| Rol | Google hesabı |
|---|---|
| **A** (ilan veren) | ______________ |
| **B** (usta) | ______________ |

> İki cihaz varsa çok daha rahat: mesajlaşma, bildirim ve canlı güncelleme
> tek cihazda tam test edilemez.

**4. Bilinmesi gerekenler**
- E-posta doğrulaması **zorunlu** — ilan açmak ve mesaj atmak için
- İlan limiti **5** (aynı anda açık), günlük **10**
- Müsait olmayan usta aramada **görünmez**, yeni ilana mesaj **atamaz** —
  ama mevcut sohbetleri **sürer**
- Sohbet **kişi başına TEK** — aynı çift kaç ilan konuşursa konuşsun
- Değerlendirme **kişiye** — aynı kişiyi ikinci kez puanlamak **günceller**

### İşaretler

| İşaret | Anlamı |
|---|---|
| ⭐ | Bu turda **değişen** yer — özellikle dikkat |
| ⚠️ | Kırılırsa **ciddi** |
| 🔴 | Kırılırsa **çok ciddi**, hemen bildir |

---

## 🎯 Zamanın azsa: EN KRİTİK 5 ADIM

Bu oturumlarda ürünün yarısı değişti. Yalnız beş adıma bakacaksan bunlar:

| Adım | Ne test eder | Kırılırsa |
|---|---|---|
| **8.3.5** | Mesajlaşılan ilanı sil → **sohbet durmalı** | 🔴 Veri kaybı |
| **6.3.7** | Aynı çift iki ilan → **tek sohbet** | ⚠️ `chatIdFor` bozuk |
| **9.3.2** | İkinci puan → **"Güncelle"**, form dolu | ⚠️ Puan şişirme |
| **11.2.5** | Admin özet çipleri doğru sekmeyi açıyor mu | ⚠️ İndeks kayması |
| **12.4.2** | Hesap silme metni kodla birebir mi | 🔴 Yasal risk |

---

## 📋 İlerleme

| # | Bölüm | Adım | Durum |
|---|---|---|---|
| [1](#bolum-1) | İlk Açılış ve Giriş | 22 | ⬜ |
| [2](#bolum-2) | Ana Sayfa ve Keşfet | 29 | ⬜ |
| [3](#bolum-3) | Profil ve Usta Modu ⭐ | 34 | ⬜ |
| [4](#bolum-4) | Takip Sistemi ⭐ | 31 | ⬜ |
| [5](#bolum-5) | İlan Verme | 30 | ⬜ |
| [6](#bolum-6) | İlan Alma (Usta) ⭐ | 31 | ⬜ |
| [7](#bolum-7) | Mesajlaşma ⭐ | 32 | ⬜ |
| [8](#bolum-8) | İlan Ömrü ve Yönetimi ⭐ | 37 | ⬜ |
| [9](#bolum-9) | Değerlendirme ⭐ | 25 | ⬜ |
| [10](#bolum-10) | Güvenlik ve Ayarlar | 32 | ⬜ |
| [11](#bolum-11) | Admin Paneli 🖥️ | 57 | ⬜ |
| [12](#bolum-12) | Tanıtım Sitesi 🖥️ | 35 | ⬜ |

**Toplam 395 adım · ~4,5 saat.** 🖥️ = tarayıcıda, telefon gerekmez.

> **1–4** bağımsız, tek hesapla olur · **5–9** zincir, iki hesap ister ve
> sıra atlanmamalı · **10** bağımsız · **11–12** tarayıcıda.

---

<a id="bolum-1"></a>

## 1 · İlk Açılış ve Giriş

**Kapsam:** Onboarding, misafir gezinme, Google girişi, oturum kalıcılığı.
**Hesap:** A · **Süre:** ~15 dk

> [!tip] Temiz başlangıç
> Onboarding **cihaz başına bir kez** görünür. Yeniden görmek için uygulamayı
> kaldırıp kurun (veya uygulama verilerini temizleyin).


### 1.1 Onboarding

- [ ] **1.1.1** İlk açılışta tanıtım ekranı geliyor (3 sayfa)
- [ ] **1.1.2** Sayfalar kaydırılabiliyor, noktalar ilerlemeyi gösteriyor
- [ ] **1.1.3** "Atla" her sayfada erişilebilir
- [ ] **1.1.4** Bitince Ana Sayfa açılıyor
- [ ] **1.1.5** ⚠️ Uygulamayı kapatıp açın → onboarding **tekrar çıkmamalı**

### 1.2 Misafir gezinme

> Giriş yapmadan nereye kadar gidilebiliyor?

- [ ] **1.2.1** Ana Sayfa misafire açılıyor
- [ ] **1.2.2** Keşfet açılıyor, ustalar listeleniyor
- [ ] **1.2.3** Usta profiline girilebiliyor
- [ ] **1.2.4** ⚠️ **Mesajlar**'a basınca giriş ekranına yönleniyor
- [ ] **1.2.5** ⚠️ Giriş ekranındayken **donanım geri tuşu** → Ana Sayfa'ya
      dönmeli (uygulamayı KAPATMAMALI)
- [ ] **1.2.6** **Profil**'e basınca giriş ekranı açılıyor

### 1.3 Google ile giriş

- [ ] **1.3.1** "Google ile giriş" hesap seçiciyi açıyor
- [ ] **1.3.2** Hesap seçilince giriş tamamlanıyor
- [ ] **1.3.3** Giriş sonrası Ana Sayfa'ya dönülüyor
- [ ] **1.3.4** Alt barda **Profil** sekmesi artık profili açıyor
- [ ] **1.3.5** Profilde ad ve fotoğraf Google hesabından gelmiş

### 1.4 Oturum kalıcılığı

- [ ] **1.4.1** Uygulamayı tamamen kapatıp açın → **oturum açık kalmalı**
- [ ] **1.4.2** Yan menü (☰) açılıyor, adınız görünüyor

### 1.5 Çıkış

- [ ] **1.5.1** Yan menü → **Çıkış Yap** çalışıyor
- [ ] **1.5.2** ⚠️ Çıkışta uygulama **donmamalı/çökmemeli**
      *(B-17: çıkış zinciri 4 sn ile sınırlandı)*
- [ ] **1.5.3** Çıkış sonrası Ana Sayfa (misafir) görünüyor
- [ ] **1.5.4** Tekrar giriş yapın → hesap değişimi sorunsuz

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Onboarding her açılışta çıkıyor | Cihaz kaydı yazılmıyor |
| Giriş ekranında geri → uygulama kapanıyor | ⚠️ B-01 regresyonu |
| Çıkışta "yanıt vermiyor" | ⚠️ B-17 regresyonu — **hemen bildir** |
| Giriş sonrası boş profil | Google'dan ad/foto gelmemiş |

---

<a id="bolum-2"></a>

## 2 · Ana Sayfa ve Keşfet

**Kapsam:** Ana sayfa bölümleri, usta arama, filtreler, alt bar gezinme.
**Hesap:** A · **Süre:** ~15 dk

> [!important] Bu bölüm yeniden yazıldı
> Ana Sayfa'daki **rol ayrımı kalktı** — usta ve müşteri artık aynı sırayı
> görür. "Popüler Ürünler", "Usta Araçları" ve "Platform istatistikleri"
> bölümleri **kaldırıldı**.


### 2.1 Ana Sayfa bölümleri

Beklenen sıra (herkeste aynı):
```
[Misafirse giriş şeridi]
Usta Bul (büyük kart)
[İş İlanı Ver] [Kolay İş]
⚡ Kolay İş ilanları
⭐ Öne Çıkan Ustalar
📋 Son İş İlanları
🔥 Haftanın Ustası / Duyuru
```

- [ ] **2.1.1** "Usta Bul" kartı görünüyor, dokununca Keşfet açılıyor
- [ ] **2.1.2** "İş İlanı Ver" ilan formunu açıyor
- [ ] **2.1.3** "Kolay İş" formu **kategori seçili** açıyor
- [ ] **2.1.4** ⚠️ **"Ürünler" ile ilgili hiçbir şey görünmemeli**
      (modül kaldırıldı)
- [ ] **2.1.5** ⚠️ **"Usta Araçları" bölümü olmamalı**
- [ ] **2.1.6** Öne Çıkan Ustalar şeridi kayıyor, karta dokununca profil açılıyor
- [ ] **2.1.7** Son İş İlanları görünüyor
- [ ] **2.1.8** Aşağı çekince **yenileme** çalışıyor

### 2.2 Keşfet — usta arama

> Keşfet artık **tek liste**: yalnız ustalar. Sekme çubuğu kaldırıldı.

- [ ] **2.2.1** Keşfet açılınca ustalar **hemen listeleniyor** (boş açılmamalı)
- [ ] **2.2.2** ⚠️ **Sekme çubuğu olmamalı** (Ustalar/Ürünler/İlanlar yok)
- [ ] **2.2.3** Arama kutusuna isim/meslek yazınca sonuç süzülüyor
- [ ] **2.2.4** "Detaylı Arama" paneli açılıyor
- [ ] **2.2.5** İl/ilçe filtresi çalışıyor
- [ ] **2.2.6** Meslek filtresi çalışıyor
- [ ] **2.2.7** Filtre temizlenebiliyor
- [ ] **2.2.8** Aşağı kaydırınca **sayfalama** çalışıyor (daha fazla usta gelir)
- [ ] **2.2.9** Usta kartına dokununca profil açılıyor

### 2.3 Alt bar gezinme

- [ ] **2.3.1** Sekmeler: **Ana Sayfa · Keşfet · Mesajlar · Profil**
- [ ] **2.3.2** ⚠️ Usta modu kapalıyken **"İlanlar" sekmesi GÖRÜNMEMELİ**
- [ ] **2.3.3** Sekme değişimi hızlı, seçili sekme belli
- [ ] **2.3.4** Mesajlar sekmesinde okunmamış rozeti görünüyor (varsa)
- [ ] **2.3.5** ⚠️ Profil/Keşfet/Mesajlar'dan **geri tuşu → Ana Sayfa**
- [ ] **2.3.6** ⚠️ Ana Sayfa'dan geri tuşu → **uygulama kapanır** (doğru)

### 2.4 Yan menü (☰)

- [ ] **2.4.1** Menü açılıyor, başlıkta ad + mod yazıyor
- [ ] **2.4.2** İçerik: İş İlanı Ver · Takip Ettiklerim · Hesap Ayarları ·
      Yardım · Görünüm · Çıkış
- [ ] **2.4.3** ⚠️ **"Ajanda" olmamalı** (modül kaldırıldı)
- [ ] **2.4.4** ⚠️ **"Usta/Müşteri Moduna Geç" olmamalı**
      (mod değişimi artık profildeki anahtardan)
- [ ] **2.4.5** "Görünüm" → tema ve renk değiştirilebiliyor
- [ ] **2.4.6** Tema seçimi uygulama yeniden açılınca korunuyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Keşfet boş açılıyor | ⚠️ Arama başlatılmıyor — bildir |
| Ürün/araç/ajanda izi görünüyor | ⚠️ Kaldırılmış modül sızıntısı |
| "İlanlar" sekmesi müşteri modunda var | ⚠️ Rol kapısı bozuk |
| Geri tuşu uygulamayı kapatıyor | ⚠️ MainTabScope regresyonu |

---

<a id="bolum-3"></a>

## 3 · Profil ve Usta Modu ⭐

**Kapsam:** Instagram profil düzeni, usta modu anahtarı, vitrin, hesap ayarları.
**Hesap:** A · **Süre:** ~20 dk

> [!important] En çok değişen bölüm
> Rol ayrımı **tamamen kalktı**. Eskiden usta ve müşteri iki farklı ekran
> görüyordu; artık **tek profil** var, "Usta modu" anahtarı ek modülleri açıyor.


### 3.1 Instagram profil düzeni

Beklenen görünüm:
```
☰        Yusuf YILMAZ        🔔
 ⭕      12       8       51
avatar  takip  takipçi  tamamlanan
  ⊕
Yusuf YILMAZ ✓
[Profili düzenle] [Profilime bak]
[ 🏪 Usta modu            (•—) ]
```

- [ ] **3.1.1** Avatar **SOLDA**, sayaçlar **YANINDA** (yatay düzen)
- [ ] **3.1.2** Avatarda sağ altta **"+" rozeti** var
- [ ] **3.1.3** Avatara dokununca profil düzenleme açılıyor
- [ ] **3.1.4** Ad + doğrulama rozeti (telefon doğrulanmışsa ✓)
- [ ] **3.1.5** Üç sayaç: **takip · takipçi · tamamlanan**
- [ ] **3.1.6** İki gri düğme: **Profili düzenle · Profilime bak**
- [ ] **3.1.7** ⚠️ Sayfa **dikey/ortalanmış değil**, sola dayalı olmalı

### 3.2 Usta modu anahtarı ⭐

- [ ] **3.2.1** Aksiyon düğmelerinin altında **"Usta modu"** anahtarı var
- [ ] **3.2.2** Kapalıyken alt yazı: *"Kapalı — yalnız hizmet alıyorsun"*
- [ ] **3.2.3** ⚠️ Henüz usta profili yoksa anahtar yerine
      **"Usta olarak devam et"** çağrısı çıkıyor
- [ ] **3.2.4** Anahtarı **AÇIN** → alt yazı *"Açık — iş alabilir…"* oluyor
- [ ] **3.2.5** ⭐ Açınca **alt barda "İlanlar" sekmesi beliriyor**
- [ ] **3.2.6** Açınca profilde **Müsaitlik + Vitrin** bölümleri beliriyor
- [ ] **3.2.7** Kapatın → sekme ve modüller **kayboluyor**
- [ ] **3.2.8** Sayfa değişirken **ekran atlamıyor** (aynı sayfada kalır)

### 3.3 Profili düzenle

- [ ] **3.3.1** "Profili düzenle" → ad + fotoğraf ekranı
- [ ] **3.3.2** Fotoğraf değiştirilebiliyor (kamera/galeri)
- [ ] **3.3.3** Ad değiştirilip kaydedilebiliyor
- [ ] **3.3.4** ⚠️ Kaydetme **başarılı olmalı** — hata verirse mesajı not alın
      *(B-04: doğrulama aynaları düzeltildi)*
- [ ] **3.3.5** ⭐ Usta modu **AÇIKKEN** aynı ekranda
      **"USTA VİTRİNİ → Vitrini düzenle"** kartı görünüyor
- [ ] **3.3.6** Usta modu kapalıyken o kart **görünmüyor**

### 3.4 Vitrin düzenleme (usta modu açık)

- [ ] **3.4.1** Meslek seçimi çalışıyor (en fazla 5)
- [ ] **3.4.2** ⭐ **Kolay İş anahtarı açıkken 5 meslek seçilebiliyor**
      *(B-03: sayaç Kolay İş'ı saymamalı)*
- [ ] **3.4.3** Hizmet bölgesi (il/ilçe) eklenebiliyor
- [ ] **3.4.4** "Hakkımda" yazılabiliyor
- [ ] **3.4.5** İş fotoğrafı eklenebiliyor
- [ ] **3.4.6** Çalışma saatleri ayarlanabiliyor
- [ ] **3.4.7** ⚠️ **Kaydet düğmesi alt barın altında kalmamalı**
      *(B-08)*

### 3.5 Hesap Ayarları

> HESABIM bölümü profilden **yan menüye taşındı**.

- [ ] **3.5.1** Yan menü → **Hesap Ayarları** açılıyor
- [ ] **3.5.2** ⚠️ Profil ekranında **"HESABIM" bölümü OLMAMALI**
- [ ] **3.5.3** Telefon doğrulama durumu görünüyor
- [ ] **3.5.4** E-posta doğrulama durumu görünüyor
- [ ] **3.5.5** Üyelik/Premium satırı var
- [ ] **3.5.6** "Çıkış Yap" ve "Hesabı Sil" burada

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| İki ayrı profil ekranı hissi | ⚠️ Rol ayrımı geri gelmiş |
| Anahtar açınca sekme belirmiyor | ⚠️ Alt bar bağı kopuk |
| Profilde "İlanlarım" satırı var | ⚠️ Yan menüye taşınmıştı |
| Kaydetme "sunucu reddetti" | Mesajı **aynen** not alın |
| Meslekte 5. seçilemiyorsa | ⚠️ B-03 regresyonu |

---

<a id="bolum-4"></a>

## 4 · Takip Sistemi ⭐

**Kapsam:** Takip et/bırak, iki sekmeli liste, karşılıklı rozet, genel profil,
takip bildirimi.
**Hesap:** A + B · **Süre:** ~20 dk

> [!important] Tamamen yeni
> Eskiden yalnız **müşteri → usta** takip edilebiliyordu. Artık **herkes
> herkesi** takip eder (Instagram gibi).


### 4.1 Takip et / bırak

- [ ] **4.1.1** Usta profilinde sağ üstte **kalp** düğmesi var
- [ ] **4.1.2** Dokununca takip başlıyor, *"Takip ediliyor."* mesajı
- [ ] **4.1.3** Kalp dolu hale geliyor
- [ ] **4.1.4** Tekrar dokununca takipten çıkıyor
- [ ] **4.1.5** ⚠️ **Kendi profilinizde kalp GÖRÜNMEMELİ**
- [ ] **4.1.6** ⭐ **Usta modu AÇIKKEN de takip edebiliyorsunuz**
      *(eskiden usta modunda düğme hiç görünmüyordu)*

### 4.2 Takip listesi — iki sekme

- [ ] **4.2.1** Profildeki **"takip"** sayacına dokunun → liste açılıyor
- [ ] **4.2.2** İki sekme var: **Takipçiler | Takip**
- [ ] **4.2.3** "Takip" sekmesi takip ettiklerinizi gösteriyor
- [ ] **4.2.4** ⭐ Profildeki **"takipçi"** sayacına dokunun →
      **Takipçiler sekmesi açık** gelmeli
      *(eskiden yanlış liste açılıyordu)*
- [ ] **4.2.5** Boş listede açıklayıcı metin çıkıyor
- [ ] **4.2.6** Listedeki satırda ad + fotoğraf görünüyor
- [ ] **4.2.7** Usta takip edildiyse **meslek + puan** satırı da var
- [ ] **4.2.8** Sıradan kullanıcı takip edildiyse **meslek satırı YOK**
- [ ] **4.2.9** Aşağı çekince yenileme çalışıyor

### 4.3 Genel kullanıcı profili (`/u/:uid`)

> Usta vitrini **olmayan** kişiler için yeni ekran.

- [ ] **4.3.1** Takip listesinden bir **usta olmayan** kişiye dokunun
- [ ] **4.3.2** ⭐ Profil açılıyor ve **BOŞ DEĞİL** — avatar, ad, sayaçlar var
      *(eskiden usta profili ekranı açılıp boş görünüyordu)*
- [ ] **4.3.3** "Bu kullanıcı henüz usta vitrini açmamış" yazısı var
- [ ] **4.3.4** **Takip Et** ve **Mesaj Gönder** düğmeleri çalışıyor
- [ ] **4.3.5** ⚠️ **E-posta / telefon GÖRÜNMEMELİ**
- [ ] **4.3.6** Usta olan birine dokununca **zengin usta profili** açılıyor
      (otomatik devretme)
- [ ] **4.3.7** Kendi profilinize girerseniz takip/mesaj düğmeleri gizli

### 4.4 Karşılıklı takip rozeti

**Hazırlık:** B hesabı A'yı takip etsin.

- [ ] **4.4.1** A hesabıyla B'nin profiline girin
- [ ] **4.4.2** ⭐ Ad altında **"Seni takip ediyor"** rozeti görünüyor
- [ ] **4.4.3** B takipten çıkınca rozet **kayboluyor**
- [ ] **4.4.4** Kendi profilinizde rozet görünmüyor

### 4.5 Takip bildirimi

> ⚠️ **İki cihaz gerekir** — tek cihazda tam test edilemez.

- [ ] **4.5.1** B, A'yı takip etsin
- [ ] **4.5.2** A'nın **bildirim listesinde** "Yeni takipçi" görünüyor
- [ ] **4.5.3** Bildirime dokununca **B'nin profili** açılıyor
- [ ] **4.5.4** A'nın telefonuna **push** geliyor *(2. cihaz)*
- [ ] **4.5.5** ⭐ B takipten çıkıp **tekrar takip etsin** → listede
      **tek satır** kalmalı (mükerrer bildirim yok)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Takipçi sayacı yanlış liste açıyor | ⚠️ Regresyon — bildir |
| Usta olmayan profil boş | ⚠️ `/u/:uid` devretmesi bozuk |
| Usta modunda kalp yok | ⚠️ Eski kısıt geri gelmiş |
| Takip-bırak-takip → 2 bildirim | ⚠️ Deterministik kimlik bozuk |
| Profilde e-posta görünüyor | 🔴 **Gizlilik — hemen bildir** |

---

<a id="bolum-5"></a>

## 5 · İlan Verme

**Kapsam:** İlan formu, limit, düzenleme, silme, iptal.
**Hesap:** A · **Süre:** ~20 dk

> [!note] Herkes ilan verebilir
> Usta modu açık da olsa kapalı da olsa ilan verilebilir. İlan vermek
> "müşteri" olmayı gerektirmiyor.


### 5.1 İlan oluşturma

- [ ] **5.1.1** "İş İlanı Ver" formu açılıyor (Ana Sayfa veya yan menü)
- [ ] **5.1.2** Kategori seçimi çalışıyor (arama ile)
- [ ] **5.1.3** Başlık ve açıklama yazılabiliyor
- [ ] **5.1.4** İl seçimi çalışıyor
- [ ] **5.1.5** ⚠️ İl seçince **klavye kapanıyor**, ekran zıplamıyor;
      ilçe alanı **vurgulanıyor** *(B-09)*
- [ ] **5.1.6** İlçe seçimi çalışıyor
- [ ] **5.1.7** Fotoğraf eklenebiliyor, yüklenirken **spinner** dönüyor
- [ ] **5.1.8** ⭐ **Fotoğraf yüklenirken "Yayınla"ya basın** →
      *"Fotoğraf yükleniyor, bekleyin"* uyarısı çıkmalı, ilan gitmemeli
      *(B-02: sessiz veri kaybı düzeltildi)*
- [ ] **5.1.9** Süre seçimi (3 gün / 5 gün / 7 gün) — Kolay İş'te seçim YOK, 1 gün sabit
- [ ] **5.1.10** Zorunlu alan boşken kaydet engelleniyor, uyarı net
- [ ] **5.1.11** Kaydedince ilan oluşuyor, İlanlarım'da görünüyor

### 5.2 Kolay İş

- [ ] **5.2.1** "Kolay İş" girişi kategoriyi **önceden seçili** açıyor
- [ ] **5.2.2** ⚠️ Örnek çipleri **kategorinin hemen altında** *(B-10)*
- [ ] **5.2.3** Çipe dokununca başlık + açıklama doluyor
- [ ] **5.2.4** İlan Ana Sayfa'daki "Kolay İş" şeridinde görünüyor

### 5.3 İlan limiti

> Aynı anda en fazla **5 açık ilan**.

- [ ] **5.3.1** 5 açık ilanınız varken 6.'yı deneyin
- [ ] **5.3.2** ⚠️ Engellenmeli, **anlaşılır mesaj** vermeli
- [ ] **5.3.3** Bir ilanı iptal edip tekrar deneyin → açılmalı

### 5.4 İlan listeleme ve detay

- [ ] **5.4.1** Yan menü → **İlanlarım** listesi açılıyor
- [ ] **5.4.2** ⚠️ İlan durumu **"Yayında"** yazıyor
      *("Teklif toplanıyor" görürseniz eski kod — bulgu yazın)*
- [ ] **5.4.3** İlan detayı açılıyor, bilgiler doğru
- [ ] **5.4.4** Fotoğraflar açılıyor, büyütülebiliyor
- [ ] **5.4.5** İlgilenen ustalar bölümü var (usta ilgi bildirince dolar)

### 5.5 Düzenleme ve silme

> Düzenleme yalnız **açık** ilanda ve yayından sonra **1 saat** içinde.

- [ ] **5.5.1** Yeni ilan düzenlenebiliyor
- [ ] **5.5.2** ⚠️ Düzenlemede **yalnız başlık + açıklama** var —
      fotoğraf/konum değiştirilemiyor *(bilinen kısıt: B-07)*
- [ ] **5.5.3** Değişiklik kaydediliyor, detayda görünüyor
- [ ] **5.5.4** Bağlanmamış ilan silinebiliyor

### 5.6 İptal

- [ ] **5.6.1** İlan iptal edilebiliyor, **neden** soruluyor
- [ ] **5.6.2** ⚠️ Nedenlerde **"Günlük ilan hakkı doldu" OLMAMALI**
      *(B-11: yalnız sunucu yazar)*
- [ ] **5.6.3** İptal edilen ilan durumu "İptal edildi" oluyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Foto yüklenirken kaydet geçiyor | ⚠️ B-02 regresyonu — veri kaybı |
| İl seçince ekran zıplıyor | ⚠️ B-09 regresyonu |
| 6. ilan sessizce açılıyor | ⚠️ Limit çalışmıyor |
| Düzenle düğmesi hiç yok | İlan 1 saatten eski mi? |

---

<a id="bolum-6"></a>

## 6 · İlan Alma (Usta Tarafı)

**Kapsam:** İlan listesi erişimi, dört kapı, ilan sahibine doğrudan mesaj.
**Hesap:** B (usta modu açık) · **Süre:** ~15 dk

> [!important] Akış değişti (2026-08-08/09)
> Usta **teklif vermez, ilgi de bildirmez** — ilan sahibine **doğrudan mesaj
> atar**. "İlgilenen Ustalar" listesi, "Ustayı Seç" ve "İlgilendiğim" sekmesi
> **kaldırıldı**. Bu bölüm eskiden onları test ediyordu.


### 6.1 Erişim kapısı ⭐

- [ ] **6.1.1** Usta modu **KAPALIYKEN** "İşler" sekmesi ilan listesi değil,
      **kendi ilanlarını** açıyor
- [ ] **6.1.2** Usta modunu açın → "İşler" artık **yakındaki ilanları** açıyor
- [ ] **6.1.3** Profil eksikse (meslek/bölge yok) → **uyarı ekranı** çıkıyor
- [ ] **6.1.4** ⭐ Profilde **"Müsait değilim"** yapın → ilan listesi
      **boş geliyor** / bilgilendirme çıkıyor
- [ ] **6.1.5** ⚠️ Ekranda **tek liste** var — "İlgilendiğim" diye ikinci
      sekme **OLMAMALI** *(kaldırıldı)*

### 6.2 İlan listesi

- [ ] **6.2.1** Yakındaki ilanlar listeleniyor
- [ ] **6.2.2** A hesabının açtığı ilan listede çıkıyor
      *(çıkmıyorsa: meslek + bölge eşleşiyor mu?)*
- [ ] **6.2.3** İlan detayı açılıyor, ilan sahibinin bilgileri görünüyor
- [ ] **6.2.4** Fotoğraflar açılıyor
- [ ] **6.2.5** ⚠️ Kartta **"N ilgilendi"** yazısı **OLMAMALI** *(sayaç kalktı)*
- [ ] **6.2.6** Kartta ilçe + "ne kadar önce" bilgisi var

### 6.3 Doğrudan mesaj ⭐

> Yeni akış: usta ilan sahibine mesaj atar, anlaşma sohbette olur.

- [ ] **6.3.1** İlan detayında **"Mesaj Gönder"** düğmesi var
- [ ] **6.3.2** ⚠️ **"Bildirim Gönder"** / **"İlgilendim"** düğmesi
      **OLMAMALI**
- [ ] **6.3.3** Basınca sohbet açılıyor
- [ ] **6.3.4** ⭐ İkinci kez basınca **aynı sohbete** giriyor
      *(kişi başına tek kutu — yeni sohbet açılmamalı)*
- [ ] **6.3.5** A'ya mesaj bildirimi gidiyor *(uygulama içi)*
- [ ] **6.3.6** A'nın telefonuna push geliyor *(2. cihaz)*
- [ ] **6.3.7** ⭐ A ile B'nin **başka bir ilan** üzerinden de konuşması →
      **yine aynı sohbet** açılıyor

### 6.4 Dört kapı ⭐

> `_messageOwner()` sırayla dört şey kontrol eder. Her birini ayrı deneyin.

**Kapı 1 — askıya alınmış hesap**
- [ ] **6.4.1** *(admin panelinden B'yi askıya alın)* → mesaj atamıyor,
      uyarı çıkıyor. **Sonra askıyı kaldırın.**

**Kapı 2 — müsaitlik**
- [ ] **6.4.2** ⭐ B'yi **müsait değil** yapın → ilana mesaj atamıyor,
      *"müsait değil görünüyorsunuz"* uyarısı
- [ ] **6.4.3** ⭐ A, Keşfet'te arama yapsın → **B listede ÇIKMIYOR**
- [ ] **6.4.4** A, B'nin profiline **doğrudan** girsin (takip listesinden) →
      profil **açılıyor**
- [ ] **6.4.5** ⭐ Profilde **"Şu an yeni iş almıyor"** yazıyor, mesaj düğmesi
      pasif
- [ ] **6.4.6** Müsaitliği açın → hepsi normale dönüyor

**Kapı 3 — eşleşme**
- [ ] **6.4.7** ⭐ B'nin **mesleğiyle alakasız** bir ilana girin *(varsa)* →
      mesaj atamıyor / ilan listede zaten yok
- [ ] **6.4.8** Farklı **ilçedeki** normal ilan listede çıkmıyor

**Kapı 4 — e-posta doğrulama**
- [ ] **6.4.9** ⭐ E-postası **doğrulanmamış** hesapla mesaj atmayı deneyin →
      doğrulama istemi çıkıyor

### 6.5 Kolay İş farkı ⭐

> Kolay İş ilanları **il geneline** gider ve meslek şartı gevşektir.

- [ ] **6.5.1** A, **Kolay İş** ilanı versin *(süre otomatik 1 gün)*
- [ ] **6.5.2** ⭐ B **farklı ilçede** olsun → ilan yine de listede **ÇIKIYOR**
- [ ] **6.5.3** ⭐ B **başka ilde** olsun → ilan **ÇIKMIYOR** (il sınırı)
- [ ] **6.5.4** Normal ilan aynı testte **ilçe şartını koruyor**

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| "İlgilendiğim" sekmesi duruyor | ⚠️ Eski kod geri gelmiş — bildir |
| "Bildirim Gönder" düğmesi var | ⚠️ Eski akış — bildir |
| Kartta "N ilgilendi" yazıyor | ⚠️ Ölü sayaç — bildir |
| Müsait değilken mesaj atılıyor | ⚠️ Kapı bozuk |
| Müsait olmayan usta aramada çıkıyor | ⚠️ Filtre bozuk |
| Aynı kişiyle ikinci sohbet açılıyor | ⚠️ `chatIdFor` bozuk — ciddi |
| İlan listede çıkmıyor | Meslek/bölge eşleşmesini kontrol et |

---

<a id="bolum-7"></a>

## 7 · Mesajlaşma ⭐

**Kapsam:** Serbest mesajlaşma, sohbet listesi, mesaj özellikleri, kilit.
**Hesap:** A + B · **Süre:** ~25 dk

> [!important] Kural değişti
> **Serbest pazaryeri:** iki taraf da baştan mesaj atabilir. Eskiden usta,
> müşteri yazana kadar bekliyordu. **İletişim maskelemesi de kaldırıldı** —
> telefon/e-posta artık gizlenmiyor.


### 7.1 Sohbet başlatma

- [ ] **7.1.1** A, ilgilenen ustanın kartından sohbet açabiliyor
- [ ] **7.1.2** Sohbet ekranı açılıyor, **ilan başlığı** üstte görünüyor
- [ ] **7.1.3** Mesaj yazılıp gönderilebiliyor
- [ ] **7.1.4** Mesaj karşı tarafa ulaşıyor
- [ ] **7.1.5** ⭐ B, **usta profilinden** doğrudan sohbet başlatabiliyor
      *(müsaitse)*

### 7.2 Serbest mesajlaşma ⭐

**Hazırlık:** Yeni ilan + yeni ilgi, müşteri **hiç yazmasın**.

- [ ] **7.2.1** ⭐ B (usta) sohbete girsin → **giriş kutusu AÇIK olmalı**
- [ ] **7.2.2** ⭐ B **ilk mesajı atabiliyor**
      *(eskiden "İletişimi müşteri başlatır" şeridi vardı)*
- [ ] **7.2.3** A mesajı alıyor
- [ ] **7.2.4** ⚠️ Hiçbir yerde *"İletişimi müşteri başlatır"* yazmamalı

### 7.3 Maskeleme kaldırıldı

- [ ] **7.3.1** ⭐ Sohbete telefon yazın (`0532 123 45 67`) →
      **olduğu gibi görünmeli**, `•••` OLMAMALI
- [ ] **7.3.2** E-posta yazın → olduğu gibi görünüyor
- [ ] **7.3.3** ⚠️ *"Güvenliğiniz için gizlendi"* uyarısı **çıkmamalı**

### 7.4 Mesaj özellikleri

- [ ] **7.4.1** Fotoğraf gönderilebiliyor
- [ ] **7.4.2** Fotoğraf karşı tarafta açılıyor, büyütülebiliyor
- [ ] **7.4.3** Mesaj silme → "Bu mesaj silindi" görünüyor
- [ ] **7.4.4** Okundu bilgisi / tik doğru
- [ ] **7.4.5** Uzun sohbette kaydırma akıcı

### 7.5 Sohbet listesi

- [ ] **7.5.1** Mesajlar sekmesi tüm sohbetleri gösteriyor
- [ ] **7.5.2** İlan sohbetlerinde **ilan başlığı** satırı var
- [ ] **7.5.3** Okunmamış rozeti doğru sayıyor
- [ ] **7.5.4** Okuyunca rozet düşüyor
- [ ] **7.5.5** Arşivleme çalışıyor (kişisel)
- [ ] **7.5.6** ⭐ Aynı çiftle **iki farklı ilan** → **TEK sohbet**
      *(kişi başına tek kutu; iki ayrı sohbet açılırsa `chatIdFor` bozuk)*

### 7.6 Sohbet silme akışı bozmuyor

- [ ] **7.6.1** Kendi mesajınızı silin → "Bu mesaj silindi" kalıyor
- [ ] **7.6.2** Sohbeti silin (kişisel) → listenizden düşüyor
- [ ] **7.6.3** ⚠️ Karşı tarafın geçmişi **etkilenmiyor**
- [ ] **7.6.4** ⭐ Silme sonrası karşı taraf **hâlâ yazabiliyor**
- [ ] **7.6.5** Karşı taraf yazınca sohbet listenizde **yeniden beliriyor**

### 7.7 Müsaitlik ve mevcut sohbet ⭐

**Hazırlık:** A ile B arasında **var olan** bir sohbet olsun.

- [ ] **7.7.1** B müsaitliğini **kapatsın**
- [ ] **7.7.2** ⭐ A, Mesajlar'dan o sohbete girsin → **hâlâ yazabilmeli**
      *(müsaitlik yalnız YENİ sohbeti engeller)*
- [ ] **7.7.3** ⭐ B de **yanıt verebilmeli**
- [ ] **7.7.4** A, B'nin profiline girsin → yeni sohbet düğmesi **pasif**

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Usta ilk mesajı atamıyor | ⚠️ Kural deploy edilmemiş olabilir |
| Telefon `•••` çıkıyor | ⚠️ Maskeleme geri gelmiş |
| Müsait değilken mevcut sohbet kilitli | 🔴 **Kritik — bildir** |
| Aynı çiftle İKİ ayrı sohbet açılıyor | ⚠️ `chatIdFor` bozuk — **ciddi** |

---

<a id="bolum-8"></a>

## 8 · İlan Ömrü ve Yönetimi ⭐

**Kapsam:** Üç durum, düzenleme penceresi, silme, limitler, süre dolumu.
**Hesap:** A (+ B doğrulama için) · **Süre:** ~25 dk

> [!important] Bu dosya 2026-08-09'da SIFIRDAN yazıldı
> Eskisi (`08-Is-Akisi.md`) usta seçimi → tamamlama onayı → sorun bildirme
> zincirini test ediyordu. **O akışın tamamı kaldırıldı.** İlan artık bir
> duyurudur: açılır, süresi dolar ya da sahibi kaldırır.

> [!warning] Durum ÜÇ tane
> `open` (Yayında) · `cancelled` (Kaldırıldı) · `expired` (Süresi doldu).
> Ekranda "İş yürüyor", "Tamamlandı", "Sorun — beklemede" gibi bir etiket
> görürseniz **eski kod geri gelmiş** demektir → bulgu yazın.


### 8.1 Durum etiketleri ⭐

- [ ] **8.1.1** Yeni ilan **"Yayında"** görünüyor
- [ ] **8.1.2** ⚠️ **"Teklif toplanıyor"** yazmıyor *(eski etiket)*
- [ ] **8.1.3** İlanlarım listesinde durum rozeti doğru
- [ ] **8.1.4** ⚠️ Listede **"N ilgilendi"** sayacı **YOK**
- [ ] **8.1.5** ⚠️ İlan detayında **adım göstergesi (stepper)** **YOK**

### 8.2 Düzenleme penceresi ⭐

> Yayından sonra **1 saat** içinde, yalnız açık ilanda.

- [ ] **8.2.1** Yeni açtığınız ilanda **"Düzenle"** görünüyor
- [ ] **8.2.2** Başlık ve açıklama değiştirilebiliyor
- [ ] **8.2.3** Bütçe **kaldırılabiliyor** (boş bırakınca gidiyor)
- [ ] **8.2.4** Kaydedince liste ve detay güncelleniyor
- [ ] **8.2.5** ⭐ **Kaldırdığınız** bir ilanda "Düzenle" **YOK**
- [ ] **8.2.6** ⚠️ *(1 saat sonra)* eski ilanda "Düzenle" **kayboluyor**
      *(uzun test — atlanabilir, notunu düşün)*

### 8.3 İlan kaldırma ⭐

> **Değişiklik:** Artık **her ilan** kaldırılabilir. Eskiden "ustaya bağlanmış
> ilan silinemez" kuralı vardı — usta ataması diye bir şey kalmadı.

- [ ] **8.3.1** İlan detayında **"Kaldır"/"Sil"** var
- [ ] **8.3.2** Onay soruluyor
- [ ] **8.3.3** Onaylayınca ilan listeden düşüyor
- [ ] **8.3.4** ⭐ **Mesajlaştığınız** bir ilanı silin → **silinebiliyor**
      *(eskiden engelliydi)*
- [ ] **8.3.5** ⭐⭐ Sildikten sonra **Mesajlar**'a bakın →
      **sohbet DURUYOR**, geçmiş mesajlar okunabiliyor
      *(sohbetler ilandan bağımsız yaşar — en kritik adım)*
- [ ] **8.3.6** B tarafında da sohbet duruyor
- [ ] **8.3.7** İptal nedeni soruluyorsa seçenekler mantıklı
      *("Günlük ilan hakkı doldu" seçeneği KULLANICIYA sunulmamalı)*

### 8.4 Açık ilan limiti ⭐

- [ ] **8.4.1** Arka arkaya **5 ilan** açın → hepsi açılıyor
- [ ] **8.4.2** ⭐ **6.** ilanı açmayı deneyin → **engelleniyor**,
      anlaşılır uyarı çıkıyor
- [ ] **8.4.3** Bir ilanı **kaldırın** → yeniden ilan açılabiliyor
      *(sayaç düştü)*
- [ ] **8.4.4** ⚠️ Uyarı metni "5" sayısını söylüyor mu?

### 8.5 Alan sınırları

- [ ] **8.5.1** Başlık **80** karakterde duruyor
- [ ] **8.5.2** Açıklama **600** karakterde duruyor
- [ ] **8.5.3** Fotoğraf **5** taneden fazla eklenemiyor
- [ ] **8.5.4** Boş başlıkla ilan verilemiyor
- [ ] **8.5.5** Çok büyük fotoğraf (>5 MB) reddediliyor / küçültülüyor

### 8.6 Süre dolumu

> Süre seçenekleri: **3 / 5 / 7 gün**. Kolay İş her zaman **1 gün**.

- [ ] **8.6.1** İlan verirken süre seçenekleri **3, 5, 7** gün
- [ ] **8.6.2** ⚠️ **24 saat** seçeneği **YOK** *(eski değer)*
- [ ] **8.6.3** ⭐ Kolay İş seçince süre **1 gün**'e sabitleniyor ve
      seçim gizleniyor
- [ ] **8.6.4** İlan detayında kalan süre / bitiş tarihi görünüyor
- [ ] **8.6.5** *(varsa eski ilan)* Süresi dolmuş ilan **"Süresi doldu"**
      görünüyor ve usta feed'inde **çıkmıyor**

### 8.7 Kolay İş ⭐

- [ ] **8.7.1** Ana sayfada **kendi tam genişlikli kartı** var
- [ ] **8.7.2** Karttan ilan verme açılıyor
- [ ] **8.7.3** Süre otomatik 1 gün *(8.6.3 ile aynı)*
- [ ] **8.7.4** ⭐ Farklı ilçedeki usta bu ilanı görüyor *(il geneli)*
- [ ] **8.7.5** Başka ildeki usta görmüyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| "Teklif toplanıyor" / "İş yürüyor" etiketi | ⚠️ Eski durum makinesi — **ciddi** |
| "Ustayı Seç" / "İşi tamamladım" düğmesi | ⚠️ Kaldırılmış akış geri gelmiş |
| İlan silinince sohbet de gidiyor | ⚠️⚠️ **En ciddi bulgu** — veri kaybı |
| Mesajlaşılan ilan silinemiyor | ⚠️ Eski `canDelete` kuralı |
| 6. ilan açılabiliyor | ⚠️ Limit kapısı bozuk (sayaç CF'den gelmiyor olabilir) |
| İlan silince limit düşmüyor | ⚠️ `onJobWritten` silme dalı çalışmıyor |
| Süre seçeneğinde 24 saat var | ⚠️ Eski değer |

---

<a id="bolum-9"></a>

## 9 · Değerlendirme

**Kapsam:** Karşılıklı puanlama, etiketler, sayaç güncellemesi.
**Hesap:** A + B · **Süre:** ~15 dk

> [!important] Karşılıklı
> İş bitince **iki taraf da** değerlendirebilir:
> müşteri → usta (`c2a`) ve usta → müşteri (`a2c`).
>
> **Gizlilik farkı:** ustanın puanı herkese açık (vitrin); müşterinin puanı
> **gizli** — profilde yalnız *kaç* değerlendirme aldığı görünür.

**Hazırlık:** Bölüm 8'de tamamlanmış bir iş.


### 9.1 Müşteri → Usta

- [ ] **9.1.1** A, sohbette/ilan detayında **"Değerlendir"** görüyor
- [ ] **9.1.2** Değerlendirme ekranı açılıyor
- [ ] **9.1.3** Yıldız (1–5) seçilebiliyor
- [ ] **9.1.4** Hazır etiketler seçilebiliyor (Temiz İşçilik, Dakik vb.)
- [ ] **9.1.5** Yorum yazılabiliyor
- [ ] **9.1.6** Gönderilince onay mesajı çıkıyor
- [ ] **9.1.7** ⭐ B'nin profilinde **puan güncelleniyor**
- [ ] **9.1.8** Değerlendirme B'nin profilinde listeleniyor
- [ ] **9.1.9** Etiketler B'nin profilinde "öne çıkan" olarak görünüyor

### 9.2 Usta → Müşteri ⭐

- [ ] **9.2.1** ⭐ B'de de **"Değerlendir"** şeridi var
- [ ] **9.2.2** B, A'yı puanlayabiliyor
- [ ] **9.2.3** ⚠️ A'nın profilinde **puan GÖRÜNMEMELİ** (gizli)
- [ ] **9.2.4** ⭐ A'nın profilinde **"tamamlanan"** sayacı artmış
- [ ] **9.2.5** ⚠️ A puan verdikten sonra B'nin şeridi **kaybolmamalı**
      *(çıkmaz regresyonu)*

### 9.3 Tekrar değerlendirme ⭐

> Kimlik `rev_{yazan}__{hedef}` — **kişi başına tek değerlendirme**.
> İlan başına değil: aynı kişiyi ikinci kez puanlarsanız GÜNCELLENİR.

- [ ] **9.3.1** Aynı kişiyi tekrar değerlendirmeye girin
- [ ] **9.3.2** ⭐ Başlık **"Değerlendirmeyi Güncelle"** diyor
- [ ] **9.3.3** ⭐ Form **eski puan ve yorumla DOLU** geliyor
- [ ] **9.3.4** ⚠️ Kaydedince **yeni kayıt oluşmamalı** — mevcut güncellenmeli
- [ ] **9.3.5** Profildeki toplam değerlendirme sayısı **artmamalı**
- [ ] **9.3.6** Ortalama puan yeni değere göre değişmeli
- [ ] **9.3.7** ⭐ **Farklı bir kişiyi** değerlendirin → bu kez sayı **artıyor**

### 9.4 Görünürlük

- [ ] **9.4.1** Değerlendirmeler usta profilinde herkese açık
- [ ] **9.4.2** Yorumlarda değerlendiren kişinin adı görünüyor
- [ ] **9.4.3** ⚠️ Misafir de usta değerlendirmelerini görebiliyor
- [ ] **9.4.4** ⭐ **Müşteri puanı da herkese açık** — müşteri profilinde
      aldığı puan görünüyor *(2026-08-08'de bilerek açıldı, gizlilik
      ihlali DEĞİL)*

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Bir tarafta "Değerlendir" yok | ⚠️ **Kritik — çıkmaz** |
| Tekrar değerlendirince sayaç artıyor | ⚠️ Puan şişirme açığı |
| Güncellemede form BOŞ geliyor | ⚠️ Mevcut kayıt okunmuyor |
| Puan güncellenmiyor | CF gecikmesi mi? 1 dk bekleyip bakın |

> [!warning] Bilinen açık — bulgu DEĞİL
> Değerlendirme için **hiçbir koşul yok** (sohbet şartı bile). Hiç
> konuşmadığınız birini puanlayabiliyorsanız bu **bilinçli bir karar**;
> sahte hesap riski kabul edildi, v2'de sohbet şartı eklenebilir.

---

<a id="bolum-10"></a>

## 10 · Güvenlik ve Ayarlar

**Kapsam:** Engelleme, şikayet, bildirim tercihleri, doğrulama, yasal, hesap.
**Hesap:** A + B · **Süre:** ~15 dk


### 10.1 Kullanıcı engelleme

- [ ] **10.1.1** Sohbet menüsünde "Engelle" var
- [ ] **10.1.2** Engellenince onay isteniyor
- [ ] **10.1.3** ⚠️ Engellenen kişi **mesaj gönderemiyor**
- [ ] **10.1.4** ⚠️ Engellenen, **engellendiğini GÖRMEMELİ**
- [ ] **10.1.5** Hesap Ayarları → Engellenen Kullanıcılar listesi
- [ ] **10.1.6** Engel kaldırılabiliyor

### 10.2 Şikayet

- [ ] **10.2.1** İlan detayında "Şikayet Et" var
- [ ] **10.2.2** Sohbette mesaj şikayeti var
- [ ] **10.2.3** Usta profilinde şikayet var
- [ ] **10.2.4** Neden seçilebiliyor, açıklama yazılabiliyor
- [ ] **10.2.5** Gönderilince onay mesajı çıkıyor
- [ ] **10.2.6** ⚠️ Aynı içeriği tekrar şikayet → mükerrer kayıt olmamalı

### 10.3 Bildirim tercihleri

- [ ] **10.3.1** Hesap Ayarları → Bildirim tercihleri açılıyor
- [ ] **10.3.2** Kategoriler: Sohbet · İş güncellemeleri · Yakındaki ilanlar
- [ ] **10.3.3** Anahtarlar kapatılıp açılabiliyor
- [ ] **10.3.4** ⭐ En altta **tanılama satırı** var — ne yazıyor? *(not alın)*
- [ ] **10.3.5** "Yeniden dene" düğmesi çalışıyor

> **Push gelmiyorsa:** tanılama satırındaki metni **aynen** not alın.
> Sebebi orada yazıyor (izin / App Check / token).

### 10.4 Doğrulama

- [ ] **10.4.1** Telefon doğrulama akışı açılıyor
- [ ] **10.4.2** SMS kodu geliyor, doğrulanıyor
- [ ] **10.4.3** ⭐ Doğrulanınca profilde **mavi tik** beliriyor
- [ ] **10.4.4** Numara değiştirilebiliyor
- [ ] **10.4.5** E-posta doğrulama bağlantısı gönderilebiliyor

### 10.5 Yasal ve yardım

- [ ] **10.5.1** Yan menü → Yardım açılıyor, SSS listeleniyor
- [ ] **10.5.2** SSS kategorileri çalışıyor
- [ ] **10.5.3** ⚠️ **"Usta Çantası" kategorisi OLMAMALI** (kaldırıldı)
- [ ] **10.5.4** Yasal metinler açılıyor (Kullanım Koşulları, Gizlilik, KVKK)
- [ ] **10.5.5** Destek formu çalışıyor

### 10.6 Hesap silme

> ⚠️ **En sona bırakın** — geri alınamaz. Test hesabıyla yapın.

- [ ] **10.6.1** Hesap Ayarları → Hesabı Sil
- [ ] **10.6.2** ⚠️ Açık onay isteniyor, "geri alınamaz" uyarısı var
- [ ] **10.6.3** Silme sırasında ilerleme göstergesi çıkıyor
- [ ] **10.6.4** Silinince oturum kapanıyor, Ana Sayfa'ya dönülüyor
- [ ] **10.6.5** Aynı hesapla tekrar giriş → **yeni/boş profil** açılıyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Engellenen kişi mesaj atabiliyor | 🔴 **Güvenlik — bildir** |
| Engellendiği anlaşılıyor | ⚠️ Gizlilik sızıntısı |
| Push tanılaması hata veriyor | Metni **aynen** kopyalayın |
| Silme sonrası eski veri duruyor | ⚠️ CF temizliği eksik |

---

<a id="bolum-11"></a>

## 11 · Admin Paneli

**Kapsam:** Erişim kapısı, 12 sekme, moderasyon araçları, sayaçlar.
**Ortam:** Tarayıcı — `alljob1-admin` sitesi · **Süre:** ~25 dk

> [!important] Ayrı uygulama
> Admin paneli tüketici uygulamasından **tamamen bağımsız** çalışır
> (`lib/main_admin.dart`, kendi Hosting sitesi). Admin kodu kullanıcının
> indirdiği binary'e **hiç girmez**. Aynı Firebase projesini paylaşır.

> [!tip] Derleme
> ```bash
> flutter build web --target lib/main_admin.dart --release
> firebase deploy --only hosting:alljob1-admin
> ```


### 11.1 Erişim kapısı ⭐

- [ ] **11.1.1** Panel adresi açılıyor, giriş ekranı geliyor
- [ ] **11.1.2** ⭐ **Normal kullanıcı** hesabıyla girin → **"Yetkisiz"**
      ekranı çıkıyor, panele girilemiyor
- [ ] **11.1.3** Admin hesabıyla girince panel açılıyor
- [ ] **11.1.4** Sağ üstte e-posta ve rol (Superadmin / Moderatör) yazıyor
- [ ] **11.1.5** Çıkış yapınca giriş ekranına dönüyor
- [ ] **11.1.6** ⚠️ Sekme başlığı **"İlanda Hizmet · Yönetim"** yazıyor

### 11.2 Sekmeler ve gezinme ⭐

> **12 sekme:** Özet · Şikayetler · Kullanıcılar · Ustalar · İlanlar ·
> Yorumlar · Destek · Bildirim · Platform · *(superadmin)* Kadro · Denetim ·
> Sistem

- [ ] **11.2.1** Geniş ekranda **sol şerit** (rail), dar ekranda **çekmece**
- [ ] **11.2.2** Her sekme açılıyor, hata vermiyor
- [ ] **11.2.3** Şikayet sekmesinde **rozet** (açık şikayet sayısı) var
- [ ] **11.2.4** ⚠️ **"Anlaşmazlıklar"** sekmesi **OLMAMALI** *(kaldırıldı)*
- [ ] **11.2.5** ⭐ Özet'teki **hızlı erişim** çipleri **doğru sekmeyi**
      açıyor *(indeksler elle eşleniyor — kayma riski yüksek)*
- [ ] **11.2.6** ⭐ Özet'teki **KPI kartına** tıklayınca doğru sekme açılıyor
- [ ] **11.2.7** Moderatör hesabında Kadro/Denetim/Sistem **görünmüyor**

### 11.3 Özet (dashboard) ⭐

- [ ] **11.3.1** Kullanıcı / usta / ilan sayaçları geliyor
- [ ] **11.3.2** ⚠️ **"Açık anlaşmazlık"** kartı **OLMAMALI**
- [ ] **11.3.3** İlan kartı alt yazısı **"Açık N · Kapalı N"**
- [ ] **11.3.4** ⚠️ **"Süren"** / **"Biten"** ilan sayacı **OLMAMALI**
- [ ] **11.3.5** ⭐ **"Eski durumlu ilan"** kartı: *(varsa)* canlıda
      kaldırılmış durum taşıyan kayıt sayısı — **hata değil**, temizlik
      göstergesi. Yoksa kart hiç görünmez.
- [ ] **11.3.6** "Sayaçları yeniden kur" çalışıyor, sayılar tutarlı
- [ ] **11.3.7** Bayat uyarısı (24 saatten eski) mantıklı görünüyor

### 11.4 Şikayetler

- [ ] **11.4.1** Şikayet kuyruğu listeleniyor, sayfalama çalışıyor
- [ ] **11.4.2** Şikayet detayı açılıyor
- [ ] **11.4.3** "Üstlen" / "Bırak" çalışıyor
- [ ] **11.4.4** Karara bağlama çalışıyor, kuyruktan düşüyor
- [ ] **11.4.5** Mesaj şikayetinde sohbet dökümü görüntülenebiliyor
- [ ] **11.4.6** Mesaj gizleme / geri alma çalışıyor

### 11.5 Kullanıcı ve usta yönetimi

- [ ] **11.5.1** Kullanıcı arama (e-posta / uid) çalışıyor
- [ ] **11.5.2** Kullanıcı özeti açılıyor; sayaçlar geliyor
- [ ] **11.5.3** ⚠️ Özette **"Teklif"** sayacı **OLMAMALI** *(kaldırıldı)*
- [ ] **11.5.4** ⭐ Askıya alma çalışıyor → **kullanıcı uygulamada**
      `/suspended` ekranına düşüyor *(cihazda doğrulayın)*
- [ ] **11.5.5** Askı kaldırma çalışıyor
- [ ] **11.5.6** Kullanıcı notu eklenebiliyor / listeleniyor
- [ ] **11.5.7** Usta doğrulama / öne çıkarma bayrakları çalışıyor
- [ ] **11.5.8** Premium verme çalışıyor
- [ ] **11.5.9** Sertifika inceleme açılıyor

### 11.6 İlan moderasyonu ⭐

- [ ] **11.6.1** İlan listesi geliyor, sayfalama çalışıyor
- [ ] **11.6.2** ⭐ Durum filtresinde **yalnız üç seçenek**:
      Açık · İptal Edildi · Süresi Doldu
- [ ] **11.6.3** ⚠️ **"Usta Seçildi"/"Tamamlandı"/"Sorun"** filtresi
      **OLMAMALI**
- [ ] **11.6.4** İl filtresi çalışıyor
- [ ] **11.6.5** İlan gizleme çalışıyor → uygulamada görünmüyor
- [ ] **11.6.6** ⭐ Zorla iptal (`force_cancel`) çalışıyor →
      **ilan sahibine** bildirim gidiyor
- [ ] **11.6.7** ⚠️ Zorla iptalde ikinci bir kişiye (usta) bildirim
      **gitmemeli** *(usta ataması yok)*

### 11.7 Yorum, destek, duyuru

- [ ] **11.7.1** Yorum listesi geliyor; gizleme çalışıyor
- [ ] **11.7.2** Gizlenen yorum uygulamada görünmüyor, ortalama puan güncelleniyor
- [ ] **11.7.3** Destek talepleri listeleniyor, durum değiştirilebiliyor
- [ ] **11.7.4** Toplu bildirim gönderiliyor *(dikkat: gerçek push gider)*
- [ ] **11.7.5** Zamanlanmış kampanya kurulabiliyor / iptal edilebiliyor

### 11.8 Superadmin alanları

- [ ] **11.8.1** Kadro: rol atama, davet oluşturma/iptal çalışıyor
- [ ] **11.8.2** ⚠️ Yetki listesinde **"Anlaşmazlık hakemliği"**
      **OLMAMALI** *(kaldırıldı)*
- [ ] **11.8.3** Denetim: kayıtlar listeleniyor, kategori filtresi çalışıyor
- [ ] **11.8.4** ⚠️ Kategori filtresinde **"Anlaşmazlık"** **OLMAMALI**
- [ ] **11.8.5** *(varsa eski kayıt)* "Anlaşmazlık çözüldü" etiketi **okunabilir
      Türkçe** görünüyor — ham `resolve_dispute` yazmıyor
- [ ] **11.8.6** Sistem: uzaktan yapılandırma okunuyor/yazılıyor
- [ ] **11.8.7** Dışa aktarma (CSV) çalışıyor, **telefon içermiyor**

### 11.9 Görünüm

- [ ] **11.9.1** Dar ekranda (telefon) panel kullanılabilir durumda
- [ ] **11.9.2** Koyu/açık tema geçişi bozulma yapmıyor
- [ ] **11.9.3** Uzun tablolar yatay kayabiliyor, taşma yok

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Normal kullanıcı panele girebiliyor | 🔴🔴 **En ciddi** — hemen bildir |
| Hızlı erişim yanlış sekme açıyor | ⚠️ İndeks kayması (sekme eklenmiş/çıkmış) |
| "Anlaşmazlık" herhangi bir yerde | ⚠️ Kaldırılmış modül izi |
| KPI sayıları toplamı tutmuyor | `jobsOther` kartına bakın |
| "Eski durumlu ilan" > 0 | Bilgi — canlıda temizlenmemiş kayıt var |
| Sayaç sıfır kalıyor | CF deploy edilmemiş olabilir |

---

<a id="bolum-12"></a>

## 12 · Tanıtım Sitesi ve Yasal Metinler

**Kapsam:** `alljob1` sitesi — marka, logo, içerik doğruluğu, yasal uyum.
**Ortam:** Tarayıcı (masaüstü + telefon) · **Süre:** ~15 dk

> [!important] Neden test ediliyor?
> Bu site **Play Store başvurusunun parçası**: gizlilik politikası ve hesap
> silme sayfası zorunlu. Metinler koddaki **gerçek davranışı** anlatmak
> zorunda — yanlış bilgi yasal risktir, kozmetik sorun değil.

> [!tip] Deploy
> ```bash
> firebase deploy --only hosting:alljob1
> ```


### 12.1 Marka ve logo ⭐

> Marka **üç kez** değişti: Ustasından → Sepette Hizmet → **İlanda Hizmet**.

- [ ] **12.1.1** ⭐ Tüm sayfalarda marka **"İlanda Hizmet"**
- [ ] **12.1.2** ⚠️ **"Sepette Hizmet"** hiçbir yerde geçmiyor
- [ ] **12.1.3** ⚠️ **"Ustasından"** / **"USTASINDAN"** hiçbir yerde geçmiyor
      *(eski logoda yazıyordu)*
- [ ] **12.1.4** ⭐ Başlıktaki logo **"İH" monogramı** (renkli), eski turuncu
      çekiçli logo **değil**
- [ ] **12.1.5** Logo 40px'te net görünüyor, bulanık değil
- [ ] **12.1.6** Tarayıcı sekmesinde favicon yeni logo
- [ ] **12.1.7** Footer'daki logo ve marka adı doğru

### 12.2 Sosyal paylaşım kartı ⭐

> Sitenin linkini WhatsApp / X / Slack'e yapıştırınca çıkan önizleme.

- [ ] **12.2.1** ⭐ Linki WhatsApp'ta paylaşın → **geniş kart** çıkıyor
      *(kare küçük ikon değil)*
- [ ] **12.2.2** Kartta **"İlanda Hizmet"** yazıyor
- [ ] **12.2.3** Kartta logo görünüyor, Türkçe karakterler bozuk değil
- [ ] **12.2.4** *(alternatif)* [opengraph.xyz](https://www.opengraph.xyz)
      ile URL'yi kontrol edin

### 12.3 İçerik doğruluğu ⭐

> Site, ürünün **bugün yaptığını** anlatmalı.

- [ ] **12.3.1** ⚠️ **"teklif"** kelimesi hiçbir yerde geçmiyor
      *(teklif akışı kaldırıldı)*
- [ ] **12.3.2** ⚠️ **"teklifleri karşılaştır"**, **"ustayı seç"** gibi
      ifadeler yok
- [ ] **12.3.3** ⭐ "Nasıl çalışır" bölümü **doğrudan mesajlaşmayı** anlatıyor
- [ ] **12.3.4** Özellik kartları mevcut özellikleri anlatıyor
- [ ] **12.3.5** Cihaz önizlemesindeki metinler gerçekle uyumlu

### 12.4 Yasal metinler ⭐⭐

> **En kritik bölüm.** Bu metinler `deleteAccount` CF'i ile birebir tutmalı.

- [ ] **12.4.1** Dört sayfa da açılıyor: Kullanım Koşulları · Gizlilik ·
      KVKK · Hesap Silme
- [ ] **12.4.2** ⭐⭐ **Hesap silme** sayfası: **"tüm ilanlarınız SİLİNİR"**
      diyor
- [ ] **12.4.3** ⚠️ **"ustaya bağlanmamış açık ilanlarınız"** ifadesi
      **OLMAMALI** *(eski davranış)*
- [ ] **12.4.4** ⚠️ **"aktif işleriniz iptal edilir"** ifadesi **OLMAMALI**
- [ ] **12.4.5** ⚠️ **"tamamlanmış işler anonimleştirilir"** ifadesi
      **OLMAMALI**
- [ ] **12.4.6** ⭐ Gizlilik politikasındaki silme maddesi hesap-silme
      sayfasıyla **çelişmiyor**
- [ ] **12.4.7** ⭐ İletişim e-postası **`ilandahizmet@gmail.com`**
      *(`aboneai.plus@gmail.com` HİÇBİR yerde geçmemeli — eski adres)*
- [ ] **12.4.8** Ana sayfadaki yasal kartlar doğru sayfalara gidiyor

> [!warning] Kod değişirse bu metinler de değişir
> `deleteAccount` CF'ine dokunan her değişiklikten sonra
> `hesap-silme.html` + `gizlilik-politikasi.html` gözden geçirilmeli.
> → [[Cloud-Functions-Haritasi]]

### 12.5 Gezinme ve görünüm

- [ ] **12.5.1** Telefonda hamburger menü açılıyor/kapanıyor
- [ ] **12.5.2** Menüden bir bağlantıya tıklayınca menü kapanıyor
- [ ] **12.5.3** ESC tuşu menüyü kapatıyor
- [ ] **12.5.4** Sayfa kaydırınca üst şerit görünümü değişiyor
- [ ] **12.5.5** "İçeriğe geç" bağlantısı Tab'a basınca beliriyor
- [ ] **12.5.6** Telefonda yatay kaydırma / taşma yok
- [ ] **12.5.7** Yasal sayfalar telefonda okunabilir

### 12.6 Admin sitesi ayrımı

- [ ] **12.6.1** ⭐ Admin paneli **ayrı adreste** (`alljob1-admin`)
- [ ] **12.6.2** Tanıtım sitesinden admin paneline **bağlantı yok**
- [ ] **12.6.3** ⭐ Admin sekmesi başlığı **"İlanda Hizmet · Yönetim"**
- [ ] **12.6.4** Admin sayfası kaynağında `noindex` var
      *(aramaya çıkmamalı)*

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Hesap silme metni koddan farklı | 🔴🔴 **Yasal risk** — hemen bildir |
| "Sepette Hizmet" / "Ustasından" | ⚠️ Eski marka — deploy edilmemiş olabilir |
| Eski turuncu çekiçli logo | ⚠️ Tarayıcı önbelleği? Ctrl+F5 deneyin |
| Paylaşım kartı kare/bozuk | ⚠️ og-image güncellenmemiş |
| "teklif" geçen cümle | ⚠️ Kaldırılmış akış |


---

# 📝 BULGULAR

Kırık bulduğun her şeyi buraya yaz. Adım numarasını yazmayı unutma —
düzeltirken oraya bakacağım.

| # | Adım | Ne oldu? | Beklenen | Öncelik |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
| 8 | | | | |
| 9 | | | | |
| 10 | | | | |

**Öncelik:** 🔴 engelleyici · ⚠️ ciddi · 🟡 küçük · 💡 iyileştirme

### Not alırken

- **Ekran görüntüsü** al — özellikle görsel bozukluklarda
- **Hangi hesapla** (A/B) ve **hangi ekranda** olduğunu yaz
- Tekrarlanıyor mu? Bir kez mi oldu, her seferinde mi?
- Hata mesajı çıktıysa **tam metnini** yaz (`permission-denied` gibi)

---

## Test bitince

1. Bulguları yukarıdaki tabloya geç
2. [[99-BULGULAR]] dosyasına da kopyala *(kalıcı kayıt)*
3. Bana tabloyu ver — sıraya koyup düzeltelim

---
İlgili: [[00-TEST-PLANI]] (bölüm bölüm) · [[Mevcut-Akislar]] · [[Bilinen-Tuzaklar]]

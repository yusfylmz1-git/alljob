# 🐛 Bulgular

> Test sırasında bulunan her şey buraya. Ben düzelttikçe **Durum** sütununu
> güncellerim.

---

## Nasıl bildirilir?

Bana şunu söylemeniz yeterli — ben buraya kaydederim:

> **"5.3.4 çalışmadı — usta hâlâ yazamıyor"**

Faydalı olursa ekleyin: hangi hesap, ekran görüntüsü, hata mesajının aynısı.

---

## Öncelik ölçeği

| | Anlamı | Örnek |
|---|---|---|
| 🔴 **P0** | Kullanıcıyı engelliyor, veri kaybı, gizlilik ihlali | Mesaj gönderilemiyor · telefon numarası herkese açık · takip kayıtları silindi |
| 🟠 **P1** | Bozuk ama etrafından dolaşılabilir | Rozet yanlış sayıyor · liste tazelenmiyor |
| 🟡 **P2** | Cila, rahatsız edici ama işlevsel | Metin taşması · koyu temada soluk renk |

---

## Açık bulgular

| # | Adım | Ne oldu | Öncelik | Durum |
|---|---|---|---|---|
| K-01 | 8.3 | Usta profilinde telefon numarası görünüyor (opt-in özellik) | — | 🤔 **karar bekliyor** |
| K-02 | 2.1 | Profil ekranı karmaşık geliyor; "Vitrini tamamla" kartı fazla dikkat çekiyor | 🟡 P2 | 🤔 **karar bekliyor** |
| K-03 | 1.1 | Onboarding sığ; "nasıl kullanılır" anlatımı eksik | 🟡 P2 | 📋 **planlandı** |
| K-04 | — | Liste açılışında kartlar için "şelale" giriş animasyonu | 🟡 P2 | 📋 **planlandı** |

### K-04 · Liste giriş animasyonu (şelale) — PLAN

**Durum:** Dokunma yaylanması (`TapScale`) **yapıldı** (`3a18eb0`). Şelale
animasyonu bekliyor.

**İstenen:** Liste açılınca kartlar hep birden değil, yukarıdan aşağıya
sırayla süzülerek görünsün.

**İki gerçek risk — naif uygulama kötü sonuç verir:**

1. **Tekrar oynatma.** Listeler `ListView.builder` kullanıyor; kaydırıp geri
   dönünce widget yeniden kurulur. `index × gecikme` yazılırsa kartlar her
   dönüşte tekrar animasyon oynatır → sinir bozucu.
   **Çözüm:** yalnız **ilk yüklemede** ve yalnız **ilk ~8 kart**; sonrakiler
   anında görünsün.
2. **Gecikme hissi.** 50 ms × 10 kart = yarım saniye; kullanıcı listeyi geç
   görmüş hisseder. **30–40 ms** ve **maks 6–8 kart** sınırı gerekir.

**Yaklaşım:** Tek paylaşılan widget yaz (`ListEnter` gibi), her ekranda ayrı
ayrı değil — yoksa 21 dosyaya dağılmış tutarsız animasyonlar olur.

**Mevcut dil:** Sohbetteki `_MessageEnter` (`chat_screen.dart`, 280 ms
`easeOutCubic`) aynı hareket dilini kullanıyor; listelerde de ona uyulmalı.

### K-03 · Onboarding + Yardım zenginleştirme — PLAN

**Karar:** Kısa onboarding + zengin Yardım. (Kullanıcı seçimi.)

**Gerekçe:** Onboarding'in düşmanı uzunluktur — 3 sayfayı 8'e çıkarırsak
kullanıcı "atla"ya basar ve hiçbirini okumaz. Detay, ihtiyaç anında
okunabileceği yerde (Yardım) durmalı.

**Şişme endişesi ölçüldü — sorun değil:**
| | Mevcut | Sonrası (tahmin) |
|---|---|---|
| Onboarding kodu | 297 satır | ~500 satır |
| Yardım kodu | 458 satır | ~700 satır |
| APK | 91 MB | +0.1 MB'tan az (kod, görsel değil) |

64K satırlık projede ~450 satır = **%0.7**. Şişme değil.

#### Faz 1 — Onboarding (3 sayfa KALSIN, kalitesi artsın)
Mevcut içerik zaten iyi (`onboarding_screen.dart:26-47`): "Aradığın usta
bölgende" / "İlanını ver ustalar gelsin" / "Usta mısın? Vitrinini aç".
- Sayfa **sayısını artırma**; görsel anlatımı güçlendir (ikon → küçük illüstrasyon
  veya animasyon)
- Son sayfaya *"Nasıl kullanılır?"* bağlantısı ekle → Yardım'a götürsün
- Atla düğmesi her zaman erişilebilir kalsın

#### Faz 2 — Yardım ekranı (asıl iş burada)
Şu an düz SSS listesi. Eklenecek: **rol bazlı adım adım rehberler**.
```
Yardım
├── 🚀 Nasıl başlarım?        ← YENİ, rehber formatı
│   ├── Müşteriysen: ilan ver → usta seç → değerlendir
│   └── Ustaysan: vitrin aç → ilgi bildir → işi tamamla
├── ❓ SSS                     ← mevcut, kategorili
└── 📞 Destek                  ← mevcut
```
Rehber içeriği ekran görselleriyle desteklenirse çok daha etkili olur.

#### Faz 3 (opsiyonel) — Bağlam içi ipuçları
Kullanıcı bir ekranı ilk kez açtığında tek seferlik ipucu balonu.
En etkili öğretme yöntemi ama en çok iş — Faz 1-2'den sonra değerlendirilsin.

> [!note] ui-ux-pro-max skill'i
> Bu iş için **fikir kaynağı** olarak mantıklı (onboarding kalıpları, tipografi,
> animasyon önerileri) ama **kod üretici** olarak değil — projenin kendi
> `AppPalette`/`AppTheme` sistemi var, yeni palet dayatması zarar verir.
> Kurulum: `npm i -g ui-ux-pro-max-cli && uipro init --ai claude`

### K-02 · Profil ekranı sadeleştirme — UX kararı

**Kullanıcı geri bildirimi:** *"müşteri ve usta profilleri farklı biliyorum ama
çok karmaşık. Vitrini düzenle de göze çok dikkat çekiyor."*

**Ekran görüntülerinden tespit — tasarım aslında iyi:**
Müşteri/Usta sekmesi net, renk kodlaması (mavi=müşteri / yeşil=usta) akıllıca,
alt bar role göre değişiyor. Sorun genel karmaşa değil, **üç nokta**:

#### 1. "Vitrini tamamla" kartı görsel olarak baskın 🟡
Turuncu/amber blok, ilerleme çubuğu, 6 rozet, büyük CTA — ekranın yarısını
kaplıyor ve **her açılışta** aynı yoğunlukta. Vurgu bilinçliydi (ustayı profil
tamamlamaya itmek) ama ölçek yanlış.

**Öneri:** İlerledikçe sönükleşsin.
- %0–50 → şu anki hâli (yeni usta gerçekten yönlendirilmeli)
- %51–99 → tek satır: *"Vitrin %67 — Hakkımda eksik"* + küçük "Tamamla" bağlantısı
- %100 → kart tamamen kalksın
- Rozetleri her zaman göstermek yerine **yalnız sıradaki adımı** yaz

#### 2. ARAÇLAR bölümü iki rolde de tekrar ediyor 🟡
`profile_screen.dart:92-120` — "Usta Çantası" ve "Ajanda" hem müşteri hem usta
modunda **aynen** görünüyor. Rol değiştirince değişmeyen bir blok, "karmaşık"
hissinin bir kaynağı: kullanıcı neyin role ait olduğunu ayırt edemiyor.

Ayrıca **isim tutarsızlığı**: müşteri modunda "Usta Çantası" yazıyor — müşteri
neden usta çantası görsün? (Araçlar herkese açık olabilir ama ismi rolü ima
ediyor.)

**Öneri:** Ya araçları rol-bağımsız ayrı bir sekmeye/menüye taşı, ya da müşteri
modunda gizle. En azından müşteri modunda adı nötrleştir ("Hesap Araçları").

#### 3. Vitrin düzenleme formu tek parça 🟡
`artisan_profile_edit_screen.dart` — 1601 satır, tek uzun form: fotoğraf,
hakkında, meslek, bölge, iş fotoğrafları, çalışma saatleri, **5 sosyal medya
alanı**, telefon anahtarı. `focusStep` deep-link'i var ama form yine bütün
hâlinde açılıyor.

**Öneri:** Sosyal medyayı katlanabilir *"Sosyal medya (isteğe bağlı)"*
bölümüne al — çoğu usta hiçbirini doldurmuyor, 5 alan boş yer kaplıyor.

> [!note] Ne zaman yapılmalı?
> **Test bittikten sonra.** Şimdi dokunulursa bölüm 2–9 yeni bir arayüzde test
> edilir ve karşılaştırma zemini kaybolur. K-01 ile birlikte topluca ele alınsın.

### K-01 · Vitrin telefonu — ürün kararı (hata DEĞİL)

**Durum:** Kod doğru çalışıyor, bilinçli tasarım. Karar sizin.

Ustanın profil düzenlemede açık bir anahtarı var: *"Telefon numaram profilimde
görünsün"*. Varsayılan **kapalı**. Üç şart birden: usta açmış + telefon
doğrulanmış + dolu (`ArtisanProfile.hasPublicPhone`). Kapatınca numara
veritabanından **silinir**, sadece gizlenmez.

**Gerilim:** Sohbette telefon yazmak maskeleniyor ([[Mimari-Kararlar]] ADR-10 —
"iş platform içinde kalmalı") ama profilde tek dokunuşla arama tuşu var. Usta
maskelemeye takılmadan aynı sonuca ulaşıyor. Komisyon/güvence modeli varsa bu
kapı onu delik bırakır.

**Seçenekler:**
| | Ne yapılır | Sonuç |
|---|---|---|
| A | Olduğu gibi bırak | Tasarım zaten sağlam; platform dışı iletişim serbest |
| B | Özelliği kaldır | Tutarlılık sağlanır; ustanın tercihi elinden alınır |
| C | Yalnız **Pro üyelere** aç | Kaçak yerine gelir kalemi olur |
| D | Yalnız **işi verilmiş müşteriye** göster | Eşleşme platformda kalır, iletişim serbestleşir |

**İlgili dosyalar:**
- `lib/data/models/artisan_profile.dart:82-98` — `showPhoneOnProfile`, `hasPublicPhone`
- `lib/features/artisan/presentation/artisan_profile_edit_screen.dart:785-800` — anahtar
- `lib/features/customer/presentation/artisan_profile_screen.dart:711` — vitrin gösterimi
- `lib/features/artisan/application/my_profile_controller.dart:282` — kaydetme

---

## Kapatılanlar

| # | Adım | Ne oldu | Nasıl çözüldü | Commit |
|---|---|---|---|---|
| B-01 | 1.2.5 | Misafir Mesajlar'a basıp giriş ekranına düşünce, **donanım geri tuşu uygulamayı küçültüyordu** (ana ekrana dönmesi gerekirdi) | `LoginScreen` + `PackageSelectScreen`'e `PopScope` | `fca9064` |

### B-01 · Giriş ekranında donanım geri tuşu

**Kök neden:** Bu ekrana `redirect` ile geliniyor (misafir korumalı bölgeye
dokunur → router yönlendirir). Yönlendirme **geçmiş yığını bırakmaz**, yani
`canPop()` false. Ekrandaki `BackButton` bunu zaten ele alıyordu
(`canPop ? pop : go(home)`) ama **donanım geri tuşu o mantığı hiç görmüyordu** —
doğrudan sisteme düşüp uygulamayı küçültüyordu.

**Çözüm:** `PopScope(canPop: false)` + elle yönlendirme. Mantık tek metotta
(`_goBack`), ekran düğmesi de ona bağlandı.

`PackageSelectScreen` de aynı boşluktaydı, birlikte düzeltildi — ama davranışı
farklı: `changing` modunda profile döner, **ilk zorunlu seçimde geri tuşu
hiçbir şey yapmaz** (plan seçmeden ilerlenemez, ama uygulama da küçülmez).

---

## 📋 Test oturumu kaydı

Her oturumun sonunda nerede kaldığımızı buraya yazın.

### Oturum 1 — 2026-08-07
- **Tamamlanan:** Bölüm 1 (Giriş ve Hesap) ✅ · Bölüm 2 (Profil ve Rol) ✅
- **🔜 KALINAN YER: Bölüm 3 — [[03-Ilanlar-Musteri]]** (hiç başlanmadı)
- **Düzeltilenler:** B-01 (`fca9064`) · SSS "Eleman" kategorisi (`4e28ea4`) ·
  kartlara TapScale (`3a18eb0`)
- **Karar/plan bekleyen:** K-01 · K-02 · K-03 · K-04
- **⚠️ Telefonda yeni derleme gerekiyor** — TapScale ve SSS düzeltmesi
  cihazdaki sürümde yok
- **Not:** Cihaz Xiaomi 22101316G / Android 14. APK kullanıcı tarafından
  kendi imzasıyla kuruluyor — ajanın derlediği debug imzalı APK çakışıyor
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Düzeltme sonrası kurulumu kullanıcı
  yapmalı.

> [!important] Sonraki oturumda buradan devam
> **Bölüm 3'ten başla.** İlan akışı sistemin merkezi — bölüm 3→4→5→6→7 zinciri
> birbirine bağlıdır, tek oturumda yapmak en verimlisi (~1.5 saat).
>
> **Gerekli hazırlık:** İkinci Google hesabı. Bölüm 4'ten itibaren usta ve
> müşteri ayrı hesaplar olmalı; ustanın kendi ilanına ilgi bildirmesi mümkün
> değil.
>
> **Kritik doğrulamalar** (henüz hiç cihazda test edilmedi):
> - 5.3 — müşteri hiç yazmadan işi verirse usta sohbete yazabiliyor mu?
> - 7.2 — müşteri puan verdikten sonra ustanın "Değerlendir" şeridi duruyor mu?

---

## Bulgu şablonu

```
### B-01 · [adım no] — kısa başlık
**Ne bekledim:**
**Ne oldu:**
**Hangi hesap:** müşteri / usta
**Tekrarlanıyor mu:** evet / hayır / bazen
**Öncelik:** P0 / P1 / P2
**Durum:** açık / inceleniyor / düzeltildi
```

---
İlgili: [[00-TEST-PLANI]] · [[Bilinen-Tuzaklar]]

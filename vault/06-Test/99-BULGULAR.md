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
| B-01 | 1.2.5 | Misafir Mesajlar'a basıp giriş ekranına düşünce, **donanım geri tuşu uygulamayı küçültüyordu** (ana ekrana dönmesi gerekirdi) | `LoginScreen` + `PackageSelectScreen`'e `PopScope` | `3e8b3d0` |

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

### Oturum 1 — ____________ (tarih)
- **Tamamlanan:** ______________
- **Kalınan yer:** ______________
- **Bulgu sayısı:** ______

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

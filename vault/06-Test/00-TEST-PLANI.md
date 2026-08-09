# 📱 Cihaz Test Planı · v3

> **v3 nesi farklı?** v2, iş akışını (teklif → usta seç → tamamlama onayı)
> test ediyordu; o akış 2026-08-08/09'da **kaldırıldı**. `08-Is-Akisi.md`
> tamamen geçersiz kaldığı için silindi, yerine ilan ömrü geldi. Ayrıca hiç
> test edilmeyen **admin paneli** ve **tanıtım sitesi** eklendi.
>
> Dayanak: [[Mevcut-Akislar]] — akışlar koddan çıkarıldı (2026-08-09).

> [!tip] Tek dosyada mı tercih edersin?
> **[[TEST-TEK-DOSYA]]** — 395 adımın tamamı sırayla, tek dosyada.
> Bu dosya bölüm bölüm gitmek isteyenler için; ikisi aynı adımları içerir.

**Cihaz:** ______________ · **Sürüm:** ______________ · **Başlangıç:** ________

---

## Uygulama şu an ne?

Tek cümle: **kullanıcı ilan verir ya da usta arar; iki taraf doğrudan
mesajlaşıp anlaşır.**

**Rol ayrımı YOK.** Aynı hesap hem müşteri hem usta olabilir; "usta modu"
profil doldurulunca açılır.

| | Usta modu KAPALI | Usta modu AÇIK |
|---|---|---|
| Alt bar | Ana Sayfa · Keşfet · **İşler** · Mesajlar · Profil | (aynı) |
| "İşler" sekmesi | **Kendi ilanlarım** | **Yakındaki ilanlar** |
| İlan verme | ✅ | ✅ |
| Başkasının ilanına mesaj | ❌ | ✅ (dört kapıdan geçerse) |
| Usta arama · takip | ✅ | ✅ |

> [!warning] İlan bir DUYURUDUR
> Usta **atanmaz**, iş "tamamlandı" **denmez**. Usta ilan sahibine doğrudan
> mesaj atar. Durum üç tane: **Yayında · Kaldırıldı · Süresi doldu**.
> Ekranda "Teklif toplanıyor" / "İş yürüyor" görürseniz **eski kod geri
> gelmiş** → bulgu yazın.

---

## İlerleme tablosu

| # | Alan | Adım | Süre | Durum | Bulgu |
|---|---|---|---|---|---|
| 1 | [[01-Ilk-Acilis-ve-Giris]] | 22 | ~15 dk | ⬜ | — |
| 2 | [[02-Ana-Sayfa-ve-Kesfet]] | 29 | ~20 dk | ⬜ | — |
| 3 | [[03-Profil-ve-Usta-Modu]] ⭐ | 34 | ~25 dk | ⬜ | — |
| 4 | [[04-Takip-Sistemi]] ⭐ | 31 | ~25 dk | ⬜ | — |
| 5 | [[05-Ilan-Verme]] | 30 | ~25 dk | ⬜ | — |
| 6 | [[06-Ilan-Alma-Usta]] ⭐ | 31 | ~25 dk | ⬜ | — |
| 7 | [[07-Mesajlasma]] ⭐ | 32 | ~30 dk | ⬜ | — |
| 8 | [[08-Ilan-Omru-ve-Yonetimi]] ⭐ | 37 | ~25 dk | ⬜ | — |
| 9 | [[09-Degerlendirme]] ⭐ | 25 | ~20 dk | ⬜ | — |
| 10 | [[10-Guvenlik-ve-Ayarlar]] | 32 | ~20 dk | ⬜ | — |
| 11 | [[11-Admin-Paneli]] 🖥️ | 57 | ~25 dk | ⬜ | — |
| 12 | [[12-Tanitim-Sitesi]] 🖥️ | 35 | ~15 dk | ⬜ | — |

**Durum:** ⬜ başlamadı · 🔄 sürüyor · ✅ geçti · ⚠️ bulgu var · ❌ kırık
🖥️ = tarayıcıda yapılır, telefon gerekmez.

**Toplam: 395 adım · ~4,5 saat.** Bulgular → [[99-BULGULAR]]

---

## ⚠️ Test öncesi hazırlık

### 1. Deploy edilmiş mi? ✅ EVET

Kural, 40 Cloud Function ve iki site **2026-08-09'da canlıya alındı**.
Emin olmak istersen:
```bash
firebase functions:list    # 40 fonksiyon dönmeli
```

### 2. Temiz kurulum

```bash
flutter clean && flutter run
```
`clean` **şart** — launcher ikonu ve logo derleme önbelleğinde kalır.

### 3. İki hesap gerekli

Pazaryeri çift taraflı. **Aynı hesapla usta modunu açıp kapatmak yetmez** —
kendi ilanınıza mesaj atamazsınız.

| Rol | Google hesabı |
|---|---|
| A (ilan veren) | ______________ |
| B (usta) | ______________ |

> **İki cihaz varsa çok daha rahat.** Mesajlaşma, takip bildirimi ve canlı
> güncelleme testleri tek cihazda tam yapılamaz.

### 4. Bilinmesi gerekenler

- **E-posta doğrulaması zorunlu** — ilan açmak ve mesaj atmak için.
  Google girişinde genelde otomatik gelir.
- **İlan limiti 5** (aynı anda açık), **günlük 10**.
- **Müsaitlik kapısı:** müsait olmayan usta aramada görünmez ve yeni ilana
  mesaj atamaz. **Mevcut sohbetleri sürer.**
- **Sohbet kişi başına TEK** — aynı çift kaç ilan konuşursa konuşsun tek kutu.
- **Değerlendirme kişiye** — aynı kişiyi ikinci kez puanlamak GÜNCELLER.

---

## Test sırası — neden böyle?

```
1 İlk açılış → 2 Ana Sayfa/Keşfet → 3 Profil + Usta modu
                                          ↓
                                    4 Takip sistemi
                                          ↓
                    5 İlan ver (A) → 6 İlana mesaj at (B)
                                          ↓
                                    7 Mesajlaş
                                          ↓
                            8 İlanı yönet / kaldır
                                          ↓
                                    9 Değerlendir
                                          ↓
                                   10 Güvenlik/Ayarlar
                                          ↓
                       11 Admin paneli · 12 Tanıtım sitesi  (tarayıcı)
```

**1–4 bağımsız**, tek hesapla yapılabilir.
**5–9 zincir**, iki hesap ister ve sıra atlanmamalı.
**10 bağımsız · 11–12 tarayıcıda**, telefondan bağımsız.

---

## 🎯 Bu turun özel hedefleri

Oturum 82 ve 83'te **ürünün yarısı değişti, hiçbiri cihazda görülmedi**:

1. **İş akışının kaldırılması** — durum 8'den 3'e indi (Bölüm 8)
2. **İlan silme serbest** — mesajlaşılan ilan da silinebiliyor, **sohbet
   duruyor** (8.3.5 — en kritik adım)
3. **Tek sohbet kutusu** — kişi başına tek, ilan bazlı değil (6.3.7)
4. **Kişi bazlı değerlendirme** — ikinci puan günceller (9.3)
5. **Tek profil tasarımı** — başkasının profili kendi profilin gibi (Bölüm 3)
6. **Yeni marka + logo** — "İlanda Hizmet" (Bölüm 12)
7. **Admin paneli sadeleşti** — anlaşmazlık sekmesi kalktı (Bölüm 11)

---
İlgili: [[Mevcut-Akislar]] · [[99-BULGULAR]] · [[Bilinen-Tuzaklar]] · eski defter: `_arsiv-v1/`

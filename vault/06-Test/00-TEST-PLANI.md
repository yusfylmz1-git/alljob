# 📱 Cihaz Test Planı · v2

> **Neden yeni defter?** v1 (`_arsiv-v1/`) silinen modülleri test ediyordu
> (Usta Çantası, Ajanda, Ürünler, Eleman) ve rol ayrımına göre yazılmıştı.
> Ürün 2026-08-07/08'de sadeleşti; defter de sıfırdan yazıldı.

**Cihaz:** ______________ · **Sürüm:** ______________ · **Başlangıç:** ________

---

## Uygulama şu an ne?

Tek cümle: **müşteri ilan verir, usta iş alır; herkes herkesi takip edip
mesajlaşır.**

**Rol ayrımı YOK.** Herkes aynı ekranları görür; "Usta modu" anahtarı açıkken
ek modüller belirir.

| | Usta modu KAPALI | Usta modu AÇIK |
|---|---|---|
| Alt bar | Ana Sayfa · Keşfet · Mesajlar · Profil | **+ İlanlar** |
| İlan verme | ✅ | ✅ |
| Başkasının ilanını görme | ❌ | ✅ (müsaitse) |
| Usta arama | ✅ | ✅ |
| Takip etme | ✅ | ✅ |

---

## İlerleme tablosu

| # | Alan | Adım | Süre | Durum | Bulgu |
|---|---|---|---|---|---|
| 1 | [[01-Ilk-Acilis-ve-Giris]] | 22 | ~15 dk | ⬜ | — |
| 2 | [[02-Ana-Sayfa-ve-Kesfet]] | 29 | ~20 dk | ⬜ | — |
| 3 | [[03-Profil-ve-Usta-Modu]] ⭐ | 34 | ~25 dk | ⬜ | — |
| 4 | [[04-Takip-Sistemi]] ⭐ | 31 | ~25 dk | ⬜ | — |
| 5 | [[05-Ilan-Verme]] | 30 | ~25 dk | ⬜ | — |
| 6 | [[06-Ilan-Alma-Usta]] ⭐ | 24 | ~20 dk | ⬜ | — |
| 7 | [[07-Mesajlasma]] ⭐ | 32 | ~30 dk | ⬜ | — |
| 8 | [[08-Is-Akisi]] ⭐ | 30 | ~25 dk | ⬜ | — |
| 9 | [[09-Degerlendirme]] | 21 | ~15 dk | ⬜ | — |
| 10 | [[10-Guvenlik-ve-Ayarlar]] | 32 | ~20 dk | ⬜ | — |

**Durum:** ⬜ başlamadı · 🔄 sürüyor · ✅ geçti · ⚠️ bulgu var · ❌ kırık

**Toplam: 285 adım · ~3,5 saat.** Bulgular → [[99-BULGULAR]]

---

## ⚠️ Test öncesi hazırlık

### İki hesap gerekli
Pazaryeri çift taraflı. **Aynı hesapla usta modunu açıp kapatmak yetmez** —
kendi ilanınıza ilgi bildiremezsiniz.

| Rol | Google hesabı |
|---|---|
| A (ilan veren) | ______________ |
| B (usta) | ______________ |

> **İki cihaz varsa çok daha rahat.** Mesajlaşma, takip bildirimi ve canlı
> güncelleme testleri tek cihazda tam yapılamaz — v1'de 9 adım bu yüzden
> ertelenmişti.

### Bilinmesi gerekenler
- **E-posta doğrulaması zorunlu** — ilan açmak, sohbet başlatmak, ilgi
  bildirmek için. Google girişinde genelde otomatik gelir.
- **İlan limiti 5** (aynı anda açık), **günlük 10**.
- **Müsaitlik kapısı:** müsait olmayan usta aramada görünmez, yeni sohbet
  alamaz, ilan listesini göremez. **Mevcut sohbetleri sürer.**
- **Otomatik tamamlama 3 gün / arşivleme 7 gün** — cihazda beklenemez,
  kod incelemesiyle doğrularız.

---

## Test sırası — neden böyle?

```
1 İlk açılış → 2 Ana Sayfa/Keşfet → 3 Profil + Usta modu
                                          ↓
                                    4 Takip sistemi
                                          ↓
                    5 İlan ver (A) → 6 İlgi bildir (B)
                                          ↓
                                    7 Mesajlaş + usta seç
                                          ↓
                                    8 İşi tamamla
                                          ↓
                                    9 Değerlendir
                                          ↓
                                   10 Güvenlik/Ayarlar
```

**1–4 bağımsız**, tek hesapla yapılabilir.
**5–9 zincir**, iki hesap ister ve sıra atlanmamalı.
**10 bağımsız.**

---

## 🎯 Bu testin özel hedefleri

Son turda yapılan **büyük değişiklikler hiç cihazda görülmedi**:

1. **Rol ayrımının kalkması** — tek profil + usta modu anahtarı (Bölüm 3)
2. **Instagram takip sistemi** — iki sekme, karşılıklı rozet, bildirim (Bölüm 4)
3. **Serbest mesajlaşma** — usta artık ilk mesajı atabilir (Bölüm 7)
4. **Müsaitlik kapısı** — yeni iş engellenir, mevcut sohbet sürer (Bölüm 6/7)
5. **Genel kullanıcı profili** `/u/:uid` (Bölüm 4)

---
İlgili: [[99-BULGULAR]] · [[Bilinen-Tuzaklar]] · eski defter: `_arsiv-v1/`

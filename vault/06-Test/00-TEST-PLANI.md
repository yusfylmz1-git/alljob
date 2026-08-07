# 📱 Cihaz Test Planı

> **Nasıl çalışıyoruz:** Siz telefonda sırayla test edersiniz, ben kod tarafından
> eşlik ederim. Bir şey beklediğiniz gibi çalışmazsa **durun ve söyleyin** —
> nedenini koddan bakarım, düzeltiriz, sonra devam ederiz.

**Cihaz:** ______________ · **Sürüm:** ______________ · **Başlangıç:** ____________

---

## İlerleme tablosu

| # | Alan | Adım | Süre | Durum | Bulgu |
|---|---|---|---|---|---|
| 1 | [[01-Giris-ve-Hesap]] | 24 | ~15 dk | ✅ | B-01 (düzeltildi) |
| 2 | [[02-Profil-ve-Rol]] | 22 | ~20 dk | ✅ | K-02 (karar bekliyor) |
| 3 | [[03-Ilanlar-Musteri]] | 26 | ~25 dk | ⚠️ | B-02·B-06…B-11 · K-07 |
| 4 | [[04-Ilanlar-Usta]] | 20 | ~15 dk | ⚠️ | **B-12** (push 🔴 P0) |
| 5 | [[05-Mesajlar]] ⭐ | 34 | ~30 dk | ⚠️ | B-18·B-19 (düzeltildi) · K-08…K-11 |
| 6 | [[06-Is-Tamamlama]] | 28 | ~25 dk | ⬜ | — |
| 7 | [[07-Degerlendirme]] ⭐ | 20 | ~15 dk | ⬜ | — |
| 8 | [[08-Guvenlik-ve-Sikayet]] | 19 | ~15 dk | ⬜ | — |
| 9 | [[09-Yan-Moduller]] | 31 | ~30 dk | ⬜ | — |

**Durum:** ⬜ başlamadı · 🔄 sürüyor · ✅ geçti · ⚠️ bulgu var · ❌ kırık

---

## 📊 Kalan iş (oturum 2 sonu — 2026-08-07)

| | Adım |
|---|---|
| **Toplam** (6.5 eklendi, 5.6 iptal) | **220** |
| ✅ Test edildi | **~126** |
| ⏸️ 2. cihaz/hesap bekliyor | **9** |
| ⛔ İptal (5.6 maskeleme) | **4** |
| 🔜 **Kalan** | **~81** |

**Kalanın dağılımı:**

| Bölüm | Kalan | Süre |
|---|---|---|
| 6 · İş Tamamlama | 28 | ~25 dk |
| 7 · Değerlendirme ⭐ | 20 | ~15 dk |
| 8 · Güvenlik ve Şikayet | 19 | ~15 dk |
| 9 · Yan Modüller | 31 | ~30 dk |
| 5 · Mesajlar (artık) | 3 | — (2. hesap) |

> **~1.5 saat kaldı.** Bölüm 6→7 zinciri bağlantılı, birlikte yapılmalı.
> Bölüm 8 ve 9 bağımsız, istenen sırada.

Bulgular → [[99-BULGULAR]]

> [!tip] Tek seferde bitirmeyin
> Bölüm bölüm ilerleyin. Her bölüm sonunda nerede kaldığınızı
> [[99-BULGULAR]] içindeki oturum kaydına yazın.
>
> **Acele ediyorsanız:** yalnız ⭐ işaretli 5 ve 7'yi yapın (~45 dk) — son
> düzeltmelerin doğrulaması onlarda.

---

## ⚠️ Test öncesi hazırlık

### İki hesap gerekli
Pazaryeri çift taraflı — müşteri ve usta **ayrı hesaplar** olmalı.

| Rol | Google hesabı | Not |
|---|---|---|
| Müşteri | ______________ | Ana test hesabı |
| Usta | ______________ | İkinci cihaz veya çıkış-giriş |

> [!tip] İki cihaz varsa çok daha rahat
> Mesajlaşma ve karşılıklı değerlendirme tek cihazda sürekli hesap değiştirmeyi
> gerektirir. İkinci bir telefon/emulator varsa kullanın.

### Bilinmesi gerekenler
- **E-posta doğrulaması zorunlu** — ilan açmak ve usta iletişimi için. Google
  girişinde genelde otomatik `true` gelir.
- **İlan limiti 5** — aynı anda en çok 5 açık ilan.
- **Otomatik tamamlama 3 gün** — tek taraflı onayda. Cihazda beklenemez, kod
  incelemesiyle doğrularız.
- **Arşivleme 7 gün** — aynı şekilde beklenemez.

---

## 🎯 Bu testin özel hedefi

Son oturumda düzelttiğimiz **karşılıklı değerlendirme çıkmazı**. Kritik
senaryo:

> Müşteri sohbete **hiç mesaj yazmadan** doğrudan "Bu Ustayı Seç" der →
> usta o sohbete yazabiliyor mu? → iş tamamlanınca **iki taraf da**
> değerlendirebiliyor mu?

**İlk yarısı ✅ DOĞRULANDI (5.3, oturum 2):** usta seçildikten sonra sohbete
yazabiliyor, sistem mesajı düşüyor. Çıkmaz kalkmış.

**İkinci yarısı bekliyor:** iş tamamlanınca iki tarafın da değerlendirebilmesi
→ [[07-Degerlendirme]] 7.2.

---

## Test sırası — neden böyle?

Akış birbirine bağlı, sıra atlanmamalı:

```
1 Giriş → 2 Profil/Rol → 3 İlan aç (müşteri)
                            ↓
                    4 İlgi bildir (usta)
                            ↓
                    5 Mesajlaş + usta seç
                            ↓
                    6 İşi tamamla
                            ↓
                    7 Değerlendir
                            ↓
              8 Güvenlik   9 Yan modüller (bağımsız)
```

8 ve 9 bağımsızdır, istediğiniz zaman yapılabilir.

---
İlgili: [[99-BULGULAR]] · [[Bilinen-Tuzaklar]]

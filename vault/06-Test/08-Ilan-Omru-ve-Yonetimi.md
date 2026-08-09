# 8 · İlan Ömrü ve Yönetimi ⭐

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

---

## 8.1 Durum etiketleri ⭐

- [ ] **8.1.1** Yeni ilan **"Yayında"** görünüyor
- [ ] **8.1.2** ⚠️ **"Teklif toplanıyor"** yazmıyor *(eski etiket)*
- [ ] **8.1.3** İlanlarım listesinde durum rozeti doğru
- [ ] **8.1.4** ⚠️ Listede **"N ilgilendi"** sayacı **YOK**
- [ ] **8.1.5** ⚠️ İlan detayında **adım göstergesi (stepper)** **YOK**

## 8.2 Düzenleme penceresi ⭐

> Yayından sonra **1 saat** içinde, yalnız açık ilanda.

- [ ] **8.2.1** Yeni açtığınız ilanda **"Düzenle"** görünüyor
- [ ] **8.2.2** Başlık ve açıklama değiştirilebiliyor
- [ ] **8.2.3** Bütçe **kaldırılabiliyor** (boş bırakınca gidiyor)
- [ ] **8.2.4** Kaydedince liste ve detay güncelleniyor
- [ ] **8.2.5** ⭐ **Kaldırdığınız** bir ilanda "Düzenle" **YOK**
- [ ] **8.2.6** ⚠️ *(1 saat sonra)* eski ilanda "Düzenle" **kayboluyor**
      *(uzun test — atlanabilir, notunu düşün)*

## 8.3 İlan kaldırma ⭐

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

## 8.4 Açık ilan limiti ⭐

- [ ] **8.4.1** Arka arkaya **5 ilan** açın → hepsi açılıyor
- [ ] **8.4.2** ⭐ **6.** ilanı açmayı deneyin → **engelleniyor**,
      anlaşılır uyarı çıkıyor
- [ ] **8.4.3** Bir ilanı **kaldırın** → yeniden ilan açılabiliyor
      *(sayaç düştü)*
- [ ] **8.4.4** ⚠️ Uyarı metni "5" sayısını söylüyor mu?

## 8.5 Alan sınırları

- [ ] **8.5.1** Başlık **80** karakterde duruyor
- [ ] **8.5.2** Açıklama **600** karakterde duruyor
- [ ] **8.5.3** Fotoğraf **5** taneden fazla eklenemiyor
- [ ] **8.5.4** Boş başlıkla ilan verilemiyor
- [ ] **8.5.5** Çok büyük fotoğraf (>5 MB) reddediliyor / küçültülüyor

## 8.6 Süre dolumu

> Süre seçenekleri: **3 / 5 / 7 gün**. Kolay İş her zaman **1 gün**.

- [ ] **8.6.1** İlan verirken süre seçenekleri **3, 5, 7** gün
- [ ] **8.6.2** ⚠️ **24 saat** seçeneği **YOK** *(eski değer)*
- [ ] **8.6.3** ⭐ Kolay İş seçince süre **1 gün**'e sabitleniyor ve
      seçim gizleniyor
- [ ] **8.6.4** İlan detayında kalan süre / bitiş tarihi görünüyor
- [ ] **8.6.5** *(varsa eski ilan)* Süresi dolmuş ilan **"Süresi doldu"**
      görünüyor ve usta feed'inde **çıkmıyor**

## 8.7 Kolay İş ⭐

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

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[09-Degerlendirme]]

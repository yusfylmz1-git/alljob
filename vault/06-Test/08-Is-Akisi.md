# 8 · İş Akışı ⭐

**Kapsam:** Usta seçimi, kilit, tamamlama onayı, seçim iptali, sorun bildirme.
**Hesap:** A + B · **Süre:** ~20 dk

> [!warning] Sıralama tuzağı
> Bu bölümde adımlar **birbirini bozar**:
> - 8.2 ilanı `completed` yapar → o ilanla 8.4/8.5 test edilemez
> - 8.4 (iptal) yalnız `workerSelected` durumunda çalışır
>
> **Üç ayrı ilan** açın: A → 8.1+8.2 · B → 8.4 · C → 8.5

---

## 8.1 Usta seçimi ⭐

**Hazırlık:** İlan + ilgi bildirmiş usta. Müşteri **hiç yazmasın**.

- [ ] **8.1.1** A, sohbette **"Bu Ustayı Seç"** şeridini görüyor
- [ ] **8.1.2** ⭐ A **hiç mesaj yazmadan** seçim yapıyor
- [ ] **8.1.3** Onay diyaloğu çıkıyor, onaylayınca "Usta seçildi"
- [ ] **8.1.4** ⭐ B sohbete girsin → **yazabiliyor**
- [ ] **8.1.5** Sohbette *"✅ Usta seçildi — iş başladı"* sistem mesajı
- [ ] **8.1.6** İlan durumu "İş yürüyor" oluyor

## 8.2 Çift taraflı tamamlama ⭐

- [ ] **8.2.1** ⭐ "İşi teslim ettim" / "İş bitti, onaylıyorum" düğmesine
      basınca **ONAY DİYALOĞU** çıkıyor *(B-18)*
- [ ] **8.2.2** ⚠️ Diyalogda *"Bu işlem geri alınamaz"* uyarısı var
- [ ] **8.2.3** "Vazgeç" işlemi iptal ediyor
- [ ] **8.2.4** A onaylıyor → karşı tarafa bildirim
- [ ] **8.2.5** Sohbette sistem mesajı çıkıyor
- [ ] **8.2.6** B de onaylıyor
- [ ] **8.2.7** ⭐ Durum **"Tamamlandı"** oluyor (iki tarafta da)
- [ ] **8.2.8** ⚠️ Sohbet **KİLİTLENMEMELİ** — taraflar hâlâ yazabilmeli
- [ ] **8.2.9** ⭐ **"Değerlendir" düğmesi iki tarafta da görünüyor**

## 8.3 Diğer ustaların kilidi

**Hazırlık:** Bir ilana **iki farklı usta** ilgi bildirsin.

- [ ] **8.3.1** A iki ustayla da sohbet açsın
- [ ] **8.3.2** A birinci ustayı seçsin
- [ ] **8.3.3** ⚠️ İkinci usta sohbete girince **kilit şeridi** görmeli:
      *"Müşteri bu iş için başka bir usta ile anlaştı."*
- [ ] **8.3.4** İkinci usta yazamıyor, geçmiş mesajları okuyabiliyor
- [ ] **8.3.5** Seçilen usta normal yazabiliyor

## 8.4 Seçim iptali

- [ ] **8.4.1** A usta seçimini iptal edebiliyor
- [ ] **8.4.2** İlan tekrar "Teklif toplanıyor" oluyor
- [ ] **8.4.3** Ustaya bilgi gidiyor
- [ ] **8.4.4** ⚠️ Diğer ustaların **kilitleri açılıyor**
- [ ] **8.4.5** İlan usta feed'inde tekrar görünüyor

## 8.5 Sorun bildirme

- [ ] **8.5.1** İş yürürken "Sorun bildir" seçeneği var
- [ ] **8.5.2** Neden seçilebiliyor, not yazılabiliyor
- [ ] **8.5.3** Durum **"Sorun — beklemede"** oluyor
- [ ] **8.5.4** ⚠️ Yaşam döngüsü **donuyor** — tamamlama onayı verilemiyor
- [ ] **8.5.5** Karşı tarafa bildirim gidiyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⭐ Tamamlanınca "Değerlendir" yok | **Kritik — bildir** |
| Teslim düğmesi onay sormuyor | ⚠️ B-18 regresyonu |
| Tamamlanınca sohbet kilitleniyor | ⚠️ Yanlış — kilitlenmemeli |
| İptal sonrası kilitler açılmıyor | CF çalışmamış olabilir |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[09-Degerlendirme]]

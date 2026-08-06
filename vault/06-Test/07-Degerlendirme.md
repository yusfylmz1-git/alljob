# 7 · Değerlendirme

**Kapsam:** Çift taraflı puanlama, güncelleme, görünürlük.
**Hangi hesap:** İkisi de

> [!danger] ⭐⭐ Bu bölümün tamamı kritik
> Son oturumda düzelttiğimiz üç hatanın ikisi tam burada. **Karşılıklı**
> değerlendirme daha önce hiç tamamlanamıyordu.

---

## 7.1 Müşteri → Usta değerlendirme

**Hazırlık:** [[06-Is-Tamamlama]] 6.1 tamamlanmış olmalı.

- [ ] **7.1.1** Müşteri sohbette **"Değerlendir"** düğmesini görüyor
- [ ] **7.1.2** ⭐ Düğmeye basınca **değerlendirme ekranı AÇILIYOR**
  - ❌ "Değerlendirme henüz açılmadı" diyorsa → **BİLDİRİN**
- [ ] **7.1.3** 1–5 yıldız seçilebiliyor
- [ ] **7.1.4** Olumlu/olumsuz **etiketler** seçilebiliyor
- [ ] **7.1.5** Puan vermeden göndermeyi deneyin → uyarı vermeli
- [ ] **7.1.6** Gönderilince onay mesajı çıkıyor, ekran kapanıyor
- [ ] **7.1.7** Ustanın profilinde **puan güncellendi** mi?
      (ortalama ve yorum sayısı — birkaç saniye sürebilir)

## 7.2 ⭐⭐ KRİTİK: Usta → Müşteri değerlendirme

> **Düzelttiğimiz hata buydu.** İlk taraf puan verince ilan `rated` oluyor ve
> ikinci taraf için "Değerlendir" şeridi **kayboluyordu**.

- [ ] **7.2.1** ⭐ Müşteri puan verdikten **SONRA** usta hesabına geçin
- [ ] **7.2.2** ⭐ **Sohbette "Değerlendir" şeridi HÂLÂ DURUYOR MU?**
  - ✅ **Doğru:** şerit duruyor, *"İş tamamlandı — müşteriyi değerlendirin"*
  - ❌ **Hata:** şerit kaybolmuş → **BİLDİRİN** (düzeltme çalışmamış)
- [ ] **7.2.3** ⭐ Usta düğmeye basınca **ekran açılıyor**
- [ ] **7.2.4** Usta puan + etiket verip gönderebiliyor
- [ ] **7.2.5** ⚠️ Ustanın verdiği puan **müşteri profilinde herkese görünmemeli**
      (yalnız ustalar görür — bilinçli tasarım)

## 7.3 Değerlendirme güncelleme

- [ ] **7.3.1** Puan verdikten sonra tekrar "Değerlendir"e basın
- [ ] **7.3.2** ⚠️ Form **önceki puanınızla dolu** geliyor
- [ ] **7.3.3** *"Daha önce değerlendirdiniz... güncellenir"* bilgisi görünüyor
- [ ] **7.3.4** Puanı değiştirip gönderin → **güncelleniyor**, ikinci kayıt
      oluşmuyor (ustanın yorum sayısı artmamalı)

## 7.4 Görünürlük

- [ ] **7.4.1** Müşterinin verdiği puan **usta profilinde herkese açık**
- [ ] **7.4.2** Yorum etiketleri profilde görünüyor
- [ ] **7.4.3** Ortalama puan doğru hesaplanmış
- [ ] **7.4.4** ⚠️ İş **"Değerlendirildi"** durumuna geçmiş

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⭐ 7.2.2'de şerit kaybolmuş | **En kritik — düzeltme çalışmamış** |
| "Değerlendirme henüz açılmadı" ekranı | Hangi hesap, iş durumu ne? |
| Düğme var ama basınca hiçbir şey olmuyor | Ekran görüntüsü al |
| Puan verdim ama profilde değişmedi | 10-15 sn bekleyip tekrar bak (CF hesaplıyor) |
| Ustanın puanı müşteri profilinde görünüyor | ⚠️ Gizlilik — bildir |
| İkinci puan yorum sayısını artırdı | Güncelleme yerine yeni kayıt açılmış |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[08-Guvenlik-ve-Sikayet]]

# 9 · Değerlendirme

**Kapsam:** Karşılıklı puanlama, etiketler, sayaç güncellemesi.
**Hesap:** A + B · **Süre:** ~15 dk

> [!important] Karşılıklı
> İş bitince **iki taraf da** değerlendirebilir:
> müşteri → usta (`c2a`) ve usta → müşteri (`a2c`).
>
> **Gizlilik farkı:** ustanın puanı herkese açık (vitrin); müşterinin puanı
> **gizli** — profilde yalnız *kaç* değerlendirme aldığı görünür.

**Hazırlık:** Bölüm 8'de tamamlanmış bir iş.

---

## 9.1 Müşteri → Usta

- [ ] **9.1.1** A, sohbette/ilan detayında **"Değerlendir"** görüyor
- [ ] **9.1.2** Değerlendirme ekranı açılıyor
- [ ] **9.1.3** Yıldız (1–5) seçilebiliyor
- [ ] **9.1.4** Hazır etiketler seçilebiliyor (Temiz İşçilik, Dakik vb.)
- [ ] **9.1.5** Yorum yazılabiliyor
- [ ] **9.1.6** Gönderilince onay mesajı çıkıyor
- [ ] **9.1.7** ⭐ B'nin profilinde **puan güncelleniyor**
- [ ] **9.1.8** Değerlendirme B'nin profilinde listeleniyor
- [ ] **9.1.9** Etiketler B'nin profilinde "öne çıkan" olarak görünüyor

## 9.2 Usta → Müşteri ⭐

- [ ] **9.2.1** ⭐ B'de de **"Değerlendir"** şeridi var
- [ ] **9.2.2** B, A'yı puanlayabiliyor
- [ ] **9.2.3** ⚠️ A'nın profilinde **puan GÖRÜNMEMELİ** (gizli)
- [ ] **9.2.4** ⭐ A'nın profilinde **"tamamlanan"** sayacı artmış
- [ ] **9.2.5** ⚠️ A puan verdikten sonra B'nin şeridi **kaybolmamalı**
      *(çıkmaz regresyonu)*

## 9.3 Tekrar değerlendirme ⭐

> Kimlik `rev_{yazan}__{hedef}` — **kişi başına tek değerlendirme**.
> İlan başına değil: aynı kişiyi ikinci kez puanlarsanız GÜNCELLENİR.

- [ ] **9.3.1** Aynı kişiyi tekrar değerlendirmeye girin
- [ ] **9.3.2** ⭐ Başlık **"Değerlendirmeyi Güncelle"** diyor
- [ ] **9.3.3** ⭐ Form **eski puan ve yorumla DOLU** geliyor
- [ ] **9.3.4** ⚠️ Kaydedince **yeni kayıt oluşmamalı** — mevcut güncellenmeli
- [ ] **9.3.5** Profildeki toplam değerlendirme sayısı **artmamalı**
- [ ] **9.3.6** Ortalama puan yeni değere göre değişmeli
- [ ] **9.3.7** ⭐ **Farklı bir kişiyi** değerlendirin → bu kez sayı **artıyor**

## 9.4 Görünürlük

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

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[10-Guvenlik-ve-Ayarlar]]

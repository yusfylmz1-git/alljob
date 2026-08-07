# 6 · İş Tamamlama

**Kapsam:** Çift taraflı onay, tek taraflı onay, seçim iptali, sorun bildirme.
**Hangi hesap:** İkisi de

---

## 6.1 Çift taraflı tamamlama ⭐

**Hazırlık:** Usta seçilmiş, iş yürüyor durumunda bir ilan.

- [ ] **6.1.1** Müşteri sohbette/ilan detayında **"Tamamlandı"** onayı verebiliyor
- [ ] **6.1.2** Onay sonrası **karşı tarafa bildirim** gidiyor
- [ ] **6.1.3** Sohbette sistem mesajı çıkıyor:
      *"📩 Müşteri işi tamamlandı olarak onayladı. Usta onayı bekleniyor."*
- [ ] **6.1.4** Usta da onay veriyor
- [ ] **6.1.5** ⭐ İş durumu **"Tamamlandı"** oluyor (iki tarafta da)
- [ ] **6.1.6** Sohbette sistem mesajı:
      *"🎉 İş tamamlandı. Karşılıklı değerlendirme yapabilirsiniz."*
- [ ] **6.1.7** ⚠️ **Sohbet KİLİTLENMEMELİ** — taraflar hâlâ yazabilmeli
      (bilinçli tasarım: teslim sonrası konuşma açık kalır)
- [ ] **6.1.8** ⭐ **"Değerlendir" düğmesi/şeridi görünüyor** (iki tarafta da)
  - Görünmüyorsa → **kritik bulgu, bildirin**

## 6.2 Tek taraflı onay

> Tek taraf onaylarsa **3 gün** sonra sistem otomatik tamamlar.
> Cihazda 3 gün beklenemez — sadece başlangıcı doğrularız.

- [ ] **6.2.1** Yalnız bir taraf onay versin
- [ ] **6.2.2** Karşı tarafa bildirim gitti mi?
- [ ] **6.2.3** "X gün içinde yanıt vermezseniz otomatik tamamlanacak" benzeri
      bir bilgi görünüyor mu?
- [ ] **6.2.4** İş durumu hâlâ "İş yürüyor" (henüz tamamlanmadı)

## 6.3 Usta seçimi iptali

- [ ] **6.3.1** Müşteri usta seçimini **iptal edebiliyor**
- [ ] **6.3.2** İlan tekrar **"Teklif toplanıyor"** oluyor
- [ ] **6.3.3** Ustaya bilgi mesajı gidiyor
- [ ] **6.3.4** ⚠️ Diğer ustaların **kilitleri açılıyor** — tekrar yazabiliyorlar
- [ ] **6.3.5** İlan usta feed'inde **tekrar görünüyor**

> [!note] Seç–iptal freni
> 3. iptalden sonra ilan kapanır (kötüye kullanım koruması). Test etmek
> isterseniz aynı ilanda 3 kez seç-iptal yapın.

## 6.4 Sorun bildirme (anlaşmazlık)

- [ ] **6.4.1** İş yürürken **"Sorun bildir"** seçeneği var
- [ ] **6.4.2** Neden seçilebiliyor, not yazılabiliyor
- [ ] **6.4.3** Bildirince iş durumu **"Sorun — beklemede"** oluyor
- [ ] **6.4.4** ⚠️ Yaşam döngüsü **donuyor** — tamamlama onayı verilemiyor
- [ ] **6.4.5** Karşı tarafa bildirim gidiyor

## 6.5 Sohbet silme iş akışını bozmuyor

> Kullanıcı sorusu (oturum 2). **Koddan cevap: bozmamalı** — yazma izni
> mesajlarda değil, sohbet dokümanındaki `customerStarted` bayrağında durur;
> iş durumu da ilan dokümanındadır. Cihazda doğrulanacak.

- [ ] **6.5.1** Müşteri kendi mesajını silsin → *"Bu mesaj silindi"* kalıyor
- [ ] **6.5.2** Müşteri **sohbeti silsin** (WhatsApp tarzı, kişisel)
  - Sohbet müşterinin listesinden düşüyor
  - ⚠️ **Ustanın geçmişi ETKİLENMİYOR** (usta hesabıyla doğrulayın)
- [ ] **6.5.3** ⭐ Silme sonrası **usta hâlâ yazabiliyor** mu?
      (`customerStarted` bayrağı korunmalı — yazamıyorsa **kritik bulgu**)
- [ ] **6.5.4** İş durumu / tamamlama onayları **etkilenmemiş**
- [ ] **6.5.5** Usta yeni mesaj yazınca sohbet müşterinin listesinde
      **yeniden beliriyor** (ama eski mesajlar ona gösterilmiyor)
- [ ] **6.5.6** Silme sonrası **değerlendirme hakkı duruyor**
      (kural sohbet dokümanının VARLIĞINA bakar; doküman silinemez)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⭐ Tamamlanınca "Değerlendir" çıkmıyor | **Kritik — bildir** (düzelttiğimiz hata) |
| Tamamlanınca sohbet kilitleniyor | ⚠️ Yanlış — kilitlenmemeli |
| İki taraf onayladı ama durum değişmedi | Uygulamayı yeniden aç, hâlâ öyleyse ciddi |
| İptal sonrası diğer ustalar hâlâ kilitli | CF çalışmamış olabilir |
| Sistem mesajları çıkmıyor | Hangi adımda çıkmadı |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[07-Degerlendirme]]

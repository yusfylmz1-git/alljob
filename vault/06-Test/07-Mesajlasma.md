# 7 · Mesajlaşma ⭐

**Kapsam:** Serbest mesajlaşma, sohbet listesi, mesaj özellikleri, kilit.
**Hesap:** A + B · **Süre:** ~25 dk

> [!important] Kural değişti
> **Serbest pazaryeri:** iki taraf da baştan mesaj atabilir. Eskiden usta,
> müşteri yazana kadar bekliyordu. **İletişim maskelemesi de kaldırıldı** —
> telefon/e-posta artık gizlenmiyor.

---

## 7.1 Sohbet başlatma

- [ ] **7.1.1** A, ilgilenen ustanın kartından sohbet açabiliyor
- [ ] **7.1.2** Sohbet ekranı açılıyor, **ilan başlığı** üstte görünüyor
- [ ] **7.1.3** Mesaj yazılıp gönderilebiliyor
- [ ] **7.1.4** Mesaj karşı tarafa ulaşıyor
- [ ] **7.1.5** ⭐ B, **usta profilinden** doğrudan sohbet başlatabiliyor
      *(müsaitse)*

## 7.2 Serbest mesajlaşma ⭐

**Hazırlık:** Yeni ilan + yeni ilgi, müşteri **hiç yazmasın**.

- [ ] **7.2.1** ⭐ B (usta) sohbete girsin → **giriş kutusu AÇIK olmalı**
- [ ] **7.2.2** ⭐ B **ilk mesajı atabiliyor**
      *(eskiden "İletişimi müşteri başlatır" şeridi vardı)*
- [ ] **7.2.3** A mesajı alıyor
- [ ] **7.2.4** ⚠️ Hiçbir yerde *"İletişimi müşteri başlatır"* yazmamalı

## 7.3 Maskeleme kaldırıldı

- [ ] **7.3.1** ⭐ Sohbete telefon yazın (`0532 123 45 67`) →
      **olduğu gibi görünmeli**, `•••` OLMAMALI
- [ ] **7.3.2** E-posta yazın → olduğu gibi görünüyor
- [ ] **7.3.3** ⚠️ *"Güvenliğiniz için gizlendi"* uyarısı **çıkmamalı**

## 7.4 Mesaj özellikleri

- [ ] **7.4.1** Fotoğraf gönderilebiliyor
- [ ] **7.4.2** Fotoğraf karşı tarafta açılıyor, büyütülebiliyor
- [ ] **7.4.3** Mesaj silme → "Bu mesaj silindi" görünüyor
- [ ] **7.4.4** Okundu bilgisi / tik doğru
- [ ] **7.4.5** Uzun sohbette kaydırma akıcı

## 7.5 Sohbet listesi

- [ ] **7.5.1** Mesajlar sekmesi tüm sohbetleri gösteriyor
- [ ] **7.5.2** İlan sohbetlerinde **ilan başlığı** satırı var
- [ ] **7.5.3** Okunmamış rozeti doğru sayıyor
- [ ] **7.5.4** Okuyunca rozet düşüyor
- [ ] **7.5.5** Arşivleme çalışıyor (kişisel)
- [ ] **7.5.6** ⭐ Aynı çiftle **iki farklı ilan** → **TEK sohbet**
      *(kişi başına tek kutu; iki ayrı sohbet açılırsa `chatIdFor` bozuk)*

## 7.6 Sohbet silme akışı bozmuyor

- [ ] **7.6.1** Kendi mesajınızı silin → "Bu mesaj silindi" kalıyor
- [ ] **7.6.2** Sohbeti silin (kişisel) → listenizden düşüyor
- [ ] **7.6.3** ⚠️ Karşı tarafın geçmişi **etkilenmiyor**
- [ ] **7.6.4** ⭐ Silme sonrası karşı taraf **hâlâ yazabiliyor**
- [ ] **7.6.5** Karşı taraf yazınca sohbet listenizde **yeniden beliriyor**

## 7.7 Müsaitlik ve mevcut sohbet ⭐

**Hazırlık:** A ile B arasında **var olan** bir sohbet olsun.

- [ ] **7.7.1** B müsaitliğini **kapatsın**
- [ ] **7.7.2** ⭐ A, Mesajlar'dan o sohbete girsin → **hâlâ yazabilmeli**
      *(müsaitlik yalnız YENİ sohbeti engeller)*
- [ ] **7.7.3** ⭐ B de **yanıt verebilmeli**
- [ ] **7.7.4** A, B'nin profiline girsin → yeni sohbet düğmesi **pasif**

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Usta ilk mesajı atamıyor | ⚠️ Kural deploy edilmemiş olabilir |
| Telefon `•••` çıkıyor | ⚠️ Maskeleme geri gelmiş |
| Müsait değilken mevcut sohbet kilitli | 🔴 **Kritik — bildir** |
| Aynı çiftle İKİ ayrı sohbet açılıyor | ⚠️ `chatIdFor` bozuk — **ciddi** |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[08-Ilan-Omru-ve-Yonetimi]]

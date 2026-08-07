# 5 · Mesajlar

**Kapsam:** Sohbet başlatma, yazma izni, usta seçimi, kilit, maskeleme.
**Hangi hesap:** İkisi de — sürekli geçiş var

> [!danger] ⭐ Bu bölüm en kritik
> Son oturumda düzelttiğimiz hata tam burada yaşanıyordu. **5.3 mutlaka
> test edilmeli.**

---

## 5.1 Sohbet başlatma (müşteri)

- [x] **5.1.1** Müşteri, ilgilenen ustanın kartından **sohbet açabiliyor** ✅
      ("Sohbete Git" düğmesi) — ⚠️ **B-18**: hemen altında onaysız
      "İşi teslim ettim" düğmesi de duruyor
- [x] **5.1.2** Sohbet ekranı açılıyor, **ilan başlığı görünüyor** ✅
      (B-19 düzeltildi `1303f57`, cihazda doğrulandı)
- [x] **5.1.3** Müşteri mesaj yazıp gönderebiliyor ✅
- [x] **5.1.4** Mesaj karşı tarafa ulaşıyor ✅
- [ ] **5.1.5** Ustaya **push bildirimi** gidiyor → ⏭️ **B-12** (tek cihaz)

## 5.2 Yazma izni — usta tarafı ⭐

> Usta, müşteri yazana kadar **yazamaz**.

- [ ] **5.2.1** Müşteri **hiç yazmadan** önce usta sohbeti açsın
- [ ] **5.2.2** ⚠️ Giriş kutusu yerine şerit görünmeli:
      *"İletişimi müşteri başlatır. Müşteri size yazınca yanıt verebilirsiniz."*
- [ ] **5.2.3** Müşteri bir mesaj yazsın → usta ekranı **kendiliğinden** açılmalı
      (uygulamayı kapatıp açmaya gerek kalmadan)
- [ ] **5.2.4** Usta artık yazabiliyor

## 5.3 ⭐⭐ KRİTİK: Müşteri hiç yazmadan işi verirse

> **Bu, düzelttiğimiz hatanın senaryosu.** Eskiden burada usta kilitli kalıyordu.

**Hazırlık:** Yeni bir ilan açın, usta ilgi bildirsin. Müşteri sohbeti açsın ama
**hiçbir şey yazmasın**.

- [ ] **5.3.1** Müşteri sohbet ekranında **"Bu Ustayı Seç"** şeridi görüyor
- [ ] **5.3.2** Müşteri **hiç mesaj yazmadan** "Bu Ustayı Seç" diyor
- [ ] **5.3.3** Onay diyaloğu çıkıyor, onaylayınca "Usta seçildi" mesajı
- [ ] **5.3.4** ⭐ **Usta hesabına geçin → sohbete girin → YAZABİLİYOR MU?**
  - ✅ **Doğru:** giriş kutusu açık, mesaj gönderilebiliyor
  - ❌ **Hata:** "İletişimi müşteri başlatır" şeridi hâlâ duruyor → **BİLDİRİN**
- [ ] **5.3.5** Sohbette **"✅ Usta seçildi — iş başladı"** sistem mesajı var

> [!note] Eski sohbetler
> Düzeltme **yeni** akışlar için çalışır. Daha önce takılı kalmış eski bir
> sohbet varsa düzelmez — müşteri oraya bir mesaj yazınca açılır. Test için
> **yeni ilan** kullanın.

## 5.4 Usta seçimi ve diğer sohbetlerin kilidi

**Hazırlık:** Bir ilana **iki farklı usta** ilgi bildirsin.

- [ ] **5.4.1** Müşteri iki ustayla da sohbet açsın, ikisine de yazsın
- [ ] **5.4.2** Müşteri **birinci ustayı** seçsin
- [ ] **5.4.3** ⚠️ **İkinci usta** hesabıyla sohbete girin:
  - Giriş kutusu yerine **kilit şeridi** olmalı:
    *"Müşteri bu iş için başka bir usta ile anlaştı."*
  - Geçmiş mesajlar **okunabilmeli**
- [ ] **5.4.4** İkinci usta yazmayı deneyince **engellenmeli**
- [ ] **5.4.5** Seçilen usta **normal yazabilmeli**

## 5.5 Mesaj özellikleri

- [ ] **5.5.1** **Fotoğraf** gönderilebiliyor
- [ ] **5.5.2** Fotoğraf karşı tarafta açılıyor, büyütülebiliyor
- [ ] **5.5.3** **Mesaj silme** çalışıyor → "Bu mesaj silindi" görünüyor
- [ ] **5.5.4** Okundu bilgisi / tik doğru çalışıyor
- [ ] **5.5.5** Uzun sohbette **kaydırma** akıcı, eski mesajlar yükleniyor

## 5.6 İletişim maskeleme ⭐

> Telefon, e-posta, sosyal medya otomatik gizlenir (platform dışına çıkış engeli).

- [ ] **5.6.1** Sohbete **telefon numarası** yazın (`0532 123 45 67`)
  - Gizlenmeli + **uyarı** gösterilmeli
- [ ] **5.6.2** **E-posta** yazın (`test@gmail.com`) → gizlenmeli
- [ ] **5.6.3** **Instagram/sosyal medya** adı yazın → gizlenmeli
- [ ] **5.6.4** Karşı taraf da maskelenmiş halini görüyor

## 5.7 Sohbet listesi

- [ ] **5.7.1** Mesajlar listesi tüm sohbetleri gösteriyor
- [ ] **5.7.2** **Okunmamış rozeti** doğru sayıyor
- [ ] **5.7.3** Mesaj okuyunca rozet **düşüyor**
- [ ] **5.7.4** Sohbet **arşivleme** çalışıyor (kişisel — karşı taraf etkilenmez)
- [ ] **5.7.5** Arşivlenen sohbete yeni mesaj gelince **arşivden çıkıyor**
- [ ] **5.7.6** ⚠️ Aynı çiftle **iki farklı ilan** varsa → **iki ayrı sohbet**
      görünüyor (ilan bazlı mimari)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⭐ 5.3.4'te usta yazamıyor | **En kritik bulgu — hemen bildir** |
| Mesaj gitmiyor, "gönderilemedi" | Ekran görüntüsü + hangi hesap |
| Telefon numarası maskelenmiyor | ⚠️ Ticari kural ihlali — bildir |
| Kilitli sohbette yazabiliyor | ⚠️ **Güvenlik sorunu — bildir** |
| Rozet sayısı yanlış | Kaç okunmamış vardı, kaç gösterdi |
| Aynı çift tek sohbette birleşiyor | İlan bazlı mimari bozuk demektir |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[06-Is-Tamamlama]]

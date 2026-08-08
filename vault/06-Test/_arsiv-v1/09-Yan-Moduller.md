# 9 · Yan Modüller

**Kapsam:** Ürünler, eleman bulma, usta çantası, takip merkezi, favoriler, üyelik.
**Bağımsız** — ana akıştan ayrı, istediğiniz zaman

---

## 9.1 Ürünler

- [ ] **9.1.1** Ürün listesi açılıyor, ürünler görünüyor
- [ ] **9.1.2** Ürün detayı açılıyor (misafir de görebilmeli)
- [ ] **9.1.3** Usta **yeni ürün ekleyebiliyor** (fotoğraf, fiyat, durum)
- [ ] **9.1.4** Eklenen ürün listede görünüyor
- [ ] **9.1.5** Ürün düzenleme / kaldırma çalışıyor

## 9.2 Eleman bulma (staffing)

- [ ] **9.2.1** Eleman ilanları listesi açılıyor
- [ ] **9.2.2** İş arayan olarak **profil oluşturulabiliyor**
- [ ] **9.2.3** Eleman ilanı verilebiliyor
- [ ] **9.2.4** İlan verince ilgili kişilere bildirim gidiyor

## 9.3 Usta çantası (hesap makineleri)

> Tamamen cihaz içi — internet gerektirmez.

- [ ] **9.3.1** Alan, boya, fayans hesapları doğru sonuç veriyor
- [ ] **9.3.2** Maliyet / kâr / teklif hesaplayıcıları çalışıyor
- [ ] **9.3.3** Birim çevirici ve süre hesabı çalışıyor
- [ ] **9.3.4** **AR ölçüm** açılıyor mu? (cihaz desteklemiyorsa net mesaj vermeli)

## 9.4 Takip merkezi

> Veriler **cihazda** tutulur (yerel veritabanı), buluta yedeklenebilir.

- [ ] **9.4.1** Yeni takip kaydı oluşturulabiliyor
- [ ] **9.4.2** Öncelik, etiket, hatırlatma ayarlanabiliyor
- [ ] **9.4.3** **Hatırlatma bildirimi** geliyor mu?
- [ ] **9.4.4** Tekrarlayan kayıt (günlük/haftalık) doğru ilerliyor
- [ ] **9.4.5** Çöp kutusu ve geri alma çalışıyor
- [ ] **9.4.6** ⚠️ **Buluta yedekle → geri yükle** çalışıyor
      (kayıtlar ve ekler korunuyor mu?)

> [!danger] Kritik
> Uygulamayı güncelledikten sonra takip kayıtlarınız **duruyor mu**?
> Kaybolduysa hemen bildirin — veritabanı dosya adıyla ilgili bilinen bir
> risk var.

## 9.5 Favoriler

- [ ] **9.5.1** Usta favorilere eklenebiliyor
- [ ] **9.5.2** Favoriler listesi doğru gösteriyor
- [ ] **9.5.3** Favoriden çıkarma çalışıyor

## 9.6 Üyelik (Pro)

> ⚠️ Gerçek ödeme — test kartı/hesabı kullanın.

- [ ] **9.6.1** Pro paket ekranı açılıyor, fiyatlar görünüyor
- [ ] **9.6.2** Satın alma akışı başlatılabiliyor (Google Play)
- [ ] **9.6.3** Satın alma sonrası Pro rozeti/ayrıcalıkları geliyor
- [ ] **9.6.4** Satın alma **iptal edilirse** uygulama takılmıyor

## 9.7 Genel / arayüz

- [ ] **9.7.1** **Koyu tema** açılıp kapanıyor, tüm ekranlar okunabiliyor
- [ ] **9.7.2** Aksan rengi değiştirilebiliyor
- [ ] **9.7.3** Bildirim tercihleri ayarlanabiliyor
- [ ] **9.7.4** Geri tuşu her ekranda mantıklı davranıyor (uygulamadan
      beklenmedik şekilde çıkmıyor)
- [ ] **9.7.5** Yardım / SSS açılıyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⚠️ Takip kayıtları kaybolmuş | **En yüksek öncelik — veri kaybı** |
| Hesap makinesi yanlış sonuç | Girdiler + beklenen + çıkan değer |
| AR ekranı çöküyor | Cihaz modeli |
| Koyu temada yazı okunmuyor | Hangi ekran, ekran görüntüsü |
| Yedekten geri yükleme eksik | Ne eksik (kayıt mı ek dosya mı) |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Başa dön:** [[00-TEST-PLANI]]

# 3 · İlanlar — Müşteri Tarafı

**Kapsam:** İlan açma, limit, düzenleme, silme, iptal, listeleme.
**Hangi hesap:** Müşteri

---

## 3.1 İlan oluşturma

- [ ] **3.1.1** "İlan Ver" / "+" düğmesi bulunabiliyor
- [ ] **3.1.2** Kategori seçimi çalışıyor
- [ ] **3.1.3** Başlık ve açıklama yazılabiliyor
- [ ] **3.1.4** **İl / ilçe / mahalle** seçimi çalışıyor
- [ ] **3.1.5** **Fotoğraf** eklenebiliyor (birden fazla)
- [ ] **3.1.6** Fiyat tipi seçilebiliyor: **Sabit bütçe** / **Keşif Gerekli**
  - Keşif Gerekli seçilince bütçe alanı gizleniyor/isteğe bağlı oluyor mu?
- [ ] **3.1.7** **Süre** seçimi (1 / 3 / 7 gün)
- [ ] **3.1.8** Zorunlu alan boşken **kaydet engelleniyor**, uyarı net
- [ ] **3.1.9** Kaydedince ilan oluşuyor ve **İlanlarım**'da görünüyor

## 3.2 Hemen Lazım (hızlı ilan)

- [ ] **3.2.1** "Hemen Lazım" girişi kategoriyi **önceden seçili** açıyor
- [ ] **3.2.2** Açılan ilan **Hemen Lazım vitrininde** görünüyor

## 3.3 İlan limiti ⭐

> Aynı anda en çok **5 açık ilan**.

- [ ] **3.3.1** 5 açık ilanınız varken **6.'yı açmayı deneyin**
- [ ] **3.3.2** ⚠️ Engellenmeli ve **anlaşılır bir mesaj** vermeli
      ("5 ilan sınırına ulaştınız" gibi) — sessizce başarısız olmamalı
- [ ] **3.3.3** Bir ilanı iptal edip tekrar deneyin → **açabilmeli**

## 3.4 İlan listeleme ve detay

- [ ] **3.4.1** **İlanlarım** listesi doğru ilanları gösteriyor
- [ ] **3.4.2** İlan durumu doğru yazıyor ("Teklif toplanıyor" vb.)
- [ ] **3.4.3** İlan detayı açılıyor, tüm bilgiler doğru
- [ ] **3.4.4** Fotoğraflar açılıyor, büyütülebiliyor
- [ ] **3.4.5** **İlgilenen ustalar** bölümü görünüyor (usta ilgi bildirdiyse)

## 3.5 İlan düzenleme ve silme

> Düzenleme yalnız **açık** ilanda ve yayından sonra **1 saat** içinde.

- [ ] **3.5.1** Yeni açılan ilan **düzenlenebiliyor**
- [ ] **3.5.2** Düzenleme kaydediliyor, detayda görünüyor
- [ ] **3.5.3** ⚠️ Ustaya **bağlanmış** ilan silinemiyor (net mesaj veriyor)
- [ ] **3.5.4** Bağlanmamış ilan silinebiliyor, listeden düşüyor

## 3.6 İlan iptali

- [ ] **3.6.1** İlan iptal edilebiliyor, **iptal nedeni** sorulabiliyor
- [ ] **3.6.2** İptal edilen ilan durumu "İptal edildi" oluyor
- [ ] **3.6.3** İptal edilen ilan **usta feed'inden düşüyor**
      (usta hesabıyla doğrulayın)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Fotoğraf yüklenmiyor / çok yavaş | Kaç fotoğraf, ne kadar sürdü |
| İlan açıldı ama listede yok | Tazeleme mi, kayıt mı? Uygulamayı yeniden aç, hâlâ yoksa ciddi |
| 6. ilan sessizce açılıyor | ⚠️ Limit çalışmıyor — bildir |
| Düzenle düğmesi hiç yok | İlan kaç dakikalık? (1 saat kuralı) |
| Konum seçimi takılıyor | İl mi ilçe mi mahalle mi |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[04-Ilanlar-Usta]]

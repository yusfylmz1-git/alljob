# 5 · İlan Verme

**Kapsam:** İlan formu, limit, düzenleme, silme, iptal.
**Hesap:** A · **Süre:** ~20 dk

> [!note] Herkes ilan verebilir
> Usta modu açık da olsa kapalı da olsa ilan verilebilir. İlan vermek
> "müşteri" olmayı gerektirmiyor.

---

## 5.1 İlan oluşturma

- [ ] **5.1.1** "İş İlanı Ver" formu açılıyor (Ana Sayfa veya yan menü)
- [ ] **5.1.2** Kategori seçimi çalışıyor (arama ile)
- [ ] **5.1.3** Başlık ve açıklama yazılabiliyor
- [ ] **5.1.4** İl seçimi çalışıyor
- [ ] **5.1.5** ⚠️ İl seçince **klavye kapanıyor**, ekran zıplamıyor;
      ilçe alanı **vurgulanıyor** *(B-09)*
- [ ] **5.1.6** İlçe seçimi çalışıyor
- [ ] **5.1.7** Fotoğraf eklenebiliyor, yüklenirken **spinner** dönüyor
- [ ] **5.1.8** ⭐ **Fotoğraf yüklenirken "Yayınla"ya basın** →
      *"Fotoğraf yükleniyor, bekleyin"* uyarısı çıkmalı, ilan gitmemeli
      *(B-02: sessiz veri kaybı düzeltildi)*
- [ ] **5.1.9** Süre seçimi (3 gün / 5 gün / 7 gün) — Kolay İş'te seçim YOK, 1 gün sabit
- [ ] **5.1.10** Zorunlu alan boşken kaydet engelleniyor, uyarı net
- [ ] **5.1.11** Kaydedince ilan oluşuyor, İlanlarım'da görünüyor

## 5.2 Kolay İş

- [ ] **5.2.1** "Kolay İş" girişi kategoriyi **önceden seçili** açıyor
- [ ] **5.2.2** ⚠️ Örnek çipleri **kategorinin hemen altında** *(B-10)*
- [ ] **5.2.3** Çipe dokununca başlık + açıklama doluyor
- [ ] **5.2.4** İlan Ana Sayfa'daki "Kolay İş" şeridinde görünüyor

## 5.3 İlan limiti

> Aynı anda en fazla **5 açık ilan**.

- [ ] **5.3.1** 5 açık ilanınız varken 6.'yı deneyin
- [ ] **5.3.2** ⚠️ Engellenmeli, **anlaşılır mesaj** vermeli
- [ ] **5.3.3** Bir ilanı iptal edip tekrar deneyin → açılmalı

## 5.4 İlan listeleme ve detay

- [ ] **5.4.1** Yan menü → **İlanlarım** listesi açılıyor
- [ ] **5.4.2** İlan durumu doğru yazıyor ("Teklif toplanıyor" vb.)
- [ ] **5.4.3** İlan detayı açılıyor, bilgiler doğru
- [ ] **5.4.4** Fotoğraflar açılıyor, büyütülebiliyor
- [ ] **5.4.5** İlgilenen ustalar bölümü var (usta ilgi bildirince dolar)

## 5.5 Düzenleme ve silme

> Düzenleme yalnız **açık** ilanda ve yayından sonra **1 saat** içinde.

- [ ] **5.5.1** Yeni ilan düzenlenebiliyor
- [ ] **5.5.2** ⚠️ Düzenlemede **yalnız başlık + açıklama** var —
      fotoğraf/konum değiştirilemiyor *(bilinen kısıt: B-07)*
- [ ] **5.5.3** Değişiklik kaydediliyor, detayda görünüyor
- [ ] **5.5.4** Bağlanmamış ilan silinebiliyor

## 5.6 İptal

- [ ] **5.6.1** İlan iptal edilebiliyor, **neden** soruluyor
- [ ] **5.6.2** ⚠️ Nedenlerde **"Günlük ilan hakkı doldu" OLMAMALI**
      *(B-11: yalnız sunucu yazar)*
- [ ] **5.6.3** İptal edilen ilan durumu "İptal edildi" oluyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Foto yüklenirken kaydet geçiyor | ⚠️ B-02 regresyonu — veri kaybı |
| İl seçince ekran zıplıyor | ⚠️ B-09 regresyonu |
| 6. ilan sessizce açılıyor | ⚠️ Limit çalışmıyor |
| Düzenle düğmesi hiç yok | İlan 1 saatten eski mi? |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[06-Ilan-Alma-Usta]]

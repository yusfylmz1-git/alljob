# 3 · İlanlar — Müşteri Tarafı

**Kapsam:** İlan açma, limit, düzenleme, silme, iptal, listeleme.
**Hangi hesap:** Müşteri

---

## 3.1 İlan oluşturma

- [x] **3.1.1** "İlan Ver" / "+" düğmesi bulunabiliyor
- [x] **3.1.2** Kategori seçimi çalışıyor
- [x] **3.1.3** Başlık ve açıklama yazılabiliyor
- [x] **3.1.4** **İl / ilçe / mahalle** seçimi çalışıyor — ⚠️ **B-09** (odak/klavye)
- [x] **3.1.5** **Fotoğraf** eklenebiliyor — loading + büyütme ✅ ·
      ⚠️ **B-02** (yükleme beklenmiyor) · ⚠️ **B-06** (çoklu seçim yok)
- [ ] **3.1.6** Fiyat tipi seçilebiliyor: **Sabit bütçe** / **Keşif Gerekli**
  - ⚠️ **K-07** — formda hiç yok, kodda `inspection` sabit. Karar bekliyor.
- [x] **3.1.7** **Süre** seçimi (1 / 3 / 7 gün)
- [x] **3.1.8** Zorunlu alan boşken **kaydet engelleniyor**, uyarı net
- [x] **3.1.9** Kaydedince ilan oluşuyor ve **İlanlarım**'da görünüyor

## 3.2 Hemen Lazım (hızlı ilan)

- [x] **3.2.1** "Hemen Lazım" girişi kategoriyi **önceden seçili** açıyor —
      ⚠️ **B-10** (örnek çipleri çok aşağıda)
- [x] **3.2.2** Açılan ilan **Hemen Lazım vitrininde** görünüyor

## 3.3 İlan limiti ⭐

> Aynı anda en çok **5 açık ilan**.

- [x] **3.3.1** 5 açık ilanınız varken **6.'yı açmayı deneyin**
- [x] **3.3.2** ⚠️ Engellenmeli ve **anlaşılır bir mesaj** vermeli — ✅ çalışıyor
- [x] **3.3.3** Bir ilanı iptal edip tekrar deneyin → **açabilmeli**
- [x] **3.3.4** **İlanlarım** ekranındaki sayaç doğru mu? (`3/5 açık` biçiminde)

> [!note] İkinci bir limit daha var
> **Günlük 10 ilan** (`maxJobsPerDay`) — sunucuda `onJobCreated` uygular.
> 5'lik limiti test ederken buna takılmazsınız, ama çok sayıda deneme
> yaparsanız karşınıza çıkabilir.

## 3.4 İlan listeleme ve detay

- [x] **3.4.1** **İlanlarım** listesi doğru ilanları gösteriyor
- [x] **3.4.2** İlan durumu doğru yazıyor ("Teklif toplanıyor" vb.)
- [x] **3.4.3** İlan detayı açılıyor, tüm bilgiler doğru
- [x] **3.4.4** Fotoğraflar açılıyor, büyütülebiliyor
- [ ] **3.4.5** **İlgilenen ustalar** bölümü görünüyor (usta ilgi bildirdiyse)
      → ⏭️ **Bölüm 4'te doğrulanacak** (usta hesabı gerekiyor)

## 3.5 İlan düzenleme ve silme

> Düzenleme yalnız **açık** ilanda ve yayından sonra **1 saat** içinde.

- [x] **3.5.1** Yeni açılan ilan **düzenlenebiliyor** — ⚠️ **B-07** (yalnız
      başlık+açıklama; fotoğraf/konum/kategori düzenlenemiyor)
- [x] **3.5.2** Düzenleme kaydediliyor, detayda görünüyor
- [ ] **3.5.3** ⚠️ Ustaya **bağlanmış** ilan silinemiyor (net mesaj veriyor)
      → ⏭️ **Bölüm 5/6'da** (önce ustaya bağlanmış ilan gerekiyor)
- [x] **3.5.4** Bağlanmamış ilan silinebiliyor, listeden düşüyor

## 3.6 İlan iptali

- [x] **3.6.1** İlan iptal edilebiliyor, **iptal nedeni** sorulabiliyor —
      ⚠️ **B-11** ("günlük hakkım bitti" seçeneği gereksiz)
- [x] **3.6.2** İptal edilen ilan durumu "İptal edildi" oluyor
- [ ] **3.6.3** İptal edilen ilan **usta feed'inden düşüyor**
      → ⏭️ **Bölüm 4'te doğrulanacak** (usta hesabı gerekiyor)

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

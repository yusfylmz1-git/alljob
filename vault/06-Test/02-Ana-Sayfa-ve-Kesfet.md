# 2 · Ana Sayfa ve Keşfet

**Kapsam:** Ana sayfa bölümleri, usta arama, filtreler, alt bar gezinme.
**Hesap:** A · **Süre:** ~15 dk

> [!important] Bu bölüm yeniden yazıldı
> Ana Sayfa'daki **rol ayrımı kalktı** — usta ve müşteri artık aynı sırayı
> görür. "Popüler Ürünler", "Usta Araçları" ve "Platform istatistikleri"
> bölümleri **kaldırıldı**.

---

## 2.1 Ana Sayfa bölümleri

Beklenen sıra (herkeste aynı):
```
[Misafirse giriş şeridi]
Usta Bul (büyük kart)
[İş İlanı Ver] [Kolay İş]
⚡ Kolay İş ilanları
⭐ Öne Çıkan Ustalar
📋 Son İş İlanları
🔥 Haftanın Ustası / Duyuru
```

- [ ] **2.1.1** "Usta Bul" kartı görünüyor, dokununca Keşfet açılıyor
- [ ] **2.1.2** "İş İlanı Ver" ilan formunu açıyor
- [ ] **2.1.3** "Kolay İş" formu **kategori seçili** açıyor
- [ ] **2.1.4** ⚠️ **"Ürünler" ile ilgili hiçbir şey görünmemeli**
      (modül kaldırıldı)
- [ ] **2.1.5** ⚠️ **"Usta Araçları" bölümü olmamalı**
- [ ] **2.1.6** Öne Çıkan Ustalar şeridi kayıyor, karta dokununca profil açılıyor
- [ ] **2.1.7** Son İş İlanları görünüyor
- [ ] **2.1.8** Aşağı çekince **yenileme** çalışıyor

## 2.2 Keşfet — usta arama

> Keşfet artık **tek liste**: yalnız ustalar. Sekme çubuğu kaldırıldı.

- [ ] **2.2.1** Keşfet açılınca ustalar **hemen listeleniyor** (boş açılmamalı)
- [ ] **2.2.2** ⚠️ **Sekme çubuğu olmamalı** (Ustalar/Ürünler/İlanlar yok)
- [ ] **2.2.3** Arama kutusuna isim/meslek yazınca sonuç süzülüyor
- [ ] **2.2.4** "Detaylı Arama" paneli açılıyor
- [ ] **2.2.5** İl/ilçe filtresi çalışıyor
- [ ] **2.2.6** Meslek filtresi çalışıyor
- [ ] **2.2.7** Filtre temizlenebiliyor
- [ ] **2.2.8** Aşağı kaydırınca **sayfalama** çalışıyor (daha fazla usta gelir)
- [ ] **2.2.9** Usta kartına dokununca profil açılıyor

## 2.3 Alt bar gezinme

- [ ] **2.3.1** Sekmeler: **Ana Sayfa · Keşfet · Mesajlar · Profil**
- [ ] **2.3.2** ⚠️ Usta modu kapalıyken **"İlanlar" sekmesi GÖRÜNMEMELİ**
- [ ] **2.3.3** Sekme değişimi hızlı, seçili sekme belli
- [ ] **2.3.4** Mesajlar sekmesinde okunmamış rozeti görünüyor (varsa)
- [ ] **2.3.5** ⚠️ Profil/Keşfet/Mesajlar'dan **geri tuşu → Ana Sayfa**
- [ ] **2.3.6** ⚠️ Ana Sayfa'dan geri tuşu → **uygulama kapanır** (doğru)

## 2.4 Yan menü (☰)

- [ ] **2.4.1** Menü açılıyor, başlıkta ad + mod yazıyor
- [ ] **2.4.2** İçerik: İş İlanı Ver · Takip Ettiklerim · Hesap Ayarları ·
      Yardım · Görünüm · Çıkış
- [ ] **2.4.3** ⚠️ **"Ajanda" olmamalı** (modül kaldırıldı)
- [ ] **2.4.4** ⚠️ **"Usta/Müşteri Moduna Geç" olmamalı**
      (mod değişimi artık profildeki anahtardan)
- [ ] **2.4.5** "Görünüm" → tema ve renk değiştirilebiliyor
- [ ] **2.4.6** Tema seçimi uygulama yeniden açılınca korunuyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Keşfet boş açılıyor | ⚠️ Arama başlatılmıyor — bildir |
| Ürün/araç/ajanda izi görünüyor | ⚠️ Kaldırılmış modül sızıntısı |
| "İlanlar" sekmesi müşteri modunda var | ⚠️ Rol kapısı bozuk |
| Geri tuşu uygulamayı kapatıyor | ⚠️ MainTabScope regresyonu |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[03-Profil-ve-Usta-Modu]]

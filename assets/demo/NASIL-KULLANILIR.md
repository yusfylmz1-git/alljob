# Demo görselleri — mağaza ekran görüntüsü seti

Bu klasör **yalnızca ekran görüntüsü çekmek** içindir. Yayın paketine (APK/AAB)
girmez, repoya commit edilmez (`.gitignore`'da).

Fotoğrafları buraya kopyalayın; uygulama mock modda açıldığında otomatik
yüklenir. Hiçbir hesaba giriş yapmanız, hiçbir yere yükleme yapmanız gerekmez.

## Dosya yoksa ne olur?

Hiçbir şey bozulmaz. Eksik her görsel için uygulama otomatik yedeğe düşer:
avatarlar renkli daire içinde baş harf gösterir, ürün ve iş kartları kategori
ikonuna döner. Ekranlar yine dolu görünür — fotoğraflar sadece daha etkileyici
yapar.

## Beklenen dosyalar

Dosya adları **birebir** böyle olmalı, uzantı `.jpg`.

### `avatar/` — 10 dosya, 512×512 kare

Persona profil fotoğrafları. Yüz ortada olsun; uygulama yuvarlak kırpar.

| Dosya | Kişi | Meslek |
|---|---|---|
| `demo_kerem.jpg` | Kerem Alptekin | Boyacı |
| `demo_sevil.jpg` | Sevil Karaduman | İç mimar |
| `demo_okan.jpg` | Okan Beyazıt | Tesisatçı |
| `demo_zeynep.jpg` | Zeynep Uçar | *(müşteri)* |
| `demo_tolga.jpg` | Tolga Şenyurt | Elektrikçi |
| `demo_ayse.jpg` | Ayşe Nur Tunç | Temizlik |
| `demo_burak.jpg` | Burak Yalçınkaya | Klima teknisyeni |
| `demo_hatice.jpg` | Hatice Gülbahar | Fotoğrafçı |
| `demo_serkan.jpg` | Serkan Doğanay | Marangoz |
| `demo_elif.jpg` | Elif Sarıkaya | Fayansçı |

> **Gerçek kişi fotoğrafı kullanmayın.** KVKK ve mağaza politikası açısından
> risklidir. Kendi fotoğraflarınız, ticari kullanıma açık stok (Unsplash,
> Pexels) veya AI üretimi tercih edin.

### `work/` — 9 dosya, 1200×900 (4:3)

Usta profillerindeki "İşlerim" galerisi ve sohbette gönderilen fotoğraflar.

| Dosya | İçerik |
|---|---|
| `work_painter_1.jpg` · `work_painter_2.jpg` · `work_painter_3.jpg` | Boyanmış iç mekân |
| `work_tiler_1.jpg` · `work_tiler_2.jpg` | Fayans / banyo |
| `work_carpenter_1.jpg` · `work_carpenter_2.jpg` | Ahşap mobilya, dolap |
| `work_interior_1.jpg` · `work_interior_2.jpg` | İç mimari, ofis / salon |

### `product/` — 8 dosya, 1000×1000 kare

Mağaza vitrinindeki ürün görselleri.

| Dosya | Ürün |
|---|---|
| `prod_1.jpg` | Mutfak bataryası (sıfır) |
| `prod_2.jpg` | Kombi sirkülasyon pompası |
| `prod_3.jpg` | Meşe TV ünitesi |
| `prod_4.jpg` | Masif ahşap yemek masası |
| `prod_5.jpg` | El dokuma kilim |
| `prod_6.jpg` | Pirinç sarkıt aydınlatma |
| `prod_7.jpg` | Klima (az kullanılmış) |
| `prod_8.jpg` | Ahşap fotoğraf çerçevesi seti |

## Toplam

27 görsel, yaklaşık 5 MB. JPG, kalite 85 önerilir.

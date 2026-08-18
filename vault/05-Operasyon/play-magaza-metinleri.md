# Play Store mağaza sayfası metinleri

> Kopyala-yapıştır için hazır. Kaynak: `vault/02-Ozellikler/Mevcut-Akislar.md`
> (koddan çıkarılmış gerçek akışlar). Uygulamada OLMAYAN hiçbir özellik
> yazılmadı — Play, açıklamayla uygulamanın uyuşmadığı durumları reddeder.

---

## 1. Uygulama adı (30 karakter sınırı)

```
İlanda Hizmet
```

---

## 2. Kısa açıklama (80 karakter sınırı)

Play arama sonuçlarında ve kart altında görünür. Üç seçenek:

**Önerilen** (78 karakter):
```
Bölgendeki ustaları bul, ilan ver, ürün al sat. Mesajla anlaş, işini hallet.
```

Alternatif A (72):
```
Usta ara, iş ilanı ver, ürün al sat. Bölgendeki hizmet pazaryeri.
```

Alternatif B (79):
```
Tamirat, tadilat, nakliye… Bölgendeki ustaya mesaj at, işini hemen hallet.
```

---

## 3. Uzun açıklama (4000 karakter sınırı)

Aşağıdaki metin ~2100 karakter — Play'de fazla uzun açıklama okunmuyor,
bu uzunluk ideal.

```
İlanda Hizmet, ihtiyacın olan ustayı bölgende bulmanı sağlayan bir hizmet
pazaryeridir. Tamirat, tadilat, nakliye, temizlik ve daha fazlası için
ilan ver; ilgilenen ustalar sana doğrudan mesaj atsın.

■ USTA MI ARIYORSUN?

• İlan ver, ustalar sana ulaşsın
İhtiyacını yaz, fotoğraf ekle, ilini seç. İlanın o bölgedeki uygun ustalara
bildirim olarak gider. Teklif toplamak için beklemene gerek yok — ustalar
doğrudan mesajla iletişime geçer.

• Ustaları incele, kendin seç
Meslek ve bölgeye göre ara. Her ustanın profilinde iş fotoğrafları,
değerlendirmeler, puanı ve varsa sertifikaları yer alır. Beğendiğin ustaya
tek dokunuşla mesaj at.

• Kolay İş
Market alışverişi, küçük taşıma, kısa gidiş gibi acil ve basit işler için
ayrı bir akış. Bir günlük ilan aç, hızlıca çözülsün.

■ HİZMET Mİ VERİYORSUN?

• Ücretsiz usta profili oluştur
Mesleğini, hizmet bölgeni ve tanıtımını ekle. İş fotoğraflarını yükle,
müşteriler seni Keşfet'te bulsun.

• Bölgendeki ilanları gör
İline ve mesleğine uyan ilanlar bildirim olarak sana düşer. İlgilendiğin
ilana mesaj atarak işi konuş.

• Değerlendirmelerle güven kazan
Tamamladığın işlerin ardından aldığın puanlar profilinde birikir.

■ MAĞAZA: ÜRÜN AL, ÜRÜN SAT

• Ürünlerini vitrine koy
Mağaza profilini aç, satış kategorilerini seç, ürünlerini fotoğrafıyla
yayınla. Alıcılar sana mesajla ulaşsın.

• Aradığın ürünü talep et
Bulamadığın bir ürün mü var? Talep oluştur — ilindeki satıcılara iletilsin.

■ NASIL ÇALIŞIR?

1. Ücretsiz kaydol
2. İlan ver ya da usta/ürün ara
3. Mesajlaş, anlaş, işini hallet

■ BİLMEN GEREKENLER

İlanda Hizmet bir ARACI PLATFORMDUR. Ödeme, teslimat ve iş anlaşması
tamamen kullanıcılar arasındadır; uygulama üzerinden ödeme alınmaz ve
ödemeye aracılık edilmez. Ustaların yetkinliği ve satıcıların ürünleri
uygulama tarafından garanti edilmez.

Güvenliğin için: peşin ödeme yapmadan önce karşı tarafı ve işi/ürünü
doğrula, mümkünse yüz yüze görüş. Uygunsuz içerik ve davranışları uygulama
içinden şikayet edebilir, istemediğin kullanıcıları engelleyebilirsin.


Kullanım koşulları: https://www.ilandahizmet.com/kullanim-kosullari.html
Gizlilik politikası: https://www.ilandahizmet.com/gizlilik-politikasi.html
```

---

## 4. Kategori ve etiketler

| Alan | Değer |
|---|---|
| Uygulama kategorisi | **İş** (Business) |
| Etiketler | Hizmetler, Yerel, Alışveriş |
| E-posta | ilandahizmet@gmail.com |
| Web sitesi | https://www.ilandahizmet.com |

---

## 5. Ekran görüntüsü çekim listesi

En az 2, ideali 4-6. Telefondan çekilecek ekranlar:

1. **Ana sayfa** — hızlı erişim kartları görünsün
2. **Keşfet → Ustalar** — usta kartları listesi
3. **Keşfet → İlanlar** — ilan listesi
4. **Usta profili** — fotoğraflar + puan + değerlendirme
5. **Sohbet** — mesajlaşma ekranı
6. **Mağaza** — ürün vitrini

⚠️ Kırmızı hata şeridi görünen kareleri kullanma.
⚠️ Gerçek kişi adı / telefon numarası / adres görünmesin.

---

## 6. Sürüm notları (ilk sürüm)

```
İlk sürüm.
```

---

## Not: neden bu kadar "aracıyız" vurgusu var?

Yasal metinlerimiz (`legal_docs.dart`) platformun taraf olmadığını,
ödemeye aracılık etmediğini açıkça yazıyor. Mağaza açıklaması bununla
**tutarlı** olmalıdır — Play, açıklamada vaat edilen ile uygulamanın
yaptığı iş uyuşmazsa reddeder. Bu paragrafı silme.

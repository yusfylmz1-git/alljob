# Testçi rehberi — kapalı test (Alpha)

> Amaç: Google'ın üretim erişimi için aradığı **12 testçi × kesintisiz 14 gün**
> şartını karşılamak ve gerçek cihazlarda hata bulmak. Google yalnız kaydolmayı
> değil **etkileşimi** de ölçüyor; testçi indirip bırakırsa başvuru reddedilebilir.
>
> Bu dosya iki bölüm: (1) testçilere gönderilecek mesajlar, (2) görev listesi.

---

## 1. Davet mesajı (WhatsApp)

> Katılım bağlantısı, kapalı test onaylandıktan sonra Play Console'da
> **Test edin ve yayınlayın → Kapalı test → Test kullanıcıları** altında çıkar.
> Aşağıdaki `[BAĞLANTI]` yerine onu koy.

```
Selam! İlanda Hizmet diye bir uygulama yaptım — usta bulma, ilan verme ve
ürün alım satımı için. Google Play'de yayına çıkmadan önce test aşamasındayız
ve senin yardımına ihtiyacım var.

Yapman gerekenler:
1. Şu bağlantıya Gmail hesabınla gir: [BAĞLANTI]
2. "Testçi ol" / "Become a tester" de
3. Aynı sayfadaki Play Store bağlantısından uygulamayı indir

ÖNEMLİ: Google'ın kuralı gereği uygulamanın 14 gün boyunca telefonunda
kurulu kalması gerekiyor. Silersen sayaç sıfırlanıyor ve baştan başlıyoruz.
Ara sıra açıp kullanman da gerekiyor — sadece kurulu durması yetmiyor.

Sana kısa bir görev listesi göndereceğim, 10 dakikanı alır. Takıldığın veya
garip gelen her şeyi bana yaz, hepsi işime yarıyor.

Teşekkürler!
```

---

## 2. Görev listesi (davetten sonra gönder)

> Kısa tut; uzun liste kimse yapmaz. Testçi başına ~10 dakika.

```
İlanda Hizmet — test görevleri (10 dk)

Sırayla dene, takıldığın yeri bana yaz:

1) GİRİŞ
   Uygulamayı aç, Google hesabınla giriş yap.
   → Giriş ekranı takıldı mı? Hata verdi mi?

2) İLAN VER
   Ana sayfa → "İş İlanı Ver"
   Bir iş yaz (ör. "Musluk damlatıyor"), fotoğraf ekle, ilini seç, yayınla.
   → İlan listede göründü mü?

3) USTA ARA
   Keşfet → Ustalar
   Meslek ve şehir seç, listeye bak, bir ustaya gir.
   → Profil açıldı mı? Fotoğraflar yüklendi mi?

4) MESAJ AT
   Bir ustaya veya ilana mesaj gönder.
   → Mesaj gitti mi? Karşı taraf görebildi mi?

5) USTA PROFİLİ AÇ
   Profil → Usta sekmesi → mesleğini ve bölgeni seç, kaydet.
   → Kaydetti mi? Hata verdi mi?

6) MAĞAZA
   Keşfet → Mağaza → bir ürün ekle veya ürünlere göz at.
   → Ürün eklenebildi mi?

7) DEĞERLENDİRME
   Bir usta profiline gir, puan ver.
   → Puan kaydedildi mi?

8) KOLAY İŞ (varsa vaktin)
   Ana sayfa → "Kolay İş" (market, taşıma, kısa gidiş — 1 günlük ilan)
   → Normal ilandan farkı çalışıyor mu?

Bulduğun her sorunu yaz: hangi ekranda, ne yaptın, ne oldu.
Ekran görüntüsü çok işime yarar.
```

---

## 3. Hatırlatma mesajı (5. ve 10. günde)

```
Selam, İlanda Hizmet testi devam ediyor. Uygulamayı silmediysen süper —
14 gün dolmadan silme lütfen. Fırsat buldukça açıp bir iki ekran gezmen
yeterli. Bir sorun fark ettiysen yazmayı unutma!
```

---

## 4. Kritik noktalar (kendin için)

| Konu | Not |
|---|---|
| **Sayaç kişi başına** | Her testçinin 14 günü kendi kaydolduğu gün başlar. Son eklenen kişi başvuru tarihini belirler → 12'yi hızlı tamamla. |
| **Kesintisiz** | Testçi listeden çıkarsa/çıkarılırsa sayaç sıfırlanır. |
| **Etkileşim şart** | Google "yeterli etkileşim" arıyor. Kurulu durması yetmez. |
| **Geri bildirim topla** | Üretim başvurusunda test geri bildirimlerini ÖZETLEMEN istenecek. Play Console → Puanlar ve yorumlar → Test geri bildirimleri. Not tut. |
| **Gmail zorunlu** | Testçi e-postası Google hesabıyla eşleşmeli, yoksa uygulamayı göremez. |

## 5. Test sırasında hata çıkarsa

Kapalı testte yeni sürüm yüklemek serbest ve hızlı:

1. Hatayı düzelt
2. `pubspec.yaml` → `version:` satırındaki `+N` sayısını **artır** (Play aynı
   versionCode'u ikinci kez kabul etmez)
3. `flutter build appbundle --release`
4. Play Console → Kapalı test → Yeni sürüm oluştur → AAB'yi yükle

Sunucu tarafı düzeltmeleri (Firestore kuralı, Cloud Function) yeni sürüm
GEREKTİRMEZ — `firebase deploy` yeter, testçiler güncelleme yapmadan etkilenir.

# Logo Değiştirme

Kod değişikliği **gerekmez**. İki dosyayı değiştirip tek komut çalıştırıyorsun.

## Hangi dosya nereye gidiyor?

| Dosya | Nerede görünür | Nasıl işlenir |
|---|---|---|
| `logo.png` | Uygulama **içinde**: giriş ekranı, açılış, yan menü, ana sayfa başlığı, Premium | Doğrudan okunur, `BrandMark` widget'ı |
| `app_icon.png` | Telefonun **ana ekranında** (uygulama simgesi) | `flutter_launcher_icons` ile Android/iOS/web boyutlarına dönüştürülür |

İkisi aynı görsel olabilir ama **olmak zorunda değil** — genelde ana ekran
simgesi daha sade olur (küçük boyutta okunması gerekir).

## Nasıl olmalı?

**`logo.png`** — uygulama içi
- Kare (1:1), en az **512×512** px
- **Şeffaf zemin** (PNG alpha)
- İçerik kenarlara dayalı, etrafında bol boşluk **olmasın**
  → `BrandMark` `BoxFit.cover` kullanıyor; boşluk bırakırsan logo küçük durur
- En büyük kullanım 248px (açılış ekranı), yani 512px rahat yeter

**`app_icon.png`** — ana ekran simgesi
- Kare, **1024×1024** px (mağaza gereksinimi)
- Şeffaf zemin
- **Kenarlardan pay bırak:** Android'de simge yuvarlak/kare/damla şeklinde
  kırpılabilir. Önemli içerik ortadaki ~%66'lık dairenin içinde kalsın,
  yoksa köşeler kesilir
- Metin koyma; 48px'te okunmaz

## Adımlar

**1. Dosyaları koy**

Yeni dosyaları bu klasöre, **aynı adlarla** koy:

```
assets/brand/logo.png
assets/brand/app_icon.png
```

Adı değiştirme — kod bu adlara bakıyor.

**2. Ana ekran simgesini üret**

```bash
flutter pub get
dart run flutter_launcher_icons
```

Bu komut Android mipmap'lerini, iOS AppIcon setini ve web ikonlarını
üretir. `app_icon.png` değişmediyse bu adımı atlayabilirsin.

**3. Temiz derle**

```bash
flutter clean
flutter pub get
flutter run
```

`flutter clean` **şart**: eski simge derleme önbelleğinde kalır, sadece
`flutter run` dersen değişmemiş gibi görünür.

Ana ekran simgesi hâlâ eskiyse uygulamayı telefondan **kaldırıp yeniden
kur** — Android launcher simgeyi agresif önbelleğe alır.

## Renkli zemin

Adaptive icon'un arka plan rengi `pubspec.yaml` içinde:

```yaml
adaptive_icon_background: "#EA580C"   # turuncu
adaptive_icon_foreground_inset: 12    # logonun kenar payı
```

Yeni logon farklı bir tonda ise bu rengi de güncelle. Logo simgenin içinde
büyük duruyorsa `inset` değerini artır (12 → 16), küçük duruyorsa azalt.

## Kontrol listesi

Değiştirdikten sonra bunlara bak:

- [ ] Açılış ekranı (248px — en büyük kullanım, bulanıklık burada belli olur)
- [ ] Giriş ekranı (180px)
- [ ] Yan menü başlığı (88px)
- [ ] Ana sayfa üst şeridi (40px — **koyu gradyan üstünde**, koyu logo
      kaybolur mu?)
- [ ] Telefon ana ekranı (simge kırpılmış mı?)
- [ ] Koyu tema — logon koyu renkliyse koyu zeminde erir

Son iki madde en sık gözden kaçan: uygulama içi logo hem beyaz hem koyu
zemin üstünde duruyor.

## Yedek davranış

Dosya bulunamazsa uygulama çökmez — `BrandMark` el aleti ikonuna düşer
(`brand_mark.dart`, `errorBuilder`). Logo aniden ikona dönüştüyse dosya adı
yanlış veya PNG bozuk demektir.

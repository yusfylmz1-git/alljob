# Play Store Yayın Rehberi

Durum: 2026-08-10. Uygulama: **İlanda Hizmet** · `com.sepettehizmet.app`

> Paket adı bilerek eski markanın adında. **DEĞİŞTİRİLEMEZ** — Play'de paket
> adı bir uygulamanın kalıcı kimliğidir; değiştirmek yeni uygulama yayınlamak
> demektir (kullanıcılar, yorumlar, satın almalar sıfırlanır).

---

## ✅ Hazır olanlar

| Ne | Durum |
|---|---|
| Release AAB derlemesi | ✅ `flutter build appbundle --release` başarılı (59.2 MB) |
| İmza yapılandırması | ✅ `key.properties` + keystore yerinde |
| Yasal sayfalar (canlı) | ✅ www.ilandahizmet.com |
| Hesap silme sayfası | ✅ `/hesap-silme.html` (Play zorunlu) |
| Cloud Functions | ✅ 48/48 canlıda |
| Firestore kuralları | ✅ deploy edildi |
| Testler | ✅ 645/645 · analyze 0 |

---

## 🔴 Yayın öncesi YAPILMASI GEREKENLER

### 1. Sürüm numarası — `pubspec.yaml`

Şu an **`1.0.0+1`**. İlk yayın için doğru, ama şunu bil:

- `+1` = **versionCode**. Play'e yüklenen her AAB'de **artmak zorunda**.
  Aynı versionCode ikinci kez yüklenemez — reddedilir.
- Her yeni yükleme öncesi `+2`, `+3`… yap.

### 2. İmza anahtarı yedeği — ⚠️ EN KRİTİK

`android/key.properties` ve `.jks` dosyası artık `.gitignore`'da (2026-08-10'da
eklendi; öncesinde kural **yoktu**, dosyalar şans eseri commit'lenmemişti).

> [!danger] Anahtarı kaybedersen uygulamayı GÜNCELLEYEMEZSİN
> Play Store'da bir uygulamanın imzası değiştirilemez. Keystore kaybolursa
> tek çare yeni paket adıyla baştan yayınlamak — mevcut kullanıcılar,
> yorumlar ve indirme sayısı KAYBOLUR.
>
> **Şimdi yap:** `.jks` dosyasını ve `key.properties` içeriğini repo dışında,
> şifreli iki ayrı yerde sakla (parola yöneticisi + çevrimdışı yedek).
>
> Play Console'da **Play App Signing**'i açarsan Google yükleme anahtarını
> saklar ve kaybolursa sıfırlanabilir — şiddetle önerilir.

### 3. Veri güvenliği formu (Play Console)

Birleşik manifest'teki izinler ve ne beyan etmen gerektiği:

| İzin | Kaynak | Play'de beyanı |
|---|---|---|
| `INTERNET` · `ACCESS_NETWORK_STATE` | Firebase | Beyan gerekmez |
| `POST_NOTIFICATIONS` | FCM push | "Bildirim gönderiyoruz" |
| `CAMERA` | `image_picker` (profil/ilan/ürün foto) | **Fotoğraf** — kullanıcı seçer |
| `VIBRATE` · `WAKE_LOCK` | FCM | Beyan gerekmez |
| `ACCESS_ADSERVICES_AD_ID` | **firebase_analytics** | ⚠️ **"Reklam kimliği kullanıyoruz"** işaretlenmeli |
| `USE_BIOMETRIC` · `USE_FINGERPRINT` | Firebase Auth (kitaplık) | Kullanılmıyor; beyan gerekmez |

**Toplanan veri olarak beyan edilecekler:**
- E-posta adresi, ad-soyad, profil fotoğrafı (hesap)
- Telefon numarası (opsiyonel, kullanıcı girer)
- Konum: **il/ilçe seçimi** — GPS DEĞİL (cihaz konum izni yok, bunu belirt)
- Kullanıcı içeriği: ilan, ürün, mesaj, değerlendirme
- Analitik: Firebase Analytics

**Kaldırılan izinler (2026-08-10):** `RECORD_AUDIO` ve
`RECEIVE_BOOT_COMPLETED`. Takip Merkezi modülüne aitti, modül silinmişti.
Mikrofon izni isteyen bir hizmet uygulaması kurulum ekranında güven
kaybettirirdi.

### 4. Play Console'da zorunlu alanlar

- [ ] **Gizlilik politikası URL'i:** `https://www.ilandahizmet.com/gizlilik-politikasi.html`
- [ ] **Hesap silme URL'i:** `https://www.ilandahizmet.com/hesap-silme.html`
      (Play 2024'ten beri hesap oluşturan uygulamalarda ZORUNLU)
- [ ] Uygulama simgesi 512×512 PNG
- [ ] Özellik grafiği 1024×500
- [ ] En az 2 telefon ekran görüntüsü (16:9 veya 9:16)
- [ ] Kısa açıklama (80 karakter)
- [ ] Tam açıklama (4000 karakter)
- [ ] İçerik derecelendirmesi anketi
- [ ] Hedef kitle: 18+ (hizmet pazaryeri, mesajlaşma içerir)

### 5. Kullanıcı içeriği (UGC) beyanı

Uygulama **kullanıcı içeriği barındırıyor** (ilan, ürün, mesaj, yorum).
Play bunun için moderasyon altyapısı ister — sende **var**, formda belirt:

- Şikayet mekanizması: her ilan/ürün/kullanıcıda "Şikayet et"
- Moderasyon: admin paneli + otomatik gizleme (3 şikayette ürün gizlenir)
- Engelleme: kullanıcı engelleme mevcut
- Hesap askıya alma: admin `adminSetUserSuspended`

### 6. Son kontroller

```bash
flutter analyze          # 0 sorun
flutter test             # 645/645
flutter build appbundle --release
```

AAB yolu: `build/app/outputs/bundle/release/app-release.aab`

---

## 📋 İlk yükleme sırası

1. Play Console → Uygulama oluştur → paket adı `com.sepettehizmet.app`
2. **Play App Signing'i aç** (anahtar kurtarma için)
3. Veri güvenliği formu (yukarıdaki tablo)
4. İçerik derecelendirmesi
5. Mağaza girişi (açıklama, görseller)
6. **Kapalı test** (internal testing) ile başla — açık yayına geçmeden
   gerçek cihazlarda dene
7. Sorun yoksa üretim yayını

> İlk incelemesi birkaç gün sürebilir. Reddedilirse gerekçe e-postayla gelir;
> en sık sebep eksik veri güvenliği beyanı veya erişilemeyen gizlilik URL'i.

---

## Bilinen açık işler (yayını ENGELLEMEZ)

- **Onboarding'e Kolay İş tanıtımı** — içerik kararı bekliyor
- **Telefon doğrulamada `unknown`** — cihaz konsol logu gerekiyor
- **İl bazlı Haftanın Ustası** — karar bekliyor
- **Mağaza modülü cihazda test edilmedi** — canlıya açık ama denenmedi

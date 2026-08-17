# Firebase — yeni paket kimliği kaydı (`com.sepettehizmet.app`)

Proje adı "Sepette Hizmet"e geçince Android/iOS paket kimliği değişti.
Firebase'de **yeni app kaydı** açılmadan `flutter build apk` ÇALIŞMAZ:

```
No matching client found for package name 'com.sepettehizmet.app'
in android/app/google-services.json
```

Bu dosyayı Console'dan indirmek gerekir — elle düzenlenmez.

---

## 1) Android app kaydı

Firebase Console → **alljob1** → ⚙ Project settings → *Your apps* → **Add app → Android**

| Alan | Değer |
|---|---|
| Android package name | `com.sepettehizmet.app` |
| App nickname (ops.) | Sepette Hizmet |

### SHA parmak izleri — ATLAMAYIN

Uygulama **Google ile giriş** (`google_sign_in`) kullanıyor. SHA eklenmezse
Google girişi `PlatformException(sign_in_failed ...)` ile düşer.

Kayıt ekranındaki *Debug signing certificate SHA-1* alanına **debug**
SHA-1'i girin; kayıt bittikten sonra app kartındaki **Add fingerprint** ile
**release** SHA-1'i de ekleyin.

```
debug   SHA-1: 5D:C4:F1:62:4B:88:DB:10:BB:AF:75:8B:AB:EF:C6:17:09:B1:26:02
release SHA-1: 99:7A:CB:23:5F:5F:0C:78:84:E1:A7:03:B1:3C:55:21:A5:00:58:87
```

SHA-256 (App Check / Play Integrity için önerilir):

```
debug   SHA-256: 0B:B2:AA:93:55:39:7B:62:7A:61:E4:A8:36:7F:F8:D5:98:22:5D:A8:25:71:E8:DA:4D:82:AE:D9:C5:88:AD:FA
release SHA-256: 39:FC:9D:97:37:FE:52:55:17:84:25:C9:31:4D:8E:27:7B:75:4B:F9:FC:48:35:94:57:33:10:B8:0B:FD:03:A6
```

> Play App Signing'e geçilince Play Console **kendi** imzasını üretir;
> oradaki SHA'lar da Firebase'e EKLENMELİ (yoksa mağazadan inen sürümde
> Google girişi çalışmaz).

### Dosyayı yerine koyun

`google-services.json` indir → `android/app/google-services.json`
(üzerine yaz).

---

## 2) iOS app kaydı

✅ Açıldı (2026-08-13). Bundle ID: `com.sepettehizmet.app`
App ID: `1:839781526307:ios:af72f93e17f9bccc9aba96`
`ios/Runner/GoogleService-Info.plist` yerinde.

---

## 3) `firebase_options.dart` yenile

`lib/firebase_options.dart` içindeki `appId` değerleri hâlâ **ESKİ**
kayıtlara ait (dosyada ⚠ notu var). Yenilemek için:

```bash
flutterfire configure --project=alljob1
```

Sorulduğunda android + ios + web seçin. Komut `appId`leri otomatik günceller.

---

## 4) App Check debug token

Paket adı değişti → **eski debug token GEÇERSİZ**.

1. `flutter run` (debug)
2. Logcat'te `Enter this debug secret into the allow list...` satırını bul
3. Console → App Check → Apps → ⋮ → **Manage debug tokens** → ekle

Acil durumda geçici atlama: `flutter run --dart-define=SKIP_APP_CHECK=true`
(yalnız debug; `main.dart` bunu destekliyor).

---

## 5) Doğrula

```bash
flutter build apk --debug
```

Beklenen: `√ Built build\app\outputs\flutter-apk\app-debug.apk`

Cihazda kontrol listesi:
- [ ] Google ile giriş
- [ ] Ana sayfa yükleniyor (Firestore okuma)
- [ ] Bildirim izni + FCM token (App Check gerekir)
- [ ] Hemen Lazım akışı

---

## Eski kayıtlar ne olacak?

`com.ustacepte.usta_cepte` ve `com.ustasindan.app` kayıtları Console'da
duruyor. Silmek ZORUNLU DEĞİL (kullanılmıyorlar). Karışıklık olmasın diye
silinebilir — ama Play'e yükleme yapılmadığından risk yok.

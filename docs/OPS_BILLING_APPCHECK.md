# Ops: Play Billing + App Check + izleme

Güncelleme: 2026-07-14 — CF deploy + App Check enforce (kısmi) + billing UI açık.

---

## 1) Play Billing

### Kod (repo) — YAPILDI
- `kBillingEnabled = **true**` (`billing_config.dart`)
- CF `verifyMembershipPurchase` **canlı** (`europe-west1`)
- Pro plan seçimi → Premium ekranı / Play IAP akışı

### Play Console — SİZDE (API ile abonelik ürünü açılamaz)
Paket: `com.sepettehizmet.app`

1. **Monetization → Subscriptions** → oluştur:
   - Product ID: `sepette_hizmet_pro_monthly` (zorunlu, kodla birebir)
   - İsteğe bağlı: `sepette_hizmet_pro_yearly`
2. İmzal AAB → **Internal testing** track
3. **License testing** hesapları ekle
4. **Users and permissions → Invite users**  
   Servis hesabı (CF runtime, deploy logundan):
   - `alljob1@appspot.gserviceaccount.com`
   - Roller: **View financial data** + **Manage orders and subscriptions**
5. Google Cloud: `androidpublisher.googleapis.com` etkinleştirildi (REST, 2026-07-14)

### Smoke
1. Free → Hizmetlerim kilitli  
2. Beta → Pro özellikler açık  
3. Play test satın alma → `isPremium` + `premiumExpiresAt`  
4. SA yetkisiz → net hata (istemci Pro vermez)

---

## 2) App Check — DURUM (2026-07-14)

| Servis | enforcementMode | Not |
|--------|-----------------|-----|
| **Firestore** | **UNENFORCED** (monitor) | 2026-07-14: admin web reCAPTCHA yokken ENFORCE paneli kilitledi → monitor’a alındı |
| **Storage** | **UNENFORCED** (monitor) | Aynı |
| **Auth (Identity Toolkit)** | **OFF** | Web girişi kilitlenmesin |

Yeniden ENFORCE: reCAPTCHA web key + admin `activate` sonrası  
`node tool/app_check_mode.js ENFORCED`

### Web
- `kAppCheckWebRecaptchaKey` hâlâ **boş** → web App Check pasif  
- Firestore enforce iken **web istekleri token olmadan reddedilir**  
  → admin web / Flutter web bozulabilir  
- Düzeltme: reCAPTCHA v3 site key → `backend_config.dart` + Console App Check web kaydı

### Debug Android
1. `flutter run` (debug) → logcat’te `DebugAppCheckProvider` token  
2. Console → App Check → Android uygulaması (**`com.sepettehizmet.app`** —
   marka iki kez değişti, paket adı ilk adında DEĞİL; `build.gradle.kts`
   `applicationId` tek doğruluk kaynağıdır) → Manage debug tokens → ekle  
3. Yoksa debug cihazda Firestore/Storage permission-denied  
4. **Paket adı değişince** eski token **geçmez** — yeni token şart  

> [!warning] `enforceAppCheck` callable'larda belirti farklıdır
> Firestore/Storage monitor modunda olduğu için debug token eksikken veri
> okuma ÇALIŞMAYA devam eder — sorun görünmez kalır. Ama `deleteAccount`
> gibi `enforceAppCheck: true` callable'lar **reddedilir**. Log:
> ```
> Failed to validate AppCheck token ... Decoding App Check token failed
> {"verifications":{"auth":"VALID","app":"INVALID"}}
> ```
> `auth: VALID` + `app: INVALID` = oturum sağlam, CİHAZ tanınmıyor.
> İstemci bunu `internal` olarak görür ve "Güvenlik doğrulaması geçilemedi"
> der (`firebase_auth_repository.dart` `_deleteErrorMessage`) — kod hatası
> sanılmasın. 2026-08-09'da "hesap silinmiyor" bulgusunun sebebi buydu.
5. **`Too many attempts`:** token reddi throttle. **30–60 dk bekle**, hot restart spam’ini kes, token’ı Console’a ekle, uygulamayı **tam kapat/aç**. Acil geliştirme:  
   `flutter run --dart-define=SKIP_APP_CHECK=true` (yalnız debug; CF `enforceAppCheck` callable’lar yine token ister)

### Auth enforce (ileride)
reCAPTCHA + debug token oturunca Identity Toolkit da ENFORCED yapılabilir.

---

## 3) Hâlâ Console / ops (kod dışı)

| Madde | Durum |
|--------|--------|
| Play abonelik ürünü + SA daveti | Manuel |
| Internal AAB yükleme | Manuel |
| reCAPTCHA web key | Manuel |
| Firestore **PITR** | **AÇIK** (2026-07-14 API; retention 7 gün) |
| CF hata alarmı (Monitoring) | Yok |
| notifications TTL | Yok |
| Haftalık Firestore export | Yok |
| **Bütçe uyarısı + otomatik kesme** | CF yazıldı, Console adımları bekliyor → `OPS_MALIYET_DUVARI.md` |
| SMS bölge kısıtı (+90) | Bekliyor → `OPS_MALIYET_DUVARI.md` §6 |

---

## 4) Deploy notu (bu ağ)

DNS IPv6 sorununda:

```bat
set NODE_OPTIONS=--dns-result-order=ipv4first
firebase deploy --only functions:verifyMembershipPurchase,firestore:rules --project alljob1
```

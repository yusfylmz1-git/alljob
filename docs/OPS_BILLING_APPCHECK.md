# Ops: Play Billing + App Check + izleme

Güncelleme: 2026-07-14 — CF deploy + App Check enforce (kısmi) + billing UI açık.

---

## 1) Play Billing

### Kod (repo) — YAPILDI
- `kBillingEnabled = **true**` (`billing_config.dart`)
- CF `verifyMembershipPurchase` **canlı** (`europe-west1`)
- Pro plan seçimi → Premium ekranı / Play IAP akışı

### Play Console — SİZDE (API ile abonelik ürünü açılamaz)
Paket: `com.ustacepte.usta_cepte`

1. **Monetization → Subscriptions** → oluştur:
   - Product ID: `usta_cepte_pro_monthly` (zorunlu, kodla birebir)
   - İsteğe bağlı: `usta_cepte_pro_yearly`
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
2. Console → App Check → Android → Manage debug tokens → ekle  
3. Yoksa debug cihazda Firestore/Storage permission-denied

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

---

## 4) Deploy notu (bu ağ)

DNS IPv6 sorununda:

```bat
set NODE_OPTIONS=--dns-result-order=ipv4first
firebase deploy --only functions:verifyMembershipPurchase,firestore:rules --project alljob1
```

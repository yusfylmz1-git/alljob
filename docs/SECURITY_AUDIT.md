# Güvenlik denetimi — Firestore / Storage / yüzey (2026-07-14)

Dürüst envanter. “0 risk” iddiası yok; mağaza + beta için **yeterli mi** ve
**kalan açıklar** net.

---

## Özet skor

| Katman | Değerlendirme |
|--------|----------------|
| Firestore kuralları | **Güçlü** — kimlik, premium, teklif, sohbet, şikayet iyi kilitli |
| Storage kuralları | **İyi** — uid klasör + raster MIME + track gizli |
| App Check | **Firestore/Storage ENFORCED** (Auth OFF; web reCAPTCHA yok) |
| Admin | **Claim + CF** — istemci self-admin yazamaz |
| Kalan riskler | Spam hızı, public read yüzeyi, web App Check, rules unit test yok |

---

## Firestore — iyi olanlar

1. **`isPremium` / `premiumExpiresAt` / (yeni) `premiumProductId`** istemci yazamaz  
2. **Puan / completedJobs** yalnız CF  
3. **Sohbet ID** deterministik; üçüncü kişi sohbet açamaz  
4. **Mesaj** sender = auth; engel kontrolü; soft-delete sınırlı  
5. **Teklif** `jobId__artisanId`; meslek+bölge eşleşmesi kuralda  
6. **İlan create** allowlist; offerCount=0; moderation seed yok  
7. **Reviews** chat/job kilidi; tek döküman / usta  
8. **Reports** create-only reporter; admin read; resolve alanları istemciye kapalı  
9. **admin\*** koleksiyonları write false; audit/roles CF  
10. **private/contact|push** — telefon public users’ta yok  
11. **membershipPurchases** tamamen kapalı (Admin SDK)

---

## Storage — iyi olanlar

1. Yazma: `folder in [profile,work,job,certificate,chat]` + **kendi uid**  
2. Görsel MIME allowlist (SVG/HTML yok) + 6 MB  
3. `track/{uid}/...` yalnız sahibi, 25 MB  
4. Eski 2 segment yola **yeni yazım kapalı**

---

## Kalan riskler (öncelik)

### P1 — Ürün / operasyon

| Risk | Etki | Mitigasyon / durum |
|------|------|---------------------|
| **Mesaj spam** (hız sınırı yok) | Maliyet, taciz | App Check kısmen; CF rate-limit / istemci debounce **yok** |
| **Web App Check yok** | Bot web’den Firestore (enforce → aslında **red**) | reCAPTCHA + register; admin web bozulabilir |
| **Public read** users/artisanProfiles/jobs/reviews/Storage | Bilinçli pazaryeri; scraping | Rate: App Check; ileride Cloud Armor / emülatör test |
| **Rules unit test yok** | Regresyon | `@firebase/rules-unit-testing` paketi önerilir |
| **Debug token sızıntısı** | Dev ortam spoof | Token’ları CI’ye koyma; periyodik sil |

### P2 — Orta

| Risk | Not |
|------|-----|
| `imageHandle` path doğrulaması zayıf | Mesajda string; başka uid path’i **okunur** (Storage public read) — gizli dosya yoksa düşük |
| `adminConfig` public read | Bayraklar public; gizli anahtar koyma |
| Bootstrap e-posta listesi client+CF | CF doğrular; client tek başına yetki vermez |
| Suspended okuma serbest | Bilinçli; create kilitli |
| Chat lastMessage spoof (üye) | Meta alanları üye güncelleyebilir — spam metin sohbet listesinde |

### P3 — Düşük / bilinçli

| Risk | Not |
|------|-----|
| iOS App Check Register yok | iOS build yoksa OK |
| Play Billing SA / ürün yok | Sahte Pro istemci yazamaz |
| Vision SafeSearch yok | UGC büyüyünce |
| PITR | **Açık** (7g) |

---

## Storage özel not

**Okuma herkese açık** = profil/iş/ilan foto linki bilen herkes indirir.  
Bu model: misafir Keşfet. **Gizli belge** (kimlik, sözleşme) Storage’a konmamalı; `certificate/` de public — hassas sertifika PDF’si için ileride private path gerekir.

---

## App Check

| Servis | Mode |
|--------|------|
| Firestore | ENFORCED |
| Storage | ENFORCED |
| Auth | OFF (web login kilitlenmesin) |

Debug: token Console allow-list. Release: Play Integrity.

---

## Admin paneli güvenlik

- Ayrı `main_admin.dart` / hosting — tüketici APK’da admin UI yok  
- `admin:true` claim; CF `assertCap`  
- Bootstrap e-posta sunucuda da var  

**Kalan:** admin web App Check; 2FA yok (Google hesabı güvenliği operatörde).

---

## Önerilen sıra (güvenlik)

1. ~~premiumProductId guard~~ (bu oturum rules)  
2. Rules emulator test iskeleti  
3. Mesaj create rate-limit (CF veya istemci debounce + anomaly)  
4. Web reCAPTCHA + App Check  
5. certificate private path (gerekirse)  

---

## Deploy

```bat
set NODE_OPTIONS=--dns-result-order=ipv4first
firebase deploy --only firestore:rules --project alljob1
```

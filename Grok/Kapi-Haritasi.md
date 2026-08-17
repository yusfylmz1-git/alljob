# Kapı haritası — ne neye bağlı

> Güncelleme: **2026-08-11** (Grok oturumu). Kod önceliklidir; bu not koddan türetilmiştir.

## Zihin modeli (3 katman)

| Katman | Soru | Alanlar |
|--------|------|---------|
| **A. Hesap** | Girişli mi? Askıda mı? | oturum, `suspended`, e-posta/telefon claim |
| **B. Yetenek** | Ne açtı? (kalıcı) | `hasArtisanProfile`, `hasShopProfile` |
| **C. Durum** | Şu an ne yapabilir? | `users.available`, `profile.isAvailable`, premium, eşleşme |

**YASAK (yetenek kapısında):** `user.isArtisan` / `activeMode`  
→ Legacy alan; switch kalktı. Yorum/UI etiket dışında kullanma.

---

## Bayraklar

| Alan | Koleksiyon | Anlam |
|------|------------|--------|
| `hasArtisanProfile` | `users` | Usta vitrini açıldı |
| `hasShopProfile` | `users` | Mağaza açıldı |
| `shopCategories` | `users` | Satış kategori kodları |
| `shopServiceAreas` | `users` | Mağaza hizmet bölgeleri |
| `available` | `users` | Ortak Müsait aynası (switch yazar) |
| `manualPause` / `alwaysAvailable` / schedule | `artisanProfiles` | Usta vitrin detayı |
| `ArtisanProfile.isAvailable` | hesaplanan | premium ∧ !pause ∧ (always ∨ takvim) |
| `emailVerified` | Auth | İlan create, chat create (rules) |
| `phoneVerified` | Auth/users | Mavi tik ön şartı |
| `isAdmin` / `role` | Auth claim | Admin paneli |

### Müsaitlik (mesaj için)

```
providerMayStartNewChat:
  (hasArtisanProfile VEYA hasShopProfile)
  VE users.available
  VE (profile yoksa OK; varsa profile.isAvailable)
```

Ortak fonksiyon:  
`lib/features/artisan/application/availability_gate.dart`  
→ `artisanAvailabilityAllowsNewChat` · `providerMayStartNewChat` · `providerIsUnavailableForNewChat`

---

## Rota kapıları (`app_router.dart` sırası)

1. Splash / yükleme  
2. Min sürüm → `/force-update`  
3. Bakım → `/maintenance` (superadmin hariç)  
4. Onboarding  
5. `suspended` → `/suspended`  
6. Oturum yok + korunan rota → `/login`  
7. Plan seçimi (ilk oturum)  
8. `/panel/*` → yalnız `hasArtisanProfile`

**Misafire açık örnek:** Keşfet listeleri, ürün detay okuma.  
**Oturum:** sohbet, profil, ilan detay/yazma, ürün new/mine/edit, shop setup.

---

## Keşfet

| Sekme | Kapı | Not |
|-------|------|-----|
| Ustalar | Yok | Listede müsait ustalar (arama filtresi) |
| İlanlar | giriş + **`hasArtisanProfile`** | Müsaitlik listeyi **kapatmaz** |
| Mağaza | Yok | Okuma serbest |

**Yeni İlan:** İlanlar sekmesi sağ üst — giriş yeterli.

---

## İlan ver vs mesaj at

### İlan vermek
Giriş · e-posta · askı değil · açık ≤5 (rules) · günlük ≤10 (CF).  
**Usta/mağaza/müsait şart değil.**

### Yeni mesaj (sağlayıcı)

| Giriş | Kapı |
|-------|------|
| İlan detayı | `availability_gate` + meslek/il + e-posta; talepte `hasShopProfile` |
| Usta profili | `availability_gate` |
| Public user | `availability_gate` |
| Ürün detayı | `availability_gate` (alıcı) + satıcı `available` |

**Mevcut sohbet:** müsaitlik bakmaz (`canSend` = kilit).

---

## Mağaza

| Eylem | Kapı |
|-------|------|
| Görmek | Yok |
| Mağaza aç | giriş + kategori + bölge → `hasShopProfile` |
| Ürün yayın | e-posta, askı, `productsEnabled`, form |
| Talep ver | iş ilanı gibi + `product_request` + `productCategoryCode` |
| Talebe mesaj | `hasShopProfile` + müsaitlik |

Kategoriler: `adminConfig/productCategories` (CF `adminUpdateProductCategories`); boşsa gömülü yedek.

---

## Premium

`premiumFreeDuringBeta` (şu an true) → herkes premium erişimli.  
`isAvailable` içinde premium yoksa false — beta bitince devreye girer.

---

## Sunucu vs istemci

| | |
|--|--|
| Rules / CF | Asıl güvenlik |
| İstemci kapıları | UX; atlanırsa rules reddeder ama delik kötü UX |

---

## Yeni özellik checklist

1. Görme mi yazma mı?  
2. `hasArtisanProfile` / `hasShopProfile`?  
3. Müsait / e-posta / askı?  
4. `startChat` → mutlaka `artisanAvailabilityAllowsNewChat`  
5. Mock paritesi  
6. `isArtisan` kullanma  

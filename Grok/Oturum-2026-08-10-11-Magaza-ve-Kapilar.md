# Oturum kaydı — Mağaza UX + kapı temizliği

| | |
|--|--|
| **Tarih** | 2026-08-10 → 2026-08-11 |
| **Ajan** | Grok (xAI) |
| **Dal** | `hemen-lazim` |
| **Amaç** | Mağaza/Keşfet sadeleştirme, admin kategori, müsaitlik deliği, kapı haritası |

> Diğer ajan: bu dosya + `Kapi-Haritasi.md` okumadan `isArtisan` ile kapı yazma.

---

## Ürün kararları (kullanıcı)

1. Keşfet Mağaza → **Ürünlerim+ kaldır** (ekleme Profil → Mağaza).  
2. Talep formu: **Ürün Talebi Oluştur** / **Ürünü Tanımlayın** + ProductCategory.  
3. İlanlar: **`hasArtisanProfile`** (aktif usta modu switch yok).  
4. Profil Mağaza: seçili kategoriler (+ bölgeler) küçük chip.  
5. Mağaza kurulum: hizmet bölgesi; usta bölgelerinden kopya.  
6. **+Yeni İlan** hero’dan → İlanlar sağ üst.  
7. Mağaza kategorileri **admin panelinden** yönetilsin.  
8. Müsait değilken ilan/talep mesajı **yok**; yönlendirme metni.  
9. Görünüm rengi: **tek** vurgu (müşteri/usta çift satır kalktı).

---

## Mimari kararlar

| Konu | Karar |
|------|--------|
| Rol switch | UI’da yok; yetenek = profil bayrakları |
| Mesaj müsaitlik | Ortak `availability_gate.dart`; `users.available` ∧ `profile.isAvailable` |
| `isArtisan` | Legacy only; yetenek kapısı değil |
| Ürün kategorisi (talep) | `jobs.category=product_request` + `productCategoryCode` |
| Admin kategoriler | `adminConfig/productCategories` + CF `adminUpdateProductCategories` |
| Vurgu rengi | `accentIdProvider` / `accent_app_v1` (+ eski anahtar göçü) |

---

## Önemli dosyalar (bu tur)

### Yeni
- `lib/features/products/presentation/shop_setup_screen.dart`
- `lib/features/products/data/product_category_providers.dart`
- `lib/features/admin/presentation/admin_product_categories_section.dart`
- `Grok/Kapi-Haritasi.md`, `Grok/00-OKU-ONCE.md`, bu dosya

### Dokunulan (özet)
- `availability_gate.dart` — isArtisan deliği kapatıldı  
- `job_detail_screen.dart` — müsait UI + hasArtisan/hasShop  
- `customer_dashboard_screen.dart` — İlanlar kapısı, Yeni İlan yeri  
- `profile_screen.dart` — Usta\|Mağaza sekmeleri, müsait sync  
- `product_category.dart` + catalog provider  
- `app_user.dart` — `shopServiceAreas`  
- `job.dart` — `productCategoryCode`  
- `create_job_screen.dart` — ürün talebi dili + ProductCategory  
- `admin_settings` + CF `adminUpdateProductCategories`  
- `firestore.rules` — job create keys + productCategoryCode  
- `accent_state.dart` / `app.dart` / drawer Görünüm — tek renk  
- Menü, chat unread “other mode”, role_bottom_bar, artisan profile edit  

### Test
- `availability_gate_test`, `magaza_mimari_uyum_test`, `drawer_menu_items_test`,  
  `test_bulgulari_2026_08_09/10`, `theme_mode_test` güncellendi.

---

## Deploy / operasyon (henüz zorunlu yapılmadıysa)

```bash
# Ürün talebi productCategoryCode + (zaten public read adminConfig)
firebase deploy --only firestore:rules

# Admin kategori kaydı
firebase deploy --only functions:adminUpdateProductCategories
```

Admin: **Sistem ayarları → Mağaza → Ürün kategorileri** (`config.manage`).

---

## Bilinen tuzaklar (bu turdan)

1. **`isArtisan` ile mesaj muafiyeti** → müsait kapalıyken yazılabiliyordu. Düzeltildi.  
2. **`users.available` vs `profile.isAvailable` desenkron** → kapı ikisini birden ister; switch ikisini yazar.  
3. **Vault `Mevcut-Akislar`** hâlâ “usta modu” diyebilir → `Grok/Kapi-Haritasi.md` öncelikli.  
4. Mevcut sohbetler müsaitlikle **kesilmez** (bilinçli).

---

## Bilinçli yapılmayanlar

- `activeMode` alanını Firestore’dan silmek (legacy / setActiveMode kurulum iptali)  
- CF digest’i productCategory’ye göre daraltmak  
- Tüm vault notlarını bu oturumda yeniden yazmak  

---

## Sonraki ajan için minimum okuma

1. `Grok/00-OKU-ONCE.md`  
2. `Grok/Kapi-Haritasi.md`  
3. Bu dosya  
4. İlgili kod (grep `isArtisan` lib altında yalnız model/yorum kalmalı)  

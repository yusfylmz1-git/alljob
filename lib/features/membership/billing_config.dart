/// Play Console abonelik ürün kimlikleri.
///
/// ## Canlıya alma checklist
/// 1. Play Console → Monetization → Subscriptions:
///    - `usta_cepte_pro_monthly` (ör. 199,99 TRY / ay)
///    - isteğe bağlı `usta_cepte_pro_yearly`
/// 2. Uygulama imzalı AAB → internal testing track
/// 3. Lisans test hesapları ekle
/// 4. Cloud Functions SA → Play Console Users and permissions
///    (View financial data + Manage orders and subscriptions)
/// 5. `firebase deploy --only functions:verifyMembershipPurchase --project alljob1`
/// 6. [kBillingEnabled] → `true`
///
/// Doğrulama: CF `verifyMembershipPurchase` (Play Developer API) →
/// yalnız sunucu `artisanProfiles.isPremium` / `premiumExpiresAt` yazar.
library;

/// false iken satın al butonu “yakında” gösterir; true iken IAP dener.
///
/// true: Play abone ol UI + IAP akışı açık.
/// Satın alma başarısı hâlâ CF `verifyMembershipPurchase` + Play Console
/// ürünü + SA yetkisine bağlı (yetki yoksa net hata; istemci Pro vermez).
const bool kBillingEnabled = true;

/// Aylık Pro abonelik product id (Play Console ile birebir aynı olmalı).
///
/// ⚠️ Marka "Sepette Hizmet"e geçti ama bu kimlikler BİLEREK eski adında
/// bırakıldı: Play Console'da ürün kimliği oluşturulduktan sonra ASLA
/// değiştirilemez ve kullanıcıya görünmez. Ürünler Console'da HENÜZ
/// oluşturulmadıysa (checklist adım 1) burada `sepette_hizmet_pro_monthly`
/// olarak yenilemek serbesttir — ama Console'daki adla birebir aynı olmalı.
const String kProMonthlyProductId = 'usta_cepte_pro_monthly';

/// Yıllık (Console'da yoksa query "not found" loglar; zarar vermez).
const String kProYearlyProductId = 'usta_cepte_pro_yearly';

Set<String> get kKnownSubscriptionIds => {
      kProMonthlyProductId,
      if (kProYearlyProductId.isNotEmpty) kProYearlyProductId,
    };

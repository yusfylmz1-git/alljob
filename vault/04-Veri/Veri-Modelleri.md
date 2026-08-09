# Veri Modelleri

`lib/data/models/` — 18 dosya, 20 sınıf, 20 enum. Özelliğe değil **alana** ait
oldukları için `features/` altında değil burada.

## Ortak sözleşme

Her model şu deseni izler:

```dart
class X {
  const X({required this.a, this.b});
  factory X.fromMap(String id, Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  X copyWith({...});
}

enum XStatus {
  a, b;
  String get apiValue => name;              // Firestore'a yazılan
  static XStatus fromString(String? v) =>   // eksik/bilinmeyen → varsayılan
      values.firstWhere((e) => e.name == v, orElse: () => a);
  String get labelTR => switch (this) {...}; // kullanıcıya görünen
}
```

> [!important] Üç kural
> 1. **`apiValue` = `name`.** Firestore'a enum'un Dart adı yazılır. Enum
>    sabitini yeniden adlandırmak **veri göçüdür** — mevcut dokümanlar eski
>    adı taşır.
> 2. **`fromString` asla patlamaz.** Bilinmeyen/eksik değer varsayılana düşer.
>    Eski dokümanlar yeni kodu çökertmesin.
> 3. **Türkçe metin modelde.** `labelTR` UI'da değil enum'da durur — tek yer,
>    tutarlı dil.

## Model kataloğu

### Çekirdek
| Model | Dosya | Not |
|---|---|---|
| `Job` | `job.dart` (571 st) | En büyük model → [[Is-Akisi-Durum-Makinesi]] |
| `Offer` | `offer.dart` | `idFor(jobId, artisanId)` deterministik kimlik |
| `ChatThread` · `ChatMessage` · `ChatUnreadMeta` | `chat.dart` | → [[Sohbet-Mimarisi]] |
| `Review` | `review.dart` | → [[Degerlendirme-Sistemi]] |
| `AppUser` | `app_user.dart` | Oturum kullanıcısı; `suspended` claim aynası |
| `ArtisanProfile` | `artisan_profile.dart` (436 st) | Usta vitrini |

### Enum'lar — iş kuralı taşıyanlar
| Enum | Değerler |
|---|---|
| `JobStatus` | open, cancelled, expired *(2026-08-09'da 8'den indi)* |
| `JobPriceType` | fixed, inspection ("Keşif Gerekli") |
| `JobDuration` | day1, day3, day7 — `expiresAt` hesabı |
| `JobDisputeParty` · `JobDisputeReason` · `JobCancelReason` | Anlaşmazlık/iptal |
| `OfferStatus` | pending, accepted, rejected, withdrawn |
| `ChatLockReason` | otherArtisanSelected, completed, archived |
| `ReviewDirection` | customerToArtisan (c2a), artisanToCustomer (a2c) |
| `UserRole` | müşteri / usta — tek hesap iki rol |
| `AvailabilityMode` | always, weekly, paused |

### Yan modüller
| Model | Dosya |
|---|---|
| `Product` + 3 enum | `product.dart` (473 st) |
| `StaffWorkerListing` · `StaffNeed` · `StaffRateType` | `staffing.dart` |
| `TrackItem` + 4 enum + 3 yardımcı | `track_item.dart` (330 st) |
| `SocialLinks` | `social_links.dart` |
| `DayAvailability` · `WeeklySchedule` | `availability.dart` |
| `Province` · `District` · `Neighborhood` · `ServiceArea` | `geo_models.dart` |
| `Favorite` · `BlockedUser` · `AppNotification` · `Report` · `Profession` | tek sınıflık dosyalar |

## Zengin model yaklaşımı

Modeller anemik veri torbası değildir — iş kuralı **modelde** durur:

```dart
// ChatThread
bool canSend(String uid) { ... }        // yazma izni
bool get isJobChat => ...               // ilan bazlı mı
String otherUid(String myUid) => ...    // karşı taraf

// JobStatus
bool get isInWork => ...
bool get canDispute => ...
int? get simpleStepIndex => ...

// ChatMessage
bool get isRedacted => deleted || moderationHidden;  // TEK kapı
```

> [!tip] Neden önemli?
> `isRedacted` gibi birleşik getter'lar, iki ayrı koşulu her çağrı yerinde
> tekrar yazma riskini kaldırır. Biri unutulursa silinen mesajın içeriği
> sızar. Yeni bir "gösterilir mi?" koşulu eklerken **modeldeki getter'ı**
> güncelle, çağrı yerlerini değil.

## Geriye uyum kalıpları

| Durum | Çözüm |
|---|---|
| Alan sonradan eklendi | `map['x'] == true` → eksikse `false` |
| Enum'a değer eklendi | `fromString` varsayılana düşer |
| Kimlik şeması değişti | Eski biçim çalışmaya devam eder (`chatId`'de `jobId` opsiyonel) |
| Yön alanı eklendi | Eksik = eski kayıt = `c2a` |

## Meslekler — `assets/data/professions.json`

144 meslek, dört alan: `code` · `nameTR` · `icon` · `category`.

> [!warning] İKİ kaynak senkron tutulmalı
> Aynı liste `lib/data/local/mock_database.dart` içindeki `kProfessionNames`
> haritasında da durur (kart/rozet gösterimi oradan okur). JSON'da adı
> değiştirip haritayı unutmak eski adın ekranda kalmasına yol açar.
> Regresyon: `test/meslek_kategori_test.dart` ikisini karşılaştırır.

**`code` DEĞİŞTİRİLEMEZ** — `artisanProfiles.professions` ve `jobs.category`
bu kodu taşır; değiştirmek veri göçüdür. Ad serbestçe düzeltilebilir.

### Kategoriler (2026-08-10)

Liste düzdü ve inşaat mesleklerine göre sıralıydı; avukat/mimar/muhasebe
sona düşüp görünmez kalıyordu — kullanıcı "avukat yok" sandı, oysa
`lawyer_consult` vardı. Çözüm iki parçalı:

1. **Gruplama.** `category` alanı + `ProfessionCategory` (kod, ad, sıra).
   `getProfessions()` listeyi kategori sırasına göre döndürür; seçim
   ekranları grup başlığı basar. Kategori içinde JSON sırası korunur —
   sık kullanılan meslekler elle öne konmuştur, alfabetik sıralama bunu
   bozardı.
2. **Adlandırma.** Kullanıcının YAZACAĞI kelime adda geçmeli:
   "Hukuki Danışmanlık" → **"Avukat / Hukuki Danışmanlık"**. Kod aynı kaldı.

Gruplama `SearchableSelectField.groupLabel` ile opsiyoneldir (il/ilçe gibi
kısa listeler etkilenmez). **Arama yazılırken gruplama kapanır** — sonuç
zaten daralmıştır, başlık gürültü olur.

> [!note] Yeni meslek eklerken
> 1. JSON'a `category` ile ekle 2. `kProfessionNames`e ekle
> 3. Aynı kategorideki kayıtların YANINA koy (gruplar ardışık olmalı)
> 4. Testi çalıştır — eksik senkron/kategori hemen düşer.

---
İlgili: [[Firestore-Semasi]] · [[Is-Akisi-Durum-Makinesi]] · [[Repository-Deseni]]

# Repository Deseni

Her veri kaynağı **arayüz** ardındadır. Arayüzün iki uygulaması olabilir:
gerçek Firebase ve bellek içi Mock.

```
abstract interface class XRepository     ← sözleşme
├── FirebaseXRepository                  ← Firestore/Auth/Storage
└── MockXRepository                      ← bellek içi (MockDatabase üstünde)
```

Seçim tek bir sabitle yapılır:

```dart
// lib/core/config/backend_config.dart
const bool useFirebaseBackend = true;   // şu an CANLI Firebase
const bool useFirebaseStorage = true;   // Blaze planı açık, gerçek Storage
```

Provider bu anahtara bakar:

```dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (useFirebaseBackend) return FirebaseChatRepository();
  final repo = MockChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
```

## Neden böyle?

Proje Firebase'siz başladı ve mock'larla geliştirildi ("Firebase-sonra"
yaklaşımı). Bu bugün üç şey kazandırıyor:

1. **Testler Firebase'e hiç dokunmaz.** 319 test Mock üzerinden koşar; emulator,
   ağ, kimlik doğrulama gerekmez. → [[Test-Stratejisi]]
2. **UI geliştirmesi backend'i beklemez.**
3. **Sözleşme belgeli.** Arayüzdeki doc-comment'ler tek gerçek kaynaktır —
   uygulamalar ona uymak zorundadır.

> [!warning] Mock paritesi bir kuraldır, süs değil
> Arayüze yeni metot eklersen **her iki uygulamayı da** yazmalısın. Mock'u
> "sonra yaparım" diye boş bırakmak testleri sessizce yanıltır: test geçer,
> canlı çöker.
>
> Mock, kuralların davranışını da taklit etmelidir. Örnek: `MockChatRepository`
> içinde usta mesajı `customerStarted` bayrağını açmaz — çünkü Firestore kuralı
> da açmaz. Parite bozulursa test yanlış güven verir.

## 29 repository arayüzü

### Çekirdek alan
| Arayüz | Dosya | Uygulamalar |
|---|---|---|
| `AuthRepository` | `auth/data/auth_repository.dart` | Firebase + Mock |
| `JobRepository` | `jobs/data/job_repository.dart` | Firebase + Mock |
| `OfferRepository` | `jobs/data/offer_repository.dart` | Firebase + Mock |
| `ChatRepository` | `chat/data/chat_repository.dart` | Firebase + Mock¹ |
| `ArtisanRepository` | `artisan/data/artisan_repository.dart` | Firebase + Mock |
| `ReviewRepository` | `review/data/review_repository.dart` | Firebase |
| `ProductRepository` | `products/data/product_repository.dart` | Firebase + Mock |
| `FavoriteRepository` | `favorites/data/favorite_repository.dart` | Firebase + Mock |
| `StaffingRepository` | `staffing/data/staffing_repository.dart` | Firebase |
| `StorageRepository` | `storage/storage_repository.dart` | Firebase |
| `MyProfileRepository` | `artisan/data/my_profile_repository.dart` | Firebase |
| `PhoneVerificationRepository` | `auth/data/phone_verification_repository.dart` | Firebase |
| `BlockRepository` · `ReportRepository` | `safety/data/` | Firebase |
| `NotificationRepository` · `NotificationPrefsRepository` | `notifications/data/` | Firebase |
| `TrackingRepository` · `TrackBackupRepository` · `TrackNotificationService` | `tracking/data/` | Firebase + Mock |

¹ `MockChatRepository` istisnai olarak arayüzle **aynı dosyada** yaşar
(`chat_repository.dart`), ayrı dosyada değil.

### Admin alanı (10 arayüz, hepsi yalnız Firebase)
`admin/data/` altında: `AdminUserRepository`, `AdminJobRepository`,
`AdminArtisanRepository`, `AdminReportRepository`, `AdminReviewRepository`,
`AdminDisputeRepository`, `AdminInviteRepository`, `AdminAuditRepository`,
`AdminStatsRepository`, `AdminRuntimeConfigRepository`.

Admin'in mock'u yoktur — panel yalnız canlı veriyle anlamlıdır ve testleri
yoktur. → [[Admin-Paneli]]

## Firebase uygulamalarında tekrar eden desenler

**Bellek önbelleği.** `FirebaseChatRepository._threads` gibi haritalar snapshot
verisini tutar; `getThread()` yalnız buna bakar. Bu yüzden liste ekranı hiç
açılmadıysa önbellek boştur — derin bağlantıda `watchThread()` (canlı akış)
kullan, `getThread()` değil.

**Tek uçuş (single-flight).** `_pendingChatDoc` haritası aynı `chatId` için
eşzamanlı `ensureChatDoc` çağrılarını tek Future'da birleştirir; yarış hâlinde
çift doküman yazımını engeller.

**Denormalizasyon.** Kural motoru sorgu yapamadığı için bazı gerçekler kopyalanır
(`customerStarted`, `jobTitle`, `offerCount`). → [[Firestore-Semasi]]

**`permission-denied` yumuşatma.** `get()` reddedilirse bazı yollar doğrudan
`create` dener — kural "yoksa oluşturulabilir" diyor olabilir.

---
İlgili: [[Durum-Yonetimi]] · [[Firestore-Semasi]] · [[Test-Stratejisi]]

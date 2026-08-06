# Durum Yönetimi (Riverpod)

`flutter_riverpod` kullanılır. Provider'lar ait oldukları özelliğin
`data/<ad>_providers.dart` dosyasında toplanır; kimlik doğrulama istisnaen
`auth/application/auth_controller.dart` içindedir.

## Provider katmanları

```
repositoryProvider     → Provider<XRepository>      (backend anahtarına bakar)
      ↓
veri provider'ı        → StreamProvider / FutureProvider  (canlı okuma)
      ↓
türetilmiş provider    → Provider<...>              (sayaç, filtre, hesap)
      ↓
controller             → AsyncNotifierProvider      (yazma işlemleri)
```

## Temel provider'lar — ezberlenmeye değer

| Provider | Tip | Verdiği |
|---|---|---|
| `currentUserProvider` | `Provider<AppUser?>` | Oturumdaki kullanıcı. **En sık kullanılan.** |
| `authStateProvider` | `StreamProvider<AppUser?>` | Canlı oturum akışı |
| `authControllerProvider` | `AsyncNotifierProvider` | Giriş / çıkış / kayıt |
| `appRuntimeConfigProvider` | `StreamProvider` | Admin'in canlı ayarları (bakım modu, min sürüm) |

### İlan
`jobRepositoryProvider` · `offerRepositoryProvider` · `openJobsProvider` ·
`quickSupportJobsProvider` · `myJobsProvider(uid)` · `jobProvider(jobId)` ·
`jobByChatIdProvider(chatId)` · `offersForJobProvider(jobId)` ·
`myOffersProvider(uid)` · `assignedJobsProvider(uid)` · `nearbyJobsProvider` ·
`artisanIsAvailableProvider`

> [!warning] `jobByChatIdProvider` yanıltıcıdır
> İlanın `chatId` **alanını** sorgular; o alan yalnız `selectOffer` içinde
> yazılır. İlan bazlı sohbette elinde zaten `thread.jobId` vardır — **onu**
> `jobProvider` ile kullan. Bu ayrım bir hataya yol açtı → [[Bilinen-Tuzaklar]]

### Sohbet
`chatRepositoryProvider` · `chatThreadProvider(chatId)` · `myThreadsProvider` ·
`messagesProvider(chatId)` · `chatUnreadMetaProvider`

> [!note] Rozet neden ayrı provider?
> Alt bar okunmamış rozeti `chatUnreadMetaProvider` kullanır —
> `users/{uid}/private/chatMeta` tek dokümanını dinler. `myThreadsProvider`
> (tüm sohbet listesi) global tutulsaydı her kullanıcı sürekli tüm thread
> snapshot'ını çekerdi: maliyet ve pil. → [[Firestore-Semasi]]

### Admin
`admin_providers.dart` içinde ~40 provider. Deseni: her alan için
`repositoryProvider` + `StreamProvider` + `filterProvider` (StateProvider) +
`controllerProvider`. → [[Admin-Paneli]]

## Sözleşmeler

**`autoDispose` ne zaman?** Ekran kapanınca dinleyici bırakılmalıysa. Örnek:
`messagesProvider` — sohbetten çıkınca Firestore listener'ı kapansın.
Uygulama boyu yaşaması gereken (`chatRepositoryProvider`) **autoDispose olmaz**;
oturum değişiminde repository'nin ölmesi önbelleği ve tek-uçuş kilidini bozar.

**`family` ne zaman?** Parametreli okuma (`jobProvider(jobId)`). Parametre
mutlaka değer eşitliği olan bir tip olmalı (String, int) — nesne verme.

**Kural ispatı için filtre.** Bazı sorgular güvenlik kuralının istediği alanı
zorunlu taşır:

```dart
// Kural `customerId == auth.uid` ister; filtresiz sorgu KOMPLE reddedilir.
.watchOffersForJob(jobId: jobId, customerId: uid)
```

Bir sorgudan sebepsiz `permission-denied` alıyorsan önce bu filtreyi ara.
→ [[Guvenlik-Kurallari]]

**Yazma sonrası tazeleme.** Yazma işleminden sonra ilgili provider'ı elle
düşür:

```dart
ref.invalidate(artisanDetailProvider(uid));
ref.invalidate(artisanReviewsProvider(uid));
```

**`ref.read` yarışı.** Stream ilk değerini yaymadan `ref.read(...).valueOrNull`
`null` döner. Değere ihtiyaç varsa `await ref.read(xProvider.future)` kullan.
Bu tam olarak değerlendirme ekranını kıran hataydı → [[Bilinen-Tuzaklar]]

---
İlgili: [[Repository-Deseni]] · [[Katman-Mimarisi]] · [[Bilinen-Tuzaklar]]

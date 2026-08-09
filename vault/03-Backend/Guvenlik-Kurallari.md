# Güvenlik Kuralları

**Dosyalar:** `firestore.rules` (1.278 satır) · `storage.rules` (63 satır)
**Deploy:** `firebase deploy --only firestore:rules --project alljob1`

## Kimlik: custom claim'ler

Yetki Firestore'dan değil **Auth token'ından** okunur. Claim'leri yalnız CF yazar.

| Claim | Anlamı | Yazan |
|---|---|---|
| `admin: true` | Yönetici | `adminSetRole` |
| `role: 'superadmin'` | Süper yönetici | `adminSetRole` |
| `suspended: true` | Askıya alınmış | `adminSetUserSuspended` |
| `email_verified` | Firebase Auth'un kendi alanı | Firebase |

```javascript
function isAdmin()      { return isSignedIn() && request.auth.token.get('admin', false) == true; }
function isSuperAdmin() { return isAdmin() && request.auth.token.get('role', '') == 'superadmin'; }
function isSuspended()  { return isSignedIn() && request.auth.token.get('suspended', false) == true; }
```

> [!danger] `.get(alan, varsayılan)` ZORUNLUDUR
> `request.auth.token.suspended` doğrudan okunursa, claim **yokken** Rules
> "Property suspended is undefined" hatası verir ve **tüm create kuralları
> reddedilir** — ilan, teklif, mesaj, yorum hepsi çöker.
>
> Bu tuzağa bir kez düşüldü. Yeni claim eklerken daima `.get()` kullan.

**Askı politikası:** askıya alınan hesap yeni içerik **oluşturamaz**; okuma
serbesttir.

**E-posta doğrulaması:** ilan açmak ve ilan üzerinden usta ile iletişim
(teklif/ilgi) için zorunlu.

## Temel ilke: alan bazlı okuma yoktur

> [!danger] Firestore alan-bazlı okuma kısıtlaması YAPAMAZ
> Bir dokümana okuma izni varsa **tüm doküman** döner. "Şu alanı gizle"
> diye bir şey yoktur.
>
> Sonucu: `users/{uid}` herkese açık okunabilir (profil adı/foto), bu yüzden
> **hassas veri oraya konulamaz**. Telefon numarası vb. yalnız sahibinin
> okuduğu `users/{uid}/private/*` alt koleksiyonuna yazılır. Kural, `owner`
> dahil kimsenin ana dokümana `phoneNumber` yazmasına izin vermez.

Yeni alan eklerken sor: *"bu alanı tanımadığım biri görse sorun olur mu?"*
Evetse `private/` altına.

## Koleksiyon yetki tablosu

| Koleksiyon | Okuma | Yazma |
|---|---|---|
| `users/{uid}` | Herkes | Yalnız sahibi (kısıtlı alanlar) |
| `users/{uid}/private/*` | Yalnız sahibi | Sahibi + CF |
| `users/{uid}/blocked/*` | Sahibi | Sahibi |
| `users/{uid}/notifications/*` | Sahibi | CF |
| `artisanProfiles/{uid}` | Herkes | Sahibi (puan alanları CF'ye kapalı) |
| `chats/{chatId}` | Üyeler | Üyeler (allowlist) |
| `chats/{id}/messages/*` | Üyeler | Gönderen (koşullu) |
| `jobs/{jobId}` | Herkes | Sahibi (kapatma **veya** açık ilanın içeriği) |
| `reviews/{reviewId}` | Herkes (c2a) | Yazan taraf |
| `reports/*` | Admin | Oluşturan + admin |
| `admin*` (7 koleksiyon) | Admin | CF / superadmin |
| `products` · `staffWorkers` · `staffNeeds` · `favorites` | Karma | Sahibi |

## Sohbet kuralları — en karmaşık bölüm

### Üyelik
İki biçim desteklenir: `members` (map) veya `participants` (list). Eski
kayıtlarla uyum için `.keys().hasAny` + tip kontrolü yapılır.

### Kimlik doğrulama (spam koruması S-CHAT-1)
```
chatId == 'chat_' + customerUid + '__' + artisanUid          → genel
chatId matches '^chat_' + customerUid + '__' + artisanUid + '__.+$'  → ilan bazlı
```
Rastgele kimlikle üçüncü kişiye sohbet açılamaz.

### Update allowlist
```javascript
.hasOnly(['lastMessage','lastMessageSenderUid','updatedAt','lastRead',
          'clearedAt','members','archivedBy','pinnedBy','customerStarted'])
```

> [!important] Listede OLMAYANLAR bilinçlidir
> `lockedAt`, `lockReason`, `jobId`, `jobTitle` — istemci **hiç** yazamaz.
> Kilidi yalnız CF koyar; açık olsaydı seçilmeyen usta kendi kilidini
> kaldırırdı. → [[Sohbet-Mimarisi]]

### `customerStarted` kapısı
```javascript
request.auth.uid == resource.data.customerUid
  && request.resource.data.customerStarted == true
```
Yalnız **müşteri**, yalnız **false→true**. Usta kendi yazma iznini açamaz;
müşteri de geri alıp ustayı susturamaz. Create'te `false` olmak zorundadır.

### Mesaj yazma (`senderMayWrite`)
```javascript
chat.lockedAt == null
  && (chat.customerUid == auth.uid || chat.customerStarted == true)
```
İstemcideki `ChatThread.canSend()` ile **aynı mantık**. İkisi birlikte
değişmelidir.

### Mesaj payload allowlist
```javascript
.hasOnly(['senderUid','text','imageHandle','createdAt','deleted'])
```
`type` listede **yok** → sistem mesajını yalnız CF yazar (sahte "Usta seçildi"
bildirimi üretilemez). `moderationHidden` de yok → kullanıcı kendini
"kaldırılmamış" ilan edemez. Metin ≤ 4000 karakter.

### Engelleme
`recipientBlockedSender()` — alıcı göndereni engellediyse mesaj oluşturulamaz.
`users/{other}/blocked/{me}` varlığına bakar.

## Kişisel bayraklar

`personalFlagsOk(field)` — kullanıcı **yalnız kendi anahtarını** değiştirir.
Tek istisna `unarchiveForOtherOk()`: mesaj gönderen taraf alıcının arşivini
`false` yapabilir (yeni mesaj sohbeti arşivden çıkarır), ama asla `true`
yapamaz.

## Sorgu ispatı — sık karşılaşılan hata

Bazı kurallar sorgunun **filtre taşımasını** zorunlu kılar:

```dart
// Filtresiz sorgu KOMPLE reddedilir:
.where('jobId', isEqualTo: jobId)
.where('customerId', isEqualTo: uid)   // ← kural ispatı, opsiyonel değil
```

> [!tip] `permission-denied` aldığında
> 1. Sorgu kuralın istediği filtreyi taşıyor mu?
> 2. Yazılan alan update allowlist'inde mi?
> 3. `email_verified` / `suspended` claim'i durumu ne?
> 4. Doküman `get()` ile okunabiliyor mu (yoksa `exists()` hatası olabilir)?

## Doküman yokken `get()`

```javascript
allow get: if isSignedIn() && (resource == null || isMember(resource.data));
```
`resource == null` dalı olmasaydı `startChat`'in var-mı kontrolü
`permission-denied` alır ve sohbet hiç oluşmazdı.

Alt koleksiyon kurallarında da `exists(path)` önce kontrol edilir — yoksa
`get().data` kural motorunu hataya düşürür ve okunabilir ret yerine
`permission-denied` döner.

## Storage

`storage.rules` (63 satır) — profil foto, ilan foto, ürün foto, sohbet foto.
Boyut ve içerik tipi sınırlı; yazma sahibine kapalı yollarda CF'ye bırakılmış.

---
İlgili: [[Cloud-Functions-Haritasi]] · [[Sohbet-Mimarisi]] · [[Firestore-Semasi]] · [[Bilinen-Tuzaklar]]

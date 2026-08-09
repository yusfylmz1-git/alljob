# Sohbet Mimarisi

## Kişi bazlı kimlik — çift başına TEK kutu

```
chat_{uidA}__{uidB}     → uidA < uidB (ALFABETİK SIRALI)
```

Üretici: `FirebaseChatRepository.chatIdFor(customerUid, artisanUid)`

**Kişi başına tek kutu.** İlan kimliğe GİRMEZ; `jobId`/`jobTitle` yalnızca
sohbetin bağlamı olarak alan şeklinde yazılır. Kimlik deterministiktir —
rastgele kimlikle üçüncü kişiye sohbet açılamaz (S-CHAT-1).

> [!warning] Kimlik SIRALIDIR — ilk parça "müşteri" DEĞİLDİR
> 2026-08-10'a kadar kimlik `chat_{müşteri}__{usta}` idi, yani **role**
> bağlıydı. Rol ise giriş noktasına göre değişiyor: ilan detayında "ilanı
> veren = müşteri", profil ekranlarında "ben = müşteri". Aynı iki kişi farklı
> kapılardan yazınca `chat_A__B` **ve** `chat_B__A` doğuyor, tek kutu
> garantisi çöküyordu (kullanıcı bulgusu: "1 kişi için 2 farklı sohbet").
>
> Uid'ler artık sıralanır → çift başına kimlik **matematiksel olarak tektir**.
> Rol bilgisi kaybolmaz, `customerUid`/`artisanUid` ALANLARI olarak durur.
> Kimlikten rol türetme (`_uidsFromChatId(...).$2 == usta`) artık YANLIŞTIR.

> [!note] Roller ilk açılışta donar
> Aynı kutuya ters yönden girilebildiği için `startChat` mevcut sohbetin
> kimlik alanlarını **yeniden yazmaz** (hem önbellekte hem sunucuda). Yoksa
> taraflar yer değiştirir, "sohbeti müşteri mi başlattı" ve okundu/rozet
> hesapları bozulurdu. Kurallar da kimlik alanlarının değişmesini reddeder.

Eski kimlikli sohbetler (rol sıralı, ya da 3 parçalı ilan bazlı) Firestore'da
durmaya devam eder ve listede görünür — `watchThreads` üyelikle sorgular,
kimliği ayrıştırmaz.

## Yazma izni — tek kapı: kilit

`ChatThread.canSend(uid)` (`lib/data/models/chat.dart`):

```dart
bool canSend(String uid) => !isLocked;   // kilitliyse kimse yazamaz
```

Sunucu kuralı (`senderMayWrite`) aynı mantığı bağımsız uygular:
`chat.get('lockedAt', null) == null`. İkisi birlikte değişmelidir.
→ [[Guvenlik-Kurallari]]

> [!note] Eskiden üç kapı vardı
> "Müşteri her zaman / usta ancak `customerStarted` ise" kuralı kalktı:
> sohbet iki yönlü serbesttir. `customerStarted` alanı hâlâ yazılır ve
> aşağıdaki nedenlerle durur, ama artık YAZMA İZNİ vermez.

### `customerStarted` — iletişimi müşteri başlatır

Usta ilana ilgi bildirir; ilk mesajı **müşteri** yazar. Kural motoru "bu
sohbette müşteri mesajı var mı?" diye sorgulayamadığı için bu gerçek chat
dokümanında **denormalize** tutulur.

Bayrağı yazan iki yol:
1. İlk müşteri mesajı — `sendMessage` içinde otomatik
2. `markCustomerStarted(chatId)` — müşteri işi verirken (`selectArtisanForJob`)

> [!warning] 2. yol neden var?
> Müşteri sohbete hiç yazmadan doğrudan "Bu Ustayı Seç" diyebilir. O durumda
> bayrak `false` kalıyordu ve seçilen usta — iş kendisine verilmiş olmasına
> rağmen — kendi işinin sohbetinde yazamıyordu. Kullanıcı bunu "yazma izniniz
> yok" diye görüyordu. İşi vermek, iletişimi başlatmaktan güçlü bir niyettir.
> → [[Bilinen-Tuzaklar]]

Kural bu yazımı **yalnız müşteriye** ve **yalnız `false→true`** yönünde açar.
Usta kendi iznini açamaz; müşteri de geri alıp ustayı susturamaz.

### Kilit (`lockedAt` + `lockReason`)

```dart
enum ChatLockReason { otherArtisanSelected, completed, archived }
```

| Sebep | Ne zaman | Yazan |
|---|---|---|
| `otherArtisanSelected` | Müşteri başka ustayı seçti | CF `lockOtherJobChats` |
| `archived` | Tamamlanmadan 7 gün sonra | CF `archiveCompletedChats` |
| `completed` | *Tanımlı ama şu an kullanılmıyor* | — |

> [!important] Kilidi YALNIZ Cloud Function koyar
> `lockedAt` / `lockReason` istemci yazımına tamamen kapalıdır
> (`chatUpdateKeysOk` allowlist'inde yoktur). Açık olsaydı seçilmeyen usta
> kendi kilidini kaldırıp işi alan ustanın müşterisine yazmaya devam ederdi.
>
> Seçim iptal edilirse `unlockJobChats` kilitleri kaldırır.

> [!note] İş tamamlanınca sohbet kilitlenmez
> Bilinçli karar: taraflar teslim sonrası konuşabilmeli. Kapanma 7 gün sonra
> arşivle olur. `completed` kilit sebebi bu yüzden kullanılmıyor.

## Arşivleme — silme değil

`archiveCompletedChats` (günde bir) tamamlanmadan 7 gün geçen işlerin
sohbetlerini salt okunur yapar. **Silmez.** Gerekçe:

- Anlaşmazlık kanıtı korunur (8. günde gelen şikayet çözümsüz kalmasın)
- `reviews` kimliği `chatId`'ye dayanır — silme değerlendirme bağını koparırdı
- Admin transcript'i (`adminGetChatTranscript`) çalışmaya devam eder

Zaten kilitli sohbetlere (seçilmeyen usta) dokunmaz; `chatsArchivedAt` ikinci
işlemeyi engeller.

## Kişisel eylemler — karşı tarafı etkilemez

| Alan | Anlamı |
|---|---|
| `archivedBy: Set<String>` | Kişisel arşiv. Yeni mesaj gelince kendiliğinden çıkar |
| `pinnedBy: Set<String>` | Listenin başına sabitleme |
| `clearedAt` | Sohbeti "benden sil" — o andan öncesi gizlenir |
| `lastRead` | Okundu bilgisi |

Kural (`personalFlagsOk`) kullanıcının **yalnız kendi anahtarını**
değiştirmesine izin verir. Tek istisna: mesaj gönderen taraf alıcının arşiv
bayrağını `false` yapabilir (yeni mesaj sohbeti arşivden çıkarır) — ama asla
`true` yapamaz, yani kimse kimsenin sohbetini arşive gömemez.

## Mesajlar

`chats/{chatId}/messages/{msgId}` — model `ChatMessage`.

| Alan | Not |
|---|---|
| `isSystem` | Yaşam döngüsü şeridi ("Usta seçildi"). **Yalnız CF yazar** |
| `deleted` | Gönderen sildi → "Bu mesaj silindi" |
| `moderationHidden` | Admin kaldırdı → ayrı metin. Gönderen geri alamaz |
| `imageHandle` | Fotoğraf |

`isRedacted` = `deleted || moderationHidden` — içerik gösterimi için **tek kapı**.

> [!warning] `type: 'system'` istemciye kapalı
> Açık olsaydı kullanıcı "Usta seçildi" gibi resmî görünen sahte bildirimler
> üretebilirdi.

## İletişim maskeleme

`core/utils/contact_masker.dart` — telefon, e-posta, sosyal medya otomatik
gizlenir (PRD §5). `sendMessage` maskeleme uygulandıysa `true` döner, UI uyarı
gösterir. Ticari kural: iş platform içinde kalmalı.

## Okunmamış sayacı

`users/{uid}/private/chatMeta` → `ChatUnreadMeta`
(`unreadTotal`, `unreadCustomer`, `unreadArtisan`).

Denormalize; alt bar rozeti tüm thread listesini dinlemeden bu tek dokümanı
izler. → [[Durum-Yonetimi]]

## Ekran yapısı

`chat_screen.dart` (2077 satır) — üstten alta:

1. `_JobCompletionChatBar` — bağlı iş durumu / onay / **Değerlendir** düğmesi
2. `_JobSelectBar` — müşteriye "Bu Ustayı Seç" (yalnız ilan `open` iken)
3. Mesaj listesi
4. Giriş çubuğu **veya** `_BlockedComposerNotice` (gerekçe şeridi) **veya**
   `_MissingChatNotice`

> [!warning] `_JobCompletionChatBar` ilanı nasıl bulmalı?
> `thread.jobId` → `jobProvider`. `jobByChatIdProvider` **yedektir** (yalnız
> genel sohbetler için) — ilanın `chatId` alanını sorgular, o alan yalnız
> `selectOffer` içinde yazılır ve eşleşmezse şerit hiç çizilmez.
> → [[Bilinen-Tuzaklar]]

---
İlgili: [[Is-Akisi-Durum-Makinesi]] · [[Degerlendirme-Sistemi]] · [[Guvenlik-Kurallari]] · [[Bilinen-Tuzaklar]]

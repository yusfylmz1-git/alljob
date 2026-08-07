# 🧹 PLAN · Kapsam sadeleştirmesi

> **Karar:** 2026-08-08, kullanıcı. *"Bizim asıl işimiz usta bulmak, ilan
> vermek."* Ürün buna indirgeniyor.

---

## Hedef

Uygulama **tek cümleye** insin: *müşteri ilan verir, usta iş alır; herkes
herkesi takip edip mesaj atabilir.*

Kullanıcı kendi ifadesiyle: *"projeye giren şaşırmasın ne nerede diye.
Aslında çok basit bir program ama ben bile karıştırıyorum."*

---

## Faz 1 · Ölü kod: `staffing` (3.722 satır / 17 dosya)

**Zaten erişilemiyor:** router'a hiç kayıtlı değil, hiçbir yerden import
edilmiyor. Yalnızca `app_router.dart:386`'da bir yorum "talep olursa geri
açılır" diyor.

Kullanıcıya görünmediği için sadeleşmeye katkısı yok — ama depoyu şişiriyor
ve her `analyze`/`test` turunda taranıyor. **Risksiz silme.**

- `lib/features/staffing/` · `test/staffing_test.dart`
- `route_paths.dart` staffing sabitleri
- Varsa `staffNeeds`/`staffWorkers` kural blokları + CF'ler

## Faz 2 · `tracking` (Ajanda) — 4.091 satır / 21 dosya

Kişisel randevu/hatırlatma. **Bu uygulamanın işi değil** — kullanıcı zaten
telefonunun takvimini kullanıyor. En büyük tek modül.

**Yalnız tracking'in kullandığı 8 paket de kalkar:**
`audioplayers` · `file_picker` · `record` · `sqflite` · `path_provider` ·
`timezone` · `collection` · `path`

> ⚠️ `flutter_local_notifications` **KALIR** — push bildirim kanalı onu
> kullanıyor (`push_service._ensureAndroidPushChannel`).

> ⚠️ **Değişmez sabit uyarısı:** CLAUDE.md `_dbName =
> 'usta_cepte_tracking.db'` sabitini "asla değiştirilmeyecek" diye
> listeliyor. Modül **tamamen kalkınca** o kural da anlamını yitirir —
> CLAUDE.md'den çıkarılmalı. Kullanıcı verisi kaybı: yerel SQLite'taki
> ajanda kayıtları silinir (buluta yedekleyenlerde `trackBackup` durur).

- `lib/features/tracking/` · `test/tracking_test.dart`
- Rotalar (`/tracking`, `/tracking/new`, `/tracking/trash`, `/tracking/backup`)
- Yan menü "Ajanda" satırı
- `pubspec.yaml` 8 paket

## Faz 3 · `products` (Ürünler) — 2.935 satır / 10 dosya

*"Başlangıçta ürün olmayacağı için gereksiz durması."*

- `lib/features/products/` · `test/products_lifecycle_test.dart`
- Keşfet "Ürünler" sekmesi → Keşfet **tek liste** olur (Ustalar)
- Profil "Ürünlerim" satırı
- `AppConstants.kProductsEnabled`
- `products` kural bloğu + ilgili CF'ler
- ⚠️ `shop_completion` "ürün ekle" adımı içeriyorsa güncellenmeli

## Faz 4 · Takip: herkes herkesi (Instagram gibi)

**Şu an yönlü:** `Favorite` modeli `customerUid → artisanUid`. Yani yalnız
müşteri, ustayı takip edebiliyor.

**Olması gereken:** `followerUid → followedUid`. Usta ustayı, müşteri
müşteriyi takip edebilsin.

**Etkilenen:** model · repo (mock+firebase) · kural · CF sayaçları · UI
(takip düğmesi her profilde).

> Bu faz **veri göçü** demek — mevcut `favorites` kayıtlarındaki alan adları
> değişir. Küçük bir dönüştürme scripti gerekir.

## Faz 5 · Mesaj: herkes herkese

**Şu an kısıtlı:** `senderMayWrite` (firestore.rules:447) — usta, müşteri
yazana kadar yazamıyor (`customerStarted` bayrağı).

**Karar gerekiyor:** Bu kısıt **spam koruması**ydı. Kaldırılırsa serbest
pazar olur ama ustalar müşterilere doğrudan mesaj atabilir.

> ⚠️ Bu, 5.2/5.3'te **test edilip doğrulanmış** bir davranış. Kaldırmadan
> önce spam riskinin kabul edildiği teyit edilmeli.

---

## Sıra ve risk

| Faz | İş | Durum | Deploy? |
|---|---|---|---|
| 1 | staffing sil | ✅ `4476326` | — |
| 2 | tracking sil | ✅ `4476326` | — |
| 3 | products sil | ✅ `4476326` | — |
| 4 | takip yönsüzleştir | ✅ **veri göçü GEREKMEDİ** | — |
| 5 | mesaj kısıtı kaldır | ✅ | **Kural deploy** |

**1-2-3 önce:** silme işleri, geri dönüşü kolay, test yükü az.
**4-5 sonra:** veri ve davranış değiştiriyor, ayrı ele alınmalı.

---
İlgili: [[99-BULGULAR]] · [[PLAN-Profil-Sadelestirme]] · [[Mimari-Kararlar]]

---

## ✅ Sonuç (2026-08-08)

**Faz 1-3** (`4476326`): 12.586 satır silindi, 8 paket kalktı.

**Faz 4 — takip yönsüzleşti.** Beklenen veri göçü **gerekmedi**: kural
zaten yönsüz çalışıyordu (`customerUid` = takip eden, `artisanUid` = takip
edilen olarak okununca). Firestore alan adları **korundu** — yeniden
adlandırmak mevcut kayıtları okunamaz yapardı. Modele `followerUid` /
`followedUid` takma adları eklendi.

Asıl kısıt UI'daydı: `favorite_button` usta modunda düğmeyi **hiç
göstermiyordu** (`if (isArtisan) return`). Kaldırıldı. Tek kalan kural:
kimse kendini takip edemez.

Profil sayaçları da tek satıra indi: **takip · takipçi · (puan | tamamlanan)**
— herkeste aynı, rol dalı yok.

**Faz 5 — mesajlaşma serbest.** `senderMayWrite` artık yalnız kilide bakıyor;
`canSend` de öyle (kural + istemci paritesi korundu).

> ⚠️ **Spam koruması bilinçli olarak azaldı.** Kalan korumalar: kilit
> (`lockedAt`), engelleme, askıya alma, şikayet + admin moderasyonu.
> `customerStarted` bayrağı KALDI — UI "konuşma başladı mı" bilgisini
> kullanıyor, ama yazma iznini artık belirlemiyor.

> ⚠️ **DEPLOY GEREKİYOR:** `firebase deploy --only firestore:rules`
> Deploy edilmeden usta mesaj atmaya çalışınca sunucu **reddeder**
> (istemci izin verir → "mesaj gönderilemedi" hatası).

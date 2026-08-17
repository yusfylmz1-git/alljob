# Demo Veri Seti — mağaza ekran görüntüleri

Play Store / App Store görselleri için mock modda üretilen gerçekçi veri:
10 persona, 4 ilan, 8 ürün, 4 sohbet, 3 favori. **Canlı Firebase'e hiç
dokunmaz** — tamamı bellek içidir, uygulama kapanınca kaybolur.

## Anahtar: `withDemoPersonas`

```dart
MockDatabase()                          // varsayılan — demo verisi YOK
MockDatabase(withDemoPersonas: true)    // demo seti dolu
```

Varsayılanın `false` olması **zorunludur**. Mevcut testler tohum sayısına
bağlıdır ve demo verisi karışırsa kırılır:

| Test | Beklenti |
|---|---|
| `magaza_mimari_uyum_test.dart` | `MockDatabase().products` boş |
| `artisan_search_test.dart` | Bursa/Osmangazi/painter ilk sayfa **20**, `isNewArtisan` tam **2** |
| `jobs_test.dart` | `job_seed_1` feed'de |

Bu yüzden personalar **kasıtlı olarak** Bursa/Osmangazi/Dikkaldırım ve
`_generalAreas` dışındaki ilçelere konmuştur (Nilüfer, Beşiktaş, Keçiören,
Ümraniye, Bornova, Muratpaşa, Gemlik, İzmit, Çankaya/Bahçelievler).
Yeni persona eklerken bu kurala uyun.

## Personalar

uid deseni `demo_<ad>`; mevcut `artisan_N` / `mock_N` / `seed_customer` ile
çakışmaz.

| uid | Ad | Meslek | İl / İlçe | Premium | Mağaza |
|---|---|---|---|---|---|
| `demo_kerem` | Kerem Alptekin | `painter` | Bursa / Nilüfer | ✅ | — |
| `demo_sevil` | Sevil Karaduman | `interior_arch` | İstanbul / Beşiktaş | ✅ | ✅ |
| `demo_okan` | Okan Beyazıt | `plumber` | Ankara / Keçiören | — | ✅ |
| `demo_zeynep` | Zeynep Uçar | **yok (müşteri)** | İzmir / Karşıyaka | — | — |
| `demo_tolga` | Tolga Şenyurt | `electrician` | İstanbul / Ümraniye | ✅ | — |
| `demo_ayse` | Ayşe Nur Tunç | `cleaner` | Ankara / Çankaya | — | — |
| `demo_burak` | Burak Yalçınkaya | `ac_technician` | İzmir / Bornova | — | ✅ |
| `demo_hatice` | Hatice Gülbahar | `photographer` | Antalya / Muratpaşa | ✅ | ✅ |
| `demo_serkan` | Serkan Doğanay | `carpenter` | Bursa / Gemlik | — | ✅ |
| `demo_elif` | Elif Sarıkaya | `tiler` | Kocaeli / İzmit | ✅ | — |

**Zeynep usta değildir** → `artisans` haritasına girmez, yalnız `demoUsers`'ta
bulunur. Tolga ve Kerem hem usta hem müşteri rolünde görünür ("rol ayrımı yok"
ilkesinin görsel kanıtı).

## Fotoğrafsız ustalar sorunu ve iki çözüm

Tohumlanan **900 ustanın hiçbirinde fotoğraf yoktur** (yalnız 9 demo personada
var). Bursa/Nilüfer aramasında 146 usta çıkıyor ve içlerinde tek fotoğraflı
Kerem'di — ekran görüntüsünde ilk görünen kartlar hep fotoğrafsız oluyordu.

**1. Fotoğraflılar öne alınır** (`mock_artisan_repository.dart`).
Sıralamaya, müsaitlik ile puan arasına bir kural girer: fotoğrafı olan usta
önce gelir. **Yalnız demo verisi yüklüyken** çalışır (`_db.demoUsers.isNotEmpty`
kapısı) → normal mock davranışı ve tohum sayısına bağlı testler etkilenmez.

**2. Fotoğrafsızlarda meslek ikonu** (`app_image.dart` → `AppAvatar`,
`artisan_card.dart` → `_AvatarFill`). Baş harf yerine mesleğin ikonu ve rengi
çizilir (`job_thumb.dart` → `jobVisualFor`). Her iki bileşende de
`professionCode` **opsiyoneldir**; verilmezse eski baş harf davranışı korunur.

> `ProfileHeader` kasıtlı olarak değiştirilmedi — meslek kodu taşımıyor ve
> müşteri profillerinde de kullanılıyor. Etki asıl Keşfet kartlarındadır.

## Fotoğraflar

`AppImage` yalnız `local://` ve `http` handle tanır (`core/widgets/app_image.dart`);
`assets/...` yolu verilirse gri kutu çıkar. Bu yüzden görseller açılışta
`MockStorageRepository.uploadBytes` ile yüklenir — o metot handle'ı **birebir
`local://$path`** üretir, yani handle'ı biz belirleriz.

```
assets/demo/avatar/demo_kerem.jpg  →  local://demo/avatar/demo_kerem
```

Üretici: `lib/data/local/demo_assets.dart` → `seedDemoAssets(storage)`.
Handle deseni iki yerde tanımlıdır ve **senkron kalmalıdır**:
`MockDatabase.demoPhoto` ve `demoAssetHandle`.

Dosya listesi ve boyutlar: `assets/demo/NASIL-KULLANILIR.md`.
Görsel yoksa sessizce atlanır → baş harf rozeti / kategori ikonu yedeği.

## Sohbetler

`MockChatRepository.seedDemoThreads()` — dört konuşma. `sendMessage()`
**kullanılmaz**: `createdAt`'i `DateTime.now()`'a sabitler (tüm mesajlar aynı
dakikaya düşer) ve `isSystem` almaz. Kayıtlar doğrudan `_threads`/`_messages`'a
yazılır, zaman damgaları geçmişe yayılır.

| Taraflar | İçerik |
|---|---|
| Zeynep ↔ Elif | Sistem şeridi, fotoğraf, teklif, pazarlık, randevu. Sabitlenmiş. |
| Zeynep ↔ Kerem | Son iki mesaj ustadan, **okunmamış** → liste rozeti |
| Tolga ↔ Sevil | İki usta; Tolga müşteri rolünde |
| Zeynep ↔ Ayşe Nur | Kısa, düzenli anlaşma |

`chatIdFor` uid'leri **alfabetik** sıralar — hangi taraf müşteri olursa olsun
tek oda. Rolü `customerUid`/`artisanUid` alanları taşır.

## Kullanıcı rehberi (parite düzeltmesi)

`MockAuthRepository` yalnız oturumdaki kullanıcıyı biliyordu; başka uid için
`displayName: 'Kullanıcı'` iskeleti dönüyordu. Firestore'da `users/{uid}`
**herkese açık okunur** (CLAUDE.md kural 5) → bu bir parite açığıydı.

```dart
MockAuthRepository(publicUserResolver: db.publicUser)
```

Rehber opsiyoneldir; verilmezse eski iskelet davranışı korunur. Bu, geçici bir
demo hilesi değil kalıcı bir düzeltmedir — sohbet başlığı, ürün satıcı adı ve
herkese açık profil akışları mock'ta artık doğru çalışır.

## Ekran görüntüsü çekimi

1. `lib/core/config/backend_config.dart` → `useFirebaseBackend = false`
2. `pubspec.yaml` → `assets/demo/` satırlarını ekle (yorumlu blok hazır)
3. `flutter run -d chrome`
4. Giriş: `musteri@test.com` / `123456`
5. Çekim bitince **1 ve 2'yi geri al** — `test/yayin_hazirlik_test.dart`
   ikisini de denetler ve açık kalırsa `flutter test` kırılır.

## Nerede ne var

| Ne | Yol |
|---|---|
| Persona / ilan / ürün / favori tohumu | `lib/data/local/mock_database.dart` |
| Görsel yükleyici | `lib/data/local/demo_assets.dart` |
| Sohbet tohumu | `lib/features/chat/data/chat_repository.dart` |
| Kullanıcı rehberi | `lib/features/auth/data/mock_auth_repository.dart` |
| Mock modu bağlantısı | `lib/main.dart` → `_demoModeOverrides()` |
| Testler | `test/demo_seed_test.dart` (28), `test/yayin_hazirlik_test.dart` (3) |
| Fotoğraf listesi | `assets/demo/NASIL-KULLANILIR.md` |

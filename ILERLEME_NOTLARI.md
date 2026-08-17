# 📓 İlerleme Notları (Proje Defteri)

> Bu dosya, geliştirme sırasında **kaldığımız yeri** kaydetmek içindir.
> Tokenlar bittiğinde veya yeni bir oturuma başladığımızda, buradan kaldığımız
> yerden devam edebiliriz. Her oturum sonunda "Son Durum" bölümünü güncelle.

---

## 🎯 Proje Hakkında
- **Proje adı:** **İlanda Hizmet** (`sepette_hizmet` Dart paketi · `com.sepettehizmet.app` paket kimliği) — hizmet pazaryeri uygulaması.
  *(Görünen marka İlanda Hizmet. Teknik kimlik `sepettehizmet`. Play/App Store kaydı yokken IAP `usta_cepte_*` → `sepette_hizmet_pro_*` çekildi; mağazada ürün açıldıktan sonra kilit.)*
- **Amaç:** Müşterileri (tamirat/tadilat ihtiyacı olanlar) bölge ve meslek bazlı ustalarla buluşturmak. TR pazarı.
- **Platform:** Flutter — Android + iOS + Web
- **Backend (hedef):** Firebase (Auth, Firestore, Storage, Cloud Functions, FCM)
- **Teknolojiler:** Flutter 3.38.7 / Dart 3.10.7, Riverpod (state), GoRouter (routing)
- **Referans:** Güncel PRD `PRD.md` (v4.0 — son sürüm). Gelir modeli yalnızca Premium; canlı müsaitlik + çalışma takvimi ana farklılaştırıcı; kredi sistemi YOK.

### Mimari Kararlar
- **Feature-first / katmanlı mimari:** `lib/core` (ortak), `lib/data` (model+kaynak), `lib/features/<özellik>/{presentation,application,data}`.
- **Repository soyutlaması:** Auth bir arayüz (`AuthRepository`) arkasında. Şu an `MockAuthRepository` (bellek içi) ile çalışıyor; Firebase gelince sadece `FirebaseAuthRepository` yazılıp provider değişecek, UI/controller değişmeyecek.
- **Coğrafi/meslek verisi:** Statik JSON assetlerinden okunuyor (`assets/data/`), Firebase'e sorgu yok.

---

## ✅ Son Durum (EN SON BURAYI OKU)

**Tarih:** 2026-08-17 — **PLAY STORE ÖNCESİ TAM DENETİM**

`flutter analyze` 0 · **935 test** (öncesi 912) · CF lint 0 hata.
Rapor: `docs/YAYIN_DENETIMI_2026_08_17.md` · Regresyon:
`test/yayin_denetimi_2026_08_17_test.dart` (23 test).

### En kritik iki bulgu (ikisi de SESSİZ arıza)

1. **`jobs(customerId+status)` indeksi yoktu → 5 ilan limiti FİİLEN KAPALIYDI.**
   Sorgu catch'e düşüyor, sayaç yazılmıyor, kural her zaman 0 okuyor. Bir
   kullanıcı sınırsız ilan açabilirdi (her ilan = bölgedeki tüm ustalara
   bildirim).
2. **`reviews(customerUID+createdAt)` indeksi yoktu** → profil ekranındaki
   yorum bloğu canlıda hiç görünmezdi.

### Düzeltilen 11 madde

Ölçek: indeksler, TTL politikası, ürün taslağı kotası (100), sayaç
sorgularına limit, usta aramasında il filtresinin sunucuya taşınması.
Güvenlik/KVKK: `reviews` create allowlist + boyut tavanı, sertifika
gizliliği, Console talimatlarının kullanıcıdan gizlenmesi, silinen
kullanıcının yorumuna `authorDeleted` işareti.
Akış: **profil fotoğrafı Keşfet'te eski kalıyordu** (kullanıcı şikâyeti),
süresi dolmuş ilana hâlâ mesaj atılabiliyordu.

### ⚠️ Yayın öncesi ELLE yapılacaklar

Kodla çözülemez, konsol ister — ayrıntı raporun sonunda:
`firebase deploy --only firestore:indexes,storage,functions` · App Check
gerçek durumu (3 belge çelişiyor) · bootstrap admin 2FA · TTL doğrulama ·
Data Safety formu (telefon "herkese açık", konum "toplanmaz", reklam kimliği
"evet") · IAP ürünü Play Console'da tanımlı mı.

---

**Tarih:** 2026-08-16 — **MAĞAZA EKRAN GÖRÜNTÜSÜ İÇİN DEMO VERİ SETİ**

`flutter analyze` 0 · **886 test geçiyor** (öncesi 852, +34 yeni).

Play/App Store görselleri için mock modda gerçekçi veri üretildi: 10 persona
(9 usta + 1 yalnız müşteri), 4 ilan, 8 ürün, 4 sohbet, 3 favori.
**Canlı Firebase'e hiç dokunulmadı** — tamamı bellek içi.

Kasa notu: `vault/06-Test/Demo-Veri-Seti.md` (personalar, tuzaklar, çekim adımları).

### Ne eklendi

| Dosya | Ne |
|---|---|
| `lib/data/local/mock_database.dart` | `MockDatabase({withDemoPersonas})` — **varsayılan false**; `_add`'e opsiyonel persona parametreleri; `demoUsers` + `publicUser()` |
| `lib/data/local/demo_assets.dart` | **YENİ** — `assets/demo/` görsellerini `local://` handle ile depoya yükler |
| `lib/features/chat/data/chat_repository.dart` | `seedDemoThreads()` — 4 Türkçe konuşma (sistem şeridi, foto, pazarlık, okunmamış rozet) |
| `lib/features/auth/data/mock_auth_repository.dart` | `publicUserResolver` — **parite düzeltmesi** (Firestore'da `users/{uid}` herkese açık okunur, mock bunu taklit etmiyordu) |
| `lib/main.dart` | `_demoModeOverrides()` — yalnız mock modda devreye girer |
| `test/helpers/mock_backend.dart` | Eksik `productRepositoryProvider` override'ı eklendi |
| `test/demo_seed_test.dart` | 28 test — verinin doğru ÜRETİLDİĞİ |
| `test/demo_ekran_test.dart` | 5 test — verinin ekranlara ULAŞTIĞI |
| `test/yayin_hazirlik_test.dart` | 3 muhafız — mock modu / demo asset yayına sızmasın |
| `lib/features/artisan/data/mock_artisan_repository.dart` | Demo modda **fotoğraflı ustalar öne** alınır (yalnız `demoUsers` doluyken) |
| `lib/core/widgets/app_image.dart` · `artisan_card.dart` | Fotoğrafsızlarda baş harf yerine **meslek ikonu** (`professionCode` opsiyonel) |

### Fotoğrafsız usta sorunu

900 tohumlanmış ustanın hiçbirinde fotoğraf yok (yalnız 9 personada var).
İki düzeltme yapıldı; ölçüm: **Türkiye geneli ilk 8 kartın 8'i fotoğraflı**,
bölge filtresinde ilk kart fotoğraflı + gerisi renkli meslek ikonu.

### ⚠️ Şu an AÇIK olan geçici değişiklikler

Ekran görüntüsü çekimi için **kasıtlı** açık; çekim bitince kapatılacak:

1. `lib/core/config/backend_config.dart:8` → `useFirebaseBackend = **false**`
2. `pubspec.yaml` → `assets/demo/{avatar,work,product}/` kayıtları

`test/yayin_hazirlik_test.dart` ikisini de denetler ve **şu an kasıtlı olarak
kırık** — ikisi kapatılınca yeşile döner. Yayın öncesi bu testin geçtiğini
doğrulayın.

### Kullanıcıya düşen

`assets/demo/` altına 27 fotoğraf (10 avatar + 9 iş + 8 ürün).
Dosya adları ve boyutlar: `assets/demo/NASIL-KULLANILIR.md`.
Fotoğraf olmadan da çalışır — baş harf rozeti + kategori ikonu yedeği devreye
girer ("Demo modu: N görsel yüklendi" logu yüklemeyi doğrular).

---

**Tarih:** 2026-08-15 — **TAM DENETİM + YAYIN SERTLEŞTİRMESİ**

`flutter analyze` 0 · **814 test** · `npm run lint` 0 hata · release AAB
doğrulandı (R8 açık). Commit: `1b8d46f`.

Rapor (artifact): denetim defteri — bulgular, gerekçeler ve Play Console
adımları. Kaynak: `vault/05-Operasyon/denetim-2026-08-15.html`.

### İki P0 (ikisi de düzeltildi + teste bağlandı)

1. **Bir satın alma → sınırsız premium.** `grantArtisanPremium` `tokenHash`'i
   hesaplayıp yazıyor ama **hiç okumuyordu**; doküman anahtarı `uid` olduğu
   için aynı Play token'ı farklı hesaplardan gönderen herkes premium
   oluyordu. Artık `membershipTokens/{hash}` sahibi tutuyor, yazım
   `runTransaction` ile yarıştırılamaz, `deleteAccount` siliyor.
2. **Harici bağlantıların hiçbiri açılmıyordu.** Manifest'te `<queries>`
   içinde `VIEW` beyanı yoktu → Android 11+ paket görünürlüğü nedeniyle
   `launchUrl` **sessizce** başarısız (menü site bağlantısı, WhatsApp,
   sosyal medya, yasal metinler). Eklenti bu bloğu kendi manifest'inde
   taşımıyor.

### Aynı oturumda kapatılan P1/P2

- **Eşzamanlı ilan limiti artık atomik** — kural motoru transaction
  yapamadığı için sayaç tazelenmeden gelen istekler limitten geçiyordu
  (TOCTOU). `onJobCreated` içinde `openReserved` rezervasyonu.
- **Tüm admin callable'ları App Check zorluyor** (30 fonksiyon).
- **R8/ProGuard açıldı** + keep kuralları; release AAB ile doğrulandı.
- **`functions/` ilk kez lint'leniyor** — hiç yapılandırma yoktu. İlk koşuda
  5 ölü tanım + 2 hatalı regex kaçışı buldu. `predeploy` hook'una bağlandı.
- **`debugPrint` → `AppLog.d`** (40 çağrı, 11 dosya). `debugPrint` release'te
  de yazıyor ve satırlar uid/chatId/FCM token öneki taşıyordu.
- **`yan_logo.png` silindi** (4,85 MB) — kod hiç yüklemiyordu, varlıkların
  yarısıydı.
- **Sürüm `1.0.0+1` → `1.0.1+2`** (Play aynı `versionCode`'u reddeder).

### ⚠️ Bu oturumda yaşanan iki kaza (kasaya yazıldı)

- PowerShell `Set-Content -Encoding utf8` zaten UTF-8 olan `index.js`'i
  ikinci kez kodladı (1150 bozuk karakter + BOM). **Türkçe kaynak dosyada
  toplu değişiklik için PowerShell kullanma.**
- Bunu geri almak için atılan `git stash`, çalışma ağacındaki
  **commit'lenmemiş ~350 satırlık CF işini** de aldı. Testler yakaladı,
  düşürülen stash SHA'sından kurtarıldı. **Stash'ten önce commit al.**

### Geriye kalan: yalnız Play Console (elle)

Kodda yapılacak iş bırakılmadı. Veri güvenliği formu, SHA-256 kaydı,
abonelik ürünü ve yasal URL girişleri konsoldan yapılır — adım adım liste
denetim raporundadır.

---

## 📌 Oturum 84 (2026-08-14) — arşiv

**Tarih:** 2026-08-14 (4. oturum) — **FOTOĞRAF ALTYAPISI**

`flutter analyze` 0 · **734/734 test** · release AAB 59.8 MB ·
yeni test `test/fotograf_kirpma_test.dart` (13 test).

### Sorun

Cihaz bulgusu: *"resimler yarım çıkıyor, profil fotoğrafı yayık görünüyor."*

**Kök neden: kırpma adımı hiç yoktu.** Kullanıcı hangi oranda fotoğraf
seçerse seçsin, kart `AspectRatio` + `BoxFit.cover` ile onu zorla çerçeveye
sığdırıyordu — dikey fotoğrafın altı/üstü kesiliyordu. Avatar da kare
olmayan kaynakta kafayı ortalayamıyordu.

### Çözüm

- **`image_cropper`** paketi + Android manifest `UCropActivity` kaydı.
- **Ortak servis:** `lib/core/utils/photo_picker.dart` →
  `PhotoPicker.pickPhoto()` / `pickMultiPhoto()`.
  ⚠️ **Yeni foto yükleme yeri eklersen bunu kullan**; doğrudan
  `ImagePicker().pickImage()` çağırma — kırpma atlanır, hata geri döner.
- **Şekiller:** profil `square` (1:1 kilitli) · ürün/ilan/vitrin `portrait`
  (4:5) · sertifika `free` (zorunlu oran belge metnini keser).
- **Kart oranları 4:5'e hizalandı** — `AppConstants.photoAspectWidth/Height`
  ve `photoCardAspectRatio`. Kritik kural: **kırpma oranı ile kart oranı
  AYNI olmalı**, yoksa kırpma hiçbir şey çözmez.
- Kırpma iptal edilirse fotoğraf ham hâliyle eklenir (seçim boşa gitmez).

**Sohbet fotoğrafı bilinçli olarak kırpmasız** — mesajlaşmada Instagram ve
WhatsApp da kırpma dayatmaz.

### Aynı oturumda düzeltilen iki cihaz bulgusu daha

1. **Telefon numarası profilde görünmüyordu.** `setPhoneVisibility` yalnız
   `artisanProfiles/{uid}` yazıyordu; profil başlığı `users/{uid}.publicPhone`
   okuyor — yazılan yer okunan yer değildi. Artık ikisine de yazılıyor ve
   `users` yazımı koşulsuz (mağaza sahibinin usta profili olmayabilir).
2. **WhatsApp ikonu gerçek logo değildi** (`Icons.chat` düz balon).
   `lib/core/widgets/whatsapp_icon.dart` — CustomPaint ile marka logosu.
   Paket eklenmedi (tek ikon için ~1 MB font bağımlılığı gereksiz).

---

**Tarih:** 2026-08-14 (3. oturum) — **TELEFON DOĞRULAMA KÖK NEDENİ BULUNDU**

### 🔴 SENİN YAPMAN GEREKEN — 1 dakika

**`androidcheck.googleapis.com` API'si KAPALI.** Telefon doğrulamanın
sürekli `(unknown)` vermesinin sebebi bu.

<https://console.cloud.google.com/apis/library/androidcheck.googleapis.com?project=alljob1>
→ **ENABLE** → 2-3 dk bekle → uygulamayı tamamen kapatıp aç.

CLI ile açılamadı (`PERMISSION_DENIED`); Console oturumu gerekiyor.

**Neden:** Firebase Auth, Android'de SMS göndermeden ÖNCE cihaz doğrulaması
(Play Integrity / SafetyNet) yapar. Bu API kapalıysa doğrulama düşer, SDK
ayırt edici kod üretemez ve `code=unknown` fırlatır. **SMS hiç gönderilmez** —
bu yüzden "numara değiştir" de çalışmıyordu (o düğme sağlam, aynı duvara
çarpıyordu).

### Canlı projeden API ile doğrulananlar (sorun YOK)

Phone provider ✅ · SMS bölge TR ✅ · debug+release SHA-1/SHA-256 ✅
(yerel keystore'larla eşleşiyor) · App Check tümü UNENFORCED (bloklamıyor) ·
playintegrity + identitytoolkit ✅ · **androidcheck ❌**

### Kodda yapılanlar

- `code=unknown` → `deviceCheckFailed` eşlemesi. Kullanıcı artık
  "(unknown)" yerine ne yapacağını söyleyen bir mesaj görüyor.
- `[TANI][telefon]` logu kök nedeni ve 3 kontrol adımını yazıyor.
- Yeni belge: **`docs/TELEFON_DOGRULAMA_TANI.md`** — kayıtlı numaraları
  nerede göreceğin, SMS harcamadan test numaraları, tam tanı listesi.

**Test numaraları (gerçek SMS gitmez, cihaz doğrulamasını da atlar):**
`+90 555 000 00 00` ve `+90 555 555 55 55` → kod `123456`

`flutter analyze` 0 · **715/715 test**

---

**Tarih:** 2026-08-14 (2. oturum) — **YAYIN ÖNCESİ TAM DENETİM**

Rapor: **`docs/YAYIN_DENETIMI_2026_08_14.md`** (bulgular + senin yapman
gerekenler). `flutter analyze` 0 · **712/712 test** · release AAB 59.3 MB ·
yeni test `test/yayin_hazirlik_denetimi_test.dart` (14 test).

### ✅ KURALLAR CANLIDA

`firebase deploy --only firestore:rules` yapıldı. Canlı ruleset doğrulandı
(2026-08-14 15:25 UTC): `providerFlagOk` her iki sağlayıcı bayrağında aktif.
Usta/mağaza açmak artık **sunucu tarafında** doğrulanmış telefon istiyor.

### ✅ 11 KIRIK TEST KAPANDI — işlev kaybı YOKTU

Tek tek incelendi; hepsi yeniden yazım sonrası eskiyen, kaynak-metin tarayan
testlerdi. Kod doğruydu. Davranış iddiaları korunarak güncellendi:

- `label: 'X'` → `label: const Text('X')` biçim değişikliği (5 test)
- `_AvailabilitySwitch` imzası değişti + sabit karakter penceresi kaydı (3)
- "Usta modu" anahtarı kaldırıldı → müsaitlik anahtarı (1)
- **`direct_contact`:** müsaitlik kapısı silinmemiş, ortak
  `artisanAvailabilityAllowsNewChat()`'e taşınmıştı — güvenlik kaybı yok
- **`test_bulgulari_10`:** `manualPause` eleme değil SIRALAMA skorunda;
  müsait olmayan usta bildirimi almaya devam ediyor

**`otherModeUnreadProvider` şüphesi kapandı:** provider bilinçli olarak 0
döndürüyor (mod switch'i kalkınca "karşı mod" kavramı da kalktı). Okunmamış
sayacı alt barda `totalUnreadProvider` ile çalışıyor.

### Düzeltilen kritik sorunlar

1. **Çıkışta sahte çökme** ("oturum kapatınca uygulama duruyor") — 10
   korumasız canlı dinleyici. Ortak yardımcı
   `lib/core/utils/signout_safe_stream.dart` → `.signOutSafe(etiket, uid)`.
   ⚠️ uid'e bağlı yeni `snapshots()` eklersen BU ÇAĞRIYI YAP.
2. **Bildirim sessiz arızası (2 kusur):** `notDetermined`'da token
   yazılıyordu (izin kapalıyken "açık" görünüyordu); çıkışta
   `_tokenRefreshSub` iptal edilmediği için İKİNCİ hesapta token yenileme
   hiç yazılmıyordu.
3. **Telefon doğrulama sunucuda zorunlu değildi** — `firestore.rules`
   `providerFlagOk()`. Yalnız bayrağı AÇARKEN aranır; mevcut ustalar
   kilitlenmez. Mock paritesi eklendi.
4. **Fiyat tavanı yoktu** — `AppConstants.maxPriceAmount` (100M ₺).
5. **4 limitsiz canlı dinleyici** (favoriler, takipçiler, engellenenler,
   sohbet listesi) → 200'lük tavanlar. Maliyet riski.
6. **Çift gönderim** — doğrulama sayfası açıkken Kaydet/Mağazayı aç etkin
   kalıyordu.

### Senin yapman gerekenler (rapordaki tam liste)

- Kuralları deploy et (yukarıdaki komut)
- Firebase Console: Phone sağlayıcısı + SMS region policy (+90) + release
  SHA-256 → **gerçek cihazda uçtan uca telefon doğrulaması dene**
- Keystore yedeği + Play App Signing

---

**Tarih:** 2026-08-14

**Kaynak:** `vault/06-Test/new.md` — dört madde tamamlandı.
`flutter analyze` temiz · 686 test geçiyor · yeni test dosyası
`test/saglayici_telefon_kapisi_test.dart` (13 test).

### Yapılanlar

1. **Sağlayıcı telefon kapısı (madde 1–2).** Yeni ortak dosya
   `lib/features/auth/application/provider_phone_gate.dart` →
   `ensureVerifiedPhoneForProvider()`. Usta profili kaydı ve mağaza kurulumu
   bu kapıdan geçer: `phoneVerified` false ise **kayıt yapılmaz**, sebebi
   anlatan sayfa → `PhoneVerificationSheet` açılır. Vazgeçilirse form açık
   kalır, veri kaybolmaz. `availability_gate.dart` ile aynı desen —
   **yeni bir sağlayıcı kaydı girişi eklersen bu kapıyı çağır.**
   Meslek/bölge (usta) ve kategori/bölge (mağaza) zorunluluğu zaten vardı.

2. **Sohbette WhatsApp (madde 3).** `chat_screen.dart` → `_WhatsappAction`
   AppBar eylemi, `wa.me` bağlantısı açar. **İki koşul birlikte:**
   `phoneVerified` **ve** `publicPhone` dolu. Hassas `phoneNumber` alanı
   KULLANILMAZ — ona bağlamak gizli numarayı sohbetten sızdırırdı.

3. **Kategori çeşitlendirmesi (madde 4).** `product_category.dart` 14 → 28
   kategori: giyim, kozmetik, gıda/market, pet, kırtasiye, tarım, güvenlik,
   temizlik, hediyelik + aydınlatma, banyo/seramik, boya, ısıtma/soğutma,
   kapı/pencere. **Eski kodların hiçbiri değişmedi** (kural 6). Sıralama
   gruplandı: yapı → ev → araç/iş → genel perakende, `diger` sonda.

4. **Profil çip taşması (madde 4).** Yeni widget
   `lib/core/widgets/collapsible_chips.dart`: ilk 6 çip görünür, kalanı
   "+N daha" rozetinin arkasında açılır/kapanır. Profildeki satış
   kategorileri ve mağaza bölgeleri bunu kullanır.

### ⚠️ Devralınan 11 kırık test (bu oturumun işi DEĞİL)

`profile_simplify_test` · `unified_profile_test` · `profile_common_fields_test`
· `artisan_login_test` · `direct_contact_test` ·
`test_bulgulari_2026_08_09/10_test` içindeki 11 test kırık. Sebep: bu oturum
ÖNCESİNDE `profile_screen.dart` yeniden yazılmış (+689/−270, commit edilmemiş)
ve bu testler kaynak dosyayı **metin olarak** tarıyor — aradıkları
`otherModeUnreadProvider` ve `label: 'İlanlarım'` dizgileri artık dosyada yok
(düğme `label: const Text('İlanlarım')` biçimine geçmiş).

Doğrulandı: profil dosyası `HEAD` hâline alınınca 11 test de geçiyor; benim
çip düzenlemem eklendiğinde/çıkarıldığında sayı 11'de sabit kalıyor.
**Karar gerekli:** testler yeni profil yapısına mı güncellenecek, yoksa eksik
`otherModeUnreadProvider` bağlantısı profile geri mi eklenecek? (İkincisi
gerçek bir işlev kaybı olabilir — karşı moddaki okunmamış mesaj rozeti.)

---

**Tarih:** 2026-08-13

**Marka hizası:** görünen ad İlanda Hizmet; paket / IAP `sepettehizmet`.
Play ve App Store kaydı olmadığı teyit edildi. Canlı koddaki `usta_cepte`
kimlikleri çekildi:

- `kProMonthlyProductId` = `sepette_hizmet_pro_monthly`
- CF `PLAY_PACKAGE_NAME` = `com.sepettehizmet.app` (eskiden yanlışlıkla
  `com.ustacepte.usta_cepte` idi — Premium doğrulaması bozuktu)
- `UstaCepteApp` → `SepetteHizmetApp`

`verifyMembershipPurchase` CF'si canlıdaysa bu paket/ürün kimliği değişikliği
deploy ister. Mağazada ürün **şimdiden** `sepette_hizmet_pro_monthly` ile
açılmalı.

**Deploy (2026-08-13):** `firestore.rules` zaten canlıdaydı (atlandı).
CF güncellendi: `verifyMembershipPurchase` + `adminBulkPlanUpdate` +
`adminUpdateProductCategories` → Successful update.

**Firebase iOS (2026-08-13):** yeni app `com.sepettehizmet.app`
(`…ios:af72f93e17f9bccc9aba96`). `GoogleService-Info.plist` +
`firebase_options.dart` güncel. Apple Developer + Codemagic sırada.

---

**Tarih:** 2026-08-10

**Oturum 84: CİHAZ TESTİ BULGULARI GİDERİLDİ. Tek commit (`b9bfac8`,
+3237/−1257) · 586/586 test · analyze 0.**

### 🔴 SIRADAKİ İŞ: `adminBulkPlanUpdate` DEPLOY EDİLECEK

Bu oturumun kod işi bitti ama **bir yeni Cloud Function canlıda yok**.
Export sayısı **40 → 41** oldu:

```bash
firebase deploy --only functions:adminBulkPlanUpdate
```

Deploy edilmiş olanlar (oturum 83 sonrası, bu oturum içinde):
- `firestore.rules` — sohbet kimliği iki sıra + bildirim `delete` izni ✅
- `deleteAccount` düzeltmesi (madde 13b, BulkWriter NOT_FOUND) ✅

> Tekrar hatırlatma: CF deploy'u **silme** gerektiriyorsa etkileşimsiz
> ortamda durur. Bu sefer yalnız EKLEME var, sorun çıkmamalı.

Deploy sonrası kalan iş cihaz testi (aşağıdaki "Kalanlar").

### Oturum 84'te ne yapıldı

Kaynak: `vault/06-Test/Yapılacaklar.md` — cihaz testinde bulunan 13 madde
ve "yeni yapılacaklar" listesinin 1. maddesi. Her maddenin kök nedeni ve
kararı o dosyada duruyor; burada yalnız mimari sonuçlar:

**Sohbet kimliği role bağlıydı** → `chat_{müşteri}__{usta}` biçimi rolü
kimliğe gömüyordu, rol ise giriş noktasına göre değişiyordu (ilan detayında
"ilanı veren = müşteri", profilde "ben = müşteri"). Aynı çift iki kutu
açıyordu. Kimlik artık uid'leri **alfabetik sıralıyor**. ⚠️ Kural da
değişti — yalnız eski sırayı kabul etseydi sohbetlerin ~yarısı
`permission-denied` alırdı. Veri göçü YAPILMADI; eski kimlikli sohbetler
üyelikle sorgulandığı için listede kalır.

**Müsaitlik kapısı dört girişten yalnız birinde vardı.** İlan detayı
kapılıydı; ilan kartındaki avatar → profil → "Sohbet et" yolu açıktı.
Ortak kapı: `artisan/application/availability_gate.dart`. Kapı **eylemde**,
gezinmede değil — profili gizlemek deliği kapatmazdı. Yalnız istemcide
çalışır, güvenlik sınırı DEĞİL.

**`isAvailableAt` premium'a bağlandı** — hesaplanan getter olduğu için veri
yazılmaz; "Premium beta ücretsiz" anahtarı kapanınca kapı kendiliğinden
iner, açılınca kalkar. Veriyi gerçekten değiştirmek gerekirse admin
"Toplu Plan" ekranı (superadmin · zorunlu kuru çalışma · ikinci onay ·
ödemeli aboneleri atlar) → **yeni CF `adminBulkPlanUpdate`**.

**Meslekler kategorilendi** — 132 → **144**, 13 kategori. Avukat zaten
vardı; sorun yokluk değil düz listede bulunamamaktı. 4 ad aramaya uygun
hale geldi ama **`apiValue` kodları değişmedi** (kural 6, göç yok).

**Değerlendirme etiketleri yöne ayrıldı** (`positiveFor`/`negativeFor`) —
usta bir müşteriyi "Temiz işçilik" diye puanlayamaz. `isNegative` her iki
listeye bakar, çünkü eski kayıtlar karşı yönün etiketlerini taşıyor.

**Hesap silme kapsamı** — ölçüt iki yönlü: kişisel veriyi sil, kötüye
kullanım kaydını koru. `reports` KALIR (yalnız `reporterUid` düşer), yoksa
"şikayet edilince hesabı sil, temize çık" açığı doğardı.

**Haftanın Ustası gerçekten rotasyona girdi** — kod puana göre sıralayıp
`.first` alıyordu, yani puan değişmedikçe aynı usta sonsuza kadar kalıyordu.
ISO hafta numarası % aday sayısı; sunucuya alan yazılmaz, aynı hafta herkes
aynı ustayı görür.

**Diğer:** ilan kartı ilanı verenin avatarıyla başlıyor · normal ilanda ilçe
şartı kalktı (sunucu zaten yalnız ile bakıyordu, sapma kapandı) · bildirim
ekranı sadeleşti + Temizle · sosyal medya silme geri okumada geri geliyordu
("alan YOK" ile "alan var ama BOŞ" ayrımı).

### ⏳ Oturum 84'ten kalanlar

- **Onboarding'e Kolay İş tanıtımı** — içerik/tasarım kararı bekliyor.
- **Telefon doğrulamada `unknown`** — kodda görünür hata yok, cihaz konsol
  logu gerekiyor.
- **İl bazlı Haftanın Ustası** — kullanıcı kararı bekliyor: (a) kullanıcının
  iline göre (b) il il rotasyon. Rotasyon çalıştığı için acil değil.

---

## 📌 Oturum 83 (arşiv)

**Tarih:** 2026-08-09

**Oturum 83: TUR B + web/admin/test defteri. 10 commit · 471/471 test ·
analyze 0. ✅ HEPSİ DEPLOY EDİLDİ. ⚠️ CİHAZ TESTİ BEKLİYOR.**

### ✅ DEPLOY TAMAMLANDI (2026-08-09)

| Ne | Durum |
|---|---|
| `firestore.rules` | ✅ 1278 → 823 satır |
| Cloud Functions | ✅ **40 fonksiyon** — yerel export sayısıyla birebir |
| Tanıtım sitesi (`alljob1`) | ✅ www.ilandahizmet.com |
| Admin paneli (`alljob1-admin`) | ✅ |

**Silinen 5 CF** Firebase'den de kaldırıldı (`functions:delete` ile elle):
`adminResolveDispute` · `archiveCompletedChats` · `autoCompleteJobs` ·
`onOfferWritten` · `remindJobAutoComplete`.

> [!warning] CF deploy'u silme gerektiriyorsa etkileşimsiz ortamda DURUR
> `firebase deploy --only functions` kodda olmayan fonksiyon bulursa
> onay ister; terminalden onay alınamayınca **iptal eder** (hiçbir şey
> bozulmaz). Önce `firebase functions:delete <ad...> --region europe-west1`
> çalıştır, sonra deploy et. `--force` ile atlama — geri dönüşü yok.

### 🔴 SIRADAKİ İŞ: CİHAZ TESTİ

```bash
flutter clean && flutter run
```

Sonra cihaz testi: **`vault/06-Test/00-TEST-PLANI.md` (v3, 395 adım)**
sıfırdan yazıldı — oturum 82'nin 5 maddesi de içinde. En kritik adımlar:
- **8.3.5** — mesajlaşılan ilanı sil → **sohbet DURMALI** (veri kaybı testi)
- **6.3.7** — aynı çift iki ilan konuşsun → **tek sohbet**
- **9.3.2** — aynı kişiyi ikinci kez puanla → **"Güncelle"**, form dolu
- **11.2.5** — admin özet çipleri **doğru sekmeyi** açıyor mu (indeks kayması)
- **12.4.2** — hesap silme metni kodla **birebir** mi (yasal risk)

### Oturum 83'te ne yapıldı

**Adım 1 — ölü kod** (`671d1b8`): `select_artisan.dart` (105 st) ve
`job_completion.dart` (381 st). Üründen hiçbir yol ulaşmıyordu.

**Kasa gerçeğe hizalandı** (`4815192` + son commit): iş akışı notu
kaldırılmış akışı canlıymış gibi anlatıyordu → 173 satırdan 81'e indi ve
artık gerçeği yazıyor. CF haritası, güvenlik kuralları, Firestore şeması,
veri modelleri ve bilinen tuzaklar notları da güncellendi.

**Adım 2a — Dart** (`edea6da`, −2763 satır):
- `JobStatus` **8 → 3 değer**: open · cancelled · expired
- `offers` katmanının tamamı, 9 repo metodu, Job modelinden 13 alan,
  `JobDisputeParty`/`JobDisputeReason`, admin hakemlik modülü,
  `MyOffersScreen`, `/panel/offers`, "İlgilendiğim" sekmesi

**Adım 2b — kural + CF** (`cf40041`, −960 satır):
- `firestore.rules` **1278 → 823 satır**. `match /offers` kalktı; jobs
  bloğundaki 6 doğrulama fonksiyonu gitti. Sahip artık ya ilanı kapatır ya
  da AÇIK ilanın içeriğini düzenler. `expired` istemciye kapalı kaldı.
- 5 CF + 2 yardımcı silindi; `onJobWritten` 5 daldan **1 dala** indi
  (açık ilan sayacı).
- `deleteAccount` sadeleşti: ilanlar anonimleştirilmiyor, siliniyor.

### Oturum 83 · ikinci yarı (web · admin · analiz · test defteri)

**Tanıtım sitesi** (`d2fdc87`) — iki tur geride kalmıştı:
- Logolar **16 Temmuz**'dandı ve üzerinde **"USTASINDAN"** yazıyordu (üç
  marka önceki ad). `assets/brand/logo.png`'den (İH monogramı) tüm boyutlar
  türetildi. Kaynakta %16 saydam pay vardı → alpha bbox'a kırpıldı, yoksa
  40px başlıkta logo daha da küçük dururdu.
- `apple-touch-icon` **beyaz zeminli** (iOS saydamı siyaha boyar).
- `og-image` 512×512 kareydi → **1200×630** sosyal kart olarak yeniden çizildi.
- **Yasal metinler düzeltildi** — bu kozmetik değil: `hesap-silme.html` ve
  `gizlilik-politikasi.html` `deleteAccount`'un ESKİ davranışını anlatıyordu
  ("aktif işler iptal edilir, tamamlanmış işler anonimleştirilir"). Tur B'de
  o akış değişti; metinler koddaki gerçeğe göre yeniden yazıldı.

**web/ kabuğu + admin** (`a9e3603`):
- Kabuk admin panelini sunuyor ama başlığı "İlanda Hizmet / Hizmet pazaryeri"
  idi → "İlanda Hizmet · Yönetim" + `noindex`.
- **maskable PWA ikonları normal ikonun aynısıydı** → Android kırparken logo
  kesilirdi. %62 iç alan + beyaz zeminle yeniden üretildi.
- `AdminStatsSnapshot`'tan 4 ölü sayaç kalktı; `jobsTotal` donuk eski
  değerleri topluyordu. `jobsOther` kartı eklendi (yalnız >0 ise görünür).
- `disputes.manage` yetkisi kaldırıldı (Dart + CF paritesi).
- Denetimde **ayrım**: "Anlaşmazlık" kategorisi kalktı ama `resolve_dispute`
  etiketi korundu — eski kayıt ham string görünmesin.
- `flutter build web --target lib/main_admin.dart --release`: **başarılı**.

**Analiz** (`70a2527`) — yeni kasa notu `vault/02-Ozellikler/Mevcut-Akislar.md`:
"Ürün bugün ne yapıyor?" — roller, 5 sekme, açılış kapıları sırası, ilan
limitleri, ustanın **dört kapısı**, Kolay İş farkları, sohbet/değerlendirme
kuralları. Koddan doğrudan çıkarıldı; test defterinin dayanağı.

**Test defteri v2 → v3** (`70a2527`) — 285 → **395 adım**:
- `08-Is-Akisi.md` **silindi** (test ettiği akış yok) → `08-Ilan-Omru-ve-Yonetimi.md`
- **Yeni:** `11-Admin-Paneli.md` (57) ve `12-Tanitim-Sitesi.md` (35) — ikisi
  de hiç test edilmiyordu
- `06-Ilan-Alma-Usta` yeniden yazıldı (ilgi bildirme → doğrudan mesaj)
- **Çelişki düzeltmeleri:** defter eski doğruyu *bulgu* sayıyordu — "aynı çift
  tek sohbette birleşiyor → mimari bozuk" (artık doğru davranış bu),
  "müşteri puanı herkese görünüyor → gizlilik ihlali" (bilerek açılmıştı)

### ⚠️ Bilinçli davranış değişiklikleri
1. **`canDelete` artık hep true.** Sahibi ilanını her zaman siler. Sohbetler
   ilandan bağımsız yaşar — silme mesaj geçmişini götürmez.
2. **`completedJobsAsCustomer` artık artmıyor.** Zaten artmıyordu (tetikleyen
   geçiş yok) ve hiçbir ekranda gösterilmiyor. Alan modelde duruyor.
3. **Admin panelinden "Anlaşmazlıklar" sekmesi kalktı** → sekme indeksleri
   kaydı, dashboard hızlı erişimi de birlikte güncellendi. Kullanıcı
   şikayeti `reports` koleksiyonundan akmaya devam ediyor.

### Geriye uyum (canlıda eski kayıt varsa)
- `JobStatus.fromString` tanımadığı değeri **`open`** sayar → `workerSelected`
  yazan doküman varsa ilan görünür kalır, çökmez.
- `jobStatsBucket` eski durumları **`jobsOther`** kovasına atar (sayımdan
  kaybolmasınlar).
- `Job.fromMap` ölü alanları okumaz; Firestore'da durabilirler.
- İkisinin de regresyon testi var.

### Oturum 82 cihaz testi listesi (hâlâ yapılacak)
Bu oturumda ürünün yarısı değişti ama **hiçbiri cihazda denenmedi**. Sıra:
1. `flutter clean && flutter run` (launcher ikonu yenilendi, önbellek şart)
2. Profili Düzenle → telefon + Instagram + web gir → **kaydet** (kural yeni
   deploy edildi; `permission-denied` gelirse kuralı kontrol et)
3. Başkasının profiline gir → başlık kendi profilinle **aynı** görünmeli,
   düğmeler "Mesaj | Takip et" olmalı
4. Bio satırlarına dokun → telefon aramalı, Instagram uygulamayı açmalı
5. Bir kişiyi değerlendir, sonra tekrar gir → "Değerlendirmeni Güncelle"
   demeli ve form ESKİ puanla dolu gelmeli

### Oturum 82'de ne değişti (özet)

**A) İŞ AKIŞI KALDIRILDI** (`12e0eca`)
Teklif topla → "Ustayı Seç" → tamamlama onayı zinciri gitti. Usta ilan
sahibine **doğrudan mesaj** atıyor. `job_detail_screen` 1994 → 909 satır.
⚠️ **Tur B YAPILMADI:** `JobStatus` enum'ı (8 değer), `offers` koleksiyonu,
56 CF referansı ve admin modülü DURUYOR. Enum değeri silmek veri göçü
(kural 6) — canlıda `workerSelected`/`completed` ilan varsa okunamaz olur.

**B) TEK MESAJ KUTUSU** (`f73cfe1`)
`chatIdFor` artık `jobId` almıyor → kişi başına TEK sohbet. "İlan
Mesajları | Genel" sekmeleri kalktı. Eski 3 parçalı sohbetler okunmaya
devam ediyor (veri kaybı yok).

**C) DEĞERLENDİRME KİŞİ BAZLI** (`55e56d8`)
Kimlik `rev_{yazan}__{hedef}` → bir kişiye bir değerlendirme, ikincisi
GÜNCELLER. **Sistem kilitliymiş:** kural `job.status in
['completed','rated']` istiyordu, iş akışı kalkınca hiçbir ilan o duruma
geçmiyordu → kimse puan yazamıyordu. Müşteri puanı artık herkese açık.
⚠️ Kullanıcı kararı: **koşul YOK** (sohbet şartı bile). Sahte hesapla puan
manipülasyonuna açık — v2'de sohbet şartı eklenebilir (altyapı hazır).

**D) MARKA: "İlanda Hizmet"** (`d72c89e`)
24 Dart metni + Android/iOS/web etiketi. Paket adı, `com.sepettehizmet.app`
ve `kProMonthlyProductId` DEĞİŞMEDİ.

**E) "Hemen Lazım" → "Kolay İş"** (`703acbe`)
Süreler 24s/3/7 → **3/5/7**; Kolay İş her zaman **1 gün**. `JobDuration.day1`
SİLİNMEDİ (Kolay İş kullanıyor + eski kayıtlar). Ana sayfada kendi tam
genişlikli kartıyla öne çıktı. Depolama kodu `quick_support` DEĞİŞMEDİ.

**F) PROFİL BİRLEŞTİRİLDİ** (`85334bc` · `ef88411` · `d547a4f`)
- Ortak alanlar (telefon, sosyal medya, web, hakkımda) `artisanProfiles`'tan
  **`users`**'a taşındı → her iki modda çalışıyor. Eski kopyalar okunuyor
  ama artık aynalanmıyor (tek doğruluk kaynağı).
- `AccountProfileEditScreen` **silindi**; tek düzenleme ekranı: üstte ortak
  alanlar, altta (usta modunda) "USTA VİTRİNİ".
- **Tek profil tasarımı:** yeni `core/widgets/profile_header.dart` — kendi
  profilim, usta profili ve müşteri profili AYNI başlığı kullanıyor. Tek
  fark düğmeler: "düzenle | bak" ↔ "Mesaj | Takip et".
- "Vitrinim" kartı kalktı, müsaitlik sade anahtar olarak başlığa taşındı.

**G) SOSYAL MEDYA DOĞRULAMA** (`3aacf4e`)
Geçersiz girdi **sessizce siliniyordu** (`controller.text = normalized ?? ''`).
Artık metin kalıyor + kırmızı hata sebebi. Boşluklu ad reddediliyor,
noktalı ad (`ahmet.usta` — Instagram'da yaygın) artık KABUL ediliyor.
Bio satırları tıklanabilir (telefon arar, link açar).

**H) YARDIM YENİLENDİ** (`703acbe`)
İçerik kaldırılmış özellikleri anlatıyordu (Eleman modülü, teklif toplama,
maskeleme). 25 soru mevcut akışa göre yazıldı, "Eleman" sekmesi kalktı.

### Deploy durumu (2026-08-09)
```
firestore.rules   ✅ DEPLOY EDİLDİ  (profileFieldsOk + değerlendirme kuralları)
functions         ✅ DEPLOY EDİLDİ  (ratingAsCustomer + "Kolay İş" push metni)
```
> Functions deploy'unda "User code failed to load / Timeout after 10000"
> alındı. Kod yerelde 1.6 sn'de yükleniyor → **ağ sorunu**.
> `NODE_OPTIONS=--dns-result-order=ipv4first` ile geçti.
> (bkz. `vault/05-Operasyon/Deploy-ve-Ortam.md` IPv4/IPv6 notu)

### Bilinen açıklar / sonraki adımlar
1. **Deploy + cihaz testi** (yukarıdaki 8 madde) — en öncelikli.
2. ~~Tur B~~ — oturum 83'te **BİTTİ**.
3. **Firestore'da ölü alan/koleksiyon temizliği** (opsiyonel): `offers`
   koleksiyonu ve ilanlardaki ölü alanlar canlıda duruyor olabilir. Kod
   onları okumuyor, zarar vermiyorlar — sırf temizlik için silinebilir.
   Bu makinede erişim yok (gcloud/ADC/servis anahtarı yok); konsoldan
   veya anahtar sağlanırsa yapılır.
4. **`vault/06-Test/` defteri iş akışına göre yazılmış** — `08-Is-Akisi.md`
   ve `06-Ilan-Alma-Usta.md` artık var olmayan adımları test ediyor.
   Defter v2 (285 adım) zaten hiç koşulmadı; koşmadan önce güncellenmeli.
5. Değerlendirmeye koşul (sohbet şartı) — v2.
6. Küfür/argo filtresi + görsel NSFW taraması — büyümeye bırakıldı.

---

<details>
<summary>Oturum 81 (2026-08-06) — değerlendirme çıkmazı + kasa</summary>

**Oturum 81: KARŞILIKLI DEĞERLENDİRME ÇIKMAZI ÇÖZÜLDÜ + OBSİDİAN MİMARİ KASASI. 319/319 test, analyze 0.**

### 🆕 Yeni oturuma başlarken
1. **`CLAUDE.md`** kökte — ajan tarafından otomatik okunur, kasaya yönlendirir.
2. **`vault/`** mimari kasası — 18 not. Giriş: `vault/00-BASLA-BURADAN.md`
   (görev tipine göre hangi notu okuyacağını söyleyen tablo).
3. Bu dosya = zaman çizgisi. Kasa = kalıcı yapı. İkisi ayrı işler.

### A) Değerlendirme çıkmazı — 3 kırık nokta (commit `d505d3f`)
**Belirti:** İş tamamlandıktan sonra sohbette "mesaj yazma izniniz yok" çıkıyor,
değerlendirme ekranı da açılmıyordu — kullanıcı çıkmaza giriyordu.

1. **`customerStarted` işi verirken yazılmıyordu.** Müşteri sohbete hiç yazmadan
   doğrudan "Bu Ustayı Seç" derse bayrak `false` kalıyor ve **seçilen usta kendi
   işinin sohbetinde yazamıyordu**. Kullanıcının gördüğü "izniniz yok" buydu —
   kilit değil, `canSend`'in usta dalı.
   → `selectArtisanForJob` artık `markCustomerStarted(chatId)` çağırıyor
   (arayüze + Firebase + Mock uygulamalarına eklendi).
   → **Kural değişikliği GEREKMEDİ:** `firestore.rules:293` (`customerStartedOk`)
   bu yazımı zaten yalnız müşteriye ve yalnız `false→true` yönünde açıyordu.

2. **"Değerlendir" düğmesi hiç çizilmiyordu.** `_JobCompletionChatBar`
   `jobByChatIdProvider`'a bağlıydı; o, ilanın `chatId` **ALANINI** sorgular ve o
   alan yalnız `selectOffer` içinde yazılır. Eşleşmeyince `job == null` → şerit
   yok → değerlendirmeye ulaşılamıyor.
   → İlan bazlı sohbette artık `thread.jobId` → `jobProvider`.
   `jobByChatIdProvider` yalnız genel sohbetler için yedek.

3. **`rated` durumu unutulmuştu.** Şerit yalnız `JobStatus.completed` arıyordu.
   İlk taraf puan verince `markRated` ilanı `rated` yapıyor ve şerit **ikinci
   taraf için tam o anda kayboluyordu** — "karşılıklı" değerlendirme bu yüzden
   hiçbir zaman tamamlanamıyordu.

**Testler:** `jobs_test.dart`'a 2 regresyon testi — biri seçim sonrası ustanın
yazabildiğini, diğeri bunun **kilidi AÇMADIĞINI** doğruluyor (başka usta seçilmiş
sohbet salt okunur kalmalı).

> ⚠️ **Geriye dönük etki:** Bu düzeltmeler YENİ akışlar için çalışır.
> `customerStarted: false` takılı kalmış MEVCUT sohbetler kendiliğinden düzelmez —
> müşteri o sohbete bir mesaj yazınca açılırlar. Toplu düzeltme istenirse tek
> seferlik CF migration gerekir.

### B) Obsidian mimari kasası (commit `db5aa25`)
**Amaç:** her oturumda 64K satır Dart + 5.1K CF + 1.3K kuralı yeniden taramadan
çalışmak (token maliyeti).

- `vault/` — 18 not, 2.201 satır, wikilink'li, graph yapılandırıldı
  - `01-Mimari` katman, repository deseni, Riverpod, rotalar, **16 ADR**
  - `02-Ozellikler` iş akışı durum makinesi, sohbet, değerlendirme, envanter
  - `03-Backend` 51 CF haritası, güvenlik kuralları, admin paneli
  - `04-Veri` Firestore şeması, veri modelleri
  - `05-Operasyon` **Bilinen-Tuzaklar** (en değerli), test stratejisi, deploy
- `CLAUDE.md` — ajanı önce kasaya yönlendirir; değişmez kurallar + asla
  değiştirilmeyecek sabitler (`usta_cepte_tracking.db`, Play ürün kimlikleri).
- Doğrulama: 0 kırık wikilink, 0 öksüz not; teknik iddialar koda karşı örneklendi.

> **Kapsam sınırı:** Kasa hedefli aramalarla çıkarıldı, 64K satırın tamamı
> okunarak değil. Mimari omurga + tuzaklar sağlam; `toolkit` / `staffing` gibi
> bu oturumda dokunulmayan modüllerin iç ayrıntısı yüzeysel (envanterde tek
> satır). Gerekirse modül bazında derinleştirilir.

### C) Sıradaki adım
- [ ] **Cihaz testi:** karşılıklı değerlendirme akışı uçtan uca (müşteri hiç
      yazmadan işi ver → usta yazabiliyor mu → iki taraf da puan verebiliyor mu)
- [ ] Takılı kalmış eski sohbetler için migration gerekli mi karar ver
- [ ] Oturum 80'den devreden cihaz testleri hâlâ bekliyor


</details>

---

## 📦 Oturum 80 (2026-08-01) — arşiv

**Oturum 80: İLAN BAZLI SOHBET MİMARİSİ + İŞ AKIŞI SADELEŞTİRME + İLAN LİMİTİ. 317/317 test, analyze 0. ✅ rules + 4 CF CANLIDA. ⚠️ CİHAZ TESTİ BEKLİYOR.**

### A) Sohbet artık İLAN BAZLI — `chat_{müşteri}__{usta}__{jobId}`
- **Önceki model:** aynı çift BÜTÜN ilanlarında tek sohbeti paylaşıyordu; `ChatThread`'de `jobId` yoktu, bağ ters yönlüydü (`jobs.chatId`) ve yalnız `selectOffer`'da yazılıyordu → sohbette hangi işin konuşulduğu belirsizdi.
- **Eski iki parçalı kimlikler ÇALIŞMAYA DEVAM EDER** (ürün/eleman sohbetleri + geçiş öncesi kayıtlar). Göç YOK; `_uidsFromChatId` iki biçimi de çözer, `jobId` null ise "genel sohbet".
- **⚠️ `ensureChatReady` en kırılgan yerdi:** chatId parse edemezse hiçbir şey yazmıyor ve hata da vermiyor (sessiz başarısızlık). Kimlik biçimi değişirken ilk güncellenen yer burası oldu.
- `ChatThread` yeni alanlar: `jobId`, `jobTitle` (denormalize — liste/AppBar ekstra okuma yapmasın), `customerStarted`, `lockedAt`, `lockReason`.

### B) İletişimi MÜŞTERİ başlatır (§2)
- Usta ilk mesajı atamaz. **Kural motoru "bu sohbette müşteri mesajı var mı" diye sorgulayamaz** → `customerStarted` bayrağı DENORMALIZE tutulur, ilk müşteri mesajında yazılır.
- Kural: bayrağı yalnız müşteri ve yalnız `false→true` yazabilir (`customerStartedOk`) — usta kendi yazma iznini açamaz, müşteri de geri alıp ustayı susturamaz.
- UI: yazma izni yoksa giriş kutusu yerine `_BlockedComposerNotice` (gerekçeyle).

### C) Usta seçimi sohbete taşındı + diğer sohbetler kilitlenir (§3)
- "Ustayı Seç" düğmesi teklif listesinden KALKTI, ustayla konuşulan sohbetin üstüne geldi (`_JobSelectBar`). İlan detayındaki kart artık yalnız "Mesaj Gönder".
- **Kilitleme CF'de** (`lockOtherJobChats`): istemci yapamaz — kural hem başkasının sohbetine yazmayı hem `lockedAt` alanını kapatır. Aksi halde seçilmeyen usta kendi kilidini açardı.
- **SEÇİM İPTALİ (yeni):** usta işi yarıda bırakırsa müşteri ilanı yeniden açar → kilitler kalkar, teklifler `pending`e döner. `ownerNoReassignArtisan` gevşetildi ama **A→B doğrudan geçiş hâlâ yasak** (iptal edip yeniden açmak gerekir). Kötüye kullanım freni: **3. iptalde ilan kapanır**.

### D) "İşe başladım" kaldırıldı + sistem mesajları (§4)
- Buton kalktı; usta doğrudan tamamlama onayı veriyor. **`inProgress` enum'u KODDA KALDI** — `statusBeforeDispute` eski kayıtlarda bu değeri tutuyor, silinseydi eski `disputed` işler geri çekilemezdi (30+ dokunma noktası da cabası).
- Yaşam döngüsü artık sohbette **sistem mesajı** olarak görünür (`type: "system"`, yalnız CF yazar — kural allowlist'inde yok, sahte "Usta seçildi" üretilemez).

### E) Çift taraflı değerlendirme (§5)
- `reviews` kimliği yöne göre ayrışır: `{chatId}` = c2a (müşteri→usta, **eski kayıtlarla aynı kimlik**), `{chatId}__a2c` = usta→müşteri.
- **Müşteri puanı YALNIZ USTALARA görünür** → herkese açık `users` dokümanına değil `users/{uid}/private/rating` altına yazılır (CF). Müşteri profili vitrin değildir; düşük puanlı müşterinin hizmet alamaz hale gelmesi istenmiyor.
- `getArtisanReviews` artık `a2c` kayıtlarını eler (usta vitrinine sızmasın).

### F) 7 gün sonra ARŞİVLEME — silme DEĞİL (§6)
- **Kullanıcı "otomatik silme" istemişti; itiraz edildi ve arşivlemede karar kılındı.** Kalıcı silme (a) anlaşmazlık kanıtını, (b) review bağını (`reviews` kimliği chatId'ye dayanır), (c) admin transcript'ini götürürdü — 8. günde gelen şikayet çözümsüz kalırdı. "Veritabanı şişkinliği" gerekçesi de sayısal olarak zayıf (10k iş × 50 mesaj ≈ 500k doküman, Firestore'da önemsiz).
- `archiveCompletedChats` (24 saatte bir): `completedAt <= now-7gün` → sohbet salt okunur + `chatsArchivedAt` damgası. Şablon: `purgeRemovedProducts`.

### G) İLAN LİMİTİ — önceden HİÇ YOKTU 🔴
- **Açık güvenlik boşluğuydu:** yayınlanan her ilan eşleşen TÜM ustalara bildirim gönderiyor (`onJobCreated` fan-out); limitsiz kullanıcı platform çapında spam üretebiliyordu.
- **5 açık ilan** (kural kapısı) + **10/gün** (CF). Kural `count()` yapamadığı için `openCount` `users/{uid}/private/jobStats`'ta denormalize — yalnız CF yazar. Günlük hak `adminRateLimits` deseniyle (`createSupportTicket`/`publishProduct` paritesi); aşılırsa ilan `cancelled` + `cancelReason: rateLimited` (yeni enum) ve fan-out yapılmaz.

### H) Kaldırılan (Oturum 79'da eklenmişti)
`_JobSelectChatBar` + `selectableJobsForChatProvider` + `offersFromArtisanProvider` + `watchOffersFromArtisan` (3 katman) + 6 test. Varlık sebepleri "sohbet ilandan türemiyor"du; artık türüyor.

**CANLIDA:** `firestore:rules` + `onJobWritten`/`onJobCreated`/`onReviewWritten` (güncel) + `archiveCompletedChats` (yeni). `functions:list` ile doğrulandı, STARTUP probe OK, `Cannot find module`/`is not a function` YOK.

**SIRADAKİ:** ⚠️ **CİHAZ TESTİ** — iki hesapla (müşteri + usta) uçtan uca: ilgi bildirimi → müşteri sohbeti başlatır → usta yanıtlar → seçim → diğer sohbet kilitli → tamamlama → çift değerlendirme. Ayrıca ilan limiti (6. ilan reddedilmeli) ve seçim iptali denenmeli.

--- (önceki oturumlar) ---

**Oturum 79 (2026-08-01): FIREBASE YENİ PAKET KAYDI + WEB APP CHECK. 306/306 test, analyze 0. ✅ Android CİHAZDA DOĞRULANDI, admin hosting CANLIDA. ⚠️ SHA-256 + iOS AÇIK.**

### A) Android kaydı `com.sepettehizmet.app` (CİHAZDA DOĞRULANDI ✅)
- Oturum 78'in bekleyen 5 maddesi kapandı. `google-services.json` yeni kayıtla indirildi; **iki `client_type: 1` girdisi** (debug + release SHA-1) dosyada doğrulandı. `flutterfire configure` ile appId yenilendi: `…android:53a729b7` (ESKİ `com.ustasindan.app`) → **`…android:07beea07`**.
- **İlk indirme EKSİKTİ:** SHA'lar Console'a girilmeden önce indirilmiş olduğu için dosyada hiç `client_type: 1` yoktu (yalnız web client). Google girişi bu hâliyle `sign_in_failed` verirdi. **Ders: SHA ekledikten SONRA dosyayı tekrar indir** — SHA'lar dosyaya sonradan yansımaz.
- Doğrulama zinciri uçtan uca kontrol edildi: json → `firebase_options.dart` → Gradle'ın ürettiği `google_app_id` (`build/app/generated/res/processDebugGoogleServices/values/values.xml`) → APK. Cihazda (Xiaomi 22101316G, Android 14) Google girişi **hatasız**; logcat'te `sign_in_failed` / `ApiException` YOK.
- **App Check debug token** kaydedildi (`76d6d9ce-…`). Öncesinde `403 App attestation failed` alınıyordu, kayıttan sonra kayboldu. Ürün paylaşımı + profil fotoğrafı yükleme cihazda çalıştı.
- **⚠️ ESKİ KAYITTA HİÇ SHA YOKTU:** `com.ustasindan.app` kaydında parmak izi hiç girilmemiş — o kimlikle Google girişi zaten çalışmıyordu. Yeni kayıtta tekrarlanmadı.

### B) Web App Check ETKİNLEŞTİRİLDİ (CANLIDA ✅)
- **Admin paneli korumasız yayındaydı.** `kAppCheckWebRecaptchaKey` boş olduğu sürece `main.dart` / `main_admin.dart` App Check'i **hiç activate etmiyordu** (kod `isNotEmpty` kontrolüne bağlı). reCAPTCHA v3 anahtarı üretildi, site anahtarı `backend_config.dart`'a yazıldı, gizli anahtar Console'daki web app kaydına girildi.
- Admin hosting deploy edildi; yayınlanan `main.dart.js` içinde anahtar **curl ile doğrulandı**. Site anahtarı gizli değildir (tarayıcı kaynağında görünür) — koruma kayıtlı alan adlarından gelir, yeni alan adı eklenirse reCAPTCHA panelinde de tanımlanmalı.
- **Web appId'si YENİLENMEDİ (gerek yok):** web kayıtları paket kimliğine bağlı değildir, paket adı değişikliği web'i etkilemedi.

### C) `_healLegacyThreads` KALDIRILDI (ölü kod)
- `members` haritası olmayan eski sohbetleri onarmak için yazılmıştı ama **hiçbir zaman çalışmadı**: `participants array_contains` ile sorguluyordu ve kurallar bunu reddediyor (`firestore.rules` "chats" notu — kural motoru array-contains'te üyelik ispatını yapamıyor; liste sorgusu bu yüzden `members.<uid> == true`'ya taşınmıştı, **heal fonksiyonu eski sorguda kalmış**).
- Tek etkisi her açılışta yutulan bir `permission-denied` üretmekti (`catch (_)`), bu da debugger'ı duraklatıyordu. Yerine neden kaldırıldığı + geriye dönük veri çıkarsa onarımın **Admin SDK'lı bir CF'den** yapılması gerektiği not olarak bırakıldı. `_membersFromChatId` duruyor (ensureChat + chatMeta yollarında kullanılıyor).

### D) İncelendi, DEĞİŞTİRİLMEDİ
- **`adminStats/global` → PERMISSION_DENIED bir hata DEĞİL:** `home_stats.dart` bunu kasıtlı yapıyor — doküman yalnız admin'e açık, normal kullanıcıda okuma başarısız olunca bölüm gizleniyor ve sahte rakam gösterilmiyor (dosyada gerekçe yazılı). Loglarda görünür ama davranış doğru.
- **`firebase.json`:** `flutterfire configure` dosyayı tek satıra sıkıştırmış ve `--platforms=android` yüzünden `dart.configurations`'tan ios/web anahtarlarını düşürmüştü. Okunabilir hâle geri getirildi, iki anahtar korundu (hosting/functions/firestore/storage ayarları zaten kaybolmamıştı).

### ⚠️ AÇIK KALANLAR
1. **SHA-256 Console'a eklenmeli** (verildi, eklendiği doğrulanmadı): release'te `AndroidProvider.playIntegrity` kullanılıyor ve SHA-256 istiyor. Eksikse **yayınlanan APK'da App Check kırılır** → kullanıcılar `permission-denied` alır. Debug'da `AndroidProvider.debug` kullanıldığı için fark edilmez.
2. **iOS:** Console kaydı ve `GoogleService-Info.plist` **yok** (dosya hiç mevcut değil → iOS build zaten yapılamıyor). `firebase_options.dart`'taki ios appId hâlâ ESKİ `com.ustacepte.ustaCepte` kaydının; dosyada ⚠️ notu duruyor. Xcode tarafı `com.sepettehizmet.app`'e taşınmış durumda.
3. **Play App Signing:** Store'a çıkarken Play Console → App signing'deki **app signing key** SHA'ları ayrıca eklenmeli — upload key'inkiler yetmez, yoksa mağazadan inen sürümde Google girişi çalışmaz.
4. **Profil kaydetme hatası (KÖK NEDEN BULUNAMADI):** telefon + sosyal medya alanları doldurulunca `Write failed at artisanProfiles/{uid}: PERMISSION_DENIED` alındı, sonra kendiliğinden düzeldi. Payload ile `firestore.rules` karşılaştırıldı, ihlal bulunamadı (`toMap()` sunucuya ait alan üretmiyor, `socialLinks` kuralı kodla uyumlu). Şüphe: `serviceProvincesOk()` (`provs.size() <= areas.size()`) veya geçici App Check token durumu. **Tekrarlarsa logcat'ten yakalanmalı.**

**SIRADAKİ:** SHA-256 doğrula → cihaz testi (Hemen Lazım akışı + mesaj moderasyonu + AR) → Play Console ilk yükleme. Açık kalanlar: dinamik meslek yönetimi, admin rehber/SSS bloğu, ESLint 9 config migrasyonu (Oturum 74'ten).

--- (önceki oturumlar) ---

**Oturum 78 (2026-08-01): PAKET YÜKSELTMESİ + PROJE ADI "SEPETTE HİZMET". 306/306 test, analyze 0. ✅ Functions CANLIDA. ✅ Firebase kaydı Oturum 79'da TAMAMLANDI.**

### A) firebase-functions 7 + firebase-admin 14 (CANLIDA ✅)
- **Deploy uyarısı kapandı.** Ama iş göründüğünden büyüktü: **firebase-admin v14 eski namespace API'sini TAMAMEN KALDIRMIŞ** → `admin.firestore` / `admin.auth` / `admin.storage` / `admin.messaging` = `undefined`. **71 çağrı noktası** modüler alt yollara çevrildi (`getFirestore()`, `FieldValue`, `getAuth()`, `getStorage()`, `getMessaging()`).
- **İki ayrı v7 kırılması:** (1) `logger` artık kök export'ta değil → `firebase-functions/logger`. (2) **`require("firebase-functions/v2")` TÜM v2 ağacını çeker**; içindeki database sağlayıcısı `@firebase/app` peer'ini ister, npm bunu kurmaz ve **cold start'ta patlar**. `setGlobalOptions` zaten `firebase-functions/v2/options` altında → yalnız o alt yol alındı.
- **⚠️ DERS — `node --check` YETMEZ:** yalnız söz dizimine bakar. İlk denemede `node --check` GEÇTİ ama `require('./index.js')` patlıyordu; deploy edilseydi **51 fonksiyonun tamamı cold start'ta düşerdi**. Doğrulama yöntemi: gerçek `require()` + export sayımı (51). Deploy önce TEK fonksiyonla (canary) yapıldı → revizyon ACTIVE + "STARTUP TCP probe succeeded" → sonra tamamı. Son 200 log satırında `Cannot find module` / `is not a function` YOK.

### B) Proje adı: "Ustasından" → **"Sepette Hizmet"**
- **Üç katman ayrı ayrı ele alındı:** (1) marka adı 60 yerde (lib/web/hosting/manifest/AndroidManifest/Info.plist), (2) Dart paketi `usta_cepte` → `sepette_hizmet` (174 import / 35 dosya + pubspec + .iml), (3) paket kimliği `com.ustasindan.app` → **`com.sepettehizmet.app`** (Android namespace + applicationId + **MainActivity.kt dizin yolu taşındı** + iOS pbxproj 6 yer).
- **iOS tutarsızlığı düzeltildi:** iOS bundle `com.ustacepte.ustaCepte` idi (Android'den FARKLI, iki isim öncesinden kalma) → artık Android ile aynı.
- **TÜRKÇE EK UYUMU:** toplu değiştirme "Sepette Hizmet'ın / 'da" gibi bozuk ekler üretti ("Hizmet" ince ünlü + sert ünsüz) → `'te` / `'in` / `'ten` olarak düzeltildi.
- **🔴 BULUNAN GERÇEK BUG:** `force_update_screen.dart` Play mağaza kimliğini `com.ustacepte.usta_cepte` tutuyordu — **zaten mevcut applicationId ile uyuşmuyordu**. Zorunlu güncelleme ekranındaki "Güncelle" düğmesi VAR OLMAYAN mağaza sayfasına gidiyordu → kullanıcı güncellenemez halde kilitli kalırdı. Düzeltildi + "applicationId ile AYNI olmak zorunda" uyarısı eklendi.
- **⚠️ BİLEREK DEĞİŞTİRİLMEYENLER (koda gerekçe yazıldı):** (a) `_dbName = 'usta_cepte_tracking.db'` — cihazdaki SQLite DOSYA ADI; değişirse mevcut kullanıcıların **tüm Takip Merkezi kayıtları kaybolmuş görünür**. (b) Play ürün kimlikleri (`usta_cepte_pro_monthly`) — Console'da oluşturulduktan sonra ASLA değişmez, kullanıcıya görünmez; Console'da henüz oluşturulmadıysa yenilemek serbest (billing_config.dart'ta not var).
- **DERLEME DOĞRULANDI:** `flutter build apk --debug` önce `google-services.json`'da yeni paket olmadığı için düştü (BEKLENEN). Geçici bir istemci girdisiyle tekrar denendi → **`√ Built app-debug.apk`** (yani namespace + MainActivity taşıma + pbxproj değişikliklerinin hepsi doğru). Geçici girdi **GERİ ALINDI** — sahte kimlik commit'lenmedi.

### ⚠️ SİZİN YAPMANIZ GEREKENLER (Firebase Console) — **Oturum 79'da KAPANDI**
1. ~~**Android:** Yeni app kaydı `com.sepettehizmet.app` (+ SHA-1/SHA-256) → `google-services.json`~~ → ✅ Oturum 79/A (SHA-256 hariç: hâlâ açık).
2. **iOS:** Yeni app kaydı `com.sepettehizmet.app` → `GoogleService-Info.plist` indir. → ⏸ **HÂLÂ AÇIK** (Oturum 79 "Açık Kalanlar" §2).
3. ~~`flutterfire configure` → appId'ler yenilenir~~ → ✅ Oturum 79/A (Android). iOS/web appId'leri için not: web'inki zaten geçerli, iOS'unki iOS kaydı açılınca yenilenecek.
4. ~~**App Check debug token** yeniden kaydedilmeli~~ → ✅ Oturum 79/A.
5. ~~Bunlar bitmeden `flutter build apk` çalışmaz~~ → ✅ derleniyor + cihazda çalışıyor.

**SIRADAKİ:** ~~Firebase kayıtları → APK derle~~ (bitti) → cihaz testi (Hemen Lazım + mesaj moderasyonu + yeni isim) → Play Console ilk yükleme. Açık kalanlar: dinamik meslek yönetimi, admin rehber/SSS bloğu, AR cihaz testi.

--- (önceki oturumlar) ---

**Oturum 77 (2026-08-01): MESAJ MODERASYONU (Trust & Safety zinciri tamamlandı). 306/306 test, analyze 0. ✅ HER ŞEY CANLIDA (rules + 1 yeni CF + 1 güncel CF + admin hosting).**
- **⚠️ ÖNCE KOD TABANI TARANDI — NOT ESKİMİŞTİ:** Oturum 75 "bayraklı mesaj kuyruğu YOK" diyordu. Gerçekte mesaj şikayeti **uçtan uca ZATEN VARDI**: `ReportTarget.message` tanımlı, sohbette basılı tut → şikayet et bağlı (`chat_screen.dart`), `reports` kuyruğu + admin ekranı + `adminGetChatTranscript` (rate limit 20/saat + audit log) çalışıyordu. Körlemesine yazılsaydı **ikinci bir kuyruk** kurulacaktı. Yalnız 3 gerçek boşluk dolduruldu.
- **(1) MESAJ KALDIRMA — EN KRİTİK BOŞLUK (`adminModerateMessage`, YENİ CF):** Şikayet doğrulansa bile taciz/dolandırıcılık mesajı sohbette KALIYORDU; moderatörün tek seçeneği kullanıcıyı askıya almaktı (orantısız). Artık moderatör mesajı kaldırabiliyor. **GÜVENLİK: hedef mesaj SUNUCUDA şikayet kaydından türetilir** — istemci chatId/msgId GÖNDERMEZ, yoksa yetkili bir moderatör herhangi bir sohbetteki herhangi bir mesajı gizleyebilirdi. Kural tarafı da kapalı: `messages` update yalnız gönderenin yumuşak silmesine açık, `moderationHidden` hasOnly listesinde YOK.
- **(2) `moderationHidden` ≠ `deleted` (BİLEREK AYRI ALAN):** Mevcut `deleted`e yazılsaydı karşı taraf yönetici kararını "gönderen sildi" sanardı. Ayrı alan + ayrı metin ("Bu mesaj yönetici tarafından kaldırıldı", tokmak ikonu). Modelde tek kapı `isRedacted` — `chat_screen`'deki 7 `deleted` kontrolünün **hepsi** gözden geçirildi (kopyala/sil/şikayet/seçim/tik/metin). **Gönderen kararı geri alamaz:** rules'ta kaldırılmış mesajda update TAMAMEN kapalı (aksi halde üstüne "silindi" yazıp etiketi değiştirebilirdi).
- **(3) TRANSCRIPT OKUNABİLİRLİĞİ + KANIT:** Kanıt ekranı 100 mesajlık düz listeydi, gönderenler **ham uid**, şikayet edilen mesaj işaretsizdi. Artık: şikayet edilen mesaj **vurgulanır + otomatik kaydırılır**, uid→ad çözülür (`db.getAll`, tek batch), zaten kaldırılmış mesajlar rozetli. **KANIT SAKLAMA:** kaldırma anında mesaj metni `reports.evidence*` alanlarına kopyalanır → sohbet/mesaj sonradan silinse de kararın gerekçesi durur. Yalnız İLK kaldırmada yazılır (geri al→tekrar kaldır akışında ilk kanıt korunur). Rules: `evidence*` istemci yazımına kapalı (şikayetçi sahte kanıt uyduramaz).
- **Not:** Moderatörün transcript'inde yönetici-kaldırdığı mesaj GÖRÜNÜR kalır (kararı denetleyen kişi neyi kaldırdığını görmeli); kullanıcının KENDİ sildiği içerik sunucuda da verilmez (mevcut davranış korundu).
- **Denetim:** `hide_message` / `unhide_message` audit action'ları + TR etiket + Şikayet kategorisi + ikon eklendi (yoksa panelde ham kod görünüp filtreye düşmeyecekti).
- **Test:** admin_test +5 — `targetId` çözümü (chat id'leri `chat_{uid}__{uid}` kalıbında olduğundan **`split('_')` mesaj kimliğini BOZARDI** → prefix soyma; başka sohbetin targetId'si null döner = yönetici rastgele mesaj kaldıramaz), bozuk girdi, mock kaldır/geri al, audit kategorisi. Biçim tek kaynağa alındı: `messageReportTargetId` / `messageIdFromReportTarget` (CF paritesi). Toplam **306/306**, analyze 0, `node --check` OK.
- **DEPLOY TAMAMLANDI ✅ (hepsi ilk denemede):** `firestore:rules` → canlı · `adminModerateMessage` (YENİ) + `adminGetChatTranscript` (güncel) → `functions:list` ile CANLIDA DOĞRULANDI · `flutter build web -t lib/main_admin.dart` + `hosting:alljob1-admin` → https://alljob1-admin.web.app güncel.
- **⚠️ KULLANICI TESTİ:** alljob1-admin.web.app → Şikayetler → bir MESAJ şikayeti aç → "Sohbet kanıtını aç" (şikayet edilen mesaj sarı vurgulu + isimler) → "Mesajı kaldır" (onay ister) → uygulamada iki tarafta da "yönetici tarafından kaldırıldı" görünmeli. NOT: `chats.read` + `reports.manage` yetkileri gerekli.
- **SIRADAKİ (kullanıcı seçecek):** (a) Dinamik meslek yönetimi (ağır, `kProfessionNames` derleme sabiti) · (b) Rehber/SSS admin bloğu (hafif) · (c) cihaz testi (Hemen Lazım akışı + mesaj moderasyonu + AR + App Check debug token) · (d) ESLint 9 config migrasyonu (Oturum 74'ten açık; deploy'u engellemiyor ama `firebase-functions` sürüm uyarısı veriyor).

--- (önceki oturumlar) ---

**Oturum 76 (2026-08-01): "HIZLI DESTEK" → "HEMEN LAZIM" YENİDEN KONUMLANDIRMA. 301/301 test, analyze 0, rules dry-run OK. ⚠️ RULES + FUNCTIONS DEPLOY BEKLİYOR.**
- **İSİM DEĞİŞTİ (kullanıcı seçti): "Hızlı Destek (ayak işleri)" → "Hemen Lazım".** "Ayak işleri" ibaresi HER YERDEN kaldırıldı (küçültücü ton). **DEPOLAMA KODLARI DEĞİŞMEDİ** — `quick_support` (ilan kategorisi) ve `other` (usta kodu) aynı kaldı; yalnız görünen ad değişti. Yeni sabit `kQuickSupportName` (job.dart) → metinler tek noktadan değişir. Veri göçü GEREKMEZ.
- **(1) USTA PROFİLİNDE AYRI ANAHTAR:** Hemen Lazım artık meslek listesinin İÇİNDE bir satır değil, meslek seçiminin HEMEN ÜSTÜNDE ayrı bir `Switch` (`_QuickSupportSwitch`). Meslek listesinden (`_ProfessionMultiSelect`) ve `professions.json` seçilebilirlerinden süzülüp çıkarıldı; sayaç/chip'ler onu saymaz, "Temizle" düğmesi anahtarı BOZMAZ. Yeni controller API: `quickSupportEnabled` + `setQuickSupportEnabled`. **maxProfessions (5) sınırı anahtarı ENGELLEMEZ** — meslek değil, ayrı hizmet tercihi (5 meslekli usta da açabilir). **Kapatma legacy `quick_support` kodunu DA temizler** — yalnız `other` silinseydi anahtar kapalı görünüp ilanlar gelmeye devam ederdi (test edildi).
- **(2) İLÇE → İL GENELİ (kullanıcı kararı: il geneli + ilçe önceliği):** Hemen Lazım ilanı artık ilan sahibinin İLİNDEKİ tüm Hemen Lazım ustalarına gider (eskiden aynı ilçe şartı vardı → kısa işlerde usta azlığından çoğu ilan alıcısız kalıyordu). **Klasik meslek ilanları İLÇE şartını AYNEN korur** (regresyon testi yazıldı). Aynı ilçedekiler elenmez, ÖNE ALINIR: yeni `sortJobsForArtisanFeed` (Hemen Lazım üstte → kendi ilçesi önce → en yeni) + kartta yeşil **"Yakınında"** rozeti (`NearbyJobCard.isNearby`).
- **⚠️ 3 KATMANLI PARİTE ŞART — hepsi güncellendi:** istemci `Job.matchesArtisan` (job.dart) · CF `onJobCreated` (il eşleşmesi + bildirim başlığı artık İL yazar, uzak ilçe "bölgenizde" sanılmasın) · **rules `artisanMatchesOpenJob`**. Rules'ta il kontrolü için YENİ ALAN `serviceProvinces` gerekti — **kurallar string ayıramadığından `"İl|İlçe"` anahtarından il çıkarılamıyor.** Alan `toMap` + `_healMatchFields` ile yazılır (mevcut ustalar ilk profil okumasında KENDİLİĞİNDEN onarılır, elle işlem yok). Kötüye kullanıma karşı `serviceProvincesOk()`: `serviceProvinces.size() <= serviceAreas.size()` → usta tek bölge seçip 81 il yazıp tüm ülkenin ilanlarına teklif veremez.
- **(3) ANA SAYFA "⚡ HEMEN LAZIM" ŞERİDİ (`home_quick_support.dart`):** ilan başlığı + ilan sahibinin profil fotoğrafı + ilçe kartları, yatay şerit + "Tümünü Gör →". **Hemen Lazım ilanı yoksa bölüm TAMAMEN gizlenir** (boş başlık bırakmaz). Yeni `quickSupportJobsProvider` `openJobsProvider`'dan SÜZER → ek Firestore sorgusu/indeksi YOK, mevcut ana sayfa yenilemesi bu bölümü de tazeler. Yeni ekran + rota `/jobs/quick` (`QuickSupportJobsScreen`). **DİKKAT: rota `/jobs/:jobId` deseninden ÖNCE tanımlandı**, yoksa "quick" ilan kimliği sanılırdı. Misafire AÇIK (vitrin; guard'da `jobsBase` istisnası) — ilan detayı + teklif yine oturum ister, misafire giriş çağrısı gösterilir.
- **(4) MÜŞTERİ TARAFI ÖNE ÇIKARMA:** ana sayfa ikincil aksiyonu müşteride "Ürünleri Keşfet" yerine **"⚡ Hemen Lazım"** (Ürünler zaten alt bar + Keşfet'te). `/jobs/new?kind=quick` → ilan formu kategori SEÇİLİ açılır (`CreateJobScreen.initialCategory`; kilitlenmez, değiştirilebilir). Ustada ürün kısayolu korundu.
- **Diğer metinler:** SSS'e "Hemen Lazım ilanları hangi bölgeden gelir?" maddesi eklendi (il geneli + Yakınında rozeti açıklanır); tanıtım sheet'i, ilan formu bilgi kutusu, üyelik paketi, `shop_completion` ipucu, kaydetme doğrulama mesajı ("...veya anahtarı açın") güncellendi. Mock seed'de `other` ustalarına ayrı tanıtım metni (yoksa "Hemen Lazım olarak çalışıyorum" gibi anlamsız cümle çıkıyordu).
- **BULUNAN VE DÜZELTİLEN GERÇEK BUG:** `sortJobsForArtisanFeed` yakınlık haritasını önce `jobId` ile anahtarlıyordu; **kaydedilmemiş ilanlarda (ve testlerde) jobId boş** olduğundan hepsi tek anahtara düşüp birbirinin değerini eziyordu → `Map.identity()` ile nesne kimliğine geçildi.
- **Test:** YENİ `test/quick_support_test.dart` (4: bölüm boşsa gizlenir, klasik ilan şeride sızmaz, boş müşteri adı → "Komşunuz", provider süzmesi) + `jobs_test` Hemen Lazım grubu yeniden yazıldı (il geneli eşleşme, klasik ilçe regresyonu, isNearbyForAreas, feed sıralaması) + `my_profile_test` +4 (anahtar meslekleri bozmaz, 5 meslek doluyken açılır, legacy kod temizliği, serviceProvinces senkronu). Toplam **301/301**, analyze 0, `node --check` OK, rules dry-run OK.
- **⚠️ DEPLOY BEKLEYEN (kullanıcı onayı gerekir):** (a) **`firestore:rules`** — `serviceProvinces` + Hemen Lazım il eşleşmesi. **Bu deploy EDİLMEDEN Hemen Lazım ilanlarına başka ilçeden teklif verilemez** (kural reddeder; istemci izin verse de sunucu keser). (b) **`functions`** — `onJobCreated` il düzeyi bildirim. Deploy edilmezse başka ilçedeki ustalara PUSH gitmez (uygulama içi liste yine çalışır).
- **SIRADAKİ:** rules+functions deploy → cihazda Hemen Lazım akışı testi (profil anahtarı → ilan ver → başka ilçeden görünüyor mu + "Yakınında" rozeti) → ESLint 9 config migrasyonu (Oturum 74'ten açık).

--- (önceki oturumlar) ---

**Oturum 75 (2026-07-31): ADMIN EKSİK MODÜLLERİ + DEPLOY. 289/289 test, analyze 0. ✅ HER ŞEY CANLIDA (rules + 5 yeni CF + admin hosting).**
- **⚠️ GEMINI PROMPT'U DEĞERLENDİRİLDİ:** Kullanıcı Gemini'nin ürettiği 6 modüllük admin prompt'unu getirdi. Kod tabanı taranınca **istenenlerin ~%60'ı ZATEN VARDI** (Modül 5 feature flags = `admin_settings_screen`, Modül 6 export+destek = `admin_export_util`+`admin_support_screen`, RBAC 18 yetki, audit log, `adminGetChatTranscript`, askıya alma). Körlemesine uygulansa çalışan kodun üzerine ikinci kopyalar yazılacaktı. **Yalnız gerçek boşluklar dolduruldu.**
- **(1) MANUEL PREMIUM (`adminGrantPremium` + `admin_premium_sheet.dart`):** `verifyMembershipPurchase` Play makbuzuna dayanır; destek senaryolarında (ödeme alındı/doğrulama düştü, telafi, kampanya) makbuzsuz premium verme yolu yoktu. Gerekçe ZORUNLU (audit log). **UZATMA MANTIĞI:** mevcut bitiş ileri tarihliyse süre ONUN ÜZERİNE eklenir — düz "bugün+N" yazılsaydı 100 günü kalan üyeye 30 gün verilince üyelik KISALIRDI. Play kaydına dokunmaz; manuel iz ayrı `premiumOverrides` koleksiyonunda (rules: istemciye tamamen kapalı). **YENİ YETKİ `finance.manage`** — varsayılan moderatör setinde BİLEREK yok (para etkili).
- **(2) 360° KULLANICI KARTI (`adminUserSummary` + `admin_user_overview.dart`):** kullanıcı sheet'i yalnız ad/e-posta gösteriyordu; moderatör "ne yapmış" bilmeden askıya alıyordu. Artık ilan/açık ilan/teklif/değerlendirme/ürün + hakkında ve tarafından açılan şikayet sayıları + usta premium/onay/puan durumu. Sayımlar `count()` aggregate (doküman okumaz, indeks istemez); sayım düşen alan null → UI'da "0" değil "—". **DİKKAT: alan adları kod tabanından doğrulandı** — `offers` KÖK koleksiyon + `artisanId`, `reviews` KÖK + `artisanUID`, ürün `ownerUid`. Tahminle yazılsaydı sorgular sessizce 0 dönerdi.
- **(3) DAHİLİ ADMIN NOTLARI (`adminAddUserNote`/`adminListUserNotes`):** append-only (silinmez), rules'ta `adminUserNotes` istemciye TAMAMEN kapalı — kullanıcı hakkında yazılanları okuyamamalı.
- **(4) BELGE (SERTİFİKA) DOĞRULAMA (`adminReviewCertificates` + `admin_certificate_sheet.dart`):** Uygulama ustaya *"Belgeler yönetici onayından geçer"* DİYORDU ama mekanizma YOKTU — verilmiş ama karşılanmayan söz. Model'e `certificateStatus` (none/pending/approved/rejected) + red gerekçesi; rules'ta istemci yazımına kapalı (usta kendini "belgeli" ilan edemez). **`onArtisanProfileWritten` trigger'ı belge listesi değişince durumu otomatik `pending`e döndürür** → onay alıp sonra belge değiştirerek rozeti korumak imkânsız. Kullanıcı kararı: **usta bazında tek onay** + **etki yalnız rozet** (mavi tik mantığına DOKUNULMADI). Reddetmede gerekçe zorunlu ve ustaya bildirim gider. Usta kendi profilinde durumu + red gerekçesini görüyor.
- **DEPLOY TAMAMLANDI ✅ (hepsi İLK denemede):** `firestore:rules` → canlı · 5 yeni CF (`adminGrantPremium`, `adminUserSummary`, `adminAddUserNote`, `adminListUserNotes`, `adminReviewCertificates`) + `onArtisanProfileWritten` güncellemesi → `functions:list` ile CANLIDA DOĞRULANDI · `flutter build web -t lib/main_admin.dart` + `hosting:alljob1-admin` → https://alljob1-admin.web.app güncel.
- **Test:** admin_test +12 (premium uzatma/kısaltma regresyonu, gerekçe zorunluluğu, belge onayının mavi tike dokunmaması, not sıralaması). Toplam **289/289**, analyze 0.
- **⚠️ KULLANICI TESTİ:** alljob1-admin.web.app → Ustalar sekmesi → bir usta kartında **Premium** ve **Belgeler** düğmeleri; Kullanıcılar sekmesi → bir kullanıcıya dokun → altta **aktivite özeti + dahili notlar**. NOT: `finance.manage` yetkisi superadmin'de var; moderatör hesabına Kadro'dan açıkça verilmeli.
- **SIRADAKİ (kullanıcı seçecek):** (a) Rehber + Yardım/SSS bloğu (hafif, deploy'suz) · (b) Bayraklı mesaj kuyruğu (Trust & Safety — CF+şema+rules, ağır) · (c) Dinamik meslek yönetimi (ağır, `kProfessionNames` derleme sabiti) · (d) cihaz testi (AR + App Check debug token + bu oturumun değişiklikleri).

--- (önceki oturumlar) ---

**Oturum 74 (2026-07-31): 7 MADDELİK HATA LİSTESİ + DENETİM. 272/272 test, analyze 0, rules dry-run OK. ⚠️ RULES + FUNCTIONS DEPLOY BEKLİYOR.**
- **(1) Ana sayfa yenileme YOKTU** → `RefreshIndicator` + `AlwaysScrollableScrollPhysics`; 4 provider invalidate edilir, her biri kendi hatasını yutar (biri düşerse diğerleri yenilenir).
- **(2) "İş Ver" → "İş İlanı Ver"** (`home_quick_access.dart`).
- **(3) HESAP SİLME — KOD DOĞRUYDU, ENGEL APP CHECK.** CF `deleteAccount` canlıda (`functions:list` ile teyit) ve Firestore+Storage+Auth'u siliyor, istemci `signOut()` yapıyor. Sorun: CF `enforceAppCheck:true`; cihaz debug token'ı Console'da kayıtlı değilse istek handler'a VARMADAN reddediliyor → kullanıcı sebepsiz "silinemedi" görüyordu (Oturum 68'deki "Yayınla" hatasının aynısı). Hata kodu artık TR mesaja çevriliyor (`_deleteErrorMessage`) + ham hata `debugPrint`. **KULLANICI: Console → App Check → debug token ekle.**
- **(4) Ana sayfadaki arama kutusu KALDIRILDI** (Keşfet'te gerçek arama var; kutu yalnız oraya yönlendiriyordu).
- **(5) MESAJLAR PROFESYONELLEŞTİ:** Tümü/Okunmamış/Arşiv sekmeleri · sohbet sabitleme (sabitliler üstte) · arşivleme · okundu/iletildi tikleri. Arşiv+pin KİŞİSEL (`archivedBy`/`pinnedBy` map alanları, `clearedAt` kalıbı); yeni mesaj sohbeti ALICI'nın arşivinden çıkarır, gönderenin arşivi korunur. Arama artık son mesaj içinde de arıyor + `foldTrSearch` (Türkçe 'İ' hatası buradaydı).
- **(6) TELEFON + SOSYAL MEDYA:** `showPhoneOnProfile` altyapısı ZATEN vardı ama UI'dan erişilemiyordu — yalnız doğrulama anında bir kez soruluyordu. Profil düzenlemeye kalıcı anahtar eklendi (anında kaydeder; KVKK: rıza tek dokunuşta geri alınabilir). YENİ `SocialLinks` modeli: Instagram/YouTube/TikTok/WhatsApp iş hattı/web sitesi. Girdi normalize edilir (tam URL → kullanıcı adı; `javascript:` reddedilir; TR telefon → E.164) + rules alan/uzunluk doğrulaması.
- **(7) Sohbette Enter artık ALT SATIR.** Mobilde `TextInputAction.newline`; fiziksel klavyede (web/masaüstü) `Shortcuts`+`Actions` ile Enter gönderir, Shift+Enter alt satır.
- **🔴 DENETİMDE BULUNAN CİDDİ HATA — `functions/index.js` KODLAMA BOZUKLUĞU:** Ürün (PRD-006) bölümü yanlış kodlamayla kaydedilmiş, 31 yerde Türkçe harfler U+FFFD olmuştu. **`foldTrSearchJs` eşlemelerinin TAMAMI bozuktu → fonksiyon hiçbir harfi katlamıyordu.** Ürün yayınlanırken `titleFold` bu bozuk fonksiyonla üretildiğinden sunucunun yazdığı arama alanı istemcininkinden (`search_fold.dart`) FARKLIYDI → Türkçe ürün araması sessizce tutmuyordu. Ayrıca 20+ kullanıcı hata mesajı okunamaz haldeydi. Düzeltildi + `İnşaat→insaat` ile fiilen doğrulandı; bu bölüm ASCII'ye alındı.
- **Test:** YENİ `test/chat_list_test.dart` (12 test: arşiv kişiselliği, alıcı arşivden çıkma, pin kalıcılığı, tik verisi, SocialLinks normalizasyonu). Bu testler yazılırken `normalizeHandle`'da gerçek bir bug bulundu (`instagram.com` kullanıcı adı sanılıyordu) → düzeltildi. Toplam **272/272**, analyze 0.
- **⚠️ DEPLOY BEKLEYEN (kullanıcı onayı gerekir):** (a) `firestore:rules` — socialLinks doğrulaması + chats archivedBy/pinnedBy izinleri. **Bunlar deploy edilmeden sosyal medya kaydetme ve arşiv/pin CANLIDA ÇALIŞMAZ** (rules reddeder). (b) `functions` — foldTrSearchJs + ürün hata mesajları.
- **AÇIK KALAN (rapor edildi, dokunulmadı):** iOS bundle ID hâlâ `com.ustacepte.ustaCepte` (Android `com.ustasindan.app`'e geçti) — düzeltmesi Firebase'de yeni iOS app kaydı + yeni GoogleService-Info.plist ister, macOS gerekir. Firebase paketleri 1 major geride (ayrı migrasyon). Sohbet listesi sorgusu limitsiz (ölçek gelince cursor'a taşınmalı). ESLint 9 config migrasyonu yapılmamış (deploy'u engellemiyor).
- **SIRADAKİ:** rules+functions deploy → App Check debug token → AR cihaz testi → Play Console.

--- (önceki oturumlar) ---

**Oturum 73 (2026-07-31): BİRİKMİŞ İŞ COMMIT'LENDİ (Oturum 64→72 arası ~5 aylık çalışma git'e girdi). Kırmızı test onarıldı → 260/260, analyze 0. KOD DAVRANIŞI DEĞİŞMEDİ.**
- **Durum tespiti:** Son commit `d04b1ee` (16 Tem) idi ama notlar 22 Tem'e kadar gidiyordu → 212 dosya commit'lenmemiş bekliyordu (93'ü lib/test, ~3.600 satır). Toolkit, Ana Sayfa, Ürünler, AR, JDK 17 ayarları — hepsi yalnız çalışma kopyasındaydı.
- **Çöp temizliği:** `deploy_*.txt`, `tool/last_*.txt`, `tool/_kprof.txt` ve yanlışlıkla oluşmuş `console.log(e` dosyası `.gitignore`'a eklendi (deploy komut logları, repoya girmez). `android/build/` index'ten düşürüldü (gitignore'daydı ama takip sürüyordu). İmza anahtarları kontrol edildi: `android/key.properties` + `.jks` ignore'da, sızıntı YOK.
- **KIRMIZI TEST ONARILDI (`home_screen_test.dart`):** Test var olmayan bir "Kategoriler" bölümünü arayıp `scrollUntilVisible` ile sona kadar kaydırıp `Bad state: No element` atıyordu. **Kök neden:** Ana Sayfa Oturum 71'den sonra yeniden düzenlenmiş, kategoriler bölümü ekrandan çıkarılmış; test güncellenmemiş. Ürün kodu doğruydu → test ekranın gerçek haline uyduruldu (kategori beklentisi kaldırıldı).
- **ÖLÜ KOD SİLİNDİ:** `home_categories.dart` + `home_announcement.dart` hiçbir yerden import edilmiyordu (duyuru işlevi `home_discover.dart` içine taşınmış). İkisi de silindi; analyze 0 kaldı.
- **9 commit** (konu bazlı): gitignore · platform (paket adı+ikonlar+AR+JDK17) · PRD-007 Usta Çantası · PRD-006 Ürünler · Ana Sayfa · backend (CF+rules+indeks) · hata dayanıklılığı · tanıtım sitesi · uygulama katmanı.
- **Doğrulama:** `flutter test` = **260/260** (255'ten 260'a çıktı — arada eklenen testlerle), `flutter analyze lib test` = 0, `node --check functions/index.js` OK.
- **⚠️ HİÇBİR ŞEY DEPLOY EDİLMEDİ.** Commit'lenen backend değişikliklerinin (CF/rules/indeks) canlıda olup olmadığı bu oturumda DOĞRULANMADI — notlara göre Oturum 64/65'te deploy edilmişti, sonraki ürün/toolkit CF'leri için durum belirsiz. Deploy öncesi `firebase functions:list` ile teyit et.
- **SIRADAKİ (değişmedi):** (1) ARCore'lu Android'de `flutter run` → AR ekranı cihaz testi. (2) macOS'ta `cd ios && pod install` → ARKit testi. (3) App Check debug token Console'a eklendi mi teyit (Oturum 68: `4272f605-77f3-44b8-9060-adbf309f8cae`). (4) Play Console ilk yükleme + Play App Signing SHA'ları.

--- (önceki oturumlar) ---

**Tarih:** 2026-07-22

**Oturum 72 (2026-07-22): ANDROID BUILD HATASI ÇÖZÜLDÜ (AR paketi Java 17 toolchain). `flutter build apk --debug` = ✓ Built app-debug.apk (235 MB). AR dahil her şey derleniyor.**
- **Hata:** `Gradle task assembleDebug failed` → kök neden: `ar_flutter_plugin_plus` build.gradle'ı `jvmToolchain(17)` çağırır ve Gradle TAM Java 17 toolchain arar. Makinede yoktu (sistem Java 8; Android Studio jbr = JDK 21). "Cannot find a Java installation matching languageVersion=17".
- **Çözüm (kullanıcı onayı: JDK 17 kur):** winget bu ortamda çalışmadı (kaynak/admin) → Temurin JDK 17 Adoptium API'sinden zip indirildi (`api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse`), `C:\Users\Okul\jdks\jdk-17.0.19+10`'a açıldı (admin gerekmez, kullanıcı dizini).
- **Gradle ayarı (`android/gradle.properties`):** `org.gradle.java.home=.../Android Studio1/jbr` (Gradle'ı JDK 21'de çalıştır; Java 8 Gradle'a yetersiz), `org.gradle.java.installations.paths=C:/Users/Okul/jdks/jdk-17.0.19+10,C:/Program Files/Android/Android Studio1/jbr` (toolchain adayları: 17 + 21), `auto-download=false`. `flutter config --jdk-dir` de jbr'ye set edildi.
- **⚠️ MAKİNEYE ÖZEL YOL UYARISI:** `gradle.properties`'teki JDK yolları BU makineye özgü (`C:/Users/Okul/...`). Başka makinede/CI'da build alınırsa bu yolları o makinenin JDK 17 + JDK yoluna güncelle. Git'te izlenen dosya olduğundan farkında ol.
- **Denenip GERİ ALINAN:** `android/build.gradle.kts`'e subproject toolchain override (jvmToolchain(21) + JavaCompile compilerFor) — AGP kendi toolchain'ini zorladığı için tutmadı; JDK 17 kurulunca gereksiz oldu, temizlendi. build.gradle.kts artık orijinal halinde.
- **Ek temizlik:** `.gitignore`'a `/android/build/` + `/android/.gradle/` eklendi (build çıktısı commit'lenmesin — `problems-report.html` sızıyordu).
- **SIRADAKİ:** Artık `flutter run` ile gerçek cihazda çalıştırılabilir. AR ekranını ARCore'lu Android'de test et (Oturum 70). Ana Sayfa + Usta Çantası zaten çalışır durumda.

--- (önceki oturumlar) ---

**Oturum 71 (2026-07-22): ANA SAYFA (platform dashboard) eklendi. Yalnız istemci → DEPLOY GEREKMEZ. Full suite 255/255, analyze 0.**
- **Ne:** Uygulamaya giren kişi artık doğrudan Keşfet'e değil, platformun tamamını gösteren bir Ana Sayfa'ya düşer (karşılama + arama + hızlı erişim + istatistik + öne çıkanlar + duyuru + usta araçları). Kullanıcı kararı: "Ana Sayfa = yeni `/`" + "istatistik: şimdi UI, veri sonra".
- **Rota değişimi (dikkat):** `RoutePaths.home` (`/`) artık `HomeScreen`; Keşfet `RoutePaths.explore` (`/explore`) → `CustomerDashboardScreen`. Splash/login/onboarding zaten `/`'a gidiyordu → artık Ana Sayfa'ya varıyorlar (istenen). **Alt bar 5 sekme oldu:** `MainTab.home` eklendi (Ana Sayfa·Keşfet·İşler·Mesajlar·Profil) — PRD-007'deki "4 sekme dokunulmaz" ilkesi bu bilinçli kararla güncellendi.
- **Dosyalar:** `lib/features/home/presentation/home_screen.dart` + `widgets/` → `home_quick_access` (4 kart), `home_stats` (kendi hataya-dayanıklı `homeStatsProvider`; permission-denied/boş → **bölüm gizli**, sahte rakam yok), `home_announcement` (mevcut `appRuntimeConfigProvider.hasAnnouncement`; yoksa gizli; CTA url_launcher), `home_featured` (`oneChikanUstaProvider` + `discoverProductsProvider` + `openJobsProvider`; her kart veri yoksa gizli), `home_tools` (Usta Çantası kısayolları → toolkit).
- **İstatistik gerçeği:** `adminStats/global` var ama firestore.rules "yalnız admin okur" + üründe `productsTotal` sayacı YOK. Bu yüzden bölüm şimdilik gizli. Herkese açmak için: rules'a genel okuma (yalnız sayı alanları) + CF'ye `productsTotal` sayacı + DEPLOY → sonra bölüm otomatik görünür.
- **Test:** `home_screen_test.dart` (misafir smoke) + mevcut onboarding/artisan_login testleri `CustomerDashboardScreen`→`HomeScreen` güncellendi. `legal_test` kendi stub router'ıyla etkilenmedi. Full suite 255/255, analyze 0.
- **SIRADAKİ (opsiyonel):** (1) İstatistik verisini canlıya bağlamak için rules + CF productsTotal deploy. (2) Öne çıkan usta algoritmasını premium/aktivite kriterleriyle zenginleştirmek. (3) PRD-007 AR cihaz testi hâlâ bekliyor (Oturum 70).

--- (önceki oturumlar) ---

**Oturum 70 (2026-07-22): PRD-007 Faz D (AR-1 ölçüm) + Faz E köprüsü KOD BİTTİ. ⚠️ İSTEMCİ paket ekledi → build/mağaza sürümü değişir; GERÇEK CİHAZ testi bekliyor. Toolkit 36 test, tüm suite 254/254, analyze 0.**
- **Kullanıcı kararı:** "ikisi de şart (tek paket)" → `ar_flutter_plugin_plus: ^1.1.3` (ARCore + ARKit tek köprü) + `vector_math` (doğrudan import). Deploy kararlarını duruma göre ben verdim; build/yayın YAPILMADI (senin adımın).
- **Platform ayarları:** Android `minSdk = maxOf(flutter.minSdkVersion, 24)` (ARCore) + Manifest `camera.ar` feature (required=false) + `com.google.ar.core=optional` meta-data. iOS `IPHONEOS_DEPLOYMENT_TARGET 13→15` (3 yer) + `NSCameraUsageDescription` AR metni. Podfile YOK (macOS'ta `pod install` gerekir — iOS build orada).
- **AR-1 ekranı** (`ar_screen.dart`, placeholder'ın yerine): `ARView` + plane detection → 2 noktaya dokun → `worldTransform.getTranslation()` → `uzunlukM` (saf Dart, testli) → sonuç kartı + "Alan'a aktar". AppBar'da her zaman **"Elle ölç"** aksiyonu (destek yoksa/izin yoksa PRD kuralı: elle ölçüme geç; paket kendi hata snackbar'ını gösterir, çökme yok).
- **Faz E köprüsü:** AR "Alan'a aktar" → `/toolkit/area?ar_uzunluk=X`; AreaScreen initState'te ilk yüzeyin "en"ini doldurur + `SonucKarti`'ya `kaynak: OlcuKaynagi.ar` rozeti (AR/Manuel; `sonuc_karti.dart`'a `kaynak` parametresi eklendi).
- **Test (+4):** `uzunlukM` eksen/3-4-5 çapraz/eksik koordinat→0, `ArUzunlukSonucu` tahmini+özet. Full suite 254/254 (AR paketi mevcut testleri kırmadı). `flutter analyze lib` = 0.
- **⚠️ SIRADAKİ = SADECE SENİN CİHAZ TESTİN (kod bitti):** (1) ARCore'lu Android'de `flutter run` → AR ekranı + iki nokta ölçüm + desteksizde "Elle ölç". (2) macOS'ta `cd ios && pod install` → ARKit iPhone testi. (3) `pubspec version:` bump → App Bundle → mağaza. Detay: `docs/PRD_007_USTA_CANTASI.md` "AR yayın öncesi kontrol". İyileştirme: AR-2 (dikdörtgen doğrudan m²).

--- (önceki oturumlar) ---

**Oturum 69 (2026-07-22): PRD-007 Usta Çantası — Faz A→C + F BİTTİ (AR hariç MVP tamam). Yalnız istemci → DEPLOY GEREKMEZ. Toolkit 32 test, TÜM SUITE 250/250, analyze 0.**
- **Kaynak:** `docs/PRD_007_USTA_CANTASI.md` (§0 panosu A/B/C/F ✅; D/E ⏸️ PC başı). Kullanıcı "tüm fazları sırayla yap, PC başında değilim" dedi; AR (D/E) dışındaki her şey uygulandı.
- **8 hesaplayıcı canlı, misafir açık:** Alan/Boya/Fayans (Faz B) + Maliyet/Kâr/Teklif/Birim/Süre (Faz C). Motor saf Dart 2 dosya (`toolkit_calculators.dart`, `toolkit_cost.dart`), tümü `HesapSonucu` (tahmini hep true, `ozet` paylaş metni). `trSayi` TR biçim (intl paketsiz).
- **Ekranlar:** `lib/features/toolkit/presentation/` → area/paint/tile/cost/profit/quote/units/duration + `ar_screen` (placeholder). Ortak widget'lar: `SayiAlani` (TR ondalık + `parseTrAmount`), `FireSecici`, `SonucKarti` (panoya **Kopyala**, share_plus YOK — Clipboard native), `TahminiUyariBanner` (zorunlu uyarı).
- **Hub + router:** `toolkit_hub_screen` 3 grup + AR yıldız; tüm kartlar aktif + rota. Router `/toolkit` ve 9 alt rota — **`needsLogin`'e EKLENMEDİ** (misafir açık, K2). Drawer + Profil ARAÇLAR girişleri.
- **Faz F cilâ:** Yardım'a 2 FAQ ("Usta Çantası nedir?", "Sonuçlar kesin mi?") + `kFaqCategories`'e "Usta Çantası"; hub'da "nasıl çalışır?" → Yardım linki. Hub'daki ölü "Yakında" kod yolu temizlendi (`_ToolCard` sadeleşti).
- **Test:** `test/toolkit_test.dart` 32 test (modeller + 8 hesap + hub smoke açık/koyu + scroll). Full suite 250/250 (regresyon yok).
- **KALAN = SADECE Faz D + E (AR kamera) — PC BAŞI GEREKİR:** native ARCore/ARKit paketi (pubspec), Manifest/Info.plist kamera AR amaç metni, cihazda test, YENİ MAĞAZA SÜRÜMÜ + App Check release kaydı. Körlemesine paket+deploy riski nedeniyle otomatik YAPILMADI. `/toolkit/ar` hazırlık ekranı (desteksizde çökmez, elle ölçüme yönlendirir) + hub kartı bağlı. **Başlarken: PRD §6.6 "Faz D başlangıç kontrol listesi" (6 madde).**

--- (önceki oturumlar) ---

**Oturum 69-B (2026-07-22): PRD-007 Faz B (Ölçüm hesapları) bitti. 22/22 test.**
- **Kaynak:** `docs/PRD_007_USTA_CANTASI.md` (§0 panosu Faz B ✅).
- **Motor (saf Dart):** `application/toolkit_calculators.dart` → `alanHesapla` (brüt/düşüm/net + fire dâhil m²), `boyaHesapla` (alan×kat/verim → tahmini litre; verim 0/neg → güvenli 10; kat<1→1), `fayansHesapla` (derz mm efektif alanı büyütür, fire dâhil adet yukarı yuvarlanır, geçersiz ebat→0 çökme yok). `trSayi` TR biçim (1.234,5) — intl paketi eklemeden. Her sonuç `HesapSonucu` (tahmini hep true, `ozet` paylaş metni).
- **Ekranlar:** `area_screen.dart` (çok yüzey en×boy + yüzey ekle/sil + düşüm + fire), `paint_screen.dart` (alan + kat chip + verim), `tile_screen.dart` (alan + ebat + derz + fire). Ortak widget'lar: `SayiAlani` (TR ondalık klavye + `parseTrAmount`), `FireSecici` (%0/5/10/15/Özel chip), `SonucKarti` (vurgu + ozet + **panoya Kopyala**; share_plus YOK, Clipboard native).
- **Bağlama:** hub Ölçüm kartları `hazir:true` + rota; router `/toolkit/area|paint|tile` (misafir açık, `needsLogin`'e eklenmedi).
- **Doğrulama:** analyze 0 (toolkit+router+test); `flutter test test/toolkit_test.dart` = 22/22 (trSayi, alan fire, boya güvenli varsayılanlar, fayans derz/fire/yuvarlama/çökme-yok).
- **SIRADAKİ = Faz C:** Maliyet (malzeme+işçilik+yol+diğer), Kâr (%/sabit→satış), Teklif (kalemler+KDV %20+kopyala), Birim dönüştürücü, İş süresi (m²×meslek şablonu). Aynı motor+ekran+test kalıbı. Bitince `Faz C bitti → Faz D'ye geçiyoruz. Kaynak: docs/PRD_007_USTA_CANTASI.md`.

--- (önceki oturumlar) ---

**Oturum 69-A (2026-07-22): PRD-007 Usta Çantası — Faz A (İskelet) bitti. Yalnız istemci, yeni feature `lib/features/toolkit/` → DEPLOY GEREKMEZ. Toolkit testleri 10/10, analyze 0.**
- **Kaynak:** `docs/PRD_007_USTA_CANTASI.md` (kanonik; diske yazıldı, r2). PRD kod gerçekleriyle doğrulandı (drawer `_open` kalıbı, router `needsLogin` whitelist, profil ARAÇLAR `_MenuRow`, `Validators.parseTrAmount`).
- **Uygulanan (Faz A):** `RoutePaths.toolkit` (+ alt path sabitleri, ekranlar Faz B+). `application/toolkit_models.dart` saf Dart: `Yuzey` (dikdörtgen/alan + düşüm, net alan negatife düşmez), `FireOrani`, `OlcuKaynagi`, `OlcumSeansi` (immutable, toplam net m²), `HesapSonucu` (tahmini hep true). Ortak `TahminiUyariBanner`. `ToolkitHubScreen`: gruplar (Ölçüm / İş & Maliyet / Diğer) + AR yıldız kartı; **tüm araçlar "Yakında" pasif** (Faz A yalnız hub).
- **Girişler:** Drawer'a **Usta Çantası** satırı (Yardım üstünde, misafir+üye). Profil → ARAÇLAR'a **Usta Çantası** `_MenuRow` (Ajanda üstünde). Router `/toolkit` rotası — **`needsLogin` listesine bilinçli EKLENMEDİ** (misafir açık, K2).
- **Doğrulama:** `flutter analyze` 6 dosya = 0 issue. `flutter test test/toolkit_test.dart` = 10/10 (hub açık+koyu smoke, Yuzey matematiği, seans toplamı immutable, fire oranları, kaynak rozetleri).
- **SIRADAKİ = Faz B (Alan / Boya / Fayans hesapları):** hub kartlarını `hazir:true` yap + rota bağla, tam UX + unit test + sonuç kartı + kopyala/paylaş metin. Girdi parse'ı `Validators.parseTrAmount` kalıbı. Bitince `Faz B bitti → Faz C'ye geçiyoruz. Kaynak: docs/PRD_007_USTA_CANTASI.md`.

--- (önceki oturumlar) ---

**Oturum 68 (2026-07-20): "YAYINLA basınca ürün yayınlanmıyor" HATASI düzeltildi. Yalnız istemci → DEPLOY GEREKMEZ. 217/217 test, analyze 0.**
- **Kök neden:** `product_edit_screen.dart` `_save(publish:true)` içinde vitrin (usta profili) doluluğu `ref.read(myProfileControllerProvider).valueOrNull` ile okunuyordu. `MyProfileController.build()` **async** (repo'dan profil çeker). Kullanıcı Ürünlerim→"Yeni ürün" ekranına o oturumda Profil ekranını hiç açmadan geldiyse provider ya hiç başlamamış ya hâlâ yükleniyor → `valueOrNull == null` → `ShopCompletion.from(draft:null)` → `canMatchJobs=false` → yayın **profil aslında eksiksiz OLSA BİLE** reddediliyor, "Taslak kaydedildi. Yayın için vitrin eksik…" snackbar'ı çıkıyordu (kullanıcının gördüğü "yayınlamıyor" bu).
- **Düzeltme:** yayından önce taslak `await ref.read(myProfileControllerProvider.future)` ile beklenir (hata olursa `valueOrNull`'a düşer = eski davranış; `!mounted` guard'ı eklendi). Ayrıca yayın engellenirse mesaj artık **tam olarak neyin eksik olduğunu** söyler (`_publishBlockedMessage`: askı / eksik vitrin adımları [profil foto, meslek, bölge] / eksik ürün alanları ayrıştırılır).
- **Doğrulama:** CF `publishProduct`+`updateProductContent`+`adminModerateProduct`+`onProductReportWritten` CANLIDA (functions:list ile teyit); yani "yayın servisi yok" DEĞİLDİ. Firestore `products` rules match'i yerelde tam (satır 904+). analyze 0, 217/217 test yeşil.
- **GERÇEK KÖK NEDEN BULUNDU (logcat kanıtı):** Draft Firestore'a YAZILIYOR (rules OK); patlayan `publishProduct` **CF çağrısı**. CF `CONSUMER_CALL_OPTS = {enforceAppCheck:true}` (functions/index.js:43). Logcat: `DebugAppCheckProvider: debug secret … 4272f605-77f3-44b8-9060-adbf309f8cae` + `App attestation failed. code:403` + `FirebaseContextProvider: Error getting App Check token`. Yani 66. oturumun uyardığı iş: paket adı `com.ustasindan.app` için **debug token Console'a kaydedilmemiş** → tüm enforceAppCheck'li CF çağrıları reddediliyor (publishProduct/deleteAccount/createSupportTicket/verifyMembershipPurchase). Firestore create çalışıyor çünkü CF App Check'i ayrı/daha sıkı enforce ediyor.
- **ÇÖZÜM (KULLANICI, Console):** Firebase Console → alljob1 → App Check → Apps → **Ustasindan Android** → Manage debug tokens → Add → değer: `4272f605-77f3-44b8-9060-adbf309f8cae` → Kaydet → uygulamada tekrar "Yayınla" (yayılma 1-2 dk). Not: bu cihaza özel debug secret; her yeni debug cihaz kendi secret'ını üretir (logcat'ten alınır).
- **KOD İYİLEŞTİRMESİ (kalıcı, deploy'suz):** `_saveErrorMessage` artık `FirebaseFunctionsException`'ı tip olarak tanıyıp koda göre mesaj veriyor (unauthenticated→"App Check kaydı gerekebilir", internal→"App Check doğrulaması başarısız olabilir", vb.) — kör "Kayıt başarısız" bitti. `firebase_product_repository.publishProduct` CF hata code/message/details'i loglar. `product_edit_screen._save` catch'i ham hata+stack basar (debugPrint). analyze 0, 217/217 test.
- **SIRADAKİ:** kullanıcı debug token'ı Console'a ekleyip "Yayınla"yı doğrulasın. Sonra: App Check Play Integrity kaydı (release) → duman testi → Play ilk yükleme.

--- (önceki oturumlar) ---


**Oturum 67 (2026-07-20): ÜRÜNLER SEKMESİ DENETİM + ONARIM PAKETİ ("hatalar eksikler çok fazla"). Yalnız istemci → DEPLOY GEREKMEZ. 217/217 test, analyze 0.**
- **Fiyat ayrıştırma HATASI (ciddi) düzeltildi:** "1.500" yazan usta 1,5 ₺ kaydediyordu (`[^\d.]` regex noktayı ondalık sanıyordu); virgül hiç desteklenmiyordu. Yeni `Validators.parseTrAmount` (validators.dart): virgül+nokta birlikteyse SONDAKİ ayraç ondalık; yalnız virgül → ondalık; yalnız nokta → ardından tam 3 hane (veya çok nokta) ise binlik ("1.500"=1500), değilse ondalık ("10.5"=10.5). Edit ekranı `_parsePrice` + alan validator'ı buna geçti; klavye `numberWithOptions(decimal:true)` + hint. **+4 test** (products_lifecycle_test).
- **Keşfet → Ürünler paneli yenilendi (`products_explore_panel.dart`):** arama kutusu (300ms debounce; başlık/etiket/usta adı/kategori adı `matchesTrSearch` ile istemci tarafı), kategori + il FilterChip'leri (alt sayfada aranabilir liste + "Tümü"; il listesi `provincesProvider`), "Temizle" chip'i, pull-to-refresh (invalidate + future bekleme). Boş durumlar AYRIŞTI: hiç ürün yok (usta değilse "Ürünlerim'den ekleyin" DENMEZ) vs filtre eşleşmedi ("Filtreleri temizle" aksiyonu). Filtreleme istemci tarafı (repo zaten 60 tavanlı çekiyor; sorgu/indeks değişmedi).
- **Ürün düzenleme (`product_edit_screen.dart`):** (1) il/ilçe SERBEST METİN → `SearchableSelectField` (il `provincesProvider`, ilçe `districtsProvider(il.id)`, ilçe opsiyonel "İlçe seçme (tüm il)"); kayıtlı adlar `_resolveLocation` ile Province/District nesnesine çözülür (eşleşmeyen eski serbest metin → kullanıcı listeden yeniden seçer — veri temizliği). İl değişince ilçe sıfırlanır. Yazım hatalı il artık Keşfet il filtresinden ürün düşüremez. (2) `_bootstrap` try/catch'e alındı — ağ hatasında SONSUZ YÜKLEME yerine ErrorView + "Tekrar dene" (`_loadFailed`). (3) Kategori dropdown'ına validator (yalnız snackbar'dı).
- **Ürünlerim (`my_products_screen.dart`):** "Kaldır" ve "Satıldı" artık AlertDialog ile onay soruyor (satıldı geri yayına alınamaz; kaldır taslağa dönebilir — mesajlarda belirtildi). Tek dokunuş yaşam döngüsü kazası bitti.
- **Ürün detay (`product_detail_screen.dart`):** (1) sohbet ilk mesajındaki `ustacepte://products/…` ÖLÜ LİNK kaldırıldı (şema manifest'te hiç kayıtlı değildi + eski marka) → düz metin «başlık»; (2) foto galerisine sayfa nokta göstergesi (`_PhotoGallery`, >1 fotoda animasyonlu noktalar); (3) satıcı avatarı `NetworkImage` → `AppAvatar` (mock `local://` handle'ları ve önbellek artık doğru).
- **SIRADAKİ:** Oturum 66'nın bekleyeni sürüyor: App Check kaydı (kullanıcı, Console) → cihaz duman testi → Play Console ilk yükleme. Ürünlerde bilinçli ertelenen: sunucu tarafı arama/il filtreli sorgu (ölçek gelince indeksli sorguya taşınır), viewCount sayacı.

--- (önceki oturumlar) ---


**Oturum 66 (2026-07-18): PAKET ADI DEĞİŞİMİ — com.ustacepte.usta_cepte → com.ustasindan.app (marka "Ustasından" ile hizalama; Play'e İLK yükleme ÖNCESİ son şans, kullanıcı AskUserQuestion ile com.ustasindan.app seçti). analyze 0; debug APK + release AAB yeni paketle OK; imza doğrulandı. ⚠️ KULLANICI: App Check kaydı ŞART (aşağıda).**
- **Android:** build.gradle.kts namespace+applicationId → com.ustasindan.app; MainActivity → `kotlin/com/ustasindan/app/` (package satırı güncel). Dart paket adı (`usta_cepte`) BİLEREK değişmedi — içseldir, mağazada görünmez.
- **Firebase (hepsi CLI):** YENİ Android app kaydı "Ustasindan Android" → **appId `1:839781526307:android:53a729b742c6a8439aba96`**; google-services.json yeniden indirildi (proje düzeyi dosya — iki app da içinde, gradle paket adına göre seçer; eski .bak silindi); upload anahtarının SHA-256+SHA-1'i YENİ app'e kaydedildi; firebase_options.dart android.appId + firebase.json flutter eşlemesi güncellendi (apiKey aynı — proje düzeyi anahtar).
- **Doğrulama:** debug APK output-metadata `"applicationId": "com.ustasindan.app"` ✓; `flutter build appbundle` → 53.1MB, keytool ile upload anahtarı imzası ✓; analyze 0.
- **⚠️ KULLANICI (cihazda çalıştırmadan ÖNCE):** Console → **App Check** → yeni "Ustasindan Android" uygulamasını **Play Integrity** sağlayıcısıyla kaydet + debug cihaz için YENİ **debug token** ekle (eski ustacepte app'inin tokenı yeni app'e GEÇMEZ; Firestore/Storage ENFORCED olduğundan kayıtsız yeni uygulama permission-denied alır → uygulama açılır ama veri gelmez).
- **Eski app kaydı** (ustacepte, `…b73835fe…`) Firebase'de DURUYOR — yeni düzen cihazda doğrulanana kadar SİLME; sonra Console'dan kaldırılabilir.
- **Play Console'a yüklenecek dosya:** bugünkü `build\app\outputs\bundle\release\app-release.aab` (com.ustasindan.app; dünkü AAB eski paket adıyla — KULLANMA).
- **SIRADAKİ:** App Check kaydı (kullanıcı) → cihaz duman testi → Play Console ilk yükleme → Play App Signing SHA'ları (yeni app'e) → kapalı test.

--- (önceki oturumlar) ---


**Oturum 65 (2026-07-17): ELEMAN (STAFFING) MODÜLÜ DENETİMİ + SERTLEŞTİRME PAKETİ. Kullanıcı "eleman arama bölümünü test et" dedi; denetim 2 ciddi açık buldu, "başlayalım" ile hepsi kapatıldı. 206/206 test, analyze 0, rules dry-run OK, admin web build OK. ⚠️ RULES + FUNCTIONS DEPLOY + ADMIN HOSTING REDEPLOY BEKLİYOR.**
Denetim bulguları: (a) deleteAccount staffing'i temizlemiyordu (KVKK — silinen hesabın herkese açık kartı/ilanları sonsuza dek yayında kalıyordu), (b) moderasyon yolu YOKTU (şikayet hedefi değildi, moderationHidden yoktu, admin aracı yoktu — Play UGC riski), (c) rules'ta alan allowlist'i yoktu (sınırsız ekstra alan + doğrulanmamış displayName/photoURL), (d) staffNeeds sınırsız create, (e) Türkçe arama kırıktı (toLowerCase 'İ'→'i̇' birleşik nokta; foldTrSearch kullanılmıyordu).
- **CF (`functions/index.js`):** (1) `deleteAccount` → `staffWorkers/worker_{uid}` + tüm `staffNeeds` bulkWriter'a eklendi; (2) `adminSetUserSuspended` → askıda kart `openToWork=false` + açık ilanlar `closed` (askı kalkınca otomatik geri AÇILMAZ); (3) YENİ `adminModerateStaffing` callable (targetType staffWorker|staffNeed, hide/unhide, `jobs.moderate` yetkisi, audit log); (4) YENİ `onStaffNeedCreated` trigger — kullanıcı başına 5 AÇIK ilan tavanı, fazlası oluşur oluşmaz silinir (aggregate `count()`, indekssiz).
- **Rules (`firestore.rules`):** staffWorkers create/update AYRILDI + `workerKeysOk` allowlist (legacy 'kind' dahil) + displayName 1..60 + photoURL https+≤500 + moderasyon alanları: create'te hiç yazılamaz, update'te diff'te DEĞİŞEMEZ (merge'li setWorkerOpen bozulmaz). staffNeeds: `needKeysOk` allowlist + employerName/photo/workDate doğrulama (moderasyon alanları allowlist DIŞI — create'te seed edilemez; update zaten yalnız status). reports targetType += 'staffWorker','staffNeed'.
- **İstemci:** `staffing.dart` her iki modele `moderationHidden` (fromMap okur; **toMap BİLEREK yazmaz** → istemci kaydı admin gizlemesini geri açamaz; test var). Firebase+Mock browse listeleri gizliyi süzer; worker detayı gizliyse "Profil yok". `report.dart` ReportTarget += staffWorker/staffNeed (+report_sheet başlıkları). Worker detayına "Profili şikayet et", need kartlarına bayrak ikonu (girişsiz → login). Filtreler `foldTrSearch`'e geçti (arama + ilçe eşitliği); staff_need_edit'e açık ilan tavanı ön-kontrolü (sayım yapılamazsa sunucu tavanına bırakır).
- **Admin:** `AdminReportRepository.moderateStaffing` (CF çağrısı; Mock'ta `hiddenTargets` seti) + şikayet detay sheet'inde staffing hedefi için "İçeriği gizle / Gizlemeyi kaldır" (sheet kapanmaz, ardından karar verilir) + `_TargetBadge` yeni rozetler.
- **Test:** staffing_test +3 (moderationHidden toMap koruması · staffing reportDocId · Türkçe fold regresyonu "İnşaat/Şişli/Şükrü" düz yazımla bulunur) → toplam **206/206**; analyze 0; `node --check` OK; `firebase deploy --only firestore:rules --dry-run` compile OK; `flutter build web -t lib/main_admin.dart` OK.
- **DEPLOY TAMAMLANDI ✅ (aynı gün, kullanıcı "evet" onayıyla):** (1) rules → İLK denemede canlı (opsiyonsuz). (2) admin hosting → İLK denemede canlı (alljob1-admin.web.app güncel). (3) functions → tekli denemeler ağa takıldı (opsiyonsuz: generateUploadUrl düştü; ipv6first+autoselect: list düştü) → **DÖNÜŞÜMLÜ KONFİGÜRASYON DÖNGÜSÜ kazandı** (autoselect → ipv6first+autoselect → opsiyonsuz → ipv4first+autoselect, 15 sn ara): 3. denemede (opsiyonsuz) **39 başarılı operasyon** (37 update + adminModerateStaffing/onStaffNeedCreated CREATE); `functions:list` ile 2 yeni fonksiyon canlıda doğrulandı. AĞ REÇETESİ GÜNCELLENDİ: tek doğru NODE_OPTIONS yok, uç/dakika bazında değişiyor → takılınca döngü kur (hafıza notu da güncellendi).
- **YENİ AAB HAZIR ✅:** `flutter build appbundle` → `build\app\outputs\bundle\release\app-release.aab` (53.1MB, staffing sertleştirmeleri DAHİL, upload anahtarıyla imzalı). Play Console'a YÜKLENECEK DOSYA BU (16 Tem tarihli eski 52.6MB'lik değil).
- **SIRADAKİ:** Play Console ilk yükleme (kapalı test) + Play App Signing SHA'larını Firebase'e ekleme → kapalı test turu. Bilinçli ertelenen küçükler: worker detayının FutureProvider'a alınması, staffing about'ta iletişim maskeleme kararı.

--- (önceki oturumlar) ---


**Oturum 64 (2026-07-16): PLAY STORE ÖNCESİ DENETİM + SIFIR-HATA PAKETİ. Kırmızı testler onarıldı; hata UX üçlüsü (ErrorWidget yedeği + çevrimdışı şeridi + "Sorunu bildir") ve CF sertleştirme (maxInstances + enforceAppCheck + destek rate-limit) eklendi. 203/203 test, analyze 0. ⚠️ FUNCTIONS DEPLOY BEKLİYOR.**
Kullanıcı Play öncesi "maliyet + güvenlik + kullanıcı hataları" denetimi istedi; rapor sonrası "evet başla" ile 2-4. maddeler uygulandı.
- **DENETİM ÖZETİ:** rules/storage güçlü (SECURITY_AUDIT ile uyumlu); YENİ bulgular: (a) **release imzası hâlâ debug** (`android/app/build.gradle.kts` buildTypes.release → Play engeli + canlıda Play Integrity/App Check kırılır — KULLANICI: keystore + SHA-256, aşağıda), (b) CF callable'larda enforceAppCheck yoktu, (c) maxInstances yoktu (fatura emniyeti), (d) createSupportTicket rate-limit'sizdi, (e) 10 test kırmızıydı (fikstür/API kayması — ürün hatası değil), (f) ErrorWidget.builder yoktu (release'te boz gri kutu), (g) çevrimdışı tespiti yoktu (boş önbellek + internetsiz → sonsuz spinner).
- **Test onarımı (10 kırmızı → 0):** `tracking/admin_test` fikstür adları `'N'`→geçerli (validator min 3 artık); `my_profile_test` `hasPremiumAccess` getter→metod çağrısı; `legal_test` YENİDEN yazıldı — `/register`→login yönlendirme testi + KVKK onay kapısı testi RegisterScreen'i DOĞRUDAN pompalayan iki-rotalı mini router'la (rota emekli ama form kodda; ekran geri bağlanırsa onay kapısı regresyonu). `admin_test` `_u`→`u` (lint).
- **ErrorWidget.builder (`core/widgets/app_error_fallback.dart`):** release'te widget derleme hatasında markalı sakin yedek (Directionality/Theme'siz ağaçta da güvenli; FittedBox → taşma-hatası döngüsü imkânsız). main.dart + main_admin.dart kReleaseMode'da kurar; hata yine Crashlytics'e gider.
- **Çevrimdışı şeridi (`core/widgets/offline_banner.dart` + connectivity_plus ^7.3.0):** `isOfflineProvider` (checkConnectivity seed + onConnectivityChanged; tespit edilemezse güvenli=çevrimiçi) + `OfflineBannerHost` — MaterialApp.router `builder:` kabuğu, üstte "İnternet bağlantısı yok" hap şeridi (IgnorePointer, animasyonlu). Gerekçe: Firestore çevrimdışında hata FIRLATMAZ; boş önbellekte kullanıcı "takıldı" sanıyordu.
- **"Sorunu bildir" (kullanıcı→admin hata kanalı):** `ErrorReportScope` (InheritedWidget, `status_views.dart`) — tüketici app.dart kökte sağlar; TÜM ErrorView'larda otomatik "Sorunu bildir" düğmesi çıkar (admin panel/test ağaçları sağlamaz → düğme yok, rota varsayımı yok). Akış: düğme → `/help?konu=...&detay=...` (hata özeti + kClientVersion önceden yazılı) → HelpScreen `initialSubject/initialBody` + forma otomatik kaydırma → mevcut `createSupportTicket` → admin destek kuyruğu; yanıt bildirimle. Yeni `test/error_report_test.dart` (3 test).
- **CF sertleştirme (`functions/index.js`):** (1) `setGlobalOptions({maxInstances: 10})` — istismar/döngüde fatura emniyeti; (2) `CONSUMER_CALL_OPTS = {region, enforceAppCheck: true}` YALNIZ tüketici mobil callable'larına: deleteAccount / createSupportTicket / verifyMembershipPurchase (admin* callable'lara EKLENMEDİ — admin web'de reCAPTCHA yok, panel kilitlenirdi); (3) createSupportTicket rate-limit: kullanıcı başına 2 dk'da 1 + günde 10 (`adminRateLimits/support_{uid}` transaction, istanbulDayKey). Help ekranı resource-exhausted/invalid-argument sunucu mesajını aynen gösterir.
- Toplam **203/203 test** (200 + yeni 3); analyze 0; `node --check functions/index.js` OK.
- **⚠️ DEPLOY (kullanıcı onayıyla):** `set NODE_OPTIONS=--dns-result-order=ipv4first` → `firebase deploy --only functions --project alljob1` (maxInstances + enforceAppCheck + rate-limit canlıya). Debug cihazda App Check debug token'ı Console'da kayıtlı olmalı (zaten kayıtlı — Firestore enforcement bunu gerektiriyordu). NOT: tüketici WEB'de (reCAPTCHA anahtarı boşken) bu 3 callable çalışmaz — tüketici web yayınlanmıyor, sorun değil; anahtar girilince kendiliğinden düzelir.
- **İMZA TAMAMLANDI (aynı oturum devamı, "ozaman başlayalım"):** (1) `C:\Users\Okul\upload-keystore.jks` üretildi (keytool, alias `upload`, RSA 2048, 10000 gün; şifre `C:\Users\Okul\upload-keystore-sifre.txt` — ⚠️ KULLANICI İKİSİNİ DE GÜVENLİ YERE YEDEKLEMELİ, repo dışında ve gitignore'da). (2) `android/key.properties` yazıldı (git'e girmiyor, check-ignore doğrulandı). (3) build.gradle.kts zaten hazırdı → `flutter build appbundle` İLK denemede DÜŞTÜ: **google-services 4.3.15, Crashlytics gradle v3 ile uyumsuz** (release/minify'da `appIdFile` hatası — bugüne dek release build alınmadığından gizliydi) → `settings.gradle.kts` 4.3.15→**4.4.2** → **app-release.aab (52.6MB) OK**; `keytool -printcert -jarfile` ile paketin upload anahtarıyla imzalandığı DOĞRULANDI. (4) Upload anahtarının **SHA-256 + SHA-1'i Firebase'e CLI ile kaydedildi** (`firebase apps:android:sha:create`, ipv4first ile) — SHA-1 Google girişi (release) için de gerekli.
- **FUNCTIONS DEPLOY CANLIDA ✅ (2026-07-17, kullanıcı "deploy et" onayıyla):** CF sertleştirmeleri (maxInstances 10 + enforceAppCheck + destek rate-limit) canlıda DOĞRULANDI — üç tüketici callable'a App Check'siz curl → jenerik `{"message":"Unauthenticated"}` (SDK kapısı handler'dan önce reddediyor; eski kod Türkçe "Oturum gerekli." dönerdi). CLI'ın "Skipped (No changes detected)" çıktısı DOĞRUymuş (hash eşleşmesi = istenen config zaten canlı).
- **DEPLOY AĞ DERSİ (ÖNEMLİ — eski not GÜNCELLENDİ):** `serviceusage.googleapis.com` bu ağda IPv4'ten ÖLÜ, yalnız IPv6 çalışıyor → ezberdeki `NODE_OPTIONS=ipv4first` bu kez deploy'u "Error generating the service identity for pubsub/eventarc" ile üst üste DÜŞÜRDÜ. Kural artık: önce NODE_OPTIONS'suz dene; "Failed to make request" görürsen ipv4first; "service identity" hatası görürsen NODE_OPTIONS'u kaldır. Ayrıca `--only functions:<ad>` açık hedefleme atlama kontrolünü bypass eder (planner `targetedByOnly`).
- **⚠️ KULLANICI (Play Console):** Play Console'da uygulama oluştur → app-release.aab yükle (kapalı test) → Test et ve yayınla → Uygulama bütünlüğü'ndeki **Play App Signing SHA-256 + SHA-1'i** Firebase'e de ekle (kullanıcı hash'i yapıştırırsa CLI ile eklenebilir). Bu yapılmadan Play'den inen kurulumda App Check/Google girişi çalışmaz.
- **SIRADAKİ:** functions deploy (açık onayla) → Play Console ilk yükleme + Play SHA'ları → kapalı test → bütçe alarmı (Console). İsteğe bağlı: rules unit test iskeleti, web reCAPTCHA.

--- (önceki oturumlar) ---

**Oturum 63 (2026-07-13, aynı gün): ŞİKAYET + ANLAŞMAZLIK KUYRUKLARINA CURSOR SAYFALAMA ("eksik kalmasın"). Yalnız istemci — YENİ İNDEKS/KURAL/CF YOK. 151/151 test, analyze 0. Admin web REBUILD + hosting REDEPLOY (canlı: alljob1-admin.web.app).**
Kullanıcı "evet devam eksik kalmasın" + AskUserQuestion → "Kuyruk sayfalama (şikayet/anlaşmazlık)". Denetim kaydındaki (Oturum 61) cursor kalıbı genelleştirilip her iki kuyruğa taşındı; 200 sabit tavan kalktı.
- **NOT (App Check):** İncelendi — istemci App Check kablolaması ZATEN tam (main.dart + main_admin); kalan yalnız reCAPTCHA anahtarı + Console enforcement (kod değil). firebase-functions ^6→7 + admin ^12→13 MAJOR/breaking → canlı fonksiyonlarda habersiz yapılmadı (ayrı migrasyon işi). Bu yüzden gerçek kod işi = kuyruk sayfalama.
- **Genel `paged_queue.dart`:** `PagedData<T>{items,hasMore,loadingMore}` + `PagedController<T> extends StateNotifier<AsyncValue<PagedData<T>>>` (load/refresh/loadMore, pageSize 30; loadMore son öğenin cursor'ıyla ekler; `cursorOf`/`PageFetcher` typedef'leri). Şikayet+anlaşmazlık ORTAK bu controller'ı kullanır (denetim kendi controller'ında kaldı; ileride birleştirilebilir).
- **Repo fetchPage'leri:** `AdminReportRepository.fetchPage` (orderBy createdAt desc + `where(createdAt<cursor)`; TEK ALAN, indeks yok; openOnly İSTEMCİ tarafı filtre) + `AdminDisputeRepository.fetchPage` (`where(status==disputed).orderBy(createdAt desc)` + cursor → **mevcut `jobs(status,createdAt desc)` indeksini kullanır**, Oturum 19'dan; yeni indeks YOK). Mock parite. Cursor = `createdAt.toIso8601String()` (DateTime.tryParse UTC-lik korur → depo metnine sadık, sınır kayması yok).
- **Providerlar:** `reportQueueControllerProvider` + `disputeQueueControllerProvider` (StateNotifierProvider.autoDispose). **Rozetler CANLI kaldı:** `openReportCountProvider`/`openDisputeCountProvider` hâlâ mevcut `adminReportsProvider`/`adminDisputesProvider` STREAM'lerinden besleniyor (yeni şikayet/anlaşmazlık sekme rozetinde anında görünür); yalnız LİSTELER sayfalandı.
- **UI:** ortak `paged_footer.dart` (`PagedFooter`: spinner / "Daha fazla yükle" / "Kuyruğun sonu"). Şikayet ekranı (createdAt sayfalama + Açık/Tümü istemci filtresi korundu + Yenile ikonu + RefreshIndicator + alt footer; filtre boşsa ipucu+footer). Anlaşmazlık ekranı (Yenile + RefreshIndicator + footer). Not: anlaşmazlık listesi artık createdAt sırasında (eskiden disputedAt) — disputedAt sıralı sayfalama (status,disputedAt) indeksi ister; anlaşmazlıklar zaten az olduğundan createdAt tercih edildi (deploy'suz).
- **Test (`test/admin_test.dart` +2 → 151/151):** report fetchPage createdAt cursor sayfalama (2'şer, sonda boş) + dispute fetchPage createdAt cursor.
- Toplam **151/151**; analyze 0; `flutter build web -t lib/main_admin.dart` OK; **`firebase deploy --only hosting:alljob1-admin` YAPILDI** (canlı site güncel).
- **SIRADAKİ:** kullanıcı canlı test. Admin Faz 2 tam + tüm kuyruklar ölçek-hazır. Kalan (kod değil/erken): App Check enforce (Console) · firebase-functions/admin major yükseltme (ayrı migrasyon) · BigQuery.
- ⚠️ Kullanıcı: Şikayetler/Anlaşmazlıklar sekmelerinde altta "Daha fazla yükle" + üstte Yenile/aşağı-çek. Yeni gelen kayıt sayısı sekme rozetinde anında (canlı) görünür; listeye yansıması için Yenile.

--- (önceki oturumlar) ---

**Oturum 62 (2026-07-13, aynı gün): 🚀 BİRİKMİŞ ADMIN DEPLOY YAPILDI (52-REVİZE→61 hepsi CANLIDA). Kullanıcı "evet" ile onayladı; ben sırayla çalıştırdım.**
Oturum 52-REVİZE'den 61'e kadar biriken TÜM admin backend'i tek oturumda canlıya alındı. Artık admin Faz 2'nin hiçbir parçası "deploy bekliyor" değil.
- **(1) `firebase deploy --only firestore:rules` ✅** — compiled + released. İçerik: admin READ (reports/adminAuditLogs/adminRoles), `isSuspended()` + 4 create dalı guard, `users` alan koruması (phoneNumber/suspended/suspendedAt), isVerified/phoneVerified guardları, adminRoles koleksiyonu.
- **(2) `firebase deploy --only functions:{claimAdminAccess,adminResolveReport,adminResolveDispute,onJobWritten,adminSetUserSuspended,adminSetRole,adminAssignReport}` ✅** — 6 create + onJobWritten update, hepsi europe-west1 Node 22 Gen2. **DERS TEKRARI:** İLK denemede `generateUploadUrl`'de "Failed to make request" (flaky precheck, ipv4first ayarlıyken bile); **RETRY'de sorunsuz geçti** (Oturum 21/49 kalıbı — takılırsa aynen tekrar dene).
- **(3) Ayrı admin sitesi ✅:** `firebase hosting:sites:create alljob1-admin` (oluşturuldu) → `flutter build web -t lib/main_admin.dart` → `firebase deploy --only hosting:alljob1-admin`. **CANLI: https://alljob1-admin.web.app** (45 dosya). Mevcut `alljob1` sitesine (yasal HTML) DOKUNULMADI (ayrı `--only hosting:alljob1-admin`).
- **⚠️ Kalan (kod değil, KULLANICI/Console işi):** (a) App Check enforcement Console'dan açılacaksa önce web reCAPTCHA v3 site anahtarı `kAppCheckWebRecaptchaKey`'e girilmeli (şu an boş → admin/tüketici web'de App Check pasif, sorun yok). (b) Deploy uyarısı: `functions/package.json` firebase-functions sürümü eski (deploy'u ENGELLEMEDİ; ileride `npm i --save firebase-functions@latest` ayrı iş — breaking değişiklik olabilir).
- **⚠️ KULLANICI ŞİMDİ TEST ETMELİ (canlı):** https://alljob1-admin.web.app → `aboneai.plus@gmail.com` (e-posta doğrulanmış) ile gir → yetki yoksa "Yönetici erişimini etkinleştir" (bootstrap → superadmin) → 5 sekme (Şikayetler/Anlaşmazlıklar/Kullanıcılar/Kadro/Denetim) görünmeli. Şikayet çöz/üstlen, kullanıcı askıya al, rol ata dene → Denetim sekmesinde kayıtlar + Console `adminAuditLogs`'ta izler görünmeli. Tüketici uygulamasında admin izi OLMAMALI.
- **SIRADAKİ:** kullanıcı canlı testini yapar; sorun çıkarsa düzelt. Admin Faz 2 tamam. Sonraki büyük alan kullanıcıya kalmış (App Check enforce · billing/Play · başka ürün özelliği).

--- (önceki oturumlar) ---

**Oturum 61 (2026-07-13, aynı gün): ADMIN FAZ 2 — DENETİM KAYDI CURSOR SAYFALAMA. Yalnız istemci → DEPLOY GEREKMEZ (tek-alan isLessThan, bileşik indeks yok). 149/149 test, analyze 0, admin web OK.**
Kullanıcı "devam" → NOT: App Check istemci kablolaması ZATEN tam (main.dart Android playIntegrity/debug + Apple appAttest/debug + web reCAPTCHA; main_admin web reCAPTCHA) — kalan yalnız reCAPTCHA anahtarı + Console enforcement (kod değil, kullanıcı işi). O yüzden gerçek kod işi olan cursor sayfalama, en mantıklı yere (sonsuz büyüyen append-only denetim kaydı) uygulandı; canlı-akış regresyonu yok (denetim geçmiş kayıttır).
- **Repo (`admin_audit_repository.dart`):** `watchAuditLog` (stream, sabit 200 tavan) → **`fetchPage({beforeCursor, limit})`**. `AuditEntry.cursor` eklendi = kaydın DEPO'daki ham `createdAt` metni (fromMap ham metni birebir korur; elle üretilende `createdAt.toUtc().toIso8601String()`'ten türer). **`AuditEntry` artık const DEĞİL** (cursor türetimi initializer'da). Firebase: `orderBy(createdAt desc)` + `beforeCursor` varsa `.where(createdAt < beforeCursor)` → **sınır kayması yok** (cursor son kaydın BİREBİR depo metni; tek alan, indeks gerekmez). Mock: cursor'ı DateTime'a çevirip `isBefore` süzer.
- **Controller (`admin_providers.dart`):** `AuditPage {entries, hasMore, loadingMore}` + `AuditLogController extends StateNotifier<AsyncValue<AuditPage>>` (load/refresh/loadMore, sayfa 50; loadMore son kaydın cursor'ıyla ekler, `hasMore = son sayfa == 50`). `auditLogControllerProvider` (StateNotifierProvider.autoDispose). Eski `adminAuditLogProvider` stream KALDIRILDI.
- **UI (`admin_audit_screen.dart`):** appbar'a "Yenile" ikonu. Liste sonuna `_LoadMoreFooter` (yükleniyorsa spinner / daha varsa "Daha fazla yükle" / bitti ise "Kaydın sonu"). `RefreshIndicator` (aşağı çek → refresh). Filtre bar + `filterAudit` KORUNDU (yüklü sayfalar üzerinde süzer); filtre hiçbir yüklüyü geçirmezse `_NoMatch` "daha eski kayıtları yükle" önerir. Alt bar subtitle "N kayıt yüklü+".
- **Test (`test/admin_test.dart`):** watchAuditLog testi → **fetchPage** (en yeni üstte + cursor'la sonraki sayfa + sonda boş). filterAudit + AuditEntry.fromMap testleri aynen. Toplam **149/149** (net değişmedi; bir test dönüştürüldü).
- Toplam **149/149**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY: bu oturum EK GETİRMEDİ** (createdAt tek-alan `orderBy`/`isLessThan`, otomatik indeks; adminAuditLogs okuma kuralı zaten var). Bekleyen deploy hâlâ 52-REVİZE+53+54+56+58'inki.
- **SIRADAKİ (admin Faz 2+ kalan):** App Check enforce (Console + reCAPTCHA anahtarı — KULLANICI işi) · şikayet/anlaşmazlık kuyruklarına da cursor sayfalama (isteğe bağlı) · (ölçek) BigQuery export. **Admin paneli pratikte tamamlanmış sayılabilir.**
- ⚠️ Kullanıcı DEPLOY SONRASI: Denetim sekmesi → 50'şer yüklenir; altta "Daha fazla yükle" ile eskiye iner; "Yenile"/aşağı-çek en yeniyi tazeler.

--- (önceki oturumlar) ---

**Oturum 60 (2026-07-13, aynı gün): ADMIN FAZ 2 — DENETİM KAYDI FİLTRE + ARAMA. Yalnız istemci → DEPLOY GEREKMEZ. 149/149 test, analyze 0, admin web OK.**
Kullanıcı "devam" → Oturum 59 denetim görüntüleyicisinin doğal tamamlayıcısı: gerçek konsolda "yönetici X ne yaptı" / "tüm askıya almalar" gerekir.
- **Model (`admin_audit_repository.dart`):** `AuditCategory` enum (all/roles/suspension/reports/disputes + labelTR + `matches(entry)` eylem kodu grupları) + saf `filterAudit(entries, {category, query})` (kategori + aktör/hedef uid küçük-harf duyarsız arama). Test edilebilir, UI'dan bağımsız.
- **UI (`admin_audit_screen.dart` → ConsumerStatefulWidget):** üstte `_FilterBar` (aktör/hedef UID arama kutusu + temizle + yatay kaydırmalı 5 kategori ChoiceChip). Liste `filterAudit` ile süzülür; eşleşme yoksa "Eşleşen kayıt yok" boş durumu. Yüklü 200 pencere üzerinde istemci-tarafı süzme.
- **Test (`test/admin_test.dart` +1 → 149/149):** filterAudit kategori süzme (roles/reports/all) + serbest metin (aktör/hedef, büyük-küçük harf) + kategori&arama birlikte.
- Toplam **149/149**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY: bu oturum EK GETİRMEDİ.** Bekleyen deploy hâlâ 52-REVİZE+53+54+56+58'inki (58 bloğunda tam liste).
- **SIRADAKİ (admin Faz 2+ kalan):** cursor sayfalama (kuyruk >200) · App Check enforce admin sitesinde · (ölçek) BigQuery export.
- ⚠️ Kullanıcı DEPLOY SONRASI: Denetim sekmesi → kategori çipiyle (ör. "Askı") süz veya bir yönetici/hedef UID ara → yalnız eşleşenler listelenmeli.

--- (önceki oturumlar) ---

**Oturum 59 (2026-07-13, aynı gün): ADMIN FAZ 2 — DENETİM KAYDI GÖRÜNTÜLEYİCİ. Yalnız istemci → DEPLOY GEREKMEZ (adminAuditLogs okuma kuralı 52-REVİZE'de geldi). 148/148 test, analyze 0, admin web OK.**
Kullanıcı "devam" → GERÇEK boşluk: 6 oturumdur her yönetici eylemi `adminAuditLogs`'a yazılıyordu ama görüntüleyecek EKRAN yoktu (hesap verebilirlik/KVKK bunu görmeyi gerektirir). cursor sayfalamadan daha mantıklıydı.
- **Repo (yeni `admin_audit_repository.dart`):** `AuditEntry` (id/actorUid/action/targetType/targetId/before/after/createdAt + `actionLabelTR` — grant_admin/set_role/revoke_admin/suspend_user/unsuspend_user/resolve_report/claim_report/release_report/resolve_dispute Türkçe; bilinmeyen kod olduğu gibi). `AdminAuditRepository` (arayüz + Firebase `adminAuditLogs.orderBy(createdAt desc).limit(200).snapshots()` — createdAt ISO metin, tek alan otomatik indeks; + Mock seed'li).
- **Providerlar:** `adminAuditRepositoryProvider` + `adminAuditLogProvider` (yalnız admin akar). `mock_backend.dart`'a override.
- **UI:** yeni `admin_audit_screen.dart` (`AdminAuditScreen` — kart listesi: eylem ikonu+TR etiketi, Yapan/Hedef/Ayrıntı (after'dan rol/durum/karar/askı/neden/üstlenen özetlenir) + tarih). `admin_app.dart`: **5. sekme "Denetim" YALNIZ süper yöneticiye** (gözetim; `isSuper` koşullu — moderatör 3 sekme, superadmin 5 görür).
- **Test (`test/admin_test.dart` +2 → 148/148):** AuditEntry.fromMap + before/after çözme + label TR + bilinmeyen kod; MockAdminAuditRepository en yeni üstte.
- Toplam **148/148**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY: bu oturum EK GETİRMEDİ.** Bekleyen deploy hâlâ 52-REVİZE+53+54+56+58'inki (58 bloğunda tam liste). Denetim ekranı yalnız MEVCUT `adminAuditLogs`'u okur.
- **SIRADAKİ (admin Faz 2+ kalan):** cursor sayfalama (kuyruk >200) · App Check enforce admin sitesinde · (ölçek) BigQuery export · denetim kaydı filtre/arama (eylem/aktör).
- ⚠️ Kullanıcı DEPLOY SONRASI: süper yönetici → 5. sekme "Denetim" → daha önce yaptığın tüm yönetici eylemleri (rol atama, askıya alma, şikayet çözme…) kronolojik listelenmeli. Moderatörde "Denetim" + "Kadro" sekmeleri GÖRÜNMEZ.

--- (önceki oturumlar) ---

**Oturum 58 (2026-07-13, aynı gün): ADMIN FAZ 2 — ŞİKAYET ATAMA (üstlen/bırak/devral). Yeni CF var, KURAL DEĞİŞMEDİ. 146/146 test, analyze 0, admin web OK.**
Kullanıcı "devam" → çoklu-moderatör koordinasyonu: iki yönetici aynı şikayeti işlemesin diye biri kaydı ÜSTLENİR. Az önceki RBAC/kadro işinin doğal devamı.
- **CF `adminAssignReport` (functions/index.js, admin-only):** `{reportId, assign}` → assign=true `assignedTo=auth.uid`+`assignedAt`; false → `FieldValue.delete()`. audit (claim_report/release_report). **`adminResolveReport` güncellendi:** karara bağlanınca `assignedTo/assignedAt` DÜŞER (iş bitti; kimin çözdüğü resolvedBy'da). **Kural DEĞİŞMEDİ** — reports update zaten CF-only (Admin SDK yazar), admin okuma açık; sadece yeni CF deploy.
- **Model/repo:** `Report.assignedTo` (fromMap). `AdminReportRepository.assignReport(id, {assign, adminUid})` (adminUid imza paritesi; sunucuda auth.uid'den) — Firebase→CF, Mock→alan çevir + kapanınca temizle (`updateStatus`'ta `status.isClosed ? null : r.assignedTo`).
- **UI (`admin_reports_screen.dart`):** kartta `_AssignBadge` ("Bende" mavi / "Üstlenildi" gri, `report.assignedTo == myUid` ile; myUid `currentUserProvider`'dan). Detay sheet: "Üstlenen (uid)" bilgi + duruma göre buton — atanmamış→"Şikayeti üstlen", bende→"Üstlenmeyi bırak", başkasında→"Devral" (assign true yeniden atar). `_assign(bool)` metodu.
- **Test (`test/admin_test.dart` +1 → 146/146):** MockAdminReportRepository assignReport üstlen/bırak + kapanınca atama düşer.
- Toplam **146/146**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY:** bu oturum bekleyen listeye **yalnız `functions:adminAssignReport`** ekler (kural EK YOK). Tam birikmiş deploy: (1) `firebase deploy --only firestore:rules` (2) `firebase deploy --only functions:claimAdminAccess,functions:adminResolveReport,functions:adminResolveDispute,functions:onJobWritten,functions:adminSetUserSuspended,functions:adminSetRole,functions:adminAssignReport` (3) admin sitesi: create → `flutter build web -t lib/main_admin.dart` → `firebase deploy --only hosting:alljob1-admin`.
- **SIRADAKİ (admin Faz 2+ kalan):** cursor sayfalama (kuyruk >200 için) · App Check enforce admin sitesinde · (ölçek) BigQuery export.
- ⚠️ Kullanıcı DEPLOY SONRASI: iki farklı yönetici hesabıyla → biri bir şikayeti "üstlen" → diğerinin listesinde o kayıtta "Üstlenildi" rozeti görünmeli, kendi listesinde "Bende". Çözünce atama düşer. Console `adminAuditLogs`'ta claim_report/release_report.

--- (önceki oturumlar) ---

**Oturum 57 (2026-07-13, aynı gün): ADMIN FAZ 2 — YÖNETİCİ KADROSU EKRANI (roster). Yalnız istemci → DEPLOY GEREKMEZ (roster okuma kuralı Oturum 56'da geldi). 145/145 test, analyze 0, admin web OK.**
Kullanıcı "mantıklı olanı yapalım, en son deploy yapacağız" → Oturum 56'nın `adminRoles` roster'ının doğal tamamlayıcısı: tüm rol sahiplerini tek yerde listele.
- **Repo (`admin_user_repository.dart`):** yeni `AdminRosterEntry` (uid/role/updatedAt + isSuperAdmin) + `watchRoster()` (arayüz + Firebase `adminRoles.snapshots()` + Mock). `_rosterSort`: **superadmin'ler üstte**, sonra en son güncellenen. Mock artık `_changes` broadcast + `_roleUpdatedAt` tutar + `dispose()` (StreamController) — provider ve mock_backend override'ı `ref.onDispose(repo.dispose)` aldı.
- **Provider:** `adminRosterProvider` (StreamProvider, yalnız admin akar).
- **UI:** yeni `admin_roster_screen.dart` (`AdminRosterScreen` — kadro listesi: superadmin=workspace_premium ikon/"Süper Yönetici", moderatör=gavel; UID + güncellenme tarihi; dokun → `showAdminUserActions` ile rol yönetimi). `admin_app.dart`: **4. sekme "Kadro" YALNIZ süper yöneticiye** (`isSuperAdminProvider`) — pages/destinations koşullu kurulur; `safeIndex = _index.clamp(...)` (rol düşerse taşan index'i kırpar).
- **Test (`test/admin_test.dart` +1 → 145/145):** watchRoster superadmin'i üstte sıralar, setRole (ata/kaldır) roster'a yansır. setRole testine `addTearDown(repo.dispose)`.
- Toplam **145/145**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY: bu oturum EK GETİRMEDİ.** Bekleyen deploy hâlâ Oturum 52-REVİZE+53+54+56'nınki (56 bloğunda tam liste — kadro ekranı o kuralı/CF'i kullanır, yenisini eklemez).
- **SIRADAKİ (admin Faz 2+ kalan):** cursor sayfalama + assignment (kuyruk ölçeklenmesi) · App Check enforce admin sitesinde · (ölçek) BigQuery export analitiği.
- ⚠️ Kullanıcı DEPLOY SONRASI: süper yönetici olarak admin sitesi → alt barda 4. sekme "Kadro" → tüm moderatör/superadmin'ler listelenir (superadmin üstte) → bir satıra dokun → rol değiştir/kaldır. Moderatör oturumunda "Kadro" sekmesi GÖRÜNMEZ.

--- (önceki oturumlar) ---

**Oturum 56 (2026-07-13, aynı gün): ADMIN FAZ 2 — ROL ATAMA (setAdminRole, superadmin-only) + RBAC delegasyonu. KOD TAMAM, 144/144 test, analyze 0, admin web OK. ⚠️ KURAL + CF DEPLOY BEKLİYOR.**
Kullanıcı "edelim" → RBAC tamamlandı: artık superadmin başka kullanıcıları **moderatör/superadmin** yapabilir veya yetkiyi kaldırabilir. Rol anlam kazandı: **moderatör** = şikayet/anlaşmazlık/askı; **superadmin** = ayrıca rol atama.
- **CF `adminSetRole` (functions/index.js, superadmin-only):** `auth.token.role=='superadmin'` şart. Roller: `moderator|superadmin|none`. **Kendi rolünü değiştiremez** (kilitlenme). `getUser` → mevcut claim'ler → `setCustomUserClaims` **`suspended`'ı KORUYARAK** admin/role ekler/siler → `adminRoles/{uid}` roster dokümanı set/delete → `revokeRefreshTokens` (yetki değişimi kesin yansısın) → audit (set_role/revoke_admin, before/after rol). `claimAdminAccess` da artık `adminRoles/{uid}` (superadmin) yazar (roster tutarlılığı).
- **Roster (`adminRoles/{uid}`):** neden gerekli — başka kullanıcının Auth claim'i İSTEMCİDEN OKUNAMAZ; rol atama ekranı hedefin mevcut rolünü buradan okur. Kural: `read: if isAdmin(); write: if false` (yalnız CF/Admin SDK yazar).
- **İstemci:** `AdminUserRepository`'ye `findRole(uid)` (adminRoles/{uid}.role) + `setRole(uid, role)` (CF) eklendi (+ Mock parite: `_roles` map). `isSuperAdminProvider` (currentUser.isSuperAdmin). `admin_users_screen.dart` `_UserActionSheet`: açılışta `findRole` ile mevcut rolü yükler ("Yönetici rolü: Moderatör/Süper Yönetici/Yok"); **rol ATAMA butonları YALNIZ oturumdaki superadmin'e** görünür (Moderatör yap / Süper Yönetici yap / Yetkiyi kaldır). `_roleLabel` helper. `showAdminUserActions` (Oturum 55) sayesinde şikayet/anlaşmazlık → kullanıcıyı yönet → rol atama zinciri de çalışır.
- **Test (`test/admin_test.dart` +1 → 144/144):** MockAdminUserRepository setRole atar/değiştirir/kaldırır, findRole yansıtır.
- Toplam **144/144**; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY (Oturum 52-REVİZE+53+54+56 birikmiş; 55 ek getirmedi):** (1) `firebase deploy --only firestore:rules` (artık adminRoles koleksiyonu da dahil) (2) `firebase deploy --only functions:claimAdminAccess,functions:adminResolveReport,functions:adminResolveDispute,functions:onJobWritten,functions:adminSetUserSuspended,functions:adminSetRole` (3) admin sitesi: create → `flutter build web -t lib/main_admin.dart` → `firebase deploy --only hosting:alljob1-admin`.
- **SIRADAKİ (admin Faz 2+ kalan):** cursor sayfalama + assignment (şikayet/anlaşmazlık kuyruğu) · App Check enforce admin sitesinde · (ölçek) BigQuery export analitiği · admin kadro (roster) listesi ekranı (adminRoles koleksiyonundan).
- ⚠️ Kullanıcı DEPLOY SONRASI: superadmin ile admin sitesi → Kullanıcılar → bir kullanıcı ara → alttaki "Moderatör yap" → o kullanıcı bir sonraki girişte admin paneline erişebilmeli ama Kullanıcılar sekmesinde rol atama butonlarını GÖRMEMELİ (moderatör). "Yetkiyi kaldır" → panel erişimi kalkar. Console `adminRoles` + `adminAuditLogs`'ta kayıt.

--- (önceki oturumlar) ---

**Oturum 55 (2026-07-13, aynı gün): ADMIN FAZ 2 — ŞİKAYET/ANLAŞMAZLIK → HEDEF KULLANICIYI YÖNET. Yalnız admin UI kablolaması → DEPLOY GEREKMEZ (yeni CF/kural yok). 143/143 test, analyze 0, admin web OK.**
Kullanıcı "edelim" → moderasyon döngüsü kapatıldı: bir şikayeti/anlaşmazlığı görürken tek dokunuşla ilgili kullanıcının askıya-alma sayfası açılır (Oturum 54'ün suspend akışını yeniden kullanır).
- **Ortak giriş (`admin_users_screen.dart`):** yeni top-level `showAdminUserActions(context, ref, uid, {onChanged})` → uid'yi `adminUserRepositoryProvider.findByUid` ile yükler → `_UserActionSheet`'i açar (bulunamazsa/hatada snackbar). `_UserActionSheet.onChanged` artık nullable (`?.call()`).
- **Şikayet detayı (`admin_reports_screen.dart`):** çözüm notunun üstüne "Bildirilen kullanıcıyı yönet" OutlinedButton (`reportedUid` boş değilse) → `showAdminUserActions`. Böylece şikayet → suspend tek ekranda.
- **Anlaşmazlık detayı (`admin_disputes_screen.dart`):** karar notunun üstüne Wrap: "Müşteriyi yönet" (customerId) + "Ustayı yönet" (selectedArtisanId varsa) → aynı ortak giriş.
- Yeni birim mantık YOK (testli `showAdminUserActions`/`MockAdminUserRepository` yeniden kullanıldı) → test sayısı 143/143 sabit; analyze 0; `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY: bu oturum için EK YOK.** Bekleyen deploy hâlâ Oturum 52-REVİZE+53+54'ünki (aşağıda 54 bloğunda tam liste). Bu oturum onların üstüne yeni bir şey EKLEMEDİ.
- **SIRADAKİ (admin Faz 2+ kalan):** `setAdminRole` superadmin-only CF (moderatör atama) · cursor sayfalama + assignment · App Check enforce admin sitesinde · (ölçek) BigQuery export.
- ⚠️ Kullanıcı DEPLOY SONRASI (54'ünkiyle aynı deploy): admin sitesi → Şikayetler/Anlaşmazlıklar → bir kayda dokun → detayda "…kullanıcıyı yönet" → Askıya Al/Kaldır sayfası açılmalı.

--- (önceki oturumlar) ---

**Oturum 54 (2026-07-13, aynı gün): ADMIN FAZ 2 — KULLANICI YÖNETİMİ (ASKIYA ALMA). Sunucu-zorlamalı. KOD TAMAM, 143/143 test, analyze 0, HER İKİ web hedefi OK. ⚠️ KURAL + CF DEPLOY BEKLİYOR.**
Kullanıcı AskUserQuestion → "Kullanıcı yönetimi (askıya alma)". Kötüye kullanan hesabı yönetici durdurur/geri açar. Oturum 53'ün hakemliğinden farkı: **bu KURAL DEĞİŞTİRDİ** (öncekinde değişmemişti).
- **Zorlama modeli SUNUCUDA (profesyonel/güvenli):** `suspended:true` custom claim → firestore.rules yeni **iş/teklif/mesaj/değerlendirme oluşturmayı** reddeder (`isSuspended()` helper + 4 create dalına `&& !isSuspended()`). İstemci kapısı tek başına yeterli değil; kural asıl kilit.
- **CF `adminSetUserSuspended` (functions/index.js):** admin claim doğrular → hedef `getUser` → **kendini VEYA başka yöneticiyi askıya ALAMAZ** (claims.admin==true reddedilir). `setCustomUserClaims` TÜM claim'leri değiştirir → mevcut admin/role KORUNARAK yalnız `suspended` eklenir/silinir. `users/{uid}`'e **yalnız bool ayna** (`suspended`+`suspendedAt`; NEDEN gizlilik için YAZILMAZ). Askıya alırken `revokeRefreshTokens` (claim kesin yansısın). `adminAuditLogs`'a suspend_user/unsuspend_user (before/after + **neden yalnız burada**). Dönüş {ok,suspended}.
- **Kurallar (firestore.rules — DEPLOY BEKLİYOR):** üst düzey `isSuspended()`. `users` create+update: owner artık `['phoneNumber','suspended','suspendedAt']` alanlarına dokunamaz (kendini "askıda değil" yapamaz — yalnız CF/Admin SDK yazar). jobs/offers/messages/reviews create'e `!isSuspended()` eklendi.
- **İstemci kapısı (tüketici app):** `AppUser.suspended` (herkese açık users dökümanı bool aynasından; toMap'e girmez). `route_paths.dart` `/suspended`. `app_router.dart` redirect: oturum açık + `user.suspended` → TÜM rotalar `/suspended`'a kilitlenir (yalnız çıkış); askıda değilken /suspended→home; askı kapısından çıkınca misafir→home. Yeni `suspended_screen.dart` (genel mesaj + "Çıkış Yap"; NEDEN gösterilmez — gizlilik, itiraz→destek).
- **Admin taraf:** yeni `admin_user_repository.dart` (`AdminUserRepository` arayüz + Firebase + Mock): `findByUid`/`findByEmail` (email tek-alan otomatik indeksli eşitlik) + `setSuspended`→CF. Görünüm modeli = `AppUser` (tekrar kullanıldı). Provider `adminUserRepositoryProvider`. Yeni `admin_users_screen.dart` (e-posta/UID ara → kart: ad/e-posta/UID + Aktif/Askıda çip → eylem sheet: askıda değilse neden kutusu + "Askıya Al" danger, askıdaysa "Askıyı Kaldır"). `admin_app.dart`: 3. sekme **Kullanıcılar** (`manage_accounts` ikon, IndexedStack'e eklendi).
- **Test (`test/admin_test.dart` +3 → 143/143):** MockAdminUserRepository findByUid/Email (email küçük-harf duyarsız) + setSuspended aç/kapa; AppUser.fromMap suspended okuma (yoksa false). `mock_backend.dart`'a `adminUserRepositoryProvider` override.
- Toplam **143/143**; analyze 0; `flutter build web` + `flutter build web -t lib/main_admin.dart` OK.
- **⚠️ DEPLOY (Oturum 52-REVİZE + 53 + 54 birikmiş, hepsi ayrı ayrı — Oturum 49 dersi):** (1) `firebase deploy --only firestore:rules` (52-REVİZE admin READ + 54 isSuspended guard'ları + users alan koruması) (2) `firebase deploy --only functions:claimAdminAccess,functions:adminResolveReport,functions:adminResolveDispute,functions:onJobWritten,functions:adminSetUserSuspended` (3) admin sitesi: `firebase hosting:sites:create alljob1-admin` → `flutter build web -t lib/main_admin.dart` → `firebase deploy --only hosting:alljob1-admin`.
- **SIRADAKİ (admin Faz 2+ kalan):** `setAdminRole` superadmin-only CF (moderatör atama) · cursor sayfalama + assignment · şikayet→hedefe git · App Check enforce admin sitesinde · (ölçek) BigQuery export.
- ⚠️ Kullanıcı DEPLOY SONRASI: admin sitesi → Kullanıcılar sekmesi → bir e-posta/UID ara → Askıya Al. O kullanıcı tüketici app'te girişte "Hesabınız askıya alındı" kapısı görmeli VE yeni iş/mesaj/teklif/değerlendirme oluşturamamalı (kural reddi). Askıyı Kaldır → normale döner. Console'da `adminAuditLogs`'ta suspend_user kaydı (neden dahil). Not: askıya alma cihazda oturum açıkken ~1 sa (token tazelenene) veya app yeniden açılışında yansır.

--- (önceki oturumlar) ---

**Oturum 53 (2026-07-13): ADMIN FAZ 2 — ANLAŞMAZLIK (DISPUTED) HAKEMLİĞİ. KOD TAMAM, 140/140 test, analyze 0, HER İKİ web hedefi OK. ⚠️ CF DEPLOY BEKLİYOR (kural DEĞİŞMEDİ).**
Kullanıcı AskUserQuestion → "Admin Faz 2'ye geçelim" (deploy'u kendisi sonra yapacak). Oturum 52-REVİZE deploy'u HÂLÂ bekliyor (rules + functions:claimAdminAccess,adminResolveReport + admin sitesi create+build+deploy).
- **Kapatılan gerçek boşluk:** `jobs` disputed yaşam döngüsü canlıydı ama takılan anlaşmazlığı YALNIZCA açan taraf geri çekebiliyordu → iki taraf anlaşamazsa iş sonsuza dek `disputed`'da donuyordu. Yöneticiye hakemlik yetkisi verildi.
- **KURAL DEĞİŞMEDİ (kilit nokta):** `jobs` zaten `allow read: if true` (herkese açık) + tüm mutasyon CF'den (Admin SDK kuralları aşar). Yani hakemlik için SADECE `firebase deploy --only functions:adminResolveDispute,functions:onJobWritten` gerekir — firestore.rules dokunulmadı.
- **CF `adminResolveDispute` (functions/index.js, adminResolveReport deseni):** admin claim doğrular → job `disputed` olmalı → 2 güvenli karar: `cancel`→status=cancelled (+cancelReason "Yönetici kararı" serbest metin), `restore`→status=`statusBeforeDispute` (yoksa inProgress). Her ikisi: dispute alanlarını `FieldValue.delete()` ile temizler, `adminResolved:true` yazar, `adminAuditLogs`'a ATOMİK batch kaydı (action=resolve_dispute), her iki tarafa (customer+selectedArtisanId) KESİN karar bildirimi (saveNotification docId `dispute_{jobId}` — onJobWritten'in `job_{jobId}`'siyle çakışmaz + sendPushToUid). **completedJobs muhasebesi güvenli:** restore→completed olsa bile onJobWritten `fromDispute` guard'ı çift artışı engelliyor (zaten sayılmıştı).
- **onJobWritten guard eklendi:** `wasDisputed && !isDisputed` "Sorun bildirimi geri çekildi" dalı artık `after.adminResolved !== true` ister — aksi halde İPTAL edilen işe "kaldığı yerden devam ediyor" YANLIŞ bildirimi giderdi. Admin kararı kendi kesin bildirimini gönderiyor.
- **İstemci (yeni `features/admin/data/admin_dispute_repository.dart`):** `DisputeDecision{cancelJob,restoreJob}` enum + `AdminDisputeRepository` (arayüz + Firebase + Mock). Firebase `watchDisputes`: TEK eşitlik filtresi `where('status'=='disputed').limit(200)` (otomatik indeksli, bileşik indeks gerekmez) + disputedAt desc BELLEK içinde sıralar. `resolveDispute`→CF. Mock CF paritesi (cancel→cancelled, restore→statusBeforeDispute, clearDispute). `Job` modeli aynen tekrar kullanıldı.
- **Providerlar (admin_providers.dart):** `adminDisputeRepositoryProvider`, `adminDisputesProvider` (yalnız admin akar), `openDisputeCountProvider` (rozet).
- **UI:** yeni `admin_disputes_screen.dart` (`AdminDisputesScreen` — GradientAppBar gavel + çıkış + kart listesi: taraf rozeti/başlık/neden/not/tarih → detay bottom sheet: bildirim notu/sorun öncesi durum/uid'ler + karar notu (her iki tarafa iletilir) + "Devam Ettir (X)" tonal + "İşi İptal Et" danger). `admin_app.dart`: `_AdminGate` artık `_AdminHomeScreen` döndürür — alt gezinme (`NavigationBar`) Şikayetler ⇄ Anlaşmazlıklar, `IndexedStack` (akışlar korunur), her sekmede rozet (openReport/openDispute sayısı). Her iki ekran kendi Scaffold+üst barını taşır.
- **Test (`test/admin_test.dart` +3 → 140/140):** MockAdminDisputeRepository watchDisputes disputedAt desc + yalnız disputed; cancel→kuyruktan düşer; restore→kuyruktan düşer. `_dispute(...)` helper. `mock_backend.dart`'a `adminDisputeRepositoryProvider` override eklendi.
- Toplam **140/140**; analyze 0; `flutter build web -t lib/main_admin.dart` + `flutter build web` OK.
- **⚠️ DEPLOY (Oturum 52-REVİZE'ninkiyle birlikte, hepsi ayrı ayrı — Oturum 49 dersi):** (1) `firebase deploy --only firestore:rules` (52-REVİZE) (2) `firebase deploy --only functions:claimAdminAccess,functions:adminResolveReport,functions:adminResolveDispute,functions:onJobWritten` (3) admin sitesi: `firebase hosting:sites:create alljob1-admin` → `flutter build web -t lib/main_admin.dart` → `firebase deploy --only hosting:alljob1-admin`.
- **SIRADAKİ (admin Faz 2+ kalan):** kullanıcı yönetimi (askıya alma CF) · `setAdminRole` superadmin-only CF (moderatör atama) · cursor sayfalama + assignment · App Check enforce admin sitesinde · (ölçek) BigQuery export.
- ⚠️ Kullanıcı DEPLOY SONRASI: admin sitesinden gir → alt "Anlaşmazlıklar" sekmesi; `disputed` bir iş varsa görünür → "İşi İptal Et" veya "Devam Ettir" → Console'da işin durumu değişmeli, `adminAuditLogs`'ta resolve_dispute kaydı, her iki tarafa bildirim gitmeli. (Test için: müşteri bir işte "Sorun Bildir" yapıp anlaşmazlık oluşturmalı.)

--- (aşağısı önceki oturumlar) ---

**Oturum 52-REVİZE (2026-07-12): ADMIN PANELİ PROFESYONEL MİMARİYE ÇEVRİLDİ (ölçek-hazır). Kullanıcı "milyonlarca kullanıcıya göre profesyonel yaklaşım" istedi → entegre Faz 1 canlıya ALINMADAN yeniden kuruldu. 137/137 test, analyze 0, HER İKİ web hedefi + functions syntax OK. ⚠️ KURALLAR + CF + AYRI HOSTING HENÜZ YAYINLANMADI.**
- **KARAR (kullanıcıyla): admin paneli AYRI uygulama** (tüketici binary'sine admin kodu girmez), **tüm eylemler CF üzerinden + audit log**, **RBAC rol claim**, **ölçek-hazır kuyruk**. Aşağıdaki entegre notlar TARİHSELDİR; güncel mimari bu bloktur.
- **Ayrı admin web uygulaması:** `lib/main_admin.dart` (kendi giriş noktası; `flutter build web -t lib/main_admin.dart`) + `features/admin/presentation/admin_app.dart` (`AdminApp` → `_AdminGate`: yükleniyor/giriş yok→`_AdminLoginScreen`/yetkisiz→`_AccessDeniedScreen` (bootstrap düğmesi+çıkış)/admin→`AdminReportsScreen`). Tüketici uygulamasından admin TAMAMEN çıkarıldı (drawer `_AdminTile`, `/admin` rota+guard+RoutePaths.adminReports silindi). `firebase.json` çok-siteli: site `alljob1` (yasal HTML, mevcut) + `alljob1-admin` (`build/web`, SPA rewrite). **DEPLOY ÖNCESİ TEK SEFERLİK:** `firebase hosting:sites:create alljob1-admin`, sonra `flutter build web -t lib/main_admin.dart` + `firebase deploy --only hosting:alljob1-admin`.
- **RBAC:** claim artık `{admin:true, role:'superadmin'}`. `AppUser.adminRole` + `isSuperAdmin` getter (kaynak Auth claim `role`; `_readAdminClaims` ikisini de okur). `claimAdminAccess` CF superadmin verir + audit log yazar.
- **Tüm yönetici mutasyonları CF üzerinden (istemci Firestore'a YAZMAZ):** `adminResolveReport` CF (functions/index.js) yetkiyi doğrular → durum+çözüm günceller + `adminAuditLogs` kaydını ATOMİK (batch) yazar; `resolvedBy` sunucuda auth.uid'den. `FirebaseAdminReportRepository.updateStatus` artık bu CF'i çağırır (doğrudan `doc.update` KALDIRILDI). Kural: reports admin-write dalı SİLİNDİ (yalnız şikayetçi tekrar-şikayet + admin READ); yeni `adminAuditLogs` koleksiyonu (read: isAdmin, write: false → yalnız Admin SDK).
- **Ölçek-hazır kuyruk:** `watchReports` `.limit(200)` (tüm koleksiyonu akıtma yok; cursor sayfalama SONRA). `createdAt` tek-alan sıralaması otomatik indeksli → bileşik indeks gerekmez.
- **Denetim günlüğü (audit log):** `adminAuditLogs/{id}` — actorUid/action/targetType/targetId/before/after/createdAt. `writeAuditLog(entry, batch?)` yardımcı; grant_admin + resolve_report kaydediliyor. KVKK/GDPR + hesap verebilirlik + anlaşmazlık savunması.
- **Test (`test/admin_test.dart`, 6):** eskiye ek claimAdminAccess superadmin rolü doğrulaması. Mock repo değişmedi (CF etkisini taklit eder) → testler geçer. Toplam **137/137**.
- **⚠️ DEPLOY (hazır, bekliyor):** (1) `firebase deploy --only firestore:rules` (2) `firebase deploy --only functions:claimAdminAccess,functions:adminResolveReport` (3) admin sitesi: create + build -t + `firebase deploy --only hosting:alljob1-admin`. Ayrı ayrı (Oturum 49 dersi).
- **SIRADAKİ (admin Faz 2+):** anlaşmazlık (disputed) hakemliği (CF üzerinden + audit) · kullanıcı yönetimi (askıya alma CF) · `setAdminRole` superadmin-only CF (başka moderatör atama) · cursor sayfalama + assignment · App Check enforce admin sitesinde · (ölçek) BigQuery export analitiği.
- ⚠️ Kullanıcı DEPLOY SONRASI: admin sitesi URL'sinden gir (`aboneai.plus@gmail.com`, e-posta doğrulanmış) → yetki yoksa "Yönetici erişimini etkinleştir" → panel; şikayeti Çözüldü/Reddet → Console'da `adminAuditLogs`'ta kayıt görünmeli. Tüketici uygulamasında admin izi OLMAMALI.

--- (aşağısı TARİHSEL: entegre ilk tasarım, canlıya alınmadan revize edildi) ---

**Oturum 52 (2026-07-12, aynı gün): ADMIN PANELİ — FAZ 1 (Şikayet Kuyruğu) — KOD TAMAM, DEPLOY ONAY BEKLİYOR. 137/137 test, analyze 0, web build OK. ⚠️ KURALLAR + CF HENÜZ YAYINLANMADI.**
Kullanıcı "eksik kalmasın, admin paneline başlayalım" + AskUserQuestion: platform = UYGULAMA İÇİ admin ekranları, ilk kapsam = ŞİKAYET KUYRUĞU. (4 tema commit'i önce push edildi.)
- **Ön koşul netliği:** tüm P0 kapalı+canlı; yol haritasındaki bekleyenler (CI, staging, analytics, zorunlu güncelleme, billing, tasarım) admin panelini BLOKE ETMİYOR. Veri altyapısı hazırdı: `reports` koleksiyonu canlı, `jobs` disputed yaşam döngüsü canlı. Tek eksik: `admin:true` custom claim + adminOnly kural — ki bunlar zaten panelin ilk adımı.
- **Yönetici claim'i (Auth custom claim `admin:true`, kaynağı SUNUCU):** `AppUser.isAdmin` eklendi (emailVerified kalıbı — Firestore'a YAZILMAZ; repo Auth token'ından `getIdTokenResult().claims['admin']` ile doldurur). `AuthRepository.claimAdminAccess()` (Firebase: `claimAdminAccess` CF çağırır → `getIdToken(true)` ile token tazeler → manuel yayınla akışa yansıtır; Mock: bootstrap e-postaysa isAdmin=true). CF `claimAdminAccess` (functions/index.js): çağıranın DOĞRULANMIŞ e-postası `ADMIN_BOOTSTRAP_EMAILS`'te ise KENDİNE claim yazar (istemci kendine keyfî admin OLAMAZ). Bootstrap listesi `admin_config.dart` (istemci görünürlük) ↔ index.js (asıl karar) — şimdilik `aboneai.plus@gmail.com`.
- **Kurallar (firestore.rules — DEPLOY BEKLİYOR):** üst düzey `isAdmin()` (`request.auth.token.admin == true`). `reports`: `read: if isAdmin()` (kuyruk yalnız yöneticiye), `update` iki dal: (a) şikayetçi kendi kaydını tekrar-şikayetle günceller, (b) yönetici YALNIZ `['status','adminNote','resolvedBy','resolvedAt']` alanlarını değiştirir (kimlik/hedef alanlarına dokunamaz); delete kapalı.
- **Veri/repo:** `features/admin/` yeni modül. `Report` tam okuma modeli (`admin_report.dart`) + `ReportStatus` (open/reviewing/resolved/dismissed, `isClosed`). `AdminReportRepository` (arayüz + Firebase `reports` orderBy createdAt desc + Mock) — `watchReports({openOnly})` + `updateStatus`. `admin_providers.dart`: `isAdminProvider`, `adminReportRepositoryProvider`, `adminReportsProvider` (yalnız admin akar), `openReportCountProvider` (rozet).
- **UI:** `/admin/reports` rotası (router guard: `/admin` needsLogin + `!user.isAdmin` → home). `AdminReportsScreen` (GradientAppBar + Açık/Tümü filtre + kart listesi + boş durum) → karta dokun → detay bottom sheet (hedef/neden/not/uid'ler/tarih + çözüm notu + İncelemeye Al / Çözüldü / Reddet → `updateStatus`). Drawer'a `_AdminTile`: yalnız `isAdmin || bootstrap e-posta` görürse görünür; admin ise açık şikayet rozetiyle panele gider, değilse (bootstrap) önce `claimAdminAccess` çalıştırır sonra panele.
- **Test (`test/admin_test.dart`, 6):** Report.fromMap tam çözme + bozuk enum güvenli; ReportStatus.isClosed; MockAdminReportRepository sıralama/openOnly/updateStatus; claimAdminAccess izinli→admin, izinsiz→reddedilir. `mock_backend.dart`'a `adminReportRepositoryProvider` override eklendi. Toplam **137/137**.
- **⚠️ DEPLOY GEREKLİ — HENÜZ YAPILMADI:** `firebase deploy --only firestore:rules` + `firebase deploy --only functions:claimAdminAccess`. (Ayrı ayrı — Oturum 49 dersi.) Deploy'a kadar cihazda kuyruk permission-denied alır ve claim yazılamaz.
- **SIRADAKİ (admin Faz 2+):** anlaşmazlık (disputed iş) hakemliği; kullanıcı yönetimi (arama/askıya alma/usta doğrulama); başka kullanıcıyı admin yapma (admin-only callable); reports için hedefe (mesaj/ilan/kullanıcı) hızlı gidiş linki.
- ⚠️ Kullanıcı DEPLOY SONRASI: `aboneai.plus@gmail.com` ile giriş (e-posta doğrulanmış olmalı) → ☰ menü → "Yönetici Erişimini Etkinleştir" → sonra "Yönetici Paneli" → şikayet kuyruğu görünür; bir şikayeti Çözüldü/Reddet yapabilmeli. Doğrulanmamış e-postayla veya başka hesapla erişim reddedilir.

**Oturum 51 (2026-07-12, aynı gün): KULLANICI SEÇİMLİ VURGU RENGİ (Görünüm ayarı). Yalnız istemci → deploy GEREKMEDİ. 131/131 test, analyze 0, web build OK.**
Kullanıcı: "Görünüm altında Sistem/Açık/Koyu var; altına Usta için 4 güzel renk, Müşteri için de 4 renk koyalım; seçtiği renk sonraki açılışta da kalsın." Oturum 50'nin SABİT mod-renginin yerini KULLANICI SEÇİMİ aldı.
- **4 hazır renk (`accent_options.dart`):** `AccentOption` (id/labelTR/swatch + açık+koyu tam `AppAccent`). Liste: **Mavi(#2563EB) / Yeşil(#059669) / Mor(#7C3AED) / Turuncu(#EA580C)** — her biri primary ailesi + hero durakları (açık+koyu). `kAccentOptions`, `accentById(id, fallbackId)`, `kDefaultCustomerAccentId='blue'`, `kDefaultArtisanAccentId='emerald'`.
- **`AppAccent` sadeleştirildi:** artık yalnız veri taşıyıcı (tek parlaklık için renk seti); statik preset'ler + `resolve()` KALDIRILDI (preset'ler AccentOption'a taşındı).
- **Kalıcılık (`accent_state.dart`):** `customerAccentIdProvider`/`artisanAccentIdProvider` (StateProvider<String>); `read/save CustomerAccentId`/`ArtisanAccentId` (SharedPreferences, anahtarlar `accent_customer_v1`/`accent_artisan_v1`). Geçersiz/kaldırılmış id → varsayılana düşer. `main.dart` açılışta ikisini okuyup ProviderScope override eder (themeMode kalıbı).
- **`app.dart`:** aktif mod → o modun seçili accent id'si → `accentById` → `AppTheme.light(accent.light)`/`dark(accent.dark)`. Mod VEYA renk değişince tema yeniden kurulur, `AppPalette.lerp` ile yumuşak geçer.
- **UI (`app_menu_drawer` Görünüm sayfası yeniden yazıldı):** eski tek-seçim pop'lı sheet → `_AppearanceSheet` (ConsumerWidget, kapanmadan canlı uygulanır): tutma çubuğu + tema modu radio'ları (Sistem/Açık/Koyu, anında set+kaydet) + "Renk" başlığı + **Müşteri modu** ve **Usta modu** için birer `_AccentRow` (4 `_Swatch`: 42px daire, seçiliyse ink çerçeve + tik, tooltip=renk adı, Semantics). Dokununca ilgili provider set + kalıcı kaydet.
- **Test (`test/theme_mode_test.dart`):** Oturum 50'nin sabit-renk testi → "seçenekler temaya doğru enjekte" (blue/emerald primary + hero değişir, yüzey/metin sabit; 4 benzersiz id; bilinmeyen→varsayılan) + "müşteri/usta bağımsız kalıcı roundtrip (violet/orange) + geçersiz id→varsayılan". Toplam **131/131**.
- **EK (aynı oturum): renk sayısı 4 → 6.** Kullanıcı "6'ya çıksın, güzel bir pembe ekle, cırtlak/neon olmasın" dedi. Eklenenler: **Pembe (#DB2777)** ve **Turkuaz (#0D9488)** (olgun, doygun ama neon değil; turkuaz light primary #0F766E ile beyaz metin okunur). Sıra: Mavi, Yeşil, Turkuaz, Mor, Pembe, Turuncu. `_AccentRow` `Row` → `Wrap` (6 daire dar ekranda taşmaz, alt satıra sarar). Test `hasLength(4)` → 6 + pink/teal içerir.
- Toplam **131/131**; analyze 0; `flutter build web` OK.
- ⚠️ Kullanıcı cihazda: Menü (☰) → Görünüm → altta Müşteri modu / Usta modu için 6 renk dairesi; birini seç → o moddayken tüm vurgu+üst bar o renge döner; uygulamayı kapat-aç → seçim korunur. Müşteri ve usta ayrı renk tutar.

**Oturum 50 (2026-07-12, aynı gün): MOD-BAZLI VURGU RENGİ — müşteri modu tatlı mavi (#2563EB), usta modu zümrüt yeşil (#059669). Yalnız istemci → deploy GEREKMEDİ. 130/130 test, analyze 0, web build OK.**
Kullanıcı: "müşteri moduna geçince farklı tatlı bir mavi, usta modu farklı bir renk olsa." AskUserQuestion ile şema seçildi: müşteri mavi + usta yeşil (turuncu/mor seçenekleri elendi).
- **Yaklaşım (tema seviyesi, tek noktadan):** yeni `lib/core/theme/app_accent.dart` → `AppAccent` (mod başına primary ailesi: primary/onPrimary/primaryDark/primaryContainer/onPrimaryContainer/inversePrimary; açık+koyu ayrı sabitler; `customerLight/Dark`, `artisanLight/Dark`, `resolve({artisan,isDark})`). `AppTheme.light/dark` GETTER → FONKSİYON oldu (`AppTheme.light([AppAccent? accent])`, accent yoksa müşteri mavi varsayılan). `_build(brightness, accent)` accent'i hem `ColorScheme`'in primary ailesine (`.copyWith`) hem de `AppPalette`'e (`.copyWith`) enjekte eder. `app.dart` `currentUserProvider.select((u)=>u?.isArtisan ?? false)` izler → `AppAccent.resolve` → tema. Mod değişince MaterialApp yeniden kurulur; `AppPalette.lerp` zaten tanımlı olduğundan renkler YUMUŞAKÇA geçer.
- **Etki alanı:** butonlar/FAB/bağlantılar/odak kenarları/sekmeler/progress + `context.palette.primary` kullanan HER ŞEY (alt gezinme çubuğu seçili sekmesi dâhil, `role_bottom_bar` `palette.primary`) + `GradientAppBar` ışıması (lacivert hero zemini MARKA olarak sabit; yalnız radyal ışıma moda uyar — const turuncu `0x47EA580C` → `context.palette.primary` alpha 0.28). Misafir/oturumsuz → müşteri mavi.
- **BİLİNÇLİ SABİT (marka kimliği, moda göre DEĞİŞMEZ):** logo/`brand_mark`, `brandGradient`/`heroGradient` turuncu, splash/onboarding/login hero'ları, dashboard/kart marka gradyanları (~16 dosyada statik `AppColors.primary`). Bunlar marka çıpası; accent yalnız etkileşim vurgusudur.
- ⚠️ NOT (kullanıcıya söylendi): usta yeşili (#059669) uygulamanın başarı/müsait yeşiline (#039855 / müsait halkası #34D399→#059669) yakın; ana aksiyon ile başarı/müsait durumu arasında hafif benzeşme olabilir. Rahatsız ederse `app_accent.dart`'tan tek yerden değişir (ör. teal #0D9488 veya indigo).
- **Test (`test/theme_mode_test.dart` +1):** müşteri primary mavi / usta primary yeşil (ColorScheme + AppPalette), iki mod farklı, marka-dışı roller (surface/ink) İKİ MODDA AYNI (tüm tema baştan boyanmıyor — yalnız vurgu), `resolve` doğru set. Ayrıca 2 çağrı yeri güncellendi: `AppTheme.light/dark` artık fonksiyon → `create_job_screen_test` ve `theme_mode_test`'te `()` eklendi.
- **EK (aynı oturum): ÜST BAR / HERO GRADYANI da moda göre renklendirildi.** Kullanıcı "üst bardaki renkler değişir diye düşünmüştüm" dedi — ilk turda yalnız ışımayı renklendirmiştim (çok belirsiz). Artık lacivert `heroGradient` yerine mod-bazlı derin gradyan: müşteri mavi (top `#1D4ED8` → bottom `#172554`), usta zümrüt (top `#047857` → bottom `#022C22`); beyaz metin okunacak kadar koyu. `AppAccent`'e `heroTop/heroBottom` + `AppPalette`'e `heroTop/heroBottom` alanları ve `heroGradient` getter'ı (lerp'e dâhil → yumuşak geçiş) eklendi; `_build` accent'ten enjekte eder.
- **Etki (in-app, mod var):** `GradientAppBar` (ikincil ekran üst barları), müşteri ana ekran `_HeroHeader`, Profil hero'su, `app_menu_drawer` başlığı, `premium_screen`, `artisan_profile_screen` → hepsi `context.palette.heroGradient`. GradientAppBar radyal ışıması artık BEYAZ ışıltı (renk yerine derinlik). **BİLİNÇLİ LACİVERT KALAN (giriş öncesi, mod YOK):** `splash_screen`, `login_screen` — kural: "lacivert = giriş öncesi nötr marka, mavi/yeşil = aktif modun". Logo/`brandGradient` turuncu sabit.
- Toplam **130/130**; analyze 0; `flutter build web` OK.
- ⚠️ Kullanıcı cihazda görebilir: Profil → Müşteri/Usta anahtarı → tüm uygulama vurgusu VE üst bar/hero mavi↔yeşil yumuşakça geçmeli (butonlar, alt bar seçili sekme, GradientAppBar zemini, ana ekran/profil hero'su, drawer başlığı). Giriş ekranı + splash lacivert; logo turuncu kalmalı.

**Oturum 49 (2026-07-12, aynı gün): TAKİP MERKEZİ — FAZ 5 (SON FAZ: hafif bulut yedek) TAMAMLANDI. KURALLAR (Firestore + Storage) CANLIDA ✅. 129/129 test, analyze 0, web build OK + ANDROID APK OK. Kullanıcı deploy'u açıkça onayladı (AskUserQuestion).**
- **Amaç:** yerel-öncelikli mimari KORUNUR; bulut YALNIZ elle yedek/geri yükle (CANLI SENKRON YOK). Metadata Firestore'a, ek dosyaları (foto/dosya/ses) Storage'a.
- **Firestore `users/{uid}/trackBackup/{id}` (owner-only kural):** `FirebaseTrackBackupRepository` — kayıtlar tek batch ile aynalanır (eksikler silinir, mevcutlar üzerine yazılır); özet ayrılmış `__meta` dokümanında (`updatedAt`,`count`; TrackItem id'leri `t_` ile başladığından çakışmaz). `MockTrackBackupRepository` bellek-içi parite (map replace = otomatik ayna). `TrackBackupRepository` arayüzü + `TrackBackupInfo`.
- **Storage `track/{uid}/{recordId}/{fileName}` (owner-only read+write, GİZLİ):** KRİTİK — bu yol **4 segmentli** seçildi; mevcut genel `/{folder}/{uid}/{fileName}` (3 segment, `allow read: if true` KAMUYA AÇIK) kuralı tek-segment joker olduğundan 4 segmentli yolu EŞLEŞTİRMEZ → kişisel takip ekleri yanlışlıkla herkese açılmaz. Boyut sınırı 25 MB (ses/dosya görselden büyük olabilir). Kişisel foto/ses için kamuya-açık okuma KABUL EDİLEMEZDİ; ayrı gizli yol şart.
- **`StorageRepository` genişletildi:** genel `uploadBytes({path,bytes,contentType})` (yalnız görsel değil, tam yol) + `downloadBytes(handle)` — hem Mock (bellek) hem Firebase (`ref.putData`/`refFromURL().getData(30MB)`) impl. Mevcut `uploadImage`/`localBytes` dokunulmadı.
- **`AttachmentStore`:** `saveBytes(...)` eklendi (buluttan indirilen baytları yerele yazar); `baseDirOverride` (yalnız test — path_provider olmadan temp dizin) eklendi.
- **`TrackBackupService` (orkestrasyon, `application/`):** `backupNow()` = aktif kayıtları oku → her ek dosyasını Storage'a yükle → yedek kaydında bulut adresiyle değiştir → repoya yaz + `__meta` güncelle (yüklenemeyen ek atlanır, kayıt yine yedeklenir). `restoreNow()` = buluttan oku → her ek baytını indir → `AttachmentStore.saveBytes` ile yerele → repoya upsert + `notif.sync` (gelecekteki hatırlatmalar yeniden planlanır). BİRLEŞTİRME semantiği: aynı id üzerine yazılır, yerelde olup bulutta olmayan SİLİNMEZ. `BackupResult` (ok/count/error).
- **UI:** `TrackBackupScreen` (`/tracking/backup`) — son yedek bilgi kartı + "Şimdi Yedekle" + "Yedeği Geri Yükle" (onay diyaloglu, yedek yoksa pasif) + yerel-öncelikli açıklama kutusu. Giriş: Takip Merkezi üst barına `cloud_sync_outlined` ikonu (Çöp Kutusu'nun yanına). Rota `/tracking/backup`, `/tracking/:id`'den ÖNCE (sıra kritik kalıbı).
- **Providerlar:** `trackBackupRepositoryProvider` (Firebase↔Mock, `useFirebaseBackend`), `trackBackupServiceProvider`. mock_backend.dart override'a `MockTrackBackupRepository` eklendi.
- **Test (`test/tracking_test.dart` → 29 test, +2):** (1) kayıt+foto eki yedeklenir → yereli+kaynağı sil → geri yükle → kayıt+ek geri gelir, ek baytları BİRE BİR korunur (gerçek temp dosya + temp AttachmentStore + Mock storage). (2) yedek tam AYNADIR: 2 kayıt yedekle, birini yerelden sil, tekrar yedekle → bulutta 1 kalır, restore aynadan düşeni geri getirmez. **DERS:** AttachmentStore artık `implements` edilen test sahtesi `_RecordingStore`'a `saveBytes` override'ı EKLENMELİ (arayüz genişledi).
- Toplam **129/129**; analyze 0; `flutter build web` OK; `flutter build apk --debug` OK.
- **DEPLOY YAPILDI ✅:** `firebase deploy --only firestore:rules,storage`. **DERS:** birleşik `firestore:rules,storage` komutu `firebaserules.googleapis.com/...:test` precheck'inde "Failed to make request" verdi (NODE_OPTIONS ipv4first AYARLIYKEN bile — precheck endpoint'i flaky). AYRI AYRI çalıştırınca (`--only storage` sonra `--only firestore:rules`) ikisi de İLK denemede yüklendi. Bir dahaki sefere: takılırsa ayır.
- **TAKİP MERKEZİ 5 FAZ TAMAMLANDI ✅.** Sıradaki (YOL_HARITASI P1/Sprint): rules testleri/CI, zorunlu güncelleme, App Check zorlaması, Play Billing (beta sonrası).
- ⚠️ Kullanıcı gerçek cihazda (tek hesap yeter) YENİ BUILD ile denemeli: Takip Merkezi → bulut ikonu → Şimdi Yedekle → "N takip yedeklendi"; uygulamayı sil/yeniden kur (veya başka cihaz) → aynı hesapla gir → Geri Yükle → kayıtlar + ekler (foto/ses) geri gelmeli. Storage'da `track/{uid}/...`, Firestore'da `users/{uid}/trackBackup/*` görünmeli.

**Oturum 48 (2026-07-12, aynı gün): TAKİP MERKEZİ — FAZ 4 (tam filtre paneli + sıralama + erişilebilirlik + koyu tema turu) TAMAMLANDI. Yalnız istemci → deploy GEREKMEDİ. 127/127 test, analyze 0, web build OK + ANDROID APK OK. Otonom (kullanıcı önceki "tam yetki, dışardayım" talimatıyla).**
- **Filtre motoru `application/track_filter.dart` (SAF, test edilebilir):** `TrackFilter` (immutable + copyWith) — durum (Tümü/Aktif/Tamamlanan), öncelik çoklu seçim, etiket çoklu seçim (herhangi biri eşleşir), yalnız-hatırlatmalı, sıralama. `TrackSort` (son güncellenen[vars.]/son eklenen/hatırlatmaya göre/önceliğe göre/başlık A-Z). `apply(items, query:)` filtre+arama+sıralama yapar; `reminderAsc`'te hatırlatması olmayanlar sona; `advancedCount` (öncelik+etiket+hatırlatma rozeti için), `isDefault`. `collectTags(items)` benzersiz+sıralı etiketler.
- **Filtre paneli `widgets/filter_sheet.dart`:** `showTrackFilterSheet` → sıralama ChoiceChip'leri + öncelik/etiket FilterChip'leri + "Yalnız hatırlatması olanlar" switch + Temizle/Uygula. "Uygula" yeni TrackFilter döndürür (iptal→null).
- **Center ekranı yeniden bağlandı:** eski yerel `_StatusFilter` enum'u ve inline `_apply` SİLİNDİ → `TrackFilter` kullanır. Durum çipleri yatay kaydırılır (`_StatusChip`), yanında `_FilterButton` (tune ikonu + aktif filtre sayısı rozeti, `advancedCount>0` ise `primaryContainer` vurgulu). Arama kutusu + durum çipleri hızlı erişimde kaldı; gelişmiş filtreler panelde.
- **Erişilebilirlik:** TrackCard tamamla dairesi artık `Semantics(button, checked, label)` + `Tooltip` ("Tamamla"/"Aktif yap") ve **dokunma hedefi 44px yüksekliğe** çıkarıldı (genişlik 28px dar → yatay düzen bozulmadı, daire üste hizalı). Durum çiplerinde `Semantics(button, selected)`; filtre/arama-temizle düğmelerinde tooltip.
- **Koyu tema turu:** tüm tracking ekranları `context.palette` kullanıyor (Oturum 38 kalıbı) — denetlendi, kırık ton YOK. Tek bilinçli sabit renkler: foto silme rozeti scrim'i (`Colors.black54` foto üstünde) ve tam ekran foto görüntüleyici siyah zemini (her iki temada da doğru). filter_sheet/record_sheet tema-farkındalıklı (ChoiceChip/FilterChip/Switch + palette).
- **Test (`test/tracking_test.dart` → 27 test, +7):** TrackFilter birim testleri (durum/öncelik/etiket/hatırlatma/arama + 3 sıralama + advancedCount/isDefault + collectTags) + Faz 4 widget testi (filtre panelini aç → "Yüksek" seç → Uygula → liste yüksek önceliğe daralır).
- Toplam **127/127**; analyze 0; `flutter build web` OK; `flutter build apk --debug` OK (Oturum 47 dersi: native değişiklik olmasa da APK doğrulandı).
- **SIRADAKİ: TAKİP MERKEZİ Faz 5 (SON FAZ)** — hafif bulut yedek: Firestore/Storage'a **yedek + geri yükle** (canlı senkron DEĞİL). Kayıtlar `users/{uid}/trackBackup/{id}` (veya tek doküman), ek dosyaları Storage `track/{uid}/...`; kural gerekir (kendi verisine erişim) → DEPLOY gerekecek. Manuel "Yedekle"/"Geri Yükle" düğmeleri (Takip Merkezi menüsü veya Profil). Not: yerel-öncelikli mimari korunur; bulut yalnız yedek.
- ⚠️ Kullanıcı cihazda deneyebilir: Takip Merkezi → tune ikonu → öncelik/etiket/sıralama seç → Uygula; rozet aktif filtre sayısını göstermeli; sıralama uygulanmalı.
**Oturum 47 (2026-07-12, aynı gün): TAKİP MERKEZİ — FAZ 3 (zengin alanlar: kişi/telefon, konum, foto/dosya/ses ekleri) TAMAMLANDI. Yalnız istemci → deploy GEREKMEDİ. 120/120 test, analyze 0, web build OK + ANDROID APK OK. Kullanıcı "tam yetki, onay isteme, dışardayım" dedi — otonom yürütüldü.**
- **Paketler:** `file_picker: ^11.0.2` (dosya), `record: ^6.2.1` (ses kaydı), `path_provider: ^2.1.6` (yerel dizin), `audioplayers: ^6.7.1` (ses oynatma). Foto: mevcut `image_picker`. **API sürprizleri (paket kaynağından doğrulandı):** file_picker v11 → `FilePicker.pickFiles(...)` STATİK (eski `FilePicker.platform` YOK); record v6 → `AudioRecorder()`, `hasPermission()`, `start(RecordConfig(), path:)`, `stop()→String?`.
- **KRİTİK — Android build kırıklığı bulundu ve düzeltildi (Faz 2'den beri LATENT):** `flutter_local_notifications` **core library desugaring** gerektiriyor; Faz 2'de yalnız `flutter build web` çalıştırdığım için fark edilmemişti — **Android APK derlenmiyordu.** DÜZELTME `android/app/build.gradle.kts`: `compileOptions { isCoreLibraryDesugaringEnabled = true }` + `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`. **DERS: yerel bildirim/native-ağır paket eklerken `flutter build apk --debug` DE çalıştır — web build native Android sorunlarını yakalamaz.** (Bu oturumdan itibaren doğrulamaya Android APK dahil edildi.)
- **Ekler YEREL saklanır (bulut Faz 5):** yeni `AttachmentStore` — seçilen/kaydedilen dosyayı `<appDocs>/track_attachments/`'a KOPYALAR (kaynak önbelleği silinse de ek durur); `save/deleteFile/deleteFiles`. Ses kaydı geçici dosyası `move:true` ile taşınır (rename başarısızsa kopya+sil fallback). `attachmentStoreProvider`.
- **Controller:** `deletePermanently` + `emptyTrash` artık kaydın ek dosyalarını da diskten siler (yerel kopyalar sızmasın).
- **UI (`track_edit_screen`):** 3 yeni "Ekle" çipi — **İlgili kişi** (Ad + Telefon), **Konum** (serbest metin adres/etiket; lat/lng modelde var, GPS BİLİNÇLİ eklenmedi — Faz 4/ileri), **Ek** → bottom sheet (Fotoğraf=image_picker / Dosya=file_picker / Ses kaydı). `_save` artık person/location/attachments'ı da kurar (copyWith null temizleyemediği için tam-kurulum kalıbı sürüyor). Yeni `widgets/attachment_views.dart` (AttachmentEditor: foto küçük resim+sil, dosya/ses satırı+sil, "Ek ekle" spinner'lı) ve `widgets/record_sheet.dart` (`showRecordSheet` → mikrofon izni + sayaçlı kayıt sayfası, iptal geçici dosyayı siler → `RecordResult(path,durationMs)`).
- **UI (`track_detail_screen`):** kişi (telefon SelectableText) + konum satırları; "Ekler" bölümü `AttachmentGallery` — foto küçük resimleri (dokun → tam ekran `InteractiveViewer`), dosya satırları, ses notları **oynat/duraklat** (`audioplayers` `DeviceFileSource`, `_AudioTile`).
- **AndroidManifest:** `RECORD_AUDIO` izni eklendi (ses kaydı).
- **Test (`test/tracking_test.dart` → 20 test, +4):** Faz 3 widget testi (kişi+konum gir → kaydet → detayda görün) + controller ek temizliği (kalıcı silme ve çöp boşaltma ek dosyalarını siler — sahte `_RecordingStore`). Model attachments round-trip zaten vardı. **NOT:** gerçek foto/dosya/ses SEÇME ve ses OYNATMA platform gerektirir → widget testinde denenmez (mikrofon/galeri yok); sahte depo + kişi/konum (saf UI) test edildi.
- Toplam **120/120**; analyze 0; `flutter build web` OK; `flutter build apk --debug` OK.
- **SIRADAKİ: TAKİP MERKEZİ Faz 4** — tam filtre paneli + cila + erişilebilirlik + koyu tema turu. (Sonra Faz 5: hafif bulut yedek — Firestore/Storage'a yedek+geri yükle, senkron DEĞİL; ekler Storage'a, kayıtlar Firestore'a.)
- ⚠️ Kullanıcı gerçek cihazda (emülatör/telefon; Windows'ta test edilemez) YENİ BUILD ile denemeli: Takip → Yeni → Ek → Fotoğraf/Dosya/Ses kaydı ekle; kaydet; detayda foto tam ekran açılmalı, ses notu oynamalı; kişi telefonu seçilebilir olmalı. Ek eklenen kayıt kalıcı silinince dosyalar da gitmeli. iOS Windows'ta test edilemez (ses/foto izinleri iOS'ta ayrıca Info.plist gerektirir — Faz 4'te iOS turu yapılırsa NSMicrophoneUsageDescription/NSPhotoLibraryUsageDescription eklenmeli).

**Oturum 46 (2026-07-12, aynı gün): TAKİP MERKEZİ — FAZ 2 (hatırlatma + tekrarlama motoru) TAMAMLANDI. Yalnız istemci (yerel bildirim; kural/CF YOK) → deploy GEREKMEDİ. 117/117 test, analyze 0, web build OK.**
Kullanıcı "faz 2 de neler var" → anlattım → "başla" dedi. AskUserQuestion ile TEKRARLAMA MODELİ netleşti: **"aynı kayıt ilerlesin"** (tekrarlı takip tamamlanınca yeni kopya ÜRETİLMEZ; kayıt AKTİF kalır, `reminderAt` bir sonraki tarihe kayar — Apple/Google Hatırlatıcılar modeli, geçmiş tutulmaz).
- **Paket:** `flutter_local_notifications: ^22.0.1` + `timezone: ^0.11.1`. TAMAMEN yerel (FCM/bulut YOK; cihazda planlanır). **v22 API adlandırılmış parametre ister:** `initialize(settings: ...)`, `zonedSchedule(id:, title:, body:, scheduledDate:, notificationDetails:, androidScheduleMode:)`, `cancel(id:)` — pozisyonel kullanım DERLENMEZ (paket kaynağından doğrulandı: `.../flutter_local_notifications-22.0.1/lib/src/flutter_local_notifications_plugin.dart`).
- **Saat dilimi:** `timezone` + `tz.setLocalLocation(tz.getLocation('Europe/Istanbul'))` — TR kalıcı UTC+3 (DST yok), doğru duvar-saati. NOT: uluslararasılaşınca cihazın gerçek zonunu almak için `flutter_timezone` eklenmeli (aksi halde tz.local=UTC → yanlış saat).
- **Servis `TrackNotificationService` (PushService kalıbı: arayüz + gerçek + no-op):** `init/ensurePermission/sync/cancel`. `LocalTrackNotificationService` gerçek planlar; `NoopTrackNotificationService` web/test. `trackNotificationServiceProvider` web'de Noop. **`sync(item)` idempotent:** aktif+çöpte değil+GELECEK reminderAt varsa planlar, aksi halde (tamamlandı/çöpte/geçmiş/boş) iptal eder. Bildirim id'si String kayıt id'sinden kararlı 31-bit hash (`trackNotificationId`). Bildirime dokununca `RoutePaths.trackDetail(id)`'e gider (payload=id). **Kesin alarm (SCHEDULE_EXACT_ALARM) BİLİNÇLİ İSTENMEDİ** → `AndroidScheduleMode.inexactAllowWhileIdle` (Play kısıtı yok; hatırlatma birkaç dk sapabilir). Tüm metotlar try/catch (eklenti yoksa/başlatılmamışsa çökmez).
- **AndroidManifest (`android/app/src/main/AndroidManifest.xml`):** `POST_NOTIFICATIONS` + `RECEIVE_BOOT_COMPLETED` + `VIBRATE` izinleri; `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` (boot sonrası yeniden planlama) alıcıları. **DOĞRULANDI:** bu sınıflar v22'de var ve eklentinin KENDİ manifesti bunları BİLDİRMİYOR → uygulama manifestine eklemek ZORUNLU (yoksa zamanlanmış bildirim düşmez).
- **Tekrarlama matematiği (`TrackRecurrence.nextAfter(from)` — model'de, saf):** none→null; daily +1g; weekly +7g; monthly/yearly `_addMonths` ile — **ay-sonu taşması ayın SON gününe kırpılır** (31 Oca +1ay → 28/29 Şub; 29 Şub +1yıl → 28 Şub); geçersiz tarih (31 Şub → 3 Mar) OLUŞMAZ. Saat/dakika korunur.
- **Controller (`TrackingController` — bildirim senkronu eklendi):** `save`→upsert+`notif.sync`; `toggleDone`→**tekrarlı+hatırlatmalı ve tamamlanıyorsa** aynı kayıt AKTİF kalır + `reminderAt = nextAfter(...)` (geçmişte kalan tekrarları atlayıp ilk GELECEK tarihe ilerler, 5000 üst sınır); tekrarsız→aktif↔tamamlandı; `moveToTrash`→`notif.cancel`; `restore`→repo.restore+item okuyup `notif.sync`; `deletePermanently`→cancel+sil; `emptyTrash`→çöptekileri cancel+boşalt. `app.dart`'ta açılışta `notif.init()` (tap işleyicisi hazır olsun).
- **UI (`track_edit_screen`):** yeni "Ekle" çipi **Hatırlatma** → açılınca `_ReminderEditor`: tarih (`showDatePicker`) + saat (`showTimePicker`) seçici; seçili tarih kartı (dokun=değiştir, ×=kaldır) + **Tekrar** ChoiceChip'leri (Tekrar yok/Her gün/hafta/ay/yıl). İlk hatırlatma kurulurken `ensurePermission()` (izin reddedilse de kayıt olur, yalnız bildirim düşmez). **`_save` copyWith'ten TAM TrackItem kurulumuna geçti** (copyWith null'ı temizleyemiyor — hatırlatma kaldırma; ayrıca düzenlerken status/kişi/konum/ek KORUNUR). Detay ekranında hatırlatma+tekrar bilgi çipleri; TrackCard'da hatırlatma rozeti zaten vardı.
- **Test (`test/tracking_test.dart` → 16 test, +7):** nextAfter kenar durumları (ay-sonu kırpma, artık yıl, saat koruma); controller — save senkronlar / çöp-kalıcı silme iptal eder / restore yeniden senkron; tekrarlı tamamlanınca AKTİF+ileri tarih; tekrarsız tamamlanınca done. **DERSLER:** (1) v22 named-param API. (2) düz `test`te (widget değil) `ProviderContainer`'da stream-türevli `currentUserProvider` DİNLENMEZSE null kalır → `container.listen(currentUserProvider,...)` + kaydın akışa yansımasını bekle, yoksa `controller._uid` null → `save` erken döner. (3) **mükerrer override'da SON kazanır** — sahte bildirim servisi `...mockBackendOverrides()`'ten SONRA gelmeli (mock zaten Noop koyuyor).
- Toplam **117/117**; analyze 0; `flutter build web` OK.
- **SIRADAKİ: TAKİP MERKEZİ Faz 3** — zengin alanlar (kişi/telefon, konum, foto/dosya/ses ekleri). Model (`TrackPerson`/`TrackLocation`/`TrackAttachment`) ve sqflite JSON şeması BUNLARA HAZIR; eklenecek paketler: `record` (ses), `file_picker` (dosya), `path_provider` (yerel kopya). Sonra Faz 4 (tam filtre+cila+erişilebilirlik+koyu tema turu), Faz 5 (hafif bulut yedek).
- ⚠️ Kullanıcı gerçek cihazda (emülatör/telefon; Windows'ta bildirim test edilemez) YENİ BUILD ile denemeli: Takip → Yeni → Hatırlatma çipi → yakın bir tarih/saat + Her gün → izin ver → uygulamayı arka plana al → bildirimin düştüğünü ve dokununca takibe gittiğini gör. Bildirime dokununca/ tamamlayınca tekrarlıda tarih ileri kaymalı. iOS Windows'ta test edilemez.

**Oturum 45 (2026-07-12, aynı gün): TAKİP MERKEZİ — FAZ 1 (çekirdek yerel CRUD) TAMAMLANDI. Yalnız istemci (yerel sqflite; kural/CF YOK) → deploy GEREKMEDİ. 110/110 test, analyze 0, web build OK.**
Kullanıcı "devam" dedi; önceki oturumdan commit'lenmemiş yarım Takip Merkezi taslağı vardı (model+repo+ekranlar yazılmış ama Profil girişi bağlanmamış, widget testi yok). Tamamlandı + gerçek bir UI hatası bulunup düzeltildi.
- **Modül `lib/features/tracking/` (Faz 1):** meslekten bağımsız kişisel/iş takip kayıtları. `TrackItem` modeli TAM brief'e hazır (durum/öncelik/etiket/hatırlatma/tekrarlama/kişi/telefon/konum/ek foto-dosya-ses) ama Faz 1 arayüzü yalnız Başlık+Not+Öncelik+Etiket gösterir (progressive disclosure — "Ekle" çipleriyle açılır). `toMap/fromMap` JSON uyumlu (tarihler ms epoch), bozuk enum → güvenli varsayılan.
- **Depolama YEREL-ÖNCELİKLİ:** `TrackingRepository` arayüzü + `SqfliteTrackingRepository` (cihazda sqflite, tek tablo `track_items`; kaydın tamamı `data` JSON sütununda, `owner_uid`/`deleted_at`/`updated_at` ayrı sütun+indeks; reaktiflik Firestore snapshot yerine `_changes` broadcast tetikçisi) + `MockTrackingRepository` (bellek-içi parite, testler). Kayıtlar **owner_uid ile ölçekli** (aynı cihazda çok hesap birbirini görmez). `trackingRepositoryProvider` HER ZAMAN sqflite (Firebase backend'den bağımsız — takip buluta değil cihaza yazılır); testlerde `mockBackendOverrides` mock'a çevirir. Çöp kutusu = yumuşak silme (`deletedAt`), 30 gün otomatik temizlik YOK (Faz 4/5).
- **Paket:** `sqflite: ^2.4.1` + `path: ^1.9.0`. NOT: sqflite'ın web implementasyonu yok → web'de modül açılırsa RUNTIME hata verir; ama web uygulaması BİLİNÇLİ yayınlanmadı (Oturum 43) ve `flutter build web` DERLENİYOR (sağlayıcı yalnız erişilince örneklenir), sorun değil. Web hedefi gelirse `sqflite_common_ffi_web` gerekir.
- **Ekranlar (mevcut tasarım diline eşlendi — yeni görsel dil YOK):** `TrackingCenterScreen` (GradientAppBar + arama + Tümü/Aktif/Tamamlanan filtre çipleri + FAB "Yeni" + kart listesi + ilk-kayıt boş durumu), `TrackEditScreen` (yeni/düzenle; başlık zorunlu; PopScope kirli-uyarısı; alt sabit Kaydet barı), `TrackDetailScreen` (başlık+durum rozeti+bilgi çipleri+not kartı+tarihler; üst barda Düzenle/Sil; alt Tamamla/Aktif barı), `TrackingTrashScreen` (geri al / kalıcı sil / boşalt), `TrackCard` widget'ı (sol dairesel tamamla işareti + öncelik/hatırlatma/etiket rozetleri). Silme = çöpe taşı + **`showUndo` toast'ı (Geri Al)** — `snackbar_helper.dart`'a eklenen yeni yetenek (TopToast'a `actionLabel`/`onAction` + aksiyon varken daha uzun görünme süresi).
- **Giriş noktası (ÜRÜN KARARI: alt bar 4 sekme korunur):** Profil → yeni "ARAÇLAR" grubu → "Takip Merkezi" satırı (her iki modda da görünür; `RoutePaths.tracking`'e iter). Router'a rotalar eklendi — **SIRA KRİTİK:** `/tracking/new` ve `/tracking/trash`, `/tracking/:id`'den ÖNCE tanımlı (yoksa `:id` onları yakalar); modül `needsLogin` bölgesinde (misafir → girişe yönlenir).
- **GERÇEK HATA BULUNDU (widget testi sayesinde) — Oturum 41 regresyonunun TEKRARI:** `TrackEditScreen._SaveBar` ve `TrackDetailScreen._DoneBar`, `bottomNavigationBar` içinde `ResponsiveCenter` kullanıyordu. `ResponsiveCenter` = heightFactor'süz `Align` → bottomNavigationBar'ın loose dikey kısıtında TÜM ekran yüksekliğini kaplar → gövdeye 0px kalır → düzenleme formunun `ListView`'ı 0 yükseklikte, TextField'lar hiç build edilmez (ekran boş açılırdı, cihazda da!). Widget testi "düzenleme ekranında 0 TextField" ile yakaladı. **Düzeltme:** ikisinde de `Center(heightFactor: 1, child: ConstrainedBox(maxWidth: 720, ...))` + uyarı yorumu. **DERS (yine): bottomNavigationBar'a ResponsiveCenter/Align KOYMA.**
- **Test `test/tracking_test.dart` (9 test):** model (toMap/fromMap tam tur, newId çakışmaz, bozuk enum), MockRepo CRUD+çöp/geri-al+owner ölçekleme (4), ve **2 uçtan-uca widget testi** (oturum açıp Profil rotasından Takip Merkezi → Yeni → başlık gir → Kaydet → listede kart → controller ile tamamla/çöp/geri-al doğrula; karta dokun → detay → çöp kutusu rotası bağlı). DERSLER: (1) oturum için `tester.runAsync(register(...))` (mock Future.delayed, sahte saat — Oturum 44 dersi). (2) `find.byType(TextField).first` yığındaki ALTTAKİ rotaların (keşif arama kutusu) alanını yakalar → finder'ı `find.descendant(of: TrackEditScreen, ...)` ile ekrana daralt. (3) pop/geçiş animasyonu bitmeden aynı metin hem kartta hem düzenleme/detayda görünür (`find.text` 2 bulur) → assert'i ilgili ekrana daralt. (4) `find.widgetWithText(TextField, hint)` hint metnini güvenilir bulmaz.
- Toplam **110/110**; analyze 0; `flutter build web` OK.
- **SIRADAKİ: TAKİP MERKEZİ Faz 2** — hatırlatma + tekrarlama motoru (`flutter_local_notifications` + `timezone`). Model alanları (`reminderAt`, `recurrence`) hazır; kurulacak: bildirim planlama/iptal, tekrarlamada bir sonraki örneği üretme, izin isteği. Sonra Faz 3 (zengin alanlar: kişi/telefon/konum/foto/dosya/ses), Faz 4 (tam filtre+cila+erişilebilirlik+koyu tema turu), Faz 5 (hafif bulut yedek — Firestore/Storage'a yedek+geri yükle, senkron DEĞİL).
- ⚠️ Kullanıcı gerçek cihazda YENİ BUILD ile denemeli: Profil → Araçlar → Takip Merkezi → Yeni ile kayıt; tamamla/çöp/geri-al; uygulamayı kapatıp açınca kayıtlar durmalı (yerel kalıcı). Web'de açmaya çalışma (sqflite yok).

**Oturum 44 (2026-07-12, aynı gün): E-POSTA DOĞRULAMA + ONBOARDING REGRESYON DÜZELTMESİ. Yalnız istemci (kural/CF YOK) → deploy GEREKMEDİ. 101/101 test, analyze 0.**
Kullanıcı "nerede kaldık?" dedi; önceki oturumdan commit'lenmemiş yarım iş vardı (çalışıyordu ama BİR test 10 dk timeout ile KIRIKTI) — tamamlandı, düzeltildi, commit'lendi.
- **E-posta doğrulama:** `AppUser.emailVerified` — KAYNAĞI Firebase Auth'tur, `users` dökümanına YAZILMAZ/OKUNMAZ (istemcinin kendine sahte yazamayacağı alan); repo katmanı Auth kullanıcısından doldurur (`_loadOrCreate` → `.copyWith(emailVerified: fbUser.emailVerified)`). `AuthRepository.sendEmailVerification()` + `refreshEmailVerified()` (Firebase: `fbUser.reload()` + değiştiyse `_manualUpdates`'e elle yayın — `userChanges()` reload sonrası her zaman yayın yapmıyor; `too-many-requests` → TR mesaj). Mock parite: `_verificationPending` bayrağı, `refreshEmailVerified` onu işler ("bağlantıya tıklama" simülasyonu). Kayıtta doğrulama e-postası OTOMATİK gönderilir (başarısızlığı kaydı BOZMAZ, try/catch). `AuthController.sendEmailVerification/checkEmailVerified`.
- **UI:** Profil → e-posta doğrulanmışsa düz "E-posta" satırı; doğrulanmamışsa TURUNCU `mark_email_unread` "E-postanı Doğrula" satırı (`context.palette.warning`) → bottom sheet: "Doğrulama E-postasını Gönder" + "Bağlantıya Tıkladım — Kontrol Et". Kayıt başarı toast'ına "Doğrulama bağlantısı e-posta adresinize gönderildi" eklendi.
- **Onboarding regresyon:** Kullanıcı bildirimi "onboarding hiç açılmıyor". Kök neden: router redirect'i `user == null && !seenOnboarding` istiyordu → oturumu açık kalan cihazlarda ve kayıt-sonrası tanıtımı HİÇ göstermiyordu. Düzeltme: `!seenOnboarding` ise oturumdan BAĞIMSIZ onboarding'e yönlendir (`splash`→home; `!seen`→onboarding; seen ise onboarding→home). **ÜRÜN KARARI (kullanıcıyla tartışıldı):** onboarding CİHAZ bazlı (bir kez, SharedPreferences), hesap bazlı DEĞİL — misafir-önce akışta tanıtım herkese (giriş yapmadan da) gösterilmeli; hesaba bağlarsak misafir hiç görmez. Kullanıcı "cihaz bazlı daha mantıklı" dedi.
- **Ek:** `ErrorView` + dashboard `_Centered` → `Padding` yerine `SingleChildScrollView` (klavye açıkken/dar alanda taşma şeridi yerine kaydırılabilir).
- **Test:** `dual_role_test`e e-posta doğrulama (kayıtta doğrulanmamış → refresh sonrası doğrulanır → oturum kapat/aç KALICI → oturumsuz reddedilir); `onboarding_test`e "OTURUM AÇIKKEN de görülmemiş onboarding gösterilir" regresyonu. **DERS (kritik):** `testWidgets` içinde mock `login()` gibi `Future.delayed`'lı repo çağrısı `pumpWidget`'ten ÖNCE ve pump olmadan `await` edilirse sahte saat ilerlemez → Future asla dönmez → **10 dk timeout (+0)**. Çözüm: `await tester.runAsync(() => repo.login(...))` (gerçek async zone'da timer ateşlenir). Toplam **101/101**.
- **SIRADAKİ: TAKİP MERKEZİ modülü** (yeni büyük özellik — kişisel/iş takip kayıtları, her meslek için genel). Kullanıcı brief verdi + 3 karar netleşti: **depolama YEREL-öncelikli + hafif bulut yedek**; **giriş Profil içi satır** (alt bar 4 sekme korunur); **kapsam tam brief ama FAZLI sevk** (özellik kesme yok, güvenli sıra). 5 faz: (1) çekirdek CRUD yerel [sqflite + `TrackItem` modeli + repo arayüz/sqflite/Mock + provider'lar + liste/form/detay/çöp+geri al], (2) hatırlatma+tekrarlama [`flutter_local_notifications`+`timezone`], (3) zengin alanlar [kişi/telefon/konum/foto/dosya/ses — `record`,`file_picker`,`path_provider`], (4) tam filtre+cila+erişilebilirlik+koyu tema turu, (5) hafif bulut yedek [Firestore/Storage'a yedek+geri yükle, senkron DEĞİL]. Tasarım: yeni görsel dil YOK — her ekran mevcut bileşene eşlendi (`GradientAppBar`, kart 16px+softShadow, `LoadingView`/`ErrorView`, `TopToast`, `TapScale`, `context.palette`). Progressive disclosure: formda yalnız Başlık+Not görünür, gerisi "Ekle" çipleriyle açılır.

**Oturum 43 (2026-07-12, aynı gün): YASAL METİNLER + KAYIT ONAYI (YOL_HARITASI P0-3, son P0). HOSTING CANLIDA ✅ (ilk denemede; 99/99 test, analyze 0, web build OK). Kural/CF değişikliği YOK — TÜM P0'LAR KAPANDI.**
Kullanıcı "devam edelim" dedi; kalan son P0 seçildi.
- **Tek kaynak `lib/features/legal/legal_docs.dart` (SAF Dart — Flutter import'u yok, bilinçli):** 4 metin (Kullanım Koşulları, Gizlilik Politikası, KVKK Aydınlatma, Hesap Silme Talimatı) `LegalDoc/LegalSection` yapılarında; iletişim `kLegalContactEmail` (= aboneai.plus@gmail.com, TEK yerden değişir), tarih `kLegalUpdated`. DERS: içerikte kesme işareti çok (token'ı, Google'ın) — o string'ler çift tırnak.
- **HTML üretici `tool/generate_legal_html.dart`:** içerikten `hosting/*.html` üretir (responsive, koyu tema destekli, URL/e-posta linkli, • satırları `<ul>`, "1." satırları `<ol>`). Metin değişince: (1) legal_docs.dart güncelle, (2) `dart run tool/generate_legal_html.dart`, (3) `firebase deploy --only hosting`.
- **Hosting İLK KEZ kuruldu (firebase.json `"hosting": {"public": "hosting"}`) — yalnız yasal sayfalar yayında, Flutter web uygulaması BİLİNÇLİ yayınlanmadı** (o ayrı karar; ileride yayınlanırsa public dizini değişir, yasal sayfalar build/web'e kopyalanmalı). CANLI URL'ler (4'ü de 200 doğrulandı): https://alljob1.web.app/{gizlilik-politikasi,kullanim-kosullari,kvkk-aydinlatma,hesap-silme}.html — **Play Console'a: gizlilik politikası URL'si + "Veri güvenliği" formuna hesap-silme URL'si.**
- **Uygulama içi:** `features/legal/presentation/legal_screen.dart` — `/legal` hub (3 metin listesi) + `/legal/{id}` okuma sayfası (SelectionArea ile kopyalanabilir); rotalar MİSAFİRE AÇIK (needsLogin öneklerine girmiyor). Profil → Hesap grubuna "Yasal Metinler" satırı.
- **Kayıt onayı (`register_screen.dart`):** şifre tekrarının altına `FormField<bool>` onay kutusu — `Form.validate()` bunu da doğrular, işaretlenmeden kayıt OLMAZ (inline hata "Kayıt olmak için koşulları kabul etmelisiniz."). Metinde 3 tıklanabilir link (Koşullar/Gizlilik/KVKK → uygulama içi sayfalar; TapGestureRecognizer'lar dispose ediliyor); KVKK m.9 yurt dışı saklama AÇIK RIZASI cümlede. Alttaki "Zaten hesabınız var mı?" Row'u Wrap oldu (test fontunda 80px taşıyordu).
- **Test `test/legal_test.dart` (2 test):** (1) onaysız kayıt → inline hata + kullanıcı OLUŞMAZ; kutu işaretlenince kayıt tamamlanır + ana ekrana düşer. DERS: `context.go` sonrası dashboard'ın görünmesi için pump(1s) YETMEZ — router bildirimi SONRAKİ karede işlenir, ardından geçiş animasyonu: `pump(); pump(1s); pump(); pump(500ms)` kalıbı. (2) `/legal` hub + metin sayfası misafirken açılır. Toplam **99/99**.
- ⚠️ Metinler ŞABLONDUR: yayın öncesi hukukçu gözden geçirmesi + veri sorumlusu gerçek unvan/adres önerilir. İletişim adresi şimdilik geliştirici Gmail'i.
- **P0'LAR BİTTİ.** Sıradaki (YOL_HARITASI P1/Sprint): rules testleri/CI, zorunlu güncelleme, App Check zorlaması (Oturum 37 planı), Play Billing (beta sonrası).

**Oturum 42 (2026-07-12): ENGELLEME + ŞİKAYET (YOL_HARITASI P0 — UGC politikası, Play zorunluluğu). KURALLAR CANLIDA ✅ (ilk denemede deploy; 97/97 test, analyze 0, web build OK). CF değişikliği YOK.**
Kullanıcı "devam" dedi; çalışma ağacındaki yarım safety taslağı tamamlandı, doğrulandı ve yayınlandı.
- **Veri modeli:** `users/{uid}/blocked/{otherUid}` (BlockedUser: ad/foto engelleme anındaki SNAPSHOT — yönetim ekranı ekstra okuma yapmaz) + `reports/{targetType}_{targetId}__{reporterUid}` (deterministik ID → hedef başına şikayetçi başına TEK kayıt; tekrar şikayet günceller, kuyruk şişmez).
- **Kurallar (DEPLOY EDİLDİ):** (1) `blocked` alt koleksiyonu yalnız sahibi okur/yazar — engellenen engellendiğini GÖREMEZ (IG modeli). (2) Mesaj create'ine `!recipientBlockedSender()` eklendi: alıcı göndereni engellediyse mesaj SUNUCUDA reddedilir (`exists(users/{other}/blocked/{sender})`; chat dökümanına ikinci `get` sayılmaz — kural motoru aynı isteğin okumalarını önbellekler; eski dökümanda customerUid yoksa kontrol atlanır). (3) `reports`: yalnız create+update (kendi şikayeti + ID formatı kuralda birebir doğrulanır), read/delete KAPALI — admin fazında custom claim ile açılacak.
- **Mimari:** `features/safety/` — `BlockRepository`/`ReportRepository` arayüzleri + Firebase ve Mock impl'ler + `safety_providers.dart` (`myBlockedListProvider` canlı akış, `myBlockedUidsProvider` hızlı uid kümesi). Mock'lar `mock_backend.dart` override'larına eklendi.
- **UI:** (1) Sohbet üst barında ⋮ menü: "Kullanıcıyı Engelle" (onay diyaloglu, başarıda pop — sohbet listeden gizlenir) / "Engeli Kaldır" / "Şikayet Et". (2) Mesaja uzun basınca karşı tarafın mesajı için "Şikayet et" (targetId `{chatId}_{msgId}`). (3) İlan detayında sahibi olmayana "Bu ilanı şikayet et". (4) Profil → "Engellenen Kullanıcılar" (`/profile/blocked`): liste + "Engeli Kaldır". (5) Ortak `showReportSheet`: neden radyoları (spam/taciz/dolandırıcılık/uygunsuz/diğer) + 300 karakterlik opsiyonel not; başarıda "Şikayetiniz alındı" toast'ı.
- **Davranış:** engellenenin sohbeti listede GİZLENİR (engel kalkınca kendiliğinden döner — `myBlockedUidsProvider` filtresi); engelleyen de mesaj/foto gönderemez (istemci guard'ı `_iBlockedOther` + TR uyarı; karşı yönü kural keser). Engellenen tarafta hiçbir görsel değişiklik yok (IG/WhatsApp modeli).
- **Test:** yeni `test/safety_test.dart` (4 test: engelle/kaldır roundtrip + tek yönlülük; mükerrer engel çoğaltmaz; şikayet tek kayıt + farklı hedef yeni kayıt; reportDocId format kuralla birebir). Toplam **97/97**.
- ⚠️ Kullanıcı gerçek cihazda YENİ BUILD ile denemeli (iki test hesabı): engelle → karşı taraf mesaj yazınca permission-denied almalı (balon hata/tekrar dene durumuna düşer), sohbet sizin listenizde gizlenmeli; şikayet kayıtları Console → Firestore → `reports`'ta görünmeli.
- Kalan P0: yasal metinler (gizlilik politikası + kullanım koşulları) + kayıt onayı — YOL_HARITASI'ndan devam. Admin fazına not: reports kuyruğunu okuyan panel/claim yok (bilinçli).

**Oturum 41 (2026-07-11, aynı gün): YENİ İLAN SAYFASI BOŞ AÇILIYOR — kritik UI regresyonu düzeltildi (93/93 test). Deploy GEREKMEDİ (yalnız istemci); kullanıcı YENİ BUILD almalı.**
Kullanıcı: "yeni ilana basınca tasarım kayıyor, sayfa açılmıyor, sadece [yayınla] düğmesi görünüyor."
- **Kök neden (Oturum 37'nin 'yayınla butonu alta sabitlendi' işinden):** `create_job_screen`'de alt sabit bar `bottomNavigationBar: Container(... ResponsiveCenter(AppButton))` idi. `ResponsiveCenter` içindeki **`Align`, factor verilmezse mevcut alanın TAMAMINA yayılır** — Scaffold bottomNavigationBar'a tüm ekran yüksekliğini loose verdiğinden bar 800px oldu, gövdeye 0px kaldı → formun `ListView`'ı 0 yükseklikte (tembel olduğundan tek kart bile build edilmedi), buton ekranın tepesinde tek başına görünüyordu. Exception YOK (analyze/test yakalamıyordu) — teşhis, widget testinde `ListView boyutu: Size(360, 0)` dökümüyle kondu.
- **Düzeltme:** alt barda `Center(heightFactor: 1, child: ConstrainedBox(maxWidth: 720, ...))` — bar çocuğu kadar yüksek, buton genişliği yine sınırlı. Koda uyarı yorumu eklendi. **DERS: `bottomNavigationBar`/yükseklik-sınırsız yuvalara ResponsiveCenter/Align koyma** (gövdelerde sorun değil; Scaffold body zaten sınırlı).
- **Kalıcı regresyon testi `test/create_job_screen_test.dart`:** ekran 360x800'de açık+koyu temada pompalanır; exception yok + 4 bölüm kartı (sonuncusu dikey forma `dragUntilVisible` ile) + yayınla butonu bulunur. DERSLER: (1) `pumpAndSettle` bu ekranda ASLA — dropdown'lar yüklenirken dönen `LinearProgressIndicator` sonsuz animasyon, timeout; sınırlı `pump`'lar kullan. (2) Ekranda 2 ListView var (form + yatay foto şeridi) — `find.byType(ListView).first`.
- Toplam **93/93** test; analyze 0.

**Oturum 40 (2026-07-11, aynı gün): HESAP SİLME (YOL_HARITASI P0-2 — Google Play zorunluluğu). CF CANLIDA ✅ (ilk denemede deploy; 91/91 test, analyze 0, web build OK)**
Kullanıcı "devam" dedi; AskUserQuestion ile P0-2 seçildi.
- **CF `deleteAccount` (callable, europe-west1, timeout 300 sn — DEPLOY EDİLDİ `--only functions:deleteAccount --force` ile):** yalnız oturum sahibi KENDİ hesabını siler. SİL/ANONİMLEŞTİR politikası (fonksiyon başındaki yorumda da yazılı): users+alt koleksiyonlar (`recursiveDelete`: private, notifications) SİL; artisanProfiles SİL; favorites iki yönde SİL; verdiği teklifler SİL (onOfferWritten sayaçları yeniden hesaplar); sahibi olduğu ilanlar: bağlanmamış (open/cancelled) SİL (onJobWritten teklifleri temizler), aktif (workerSelected/inProgress/disputed) İPTAL+anonimleştir+ustaya bildirim/push, tamamlanmış yalnız `customerName` anonim; usta olarak seçildiği AKTİF işler İPTAL+müşteriye bildirim ("ilanı yeniden yayınlayın"); yazdığı yorumlar KALIR ama `customerDisplayName` anonim (ustanın puanı kazanılmış veri, sayaç bozulmaz), HAKKINDAKİ yorumlar SİL (onReviewWritten profil yoksa zaten atlar); sohbetlerde ad/foto anonim ("Silinmiş Kullanıcı"), mesajlar karşı tarafta kalır (WhatsApp modeli); Storage `{profile|work|job|certificate|chat}/{uid}/*` SİL; **Auth kaydı EN SON** (yarıda kalırsa kullanıcı tekrar deneyebilir). Toplu yazımlar `db.bulkWriter()` ile.
- **İstemci:** `cloud_functions: ^5.2.0` (5.6.2 çözüldü; core 3.x uyumlu — 6.x core 4 ister, MAJOR yükseltme ayrı iş). `AuthRepository.deleteAccount()` arayüze eklendi; Firebase impl: `FirebaseFunctions.instanceFor(region 'europe-west1').httpsCallable('deleteAccount')` (3 dk istemci timeout) + başarıda `signOut`; hata → TR mesajlı AuthException. Mock impl: hesap deposundan siler, oturum kapanır. `AuthController.deleteAccount()`: önce `unregisterFor` (FCM token cihazda geçersiz kılınır), sonra repo.
- **UI (`profile_screen.dart`):** Çıkış Yap'ın altına kırmızı "Hesabı Sil" satırı → `_deleteAccountFlow`: açık onay diyaloğu (nelerin silineceği yazılı, kırmızı "Kalıcı Olarak Sil") → engelleyici ilerleme diyaloğu (PopScope canPop:false) → başarıda ana sayfa + "Hesabınız silindi." toast'ı; hatada TR mesaj. Await-sonrası bağlam için drawer'daki kalıp (router + kök navigator önceden yakalanır).
- **Test:** `dual_role_test`e "hesap silme: oturum kapanır, aynı e-postayla giriş başarısız + oturumsuz silme reddedilir". Toplam **91/91**.
- ⚠️ Kullanıcı gerçek cihazda YENİ BUILD ile uçtan uca denemeli (tercihen çöp test hesabıyla): Profil → Hesabı Sil → onay → uygulama misafir keşfete düşmeli; Console'da Auth kaydı ve Firestore dökümanları silinmiş olmalı.
- Not: deploy sırasında CLI "firebase-functions güncel değil" uyarısı verdi (breaking change içerir — MAJOR Firebase yükseltmesiyle birlikte ele alınmalı, şimdilik bilinçli dokunulmadı).
- Kalan P0'lar: yasal metinler + kayıt onayı, engelleme/şikayet.

**Oturum 39 (2026-07-11): isPremium KURAL KİLİDİ (YOL_HARITASI P0-1 — gelir açığı kapatıldı). KURALLAR CANLIDA ✅ (ilk denemede deploy; 90/90 test, analyze 0, web build OK)**
Kullanıcı "devam" dedi; AskUserQuestion ile P0-1 seçildi. İkinci soruda ÜRÜN KARARI netleşti: **"şu anda premium özelliğini aktif etmeyeceğiz; BETA süresince ücretsiz olacak; 1 yıl şartımız yok"** — yani premium satın alma yok, premium ÖZELLİKLERİ (müsait olma, iş ilanları feed'i) beta boyunca herkese açık.
- **Kural (DEPLOY EDİLDİ):** `artisanProfiles` create+update guard listelerine `isPremium, premiumExpiresAt` eklendi (completedJobs kalıbı) — istemci kendine premium YAZAMAZ. Gerçek satın alma gelince yalnız CF yazacak.
- **İstemci yazım kilidi:** `FirebaseMyProfileRepository.saveMyProfile` iki alanı toMap'ten çıkarır (merge korur); Mock parite: `MockMyProfileRepository.saveMyProfile` mevcut değerleri korur, İLK kayıtta premium vermez. `MyProfileController.setPremium` SİLİNDİ (tek çağıran premium ekranıydı).
- **Beta erişim bayrağı:** `AppConstants.firstYearFreePremium` (hiç kullanılmıyordu) → **`premiumFreeDuringBeta = true`** olarak yeniden anlamlandırıldı. Yeni **`ArtisanProfile.hasPremiumAccess`** getter'ı (`premiumFreeDuringBeta || hasActivePremium`) — gating BUNA bakar; ROZET gösterimi ise `hasActivePremium`/`isPremium`'da kaldı (beta'da herkes rozetli görünmesin). Gating geçen yerler: profil "Müsaitlik" switch'i (`profile_screen`), İşler ekranı `_NotAvailableNotice` (premium cümlesi yalnız erişim yokken görünür). Teklif kartındaki premium rozeti (`job_detail_screen` ~1357) hasActivePremium'da BİLİNÇLİ bırakıldı.
- **Premium ekranı:** satın alma butonu/`setPremium` akışı kalktı → salt bilgi sayfası: fayda listesi + "Beta süresince ücretsiz" kutusu ("Ücretlendirme beta tamamlanırken duyurulacak"). Profildeki Premium satırı alt yazısı: "Beta süresince tüm özellikler ücretsiz".
- **KRİTİK SONUÇ:** Butonu düz "Yakında" yapmak pazaryerini kilitlerdi — müsait olmak premium'a bağlıydı ve müsait olmayan usta aramada HİÇ görünmüyor; hasPremiumAccess sayesinde ustalar beta'da serbestçe müsait olur. Beta bitince `premiumFreeDuringBeta=false` + Play Billing (Sprint 3).
- **Test:** eski "premium etkinleştirilir" testi → "isPremium istemci kaydıyla yazılamaz; beta erişimi yine açık" (kurcalanan profil kaydedilir → isPremium false kalır, hasPremiumAccess true). Toplam **90/90**.
- **Ayrıca:** `main.dart`'ta elle-düzenleme kazası onarıldı (`}ujub7` + bozuk yorum satırı — dosya derlenmiyordu; Oturum 36'daki `}`→`3` kazasının benzeri).
- Kalan P0'lar: hesap silme (callable CF), yasal metinler, engelleme/şikayet — YOL_HARITASI'ndan devam.

**Tamamlanan: AŞAMA 1–5 + PRD v4.0 + FIREBASE CANLI + ÇİFT TARAFLI PAZARYERI + OTURUM 15 (UX) + OTURUM 16 (Keşfette ilan paneli) + OTURUM 17 (TEK HESAP, ÇİFT ROL) + OTURUM 18 (TASARIM v2) + OTURUM 19 (MALİYET/FATURA OPTİMİZASYONU) + OTURUM 20 (BLAZE + STORAGE CANLI) + OTURUM 21 (CLOUD FUNCTIONS CANLI) + OTURUM 22 (FCM PUSH) + OTURUM 23 (GIT + CRASHLYTICS + GÜVENLİK) + OTURUM 24 (TELEFON DOĞRULAMA + MAVİ TİK) + OTURUM 25 (KIRIK TEST TEMİZLİĞİ — 68/68) + OTURUM 26 (PROFİL YÜKLENEMEDİ + OTURUM SIZINTISI + SMS BÖLGE DÜZELTMESİ) + OTURUM 27 (TEK BİRLEŞİK PROFİL SAYFASI) + OTURUM 28 (YENİ İLAN → USTA PUSH BİLDİRİMİ, CANLI) + OTURUM 29 (MESAJLAR IG DİLİ + KOMPAKT KARTLAR)**

**Oturum 38 (2026-07-10): KOYU TEMA AÇILDI (Sprint 4 devamı — yol haritasındaki "AppTheme.dark var ama kapalı; cilalanıp açılmalı" kalemi). 90/90 test, analyze 0, web build OK. Deploy GEREKMEDİ (yalnız istemci).**
Kullanıcı "devam" dedi; AskUserQuestion ile Sprint 4 devamı seçildi. Engel, ekranların statik `AppColors` sabitleri kullanmasıydı (268 kullanım, 33 dosya) — tema-farkındalıklı palete geçirildi.
- **Yeni `core/theme/app_palette.dart` — `AppPalette extends ThemeExtension<AppPalette>`:** AppColors'ın TÜM semantik tonlarının (ink/inkMuted/inkFaint, background/card/surfaceMuted/border/hairline, success/warning/danger/info + yüzeyleri, verified/star/premium, primary/secondary container'lar) açık+koyu karşılıkları. Açık palet AppColors'ı birebir kullanır; koyu palet `_darkScheme` ile uyumlu elle seçilmiş tonlar. Erişim: **`context.palette.x`** (BuildContext extension'ı; tema yoksa açık palete düşer). `AppTheme._build` her iki temaya `extensions: [AppPalette.light|dark]` takar. ÖNEMLİ ADLANDIRMA: eski `AppColors.surface` (beyaz kart) palette **`card`** oldu (`surface` adı ColorScheme ile karışıyordu).
- **Tema tercihi (Sistem/Açık/Koyu):** yeni `core/theme/theme_mode_state.dart` — `themeModeProvider` (varsayılan SİSTEM; onboarding kalıbı: gerçek değer main.dart'ta shared_preferences'tan okunup ProviderScope override ile verilir), `readThemeMode/saveThemeMode` (anahtar `theme_mode_v1`; bozuk kayıt→system). `app.dart`: `themeMode: ref.watch(themeModeProvider)` (eski `ThemeMode.light` sabiti kalktı). **UI:** hamburger menünün altına "Görünüm" satırı (misafir dâhil herkese) → bottom sheet'te RadioGroup ile 3 seçenek; seçim anında uygulanır + cihaza kaydedilir.
- **Geçiş kuralları (İLERİDE AYNI KALIPLA DEVAM ET):** (1) Kart zeminleri `context.palette.card`, çizgiler `border/hairline`, ikincil metin `inkMuted`. (2) `const` widget'larda palet kullanılamaz — const kaldırıldı (Icon/Text/BoxDecoration). (3) **Bilinçli statik kalanlar:** heroGradient/brandGradient/availableRing (marka kimliği, iki temada aynı), gradyan ÜSTÜ beyaz metin/ikonlar, `_NewJobButton` beyaz hap (gradyan üstünde sabit marka turuncusu), toast renk şeritleri (doygun tonlar her zeminde çalışır; toast'ın beyaz "sistem kartı" varyantı palete geçti), foto üstü karartma/kaldır rozetleri (Colors.black38/54), tam ekran foto görüntüleyici (siyah). (4) `phone_verification_sheet`'teki `Colors.black54` metin → `onSurfaceVariant` (koyuda okunmuyordu). (5) Skeleton shimmer artık `surfaceMuted↔border` (koyuda da görünür).
- **Dokunulan dosyalar:** core: status_views, skeleton, role_bottom_bar (alt bar zemini `palette.card`), snackbar_helper, notification_bell, rating_stars, app_menu_drawer (+Görünüm), app_theme (+extensions), app_palette (yeni), theme_mode_state (yeni); features: job_widgets (JobStatusChip switch'i palete), artisan_card, favorite_button, verification_tile, notifications, chat_list, chat (_EmptyChat), artisan_profile_edit, artisan_profile, favorites, my_offers, nearby_jobs, my_jobs, review, premium, onboarding, create_job, profile, job_detail (43 kullanım — toplu değişimde `surface`→`card` zinciri `surfaceMuted`'ı bozdu, düzeltildi; DERS: prefix'i başka token içeren toplu değişimde önce uzun token'ı değiştir).
- **Test:** yeni `test/theme_mode_test.dart` (3 test: iki temada AppPalette var ve farklı; tercih yaz→oku roundtrip; bozuk kayıt→system). Toplam **90/90**; analyze 0; `flutter build web` OK.
- ⚠️ Kullanıcı gerçek cihazda YENİ BUILD ile bakmalı: cihaz koyu moddayken uygulama artık koyu açılır (varsayılan Sistem); menü → Görünüm'den Açık/Koyu kilitlenebilir. Koyu temada göze batan ton olursa `app_palette.dart`'tan tek yerden ayarlanır.
- Bilinçli ertelenen: Keşfet hero'daki arama kutusu ve scheme tabanlı diğer yüzeyler otomatik uyumlu olmalı — cihazda koyu modda hızlı bir tur atıp doğrula.

**Oturum 37 (2026-07-10): App Check (Oturum 31 güvenlik denetiminin son maddesi). İSTEMCİ HAZIR + Play Integrity KAYITLI ✅ (zorlama KAPALI — bilinçli; 85/85 test)**
Kullanıcı "devam" dedi; AskUserQuestion ile App Check seçildi.
- **İstemci (`main.dart`):** `firebase_app_check` **0.3.2+10** eklendi (firebase_core 3.x ile uyumlu; 0.4.x core 4 ister — MAJOR Firebase yükseltmesi ayrı iş). `Firebase.initializeApp`'ten hemen sonra `activate`: Android'de `kDebugMode ? debug : playIntegrity`, Apple'da `debug : appAttestWithDeviceCheckFallback`; **web yalnız `kAppCheckWebRecaptchaKey` doluysa** etkinleşir (sabit `backend_config.dart`'ta, şu an BOŞ → web'de App Check yok, uygulama normal çalışır).
- **Sunucu kaydı (REST ile, Console'suz — Oturum 26 yöntemi):** firebase CLI refresh token'ı → OAuth access token (`oauth2.googleapis.com/token`, CLI'nin public client id/secret'ı) → `firebaseappcheck.googleapis.com/v1` PATCH `apps/{androidAppId}/playIntegrityConfig` (tokenTtl 3600s) + `serviceusage` ile `playintegrity.googleapis.com` API'si ETKİNLEŞTİRİLDİ. Bu kalıp App Check yönetimi için çalışıyor; ileride debug token eklemek için de kullanılabilir (`POST .../apps/{app}/debugTokens`).
- **ZORLAMA (enforce) BİLİNÇLİ OLARAK KAPALI:** `services/{firestore|firebasestorage|identitytoolkit}.googleapis.com` enforcementMode boş (=OFF) doğrulandı. Jetonsuz istekler hâlâ kabul ediliyor → eski build'ler KIRILMAZ. Zorlamayı açma sırası (İLERİDE, acele etme): (1) kullanıcı yeni build'i cihazda çalıştırır, logcat'te `DebugAppCheckProvider`'ın bastığı debug token'ı Console → App Check → Apps → Android → "Manage debug tokens"a ekler (veya bana verir, REST ile eklerim); (2) Console → App Check metriklerinde "verified" trafik oranı izlenir; (3) trafiğin tamamı yeni build'lerden gelince Firestore + Storage için Enforce açılır. ERKEN AÇILIRSA eski sürüm kullanan herkes permission-denied yer.
- **Web için bekleyen:** reCAPTCHA v3 site anahtarı (https://www.google.com/recaptcha/admin → v3, alanlar: alljob1.web.app, alljob1.firebaseapp.com, localhost) → site anahtarı `kAppCheckWebRecaptchaKey`'e, gizli anahtar Console'daki web uygulaması App Check kaydına. Anahtar oluşturma otomatikleştirilemiyor (Google hesabıyla manuel).
- **Doğrulama:** analyze 0; **85/85 test**; `flutter build web` OK. Kural/CF değişikliği YOK → deploy gerekmedi. Testlerde `PushService.registerFor` "no-app" logu zararsız (Oturum 25'teki bilinçli no-op).
- Not: Play Integrity yalnız Play'den dağıtılan/imzalı sürümlerde tam çalışır; debug build'ler debug provider kullanır (tasarım gereği). iOS tarafı Windows'ta test edilemez (APNs gibi bekliyor).
- **İlan verme UI cilası (aynı oturum, 2. istek):** Kullanıcı: "İlanlarım'daki Yeni İlan butonu (FAB) güzel değil, üst bara taşınsın; yeni ilan sayfasının içi tasarım olarak kötü."
  - **İlanlarım:** FAB kaldırıldı → GradientAppBar actions'a beyaz hap `_NewJobButton` (add ikonu + "Yeni İlan", lacivert gradyanda net kontrast; çöp kutusunun sağında). Boş durumda FAB gidince CTA'sız kalmasın diye `_EmptyJobs`'a "İlk İlanını Ver" FilledButton'ı eklendi.
- **Görsel tutarlılık geçişi (aynı oturum, 8. istek — "kıdemli product designer ol, yalnız görseli premium yap"):** Denetim sonucu: tema/tipografi/kartlar/alt bar/splash Oturum 18'den beri zaten iyi (yeniden boyamak gereksiz değişiklik olurdu); GERÇEK zayıflık durum ekranlarının tutarsızlığıydı — 7 ekran çıplak `Center(CircularProgressIndicator())`, 5 ekran HAM `$e` exception metni (sohbette kırmızı düz yazı!) gösteriyordu.
  - **Yeni `core/widgets/status_views.dart`:** `LoadingView` (sakin spinner, opsiyonel etiket, `compact` panel-içi varyant) + `ErrorView` (yumuşak zeminli ikon dairesi + "Bir sorun oluştu" başlığı + dostça mesaj; ham exception ASLA sızmaz). TEK durum dili.
  - **Yayılım (yalnız görsel, davranış aynı):** notifications, chat (mesajlar), chat_list, job_detail (2 nokta), artisan_profile, artisan_profile_edit, my_jobs, my_offers, nearby_jobs, favorites — hepsi LoadingView/ErrorView'a geçti; hata metinleri tek kalıpta ("… yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin."). Dashboard'a DOKUNULMADI (kendi `_Centered` bileşeni + sayfalama footer spinner'ı zaten doğru).
  - **`_EmptyChat`** düz yazıdan ikon-daire+başlık kalıbına geçti (diğer boş durumlarla aynı dil); **splash**'e GradientAppBar'daki markasal turuncu radyal ışık eklendi (açılıştan itibaren tutarlı kimlik). analyze 0; **87/87 test**.
- **Sprint 4 başlangıcı: tasarım kimliği v1 (aynı oturum, 7. istek — kullanıcı AskUserQuestion'da Sprint 4'ü seçti):**
  - **Onboarding:** yeni `features/onboarding/` — 3 sayfalık ilk açılış tanıtımı (`/onboarding`): katmanlı gradyan ikon kompozisyonu + vurgu rozeti, hap şeklinde animasyonlu nokta göstergesi, "Atla"/"Devam"/"Hemen Başla". Yalnızca İLK açılışta ve oturum yokken: `onboardingSeenProvider` **varsayılan TRUE** (testler/beklenmedik durumlar akışa hapsolmaz), gerçek değer `main.dart`'ta `shared_preferences`'tan okunup ProviderScope override'ı ile verilir; splash redirect'i `user==null && !seen` ise onboarding'e yollar, bitişte `markOnboardingSeen()` + go(home). Paket: `shared_preferences` eklendi.
  - **Mikro-etkileşim:** `core/widgets/tap_scale.dart` — basılınca 0.965'e yaylanan sarmalayıcı (Listener tabanlı, dokunuşu tüketmez); `AppButton` artık tüm CTA'larda bununla sarılı. `showSuccess/showError` haptic titreşim verir (web'de no-op).
  - **UX writing:** ilan yayın mesajı "İlanınız yayında 🎉 Bölgenizdeki ustalar haberdar ediliyor." oldu (kuru "yayınlandı." yerine).
  - **Test:** `test/onboarding_test.dart` (2 test: ilk açılış → onboarding → Atla → keşfet; görüldüyse doğrudan keşfet). DERS: testte `SharedPreferences.setMockInitialValues({})` şart — yoksa plugin kanalı olmadığından akış askıda kalıyor. analyze 0; **87/87 test**.
  - **Bilinçli ERTELENENLER:** koyu tema (tüm ekranlar statik `AppColors` sabitleri kullanıyor — tema-farkındalığına geçiş büyük refactor, ayrı iş); illüstrasyon/özel ikon seti (tasarımcı varlığı gerekir, kodla taklidi ucuz durur); konfeti anı (paket eklemeye değer mi kararına bırakıldı).
- **PM denetimi (aynı oturum, 6. istek):** Kullanıcı "proje yöneticisi ol, eksikleri çıkar" dedi → **`YOL_HARITASI.md` oluşturuldu** (koda dayalı denetim + 5 sprintlik plan). En kritik bulgular: (1) **`isPremium` istemciden bedavaya yazılabiliyor** — kuralda guard yok, tek gelir modeli delik (kanıt: artisan_profile.dart toMap + rules'ta premium yok); (2) hesap silme yok (Play zorunluluğu); (3) yasal metinler yok; (4) kullanıcı engelleme/içerik şikayeti yok (UGC politikası); (5) rules testleri/CI/staging/zorunlu güncelleme yok. Ayrıntı ve sprint sırası YOL_HARITASI.md'de — SONRAKİ OTURUMDA ORADAN DEVAM ET.
- **Fotoğraf yükleme: askıda kalma + eksik spinner'lar (aynı oturum, 5. istek):** Kullanıcı: "sohbette loading çıkıyor ama resim bir türlü yüklenmiyor; profil fotosu ve diğer fotolar yüklenirken de loading gösterilmeli."
  - **Kök neden (askıda spinner):** `FirebaseStorageRepository.uploadImage` → `putData`'nın KENDİ zaman aşımı YOK; dalgalı ağda aktarım askıda kalınca Future asla dönmüyor, sohbet balonundaki hata/"tekrar dene" akışı hiç tetiklenmiyordu. **Düzeltme:** yüklemeye 60 sn tavan (`task.timeout`), aşılırsa `task.cancel()` + rethrow → çağıran katman hata akışına düşer (sohbette balon "tekrar dene"ye geçer); `getDownloadURL`'a da 20 sn. Görseller zaten ~150–300 KB'a sıkıştırıldığından 60 sn cömert.
  - **Spinner'lar:** (1) Usta profil düzenleme (`artisan_profile_edit_screen`): `_uploading` durumu ('profile'|'work'|'certificate') — avatar üstünde karartma+spinner (WhatsApp balon dili), iş fotoğrafı/sertifika ekleme kutucuğu (`_AddTile.loading`) spinner'a döner, tıklama yutulur, aynı anda tek yükleme. (2) İlan verme (`create_job_screen`): `_uploadingPhoto` — "Ekle" kutucuğu spinner olur. Hata mesajları ayrıştı: seçim hatası "Görsel seçilemedi", yükleme hatası "Görsel yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin."
  - analyze 0; **85/85 test**. Deploy GEREKMEDİ (yalnız istemci). Kullanıcı cihazda test etmeli: kötü ağda sohbet fotosu artık en geç 60 sn'de "tekrar dene"ye düşer; profil/ilan foto yüklemede spinner görünür.
- **Sohbette klavye açılış performansı (aynı oturum, 4. istek):** Kullanıcı: "mesaj yazarken klavye yavaş açılıyor (WhatsApp'ta hissedilmiyor); rebuild'le alakalı sanırım."
  - **Teşhis:** Ekranda patolojik rebuild YOK (app.dart/ResponsiveCenter/tema MediaQuery'siz; TextField'da setState'li onChanged yok). Asıl mekanik: Scaffold `resizeToAvoidBottomInset` varsayılanı klavye animasyonunun HER karesinde tüm gövdeyi yeniden ölçüyor; debug build'de bu takılıyor (release'de büyük ölçüde sorun değil — kullanıcı kıyası release WhatsApp'a karşı). Bazı cihazlar inset'i tek karede zıplattığı için sert sıçrama da "hantallık" hissi veriyor.
  - **Çözüm (`chat_screen.dart`):** Scaffold `resizeToAvoidBottomInset: false` + Column'un en altına **`_KeyboardSpacer`** — `MediaQuery.viewInsetsOf`a YALNIZ bu yaprak abone, yükseklik 160ms easeOutCubic ile klavyeyi izler (zıplayan cihazlarda da süzülür). Giriş çubuğu klavyenin üstünde kalır (SafeArea padding'i klavye açıkken zaten 0'a düşer, çakışma yok). Bonus: listeye `keyboardDismissBehavior: onDrag` (eski mesajlara kaydırınca klavye kapanır, WhatsApp) + balon başına yeniden yaratılan `DateFormat`'lar modül düzeyi `_timeFmt/_dayFmt` oldu.
  - ⚠️ Kullanıcıya söylendi: adil test `flutter run --release` (veya --profile) ile gerçek cihazda; debug'daki takılma normaldir.
- **Değerlendirme güncelleme (aynı oturum, 3. istek). CANLIDA ✅ (kurallar + fonksiyonlar deploy, her ikisi İLK denemede):** Kullanıcı: "değerlendirme bir kez yapılıyor; ikinci kez yapılınca güncellesin." Oturum 31'deki "müşteri başına usta başına TEK yorum" kilidi korunarak ikinci gönderim artık AYNI dökümanı günceller (puan şişirme yine kapalı: kayıt sayısı artmaz).
  - **Kural:** `reviews`e update dalı eklendi — YALNIZ değerlendirmenin sahibi (`resource.data.customerUID == auth.uid`), yalnız `rating/tags/createdAt/customerDisplayName` değişebilir (kimlik alanları customerUID/artisanUID/chatId dokunulmaz), puan yine 1..5 int. delete hâlâ kapalı.
  - **CF:** `onReviewCreated` SİLİNDİ → `onReviewWritten` (onDocumentWritten): create→sayaç+1/toplam+puan; update→sayaç sabit, toplam+=(yeni−eski); yalnız etiket değişimi erken çıkar; delete savunmacı ele alınır. Deploy `--force` ile (eski fonksiyonun silinmesi onaysız geçsin diye).
  - **İstemci:** `ReviewRepository.getMyReview` (Firebase: `doc(chatId).get` — ID deterministik, sorgu gerekmez; Mock: customerUid ile arama). `review_screen`: açılışta mevcut değerlendirme ön-dolar (yıldız+etiketler), mavi bilgi şeridi "önceki değerlendirmeniz güncellenir", buton "Değerlendirmeyi Güncelle", başarı "Değerlendirmeniz güncellendi."; "yalnızca bir kez" hata metni kalktı. Mock `MockDatabase.addReview`: mevcut kayıt varsa GÜNCELLER (sayaç sabit, toplam delta; true=yeni/false=güncelleme döner; usta yoksa StateError).
  - **Test:** "2. kez değerlendiremez" testi "2. değerlendirme mevcut kaydı günceller" olarak yeniden yazıldı (sayaç sabit + toplam −5+1 + tek kayıt + farklı müşteri sayacı artırır). analyze 0; **85/85**.
  - **Yeni ilan ekranı (`create_job_screen.dart`):** düz ListView formu → **numaralı bölüm kartları** (`_SectionCard`: 28px numara rozeti + başlık + alt yazı, beyaz kart/16px köşe/softShadow — uygulamanın kart diliyle): 1 İşi Tanımlayın (başlık+kategori+Hızlı Destek kutusu), 2 Konum, 3 Detaylar (açıklama+fotoğraflar, "2/5" sayaçlı), 4 Yayın Ayarları (acil+süre; SegmentedButton tam genişlik). **"İlanı Yayınla" alta sabitlendi** (`bottomNavigationBar`: üstü hairline çizgili beyaz çubuk — kaydırmadan hep erişilir, klavyeyle yukarı çıkar). App bar'a alt yazı ("Bölgenizdeki ustalara anında duyurulur"), foto ekleme kutucuğu surfaceMuted zemin + "Ekle" etiketli oldu. Mantık/doğrulama/repo çağrıları DEĞİŞMEDİ (yalnız görsel katman). analyze 0; 85/85 test.

**Oturum 36 (2026-07-09): Sohbet profesyonelleştirme (WhatsApp/IG) + mesaj silme + ilan silme/düzenleme. CANLIDA ✅ (kurallar + 6 fonksiyon deploy, 84/84 test)**
Kullanıcı: mesaj/ilan silme yok, ilanı yayından sonra düzenleme (1 saat) yok; sohbet en alta odaklanmıyor; foto gönderirken uygulama donmuş gibi — WhatsApp gibi yüklenirken balonda loading göstergesi istendi.
- **Sohbet dipten başlar:** mesaj listesi `reverse: true` oldu (`chat_screen.dart`) — açılışta EN SON mesaj görünür, yeni mesajda dipte kalır; kaydırma gerekmez. Dizinler çevrildi (gün ayracı/grup mantığı `j` kronolojik dizinle aynı). `_scrollToBottom` artık offset 0'a gider.
- **WhatsApp tarzı foto yükleme:** `_PendingUpload` (bellekteki bytes) — balon SEÇER SEÇMEZ çizilir, üstünde karartma+spinner; yükleme arka planda (giriş kilitlenmez, `_sending` kaldırıldı; bu sırada yazılabilir/başka foto seçilebilir). Hata → balonda uyarı, dokununca "Tekrar dene / Kaldır" sheet'i.
- **Mesaj silme (yumuşak):** `ChatMessage.deleted` bayrağı; uzun basma → sheet: "Kopyala" (metin, herkesinkinde) / "Mesajı sil" (yalnız kendi, onay diyaloglu). Silinince içerik alanları KALKAR (`FieldValue.delete`), yerinde italik "Bu mesaj silindi" (`ChatMessage.deletedPreview`). Silinen SON mesajsa sohbet listesi önizlemesi de değişir (1 ek okuma). **Kural (DEPLOY GEREKLİ):** messages update yalnız gönderen + yalnız `deleted=true` + yalnız o üç alan + içerik anahtarları kalkmış olmalı; başkasının mesajı/içerik değiştirme kapalı. Mock parite + test.
- **Tam ekran foto:** balondaki fotoğrafa dokununca siyah zeminli `InteractiveViewer` (5x zoom) sayfası.
- **İlan silme:** `JobRepository.deleteJob` — yalnız ustaya BAĞLANMAMIŞ ilan (`Job.canDelete`: open/expired/cancelled; assigned StateError). Kural: `allow delete: isJobOwner() && status in ['open','cancelled']` (expired'ın status'u open). UI: ilan detayında açıkta "İlanı Sil", iptal/süresi dolmuş bildirimlerinin altında da sil butonu; onay diyalogu, başarıda pop. **CF (`onJobWritten`):** `!after` dalı artık ilanın tekliflerini batch siler (ustada hayalet kayıt kalmasın; onOfferWritten ilan yoksa offerCount'u zaten atlıyordu). Mock parite: `_db.offers.removeWhere`.
- **İlan düzenleme (1 saat):** `Job.editWindow=1h`, `canEditAt/canEditNow` (yalnız open + süresi dolmamış + yayından sonra 1 saat). `updateJobContent(title, description, budget)`; kuralda YENİ sahip dalı: `status=='open' && changedOnly(['title','description','budget'])` — 1 saat İSTEMCİDE kesilir (createdAt ISO string, kural zaman aritmetiği yapamaz; asıl koruma "yalnız open + yalnız içerik"). UI: detayda "Düzenle" (pencere içindeyse) → başlık+açıklama sheet'i (ilan verme ile aynı sınırlar). Bütçe formda yok (ilan verme de yazmıyor), repo paramı ileride hazır.
- **main.dart onarımı:** kapanış `}` yanlışlıkla `3` olmuştu (elle düzenleme kazası) — uygulama derlenmiyordu, düzeltildi.
- **Doğrulama:** analyze 0; **84/84 test** (yeni 5: mesaj silme içerik+önizleme+yetki; canEdit penceresi; updateJobContent open-only; deleteJob teklif temizliği; assigned silinemez).
- **Deploy DERSİ:** Ağ yine dalgalıydı; darboğaz HEP `firebaserules.googleapis.com` (yalnız AAAA/IPv6 dönüyor, A sorguları sık zaman aşımı → ipv4first tek başına yetmiyor). Çözüm: deploy'u BÖL — `--only functions` (firebaserules'a az uğrar, İLK denemede geçti) + `--only firestore:rules` (küçük/hızlı, 4. denemede geçti). Birleşik deploy 6 kez üst üste düşmüştü. Bu ağda bundan sonra: ipv4first + AYRI deploy + tekrar döngüsü.
- **Çoklu seçimle silme (aynı oturum, 2. istek):** Sohbet üst barına + İlanlarım üst barına çöp kutusu → seçim modu: kutucuklar belirir, "Tümünü seç" (ikinci basışta seçimi kaldırır), seçilenleri sil (onay diyaloglu), X/geri tuşu modu kapatır (`PopScope`). Sohbette yalnız KENDİ silinmemiş mesajların seçilebilir (karşı tarafınkinde kutucuk devre dışı); seçim modunda giriş çubuğu gizlenir, dokunuşlar seçimi yönetir (menü/tam ekran foto devre dışı). İlanlarım'da yalnız `canDelete` (bağlanmamış) ilanlar seçilebilir; karta uzun basış da seçim modunu açar; seçili kart vurgulanır; FAB gizlenir. Silme mevcut `deleteMessage`/`deleteJob` döngüsüyle — YENİ kural/deploy GEREKMEDİ. `MyJobsScreen` ConsumerStatefulWidget'a çevrildi.
- **Sohbet listesinden sohbet silme (aynı oturum, 3. istek — kullanıcının asıl kastı "ana Mesajlar kutusu"ydu):** Mesajlar ekranı üst barına çöp kutusu → aynı seçim modu kalıbı (kutucuklar, tümünü seç, X, PopScope, uzun basış). **Tek taraflı silme (WhatsApp "Sohbeti sil"):** `deleteThreadForMe(chatId, uid)` sohbet dökümanına `clearedAt.{uid}: Timestamp` yazar (üye zaten güncelleyebildiği için KURAL DEĞİŞİKLİĞİ/DEPLOY GEREKMEDİ). `watchThreads` `updatedAt <= clearedAt[uid]` sohbetleri listeden ELER ama önbelleğe alır (aktif işin "Sohbete Git" akışı bozulmaz); karşı taraf yazınca updatedAt ilerler → sohbet yeniden belirir. Sohbet ekranı `clearedAt`'ten ESKİ mesajları göstermez (`visibleOf` filtresi) → yeniden beliren sohbet BOŞ başlar. Onay diyalogu tek taraflılığı açıkça söyler. Test: silme→listeden düşer/karşı tarafta kalır→yeni mesajla döner (silme ile mesaj aynı ms'e denk gelirse isAfter false — testte 5 ms bekleme).
- **Üstten inen bildirim + app bar cilası (aynı oturum, 4. istek):** Kullanıcı: "mesaj silindi / bildirim mesajları altta beliriyor, kötü görünüyor; yukarıdan inmeli. İlanlarım ve İşlerim'de menü (3 çizgi) yok; app bar acemice."
  - `snackbar_helper.dart` TAMAMEN yeniden yazıldı: SnackBar yerine **`TopToast`** — root Overlay'e eklenen, üstten süzülen (280ms easeOutCubic), mesaj uzunluğuna göre 2.2–4 sn duran, dokununca/yukarı çekince kapanan bildirim. Aynı anda TEK bildirim (yenisi eskisini değiştirir; `entry.mounted` guard'ı çift remove'u önler). İki görünüm: renkli şerit (`showSuccess/showError/showInfo` — API DEĞİŞMEDİ, tüm çağrı yerleri otomatik geçti) ve `title`'lı beyaz "sistem bildirimi" kartı (`onTap` ile yönlendirme).
  - **Ön plan push'u da üstten:** `push_service._showForeground` artık SnackBar değil `TopToast.show(title, body, onTap→rota)`; Overlay bağlamı `routerProvider.routerDelegate.navigatorKey.currentContext`. `scaffoldMessengerKey` kullanımı push'tan kalktı (globals hâlâ app.dart'ta).
  - `app_menu_drawer` ve `chat_list` içindeki messenger SnackBar'ları da toast'a çevrildi (drawer'da await sonrası bağlam için kök `NavigatorState` yakalanır: `nav.mounted` + `nav.context`).
  - **Menü (3 çizgi):** `drawer: AppMenuDrawer()` İlanlarım (`my_jobs_screen`) ve İşler/Hizmetlerim (`nearby_jobs_screen`) ekranlarına eklendi — GradientAppBar hamburger'ı otomatik gösterir (Keşfet/Profil/Mesajlar'da zaten vardı).
  - **App bar düzeni:** gradyan üstünde pasif (gri) ikon çirkin durduğundan çöp kutusu artık silinecek öğe yokken HİÇ gösterilmiyor (Mesajlar + İlanlarım); İlanlarım başlığına canlı alt satır eklendi ("2 açık · 5 ilan").
- Not: kullanıcının gerçek cihazda YENİ BUILD ile test etmesi gerekenler: sohbetin dipten açılması, foto yükleme balonu, mesaj silme (tekli + çoklu seçim), sohbet silme (Mesajlar listesi), ilan sil/düzenle (tekli + çoklu seçim), üstten inen bildirimler (toast + ön plan push), İlanlarım/İşler'de menü.

**Oturum 35 (2026-07-09): "Hızlı Destek" (ayak işleri) kategorisi + "Diğer" mesleği. CANLIDA ✅ (onJobCreated deploy, 79/79 test)**
Kullanıcı: müşteri "Hızlı Destek" ilanı verebilsin → bildirim İLÇEDEKİ TÜM ustalara gitsin; meslek olarak "Diğer" seçen usta YALNIZCA bu hızlı destek ilanlarını alsın (ayak işleri sisteme girsin).
- **Kavram ayrımı (kilit karar):** `quick_support` bir İLAN KATEGORİSİDİR (usta mesleği DEĞİL — professions.json'a girmedi, usta seçemez, seed'de atlanır); `other` ("Diğer / Hızlı Destek") bir USTA MESLEĞİDİR (professions.json'a eklendi → usta profil düzenlemede ve müşteri usta aramasında otomatik görünür). Sabitler `job.dart`: `kQuickSupportCategory` / `kOtherProfession`; CF paritesi `QUICK_SUPPORT_CATEGORY`.
- **Eşleşme (`Job.matchesArtisan` — mock feed'i de bu kullanır):** ilan quick_support ise meslek ARANMAZ, il+ilçe yeter (Diğer dahil herkes); usta `other` ise quick_support DIŞINDA hiçbir ilan eşleşmez; klasik ilanlar aynen meslek+bölge.
- **Firebase feed (`watchNearbyJobs`):** `where('category', whereIn: [meslek, quick_support])` (Diğer ustasında yalnız `[quick_support]`) — `whereIn` mevcut composite index'i (category,status,createdAt) çoklu eşitlik olarak kullanır, YENİ index GEREKMEDİ; kural deploy'u da gerekmedi (kategori serbest string).
- **CF `onJobCreated` (DEPLOY EDİLDİ):** quick_support'ta meslek sorgusu yerine tüm `artisanProfiles` (tavan 1000) + bellek içi **il+İLÇE** eşleşmesi (klasik ilanlarda il düzeyi, mevcut davranış korunur); başlık "⚡ {ilçe} bölgesinde yeni Hızlı Destek ilanı" (acil: 🚨). Bildirim + push aynı `job_{jobId}` kalıbı.
- **UI:** ilan verme kategori dropdown'ının EN ÜSTÜNDE "⚡ Hızlı Destek (ayak işleri)" ("Diğer" mesleği ilan kategorisi olarak listelenMEZ — Hızlı Destek onu kapsar); seçilince turuncu bilgi kutusu ("ilçenizdeki TÜM ustalara bildirilir"). Usta profil düzenlemede "Diğer" seçilince bilgi kutusu ("yalnızca Hızlı Destek ilanları gelir"). `jobCategoryEmoji`: quick_support='⚡'. `kProfessionNames`'e iki kod da eklendi (kart/detay etiketi).
- **Doğrulama:** analyze 0; **79/79 test** (yeni 3: quick_support her meslekle ama yalnız aynı ilçede eşleşir; Diğer ustası feed'inde yalnız quick_support; normal usta feed'inde kendi mesleği + quick_support birlikte). Deploy 5. denemede geçti (ağ çok dalgalıydı: "Failed to list functions"/"generateUploadUrl" hataları; ipv4first + DNS flush + tekrar döngüsü).
- Not: Diğer/quick_support için gerçek cihaz testi kullanıcıda — yeni build gerekir (feed istemci sorgusu değişti).

**Oturum 34 (2026-07-09): Şikayet + `disputed` akışı (Oturum 31 backlog'undan). CANLIDA ✅ (kurallar + fonksiyonlar deploy, 76/76 test)**
Kullanıcı "devam" dedi; AskUserQuestion ile sıradaki iş seçildi: şikayet/disputed akışı (önerilen).
- **Model (`job.dart`):** `JobStatus.disputed` (etiket "Sorun Bildirildi", `isAssigned`'a dahil) + `canDispute` (yalnız workerSelected/inProgress/completed; rated/cancelled/open'da bildirilemez). Yeni enum'lar `JobDisputeParty` (customer/artisan) + `JobDisputeReason` (notCompleted/qualityIssue/paymentIssue/communicationIssue/other, TR etiketli). Job alanları: `disputedBy, disputeReason, disputeNote, disputedAt, statusBeforeDispute` — **toMap'e GİRMEZ** (autoCompleteAt kalıbı; yalnız repo metodları yazar), fromMap okur; `copyWith(clearDispute: true)` geri çekişte alanları temizler (null=koru kalıbı silmeye yetmediği için).
- **Repo:** `JobRepository.reportDispute({jobId, byCustomer, reason, note})` + `withdrawDispute(jobId)`. Firebase: transaction'lı (statusBeforeDispute o anki durumdan okunur; kural birebir eşleşme ister); withdraw dispute alanlarını `FieldValue.delete()` ile siler. Mock parite + StateError'lar (open'da/mükerrer bildirimde, şikayet yokken geri çekmede).
- **Kurallar (DEPLOY EDİLDİ):** `disputeOk(role)` 3 dallı: (A) şikayet-dışı güncelleme dispute alanlarına dokunamaz; (B) açma: yalnız aktif/tamamlanmış işte, `disputedBy == kendi rolü`, `statusBeforeDispute == eski durum` (dönüş durumu sahtelenemez); (C) geri çekme: YALNIZ şikayeti açan taraf, durum saklanan önceki duruma döner, dispute alanları silinmiş olmalı. **disputed'dayken başka HİÇBİR güncelleme yapılamaz** (onay bayrağı dahil — yaşam döngüsü donar). Sahip/usta changedOnly listelerine dispute alanları eklendi; usta durum geçişlerine 'disputed' + geri çekiş dönüşü eklendi.
- **CF (`onJobWritten`, DEPLOY EDİLDİ):** (1) `completedJobs` çift artış koruması: disputed→completed geçişi (geri çekiş) sayacı ARTIRMAZ (`fromDispute` guard'ı — completed'dan şikayete gidip dönen iş zaten sayılmıştı). (2) Şikayet açılınca karşı tarafa bildirim+push ("⚠️ İşle ilgili sorun bildirildi" + TR neden etiketi, `DISPUTE_REASON_TR`); geri çekilince "Sorun bildirimi geri çekildi". (3) `autoCompleteJobs` disputed işi OTOMATİK TAMAMLAMAZ (aktif-durum kontrolü zaten dışlıyor; bayat autoCompleteAt'i temizler).
- **UI (`job_detail_screen.dart`):** aktif/tamamlanmış işte iki tarafa da "Sorun Bildir" butonu (iptal butonunun yanında Wrap); `_DisputeSheet` bottom sheet (RadioGroup'lu neden seçimi — RadioListTile.groupValue bu Flutter'da deprecated — + 300 karakterlik opsiyonel not). disputed'da `_AssignedCard` yerine `_DisputePanel`: kim/neden/not/tarih, "Sohbete Git" (çözüm için açık kalır), şikayeti açana "Şikayeti Geri Çek" (onay diyaloglu). `JobStatusChip` disputed = danger kırmızısı.
- **Doğrulama:** analyze 0; **76/76 test** (yeni 3: rapor→disputed→geri çekiş roundtrip; open'da/mükerrer/şikayetsiz geri çekme StateError; dispute alanları toMap dışı + fromMap parse). Kurallar + 6 fonksiyon İLK denemede deploy oldu (ipv4first).
- Kalan (admin fazına): disputed işlerin hakem çözümü (admin paneli), eski mükerrer yorum temizliği, App Check. Console'da hâlâ bekleyen: notifications TTL politikası (Oturum 33).

**Oturum 33 (2026-07-09): Bildirim merkezi (zil + IG tarzı ekran) + "Sizi Takip Edenler". CANLIDA ✅ (kurallar + fonksiyonlar deploy, 73/73 test)**
Kullanıcı: sağ üste bildirim ikonu + IG tarzı bildirim ekranı + en altta ustayı takip edenler. Ürün kararı (AskUserQuestion): takipçiler ADLARLA görünür (IG modeli); favori dili "Takip Et" oldu.
- **Kalıcı bildirimler:** `users/{uid}/notifications/{id}` — YALNIZCA CF yazar. `saveNotification` yardımcısı; deterministik ID (`chat_{chatId}` / `job_{jobId}`) → sohbet/ilan başına TEK satır (IG kompakt). Push'tan bağımsız yazılır (token'sız kullanıcı da görür). `expireAt` (+30g Timestamp) alanı var; **Console'da TTL politikası bekliyor** (Firestore → TTL → collection group `notifications`, field `expireAt`) — yapılmazsa sadece eski kayıtlar birikir, zararsız.
- **Bildirim üreten olaylar:** yeni mesaj (onMessageCreated), bölgede yeni ilan (onJobCreated, batch'li), **usta seçildi (YENİ — bugüne dek seçilen usta push almıyordu!)**, tamamlama onayı bekleniyor, otomatik tamamlandı.
- **Kurallar:** notifications alt-koleksiyonu: sahibi okur, yalnız `read`→true güncelleyebilir, create/delete kapalı. `favorites` okuma: usta kendi takipçilerini de okuyabilir (`artisanUid == auth.uid`).
- **İstemci:** `AppNotification` modeli; `notification_repository.dart` (Firebase: orderBy createdAt limit 50; Mock: seed'li) + `myNotificationsProvider`/`unreadNotificationCountProvider`. `NotificationBell` (rozetli zil): Keşfet hero sağ üstü + usta panel app bar. `NotificationsScreen` (`/notifications`, needsLogin; eski `/panel/notifications` da aynı ekrana gider; `ArtisanNotificationsScreen` SİLİNDİ): Bugün/Bu Hafta/Daha Önce grupları, okunmamış vurgusu, dokununca sohbet/ilan, açılınca otomatik okundu. Altta "Sizi Takip Edenler": `watchFollowers` (Firebase: artisanUid filtresi + eski kayıtlar için users'tan ad tamamlama önbellekli).
- **Takip dili:** `Favorite` modeline `customerName/customerPhotoURL` snapshot'ı eklendi (buton yazar); "Favorilerim"→"Takip Ettiklerim" (ekran/menü/profil), buton mesajları "Ustayı takip ediyorsunuz / Takipten çıkarıldı".
- Deploy notu: ağ bugün çok dalgalıydı; ipv4first + 3'e kadar tekrar deneme döngüsüyle 2. denemede geçti.

**Oturum 32 (2026-07-09): İş tamamlama mühendisliği — completedJobs sayacı + otomatik tamamlama. TAMAMI CANLIDA ✅ (kurallar + 6 fonksiyon deploy edildi)**
- **Deploy sorunu ÇÖZÜLDÜ:** "Failed to make request/Failed to list functions" hatalarının nedeni Node'un IPv6'yı önce denemesi + bu ağda IPv6'nın güvenilmez olmasıydı (PowerShell IPv4 ile aynı uçlara erişebiliyordu). Çözüm: `$env:NODE_OPTIONS = "--dns-result-order=ipv4first"` ayarlandıktan sonra `firebase deploy --only functions` İLK denemede geçti. Bu makinede firebase CLI komutlarından önce bu env var hep ayarlanmalı.
Kullanıcı: "evet yapalım" (yaşam döngüsü CF'leri) + "müşteri sınırsız değerlendirme yapabiliyor" (→ Oturum 31'de kapatıldı ve kural CANLIDA; eski build/eski veriyle görülmüş olabilir. Eski mükerrer yorumların temizliği admin fazına kaldı).
- **`completedJobs` sayacı:** `ArtisanProfile.completedJobs` (yalnız CF yazar; kural `hasAny` listesine eklendi + `saveMyProfile` alanı yazımdan çıkarır). CF `onJobWritten`: iş `completed/rated`'a İLK geçişte seçili ustanın sayacı `FieldValue.increment(1)`. Usta profil ekranında "Tamamlanan İş" istatistiği eklendi.
- **Otomatik tamamlama:** Tek taraf onaylayınca (`onay bayrakları XOR` + yeni onay) CF ilana `autoCompleteAt` (=now+3g, `AUTO_COMPLETE_DAYS`) yazar ve karşı tarafa push atar. Zamanlanmış CF `autoCompleteJobs` (6 saatte bir, Europe/Istanbul): `autoCompleteAt <= now` (UTC ISO string, tek alanlı sorgu → composite index GEREKMEZ) → hâlâ aktif+tek taraflıysa `completed` + `autoCompletedBySystem:true`, onay vermeyen tarafa push; uygun değilse alan silinir. Sayaç artışını onJobWritten üstlenir (çift artış yok).
- **İstemci:** `Job.autoCompleteAt` (salt okunur, toMap'e girmez); iş detayında tek taraflı onay sonrası "… tarihine kadar yanıt vermezse otomatik tamamlanacak" bildirimi. Mock parite: `confirmDone` tek taraflıda `autoCompleteAt` set eder, iki taraflıda `MockDatabase.incrementCompletedJobs`.
- Doğrulama: analyze temiz, **70/70 test** (yeni: sayaç artışı + rated'da çift artış yok + autoCompleteAt). Kurallar (artisanProfiles completedJobs koruması) deploy edildi.
- ⚠️ **functions deploy BU AĞDAN YAPILAMADI** (googleapis uçlarına "Failed to make request", 3 deneme 3 farklı aşamada düştü — ağ engeli). Stabil ağda: `firebase deploy --only functions --project alljob1`. Deploy olana dek canlıda sayaç artmaz ve otomatik tamamlama çalışmaz (UI zararsız: 0 gösterir, bildirim çıkmaz). Bildirim başlığı düzeltmesi (Oturum 31 md.5) de aynı deploy'u bekliyor.

**Oturum 31 (2026-07-09): Uçtan uca güvenlik denetimi — 5 açık kapatıldı. KURALLAR DEPLOY EDİLDİ ✅ (functions deploy BEKLİYOR)**
Kullanıcı: "baştan sona analiz edelim, gözden kaçan varsa düzeltelim." Bulunan ve kapatılan açıklar:
1. **Sahte yorum/puan (KRİTİK):** `reviews` create kuralı yalnızca `customerUID == auth.uid` istiyordu → herkes istediği ustaya SINIRSIZ 1-5 yıldız basabilir, `onReviewCreated` CF ortalamayı güncellerdi. Düzeltme: review döküman ID'si artık deterministik `chat_{müşteri}__{usta}` (= chatId); kural ID formatını, sohbetin VARLIĞINI (`exists`), kendini-değerlendirme yasağını ve `rating` 1..5 int'i doğrular. Müşteri başına usta başına TEK yorum. İstemci: `FirebaseReviewRepository.addReview` → `doc(chatId).set(...)`; mock parite: `MockDatabase.addReview` bool döner, tekrar → `StateError` (`review_screen` hata mesajı güncellendi). Eski rastgele ID'li yorumlar okunmaya devam eder.
2. **Teklif sahtekârlığı:** `offers` create'te ID formatı ve `customerId` doğrulanmıyordu → rastgele ID'lerle aynı ilana çok teklif (offerCount şişirme) veya yanlış customerId ile müşterinin hiç göremeyeceği "hayalet" teklif mümkündü. Kural artık `offerId == jobId + '__' + auth.uid`, `customerId == get(jobs/jobId).customerId` ve ilan `open` şartı koyuyor (teklif başına 1 ek get okuma).
3. **jobs alan/geçiş kısıtları:** Sahip HER alanı yazabiliyordu (başlık, offerCount, ustanın onayı dâhil); usta status'u keyfî değere çekebiliyordu. Artık: sahip yalnız yaşam döngüsü alanları (`status, selectedOfferId, selectedArtisanId, chatId, customerConfirmedDone, cancelReason` — `artisanConfirmedDone` LİSTEDE YOK → müşteri usta onayını sahteleyemez; confirmDone tx'i alanı değiştirmeden yazdığından diff'e girmez, meşru akış bozulmaz), ilan `open`'a geri döndürülemez; usta yalnız `inProgress/completed`; `completed` ancak İKİ onay da true iken yazılabilir. create: `status=open, offerCount=0, onaylar false` zorunlu.
4. **Storage sahipliği:** Eski kural: her girişli kullanıcı HER klasöre/dosyaya yazabilirdi. Yeni yol şeması `{klasör}/{uid}/{dosya}` + kural `auth.uid == uid` ve klasör allowlist (`profile|work|job|certificate|chat`). İstemci yükleme noktaları (profil düzenleme ekranı, ilan foto, sohbet foto) uid'li yola geçti. Eski düz yollar SADECE okunur (mevcut görseller kırılmaz). ⚠️ İstemci+kural birlikte gider: kurallar deploy EDİLDİ, yeni sürümde yükleme sorunsuz.
5. **Bildirim dilbilgisi:** `onJobCreated` başlığı "İstanbul'de" gibi hatalı ek üretiyordu → "{il} bölgesinde yeni/acil iş ilanı" yapıldı. ⚠️ **functions deploy EDİLEMEDİ:** CLI bu ağdan `firestore.googleapis.com` yönetim API'sine ulaşamıyor ("Failed to make request ... databases/(default)"; rules deploy'u farklı API kullandığı için çalıştı). Başka ağda tekrar dene: `firebase deploy --only functions --project alljob1`.
- Doğrulama: `flutter analyze` temiz, **69/69 test yeşil** (yeni test: aynı müşteri aynı ustayı 2. kez değerlendiremez). Oturum 30 sonrası çalışma ağacındaki "usta seç" düzeltmesi (selectOffer customerId filtresi) hâlâ COMMIT EDİLMEDİ; kullanıcı gerçek cihazda tam yeniden derlemeyle doğrulamalı.
- Rapor edilen ama YAPILMAYAN (kullanıcı onayı/tasarım bekliyor): `completedJobs` CF sayacı, otomatik tamamlama (N gün sessizlik), `disputed` durumu, şikayet butonu, admin paneli (custom claim `admin:true` + ayrı Flutter Web + callable CF + adminLogs), App Check.

**Oturum 30 (2026-07-09): Durum güncellemesi — Google girişi doğrulandı.**
- Kullanıcı: "google giriş şu anda aktif çalışıyor." Oturum 15'ten beri "bekleyen" olarak listelenen "Google sağlayıcısını Console'da etkinleştir" maddesi **ÇÖZÜLDÜ** — kullanıcı Console'da sağlayıcıyı açmış ve gerçek cihazda/tarayıcıda test edip çalıştığını doğrulamış. Kod tarafında (`firebase_auth_repository.dart`, `login_screen.dart`) zaten Google girişi hazır bekliyordu, sadece Console ayarı bekleniyordu.
- **Kalan bekleyenler:** (1) Web push için VAPID anahtarı (`push_service.dart` → `kWebVapidKey`). (2) iOS APNs kurulumu (Windows'ta yapılamaz). (3) Kullanıcının gerçek cihazda test etmesi gereken: Oturum 28 yeni-ilan push bildirimi, Oturum 29 mesajlar yeni tasarımı.

**Oturum 28 (2026-07-08): Yeni iş ilanında aynı il + aynı meslek ustalarına push. UYGULANDI + DEPLOY EDİLDİ ✅**
Kullanıcı: "müşteri ilan verdiği anda aynı ildeki ilgili ustalara bildirim gitsin."
- **CF `onJobCreated` (`functions/index.js`, yeni):** `jobs/{jobId}` onCreate → status open + category/province varsa → `artisanProfiles.where(profession==category).limit(500)` (tek eşitlik, composite index/backfill GEREKMEZ) → bellek içi `serviceAreas[].province == job.province` filtresi → ilan sahibi atlanır (çift rol) → alıcıların `users/{uid}.fcmTokens`'ları `db.getAll` ile 100'lük parçalarda toplanır (token→sahip haritasıyla) → `sendEachForMulticast` 500'lük parçalarla. Başlık: "{il}'de yeni iş ilanı" (acilse 🚨 önekli), gövde: ilan başlığı · ilçe, data `{type:'job', jobId}`. Geçersiz token'lar sahibinin dizisinden `arrayRemove` ile düşülür (onMessageCreated kalıbı).
- **`push_service.dart`:** gezinme genelleştirildi — `_routeFor`: `chat`→sohbet, `job`→ilan detayı; ön plan SnackBar "Gör" aksiyonu da aynı rotayı kullanır.
- **DEPLOY EDİLDİ (ben):** `firebase deploy --only functions` → **onJobCreated oluşturuldu**, diğer 3 fonksiyon güncellendi. İlk 2 deploy denemesi başarısızdı: yerel DNS `cloudfunctions.googleapis.com`'u REFUSED ediyordu (okul ağı) → `ipconfig /flushdns` sonrası düzeldi. **Ders:** deploy'da `ENOTFOUND/getaddrinfo` görürsen önce DNS flush dene.
- **Doğrulama:** `node --check` OK; `flutter analyze` 0; testler **68/68**. Gerçek push testi kullanıcıda: Android cihazda usta hesabıyla giriş (token kaydolur) → başka hesaptan aynı il+meslekte ilan ver → bildirim gelmeli; dokununca ilan detayı açılır.

**Oturum 29 (2026-07-08): Mesajlar Instagram DM dili + kompakt kartlar. UYGULANDI ✅**
Kullanıcı: "mesajlar daha prof olsun (Instagram gibi), mesajda profil fotosuna basınca profili göster; ilan/usta kartları çok büyük, fazla ilan olunca ortalık karışır."
- **Sohbet listesi (`chat_list_screen.dart`, yeniden yazıldı):** üstte arama kutusu (ada göre filtre), kompakt satırlar (56px avatar, "ad" + "son mesaj · 3 dk" tek alt satır), okunmamışta kalın metin + Instagram tarzı **mavi nokta** (sayı rozeti yerine). Ham `$e` hata metni de temizlendi.
- **Sohbet ekranı (`chat_screen.dart`):** (1) **Mesaj gruplama** — aynı göndericinin ardışık mesajları grup; avatar YALNIZ grubun son mesajında, grup içi boşluk 1.5px, kuyruk (köşe kırılması) yalnız grup sonunda; baloncuklar 20px radius (Instagram'a yakın). (2) **AppBar başlığı** artık avatar + ad + alt yazı ("Usta · profili gör" / "Müşteri"); dokununca karşı profil açılır. (3) **Profil açma iki yönlü:** karşı taraf usta → herkese açık usta profili (mevcut); karşı taraf MÜŞTERİ → yeni `_CustomerPreviewSheet` mini profil kartı (bottom sheet: büyük avatar+ad+Müşteri etiketi; müşterinin public profil sayfası olmadığı için önizleme yeterli). Mesaj içi avatara dokunmak da aynı yere gider.
- **Usta kartı (`artisan_card.dart`):** iki katlı ferah kart → **tek blok kompakt satır** (44px avatar; ad+rozetler üstte, "meslek · ★4.8 (12) · 15 yıl" özet alt satırda, durum pill'i sağda). Grid `mainAxisExtent` 152→**84** (ekrana ~2 kat usta sığar).
- **İlan kartı (`job_widgets.dart` NearbyJobCard):** dikey 3 bloklu kart → **tek satırlı kompakt** (40px emoji rozeti, başlık+acil, 1 satır açıklama, "📍 ilçe · zaman · N ilgilendi" meta). Ayrı CTA satırı kaldırıldı (kartın tamamı zaten tıklanabilir; `ctaText` parametresi geriye dönük uyum için duruyor). `OfferCountBadge` ilanlarım ekranında kullanılmaya devam ediyor.
- **Doğrulama:** `flutter analyze` 0; testler **68/68**.

**Oturum 28b (2026-07-08): "İlgilenen ustalar listelenemiyor" düzeltmesi. UYGULANDI ✅**
- **Kök neden (Firestore kural-sorgu uyumsuzluğu):** `watchOffersForJob` yalnız `where(jobId==X)` sorguluyordu; `offers` okuma kuralı "teklifi veren usta VEYA ilan sahibi müşteri" der. Firestore liste sorgularında kural, SORGU FİLTRESİNDEN kanıtlanabilir olmalı — jobId filtresi sahipliği kanıtlamaz → sorgunun TAMAMI permission-denied → müşteri "İlgilenen Ustalar"ı hiç göremiyordu. (Mock modda görünmez; Firebase'e geçince ortaya çıktı.)
- **Düzeltme:** sorguya `where(customerId == oturum uid)` eklendi (iki eşitlik → composite index GEREKMEZ; kural deploy'u GEREKMEZ). `OfferRepository.watchOffersForJob({jobId, customerId})` imzası (firebase+mock+testler güncellendi); `offersForJobProvider` uid'i `currentUserProvider`'dan alır. Ham `$e` sızdıran hata metni `_NoticeCard`'lı dostça mesaja çevrildi.
- **Ders:** kural `resource.data.X == auth.uid` içeriyorsa, liste sorgusuna da `where(X == uid)` konmalı — yoksa tek tek dökümanlar okunabilse bile liste sorgusu komple reddedilir.
- **Doğrulama:** analyze 0; testler 68/68.

**Oturum 27 (2026-07-08): Tek birleşik profil sayfası — "profil sayfaları çorba" geri bildirimi. UYGULANDI ✅**
Kullanıcı: "profil sayfalarının tasarımları çorba, müşteri/usta modları çok karışık, profesyonellik 0." Karar (AskUserQuestion): **tek birleşik profil** (Uber/Airbnb ayarlar dili), prototipsiz direkt kod.
- **Yeni `lib/features/profile/presentation/profile_screen.dart`:** her iki modda AYNI sayfa (`/profile`). Yapı: kompakt hero (avatar + ad + mavi tik ikonu + e-posta, ustada meslek) → **belirgin Müşteri|Usta SegmentedButton mod anahtarı** (hasArtisanProfile olanlara; geçişte sayfada kalınır, içerik yeniden şekillenir) → gruplu menü satırları. Usta modu: DÜKKÂNIM (müsaitlik switch satırı premium-kapılı, Dükkânımı Gör ★puan alt yazılı, Profili Düzenle, Premium) + İŞLERİM (Yakınımdaki İşler/İletişimlerim rozetli, Bildirimler). Müşteri modu: AKTİVİTEM (İlanlarım, Favorilerim) + usta profili yoksa "Hizmet Vermeye Başla". Ortak: HESAP (telefon doğrulama satırı, e-posta, üyelik) + Çıkış. Tüm satırlar tek `_MenuRow` yapı taşından (ikon kutusu + başlık/alt yazı + rozet/değer/switch/chevron).
- **Silinen ekranlar:** `customer_profile_screen.dart` + `artisan_home_screen.dart` (eski panel dashboard'u). Panelin işlevleri satırlara dağıldı; değerlendirme listesi/hakkımda "Dükkânımı Gör" (herkese açık profil) üzerinden.
- **Router:** global redirect `loc == /panel → /profile` (alt rotalar `/panel/*` aynen; route-level redirect KULLANILMADI çünkü go_router'da ebeveyn redirect'i zincirdeki çocuklara da uygulanır). Splash/auth-sonrası hedef artık HEP `/` (Keşfet) — moda göre panel dallanması kalktı. `/panel` GoRoute builder'ı alt rotalar için ebeveyn olarak ProfileScreen tutar.
- **Alt bar:** Profil sekmesi artık her modda `/profile`. **Drawer:** mod geçişi `/profile`'a götürür; usta menüsünden mükerrer Premium + Profili Düzenle satırları kaldırıldı.
- **Edit ekranı temizliği:** "Mavi Tik Al" kartı formun en üstünden Kaydet'in üstüne taşındı; AppBar'daki beklenmedik "Çıkış Yap" ikonu kaldırıldı (çıkış profil sayfasında).
- **Test:** `artisan_login_test` artık ProfileScreen + 'DÜKKÂNIM' bölümünü doğrular (eski ArtisanHomeScreen beklentisi yerine).
- **Doğrulama:** `flutter analyze` 0; testler **68/68**; `flutter build web` OK.

**Oturum 26 (2026-07-08): "Profil yüklenemedi" + eski oturum verisi sızıntısı + telefon doğrulama bölge engeli. UYGULANDI ✅**
Kullanıcının 3 şikâyeti tek kod kökenine + bir Console ayarına indi:
- **Profil yüklenemedi + eski oturum sızıntısı (TEK KÖK NEDEN):** `MyProfileController.build` `ref.read(currentUserProvider)` kullanıyordu → provider hesap değişince ASLA yeniden kurulmuyordu. (a) Web'de sayfa yenilenince oturum geri yüklenmeden build çalışıp `StateError` fırlatıyor ve KALICI "Profil yüklenemedi" gösteriyordu; (b) çıkış + farklı hesapla girişte önceki kullanıcının taslağı ekranda kalıyordu. **Düzeltme:** `ref.watch(currentUserProvider.select((u) => u?.uid))` — yalnız uid izlenir (users dökümanının diğer alan güncellemeleri, ör. phoneVerified/mod geçişi, kaydedilmemiş taslağı ezmesin); uid null'sa `authStateProvider.future` beklenir (açılışta oturum geri yüklenmesi). **Ders (Riverpod):** provider `build()` içinde başka provider'a `ref.read` = donmuş bağımlılık; kullanıcıya bağlı state'te MUTLAKA `watch` (+select).
- **Telefon doğrulama "aktif değil" (GERÇEK KÖK NEDEN = SMS BÖLGE POLİTİKASI):** Phone sağlayıcısı AÇIKTI, test numarası (`+905550000000`→`123456`) kayıtlıydı; ama `smsRegionConfig.allowlistOnly` BOŞTU → hiçbir ülkeye SMS izni yok. Firebase bu durumda SDK'ya sağlayıcı-kapalıyla AYNI `operation-not-allowed` kodunu döndürüyor → uygulama yanlışlıkla "sağlayıcı etkin değil" diyordu. **Düzeltme (ben, REST ile):** firebase CLI kimliğiyle `PATCH identitytoolkit v2 /projects/alljob1/config` → `smsRegionConfig.allowlistOnly.allowedRegions=["TR"]`. Doğrulama: REST `sendVerificationCode` test numarasına OK döndü. Ayrıca `_map`'e ayrım eklendi: mesajında "region" geçen `operation-not-allowed` → yeni `PhoneVerificationException.regionBlocked` (doğru Türkçe yönlendirme: Settings → SMS region policy).
- **Doğrulama:** `flutter analyze` 0; testler **68/68**. Kullanıcı tarayıcıda hot restart sonrası test edecek: test numarası `5550000000`, kod `123456`.

**Oturum 25 (2026-07-08): Kırık testlerin temizliği + hata mesajı cilası. UYGULANDI ✅**
Kullanıcı "geçmişten kalan kırık var mı, giderelim; hatalar profesyonelce kullanıcıya bildirilsin" dedi. Uzun süredir bilinen **7 kırık test kalıcı olarak düzeltildi** → artık **68/68 yeşil**.
- **Kök neden:** `useFirebaseBackend=true` olduğundan `artisan_login_test` + `my_profile_test` provider override'sız gerçek Firebase'e gidip çöküyordu (Firebase test ortamında başlatılmaz).
- **Çözüm:** yeni `test/helpers/mock_backend.dart` → `mockBackendOverrides()` tüm backend repo sağlayıcılarını (auth/artisan/chat/favorite/job/offer/myProfile/storage) bellek-içi mock'a çevirir. İki test bunu kullanır.
- **`artisan_login_test` yenilendi:** eski "giriş panele götürür" beklentisi Oturum 17 misafir-önce yönlendirmeyle bayatlamıştı (giriş, keşiften otomatik panele ATMAZ) → test artık girişten sonra panele gidip ArtisanHomeScreen'in render olduğunu doğrular.
- **`PushService` test-güvenli:** Firebase örnekleri (`_messaging`/`_db`) artık `late` (lazy) → başlatılmamış ortamda kurulum hata vermez; `registerFor` try/catch içinde sessizce no-op.
- **Hata mesajı cilası:** `chat_screen` "Mesaj gönderilemedi: $e" ham exception sızdırıyordu → dostça mesaj. `favorite_button` toggle'ın try/catch'i yoktu → hata geri bildirimi eklendi. (Genel tarama: diğer tüm kritik akışlar zaten `context.showError` ile dostça Türkçe mesaj gösteriyor.)
- **Doğrulama:** `flutter analyze` **0**; testler **68/68** (artık kırık YOK); `flutter build web` OK. Commit `28eea93` + GitHub'a push edildi.

**Oturum 24 (2026-07-08): Telefon doğrulama (SMS OTP) + mavi tik. UYGULANDI ✅ — deploy + Console KULLANICIYA.**
Kullanıcı: "usta profil doldururken telefon istenebilir; telefonla doğrulayan mavi tikli olur." Karar (AskUserQuestion): **opsiyonel** (mavi tik ödülü) + **herkes** doğrulayabilir (mavi tik yine ustaya özel). `ArtisanProfile.isVerified` zaten vardı (kartta `Icons.verified`) ama hep false + istemciden yazılabiliyordu (açık). Uygulandı:
- **Doğrulama = Firebase Phone Auth + hesaba BAĞLAMA:** telefon mevcut e-posta/Google hesabına `linkWithCredential` (web'de `linkWithPhoneNumber`) ile bağlanır → jeton `phone_number` claim'i taşır. `lib/features/auth/data/phone_verification_repository.dart` (arayüz + `firebase_*` web/mobil ayrımı + mock kodu `123456`). `sendCode`→`PhoneVerificationSession`→`confirmCode` (link + `getIdToken(true)`).
- **Güvenli mavi tik (kilit nokta):** `firestore.rules` — `artisanProfiles.isVerified=true` ve `users.phoneVerified=true` yazımı YALNIZCA `request.auth.token.phone_number != null` iken (helper `verifiedClaimOk`/`phoneClaimOkFor`). Kimse doğrulamadan tik alamaz; CF gerekmez.
- **Model/repo:** `AppUser.phoneVerified` (public users doc, kural korumalı; toMap yazar). `AuthRepository.setPhoneVerified` (users.phoneVerified=true + numarayı `users/{uid}/private/contact`'a yazar — Oturum 23'te kurulan hassas alt-koleksiyon) + `MyProfileRepository.markVerified` (yalnız profil dökümanı VARSA isVerified=true; müşteride no-op). Mock+Firebase impl.
- **UI:** `phone_verification_sheet.dart` (numara→kod, +90 önekli, TR 10 hane), ortak `verification_tile.dart` — müşteri profilinde "Telefonunu Doğrula", usta düzenlemede "Mavi Tik Al"; doğrulanınca yeşil "Doğrulanmış" kartı.
- **Test:** `test/phone_verification_test.dart` (4 test: geçersiz numara, roundtrip, yanlış kod, setPhoneVerified).
- **Doğrulama:** `flutter analyze` **0**; testler **61/61** (yeni 4 dahil; 7 bilinen Firebase kırığı ayrı); `flutter build web` OK.
- ✅ **KURULUM TAMAM (2026-07-08):** (1) `firebase deploy --only firestore:rules --project alljob1` **DEPLOY EDİLDİ** (ben çalıştırdım) — Oturum 23 (phoneNumber guard + private alt-koleksiyon) + Oturum 24 (isVerified/phoneVerified telefon guard'ları) canlı. (2) Console'da **Phone sağlayıcısı etkin** (kullanıcı). (3) **SHA-1+SHA-256 zaten ekliydi** (flutterfire configure'dan; keytool ile doğrulandı: SHA-1 `5d:c4:f1:62:...:b1:26:02`). (4) **Test numarası eklendi** (kullanıcı). → Telefon doğrulama uçtan uca hazır; kullanıcı `flutter run` ile test edecek.

**Oturum 23 (2026-07-08): Profesyonelleşme — Git deposu + Crashlytics + güvenlik düzeltmesi. UYGULANDI ✅**
Kullanıcı profesyonel yazılım standartları (katmanlı mimari, SOLID, performans, güvenlik, hata yönetimi, CI/CD) listeledi + "sen öner". Dürüst röntgen: mimari/performans/lint zaten iyi; gerçek açıklar = (a) proje **git deposu bile değildi**, (b) merkezi loglama yok, (c) `users` dökümanında telefon sızıntısı. "Hepsini sırayla yap" dedi, tam yetki. Yapılanlar:
- **GIT (temel açık):** `git init -b main` + `.gitignore` genişletildi (`functions/node_modules`, firebase logları, `*.env`) + `.gitattributes` (LF normalizasyon) + **2 commit**: ilk commit (191 dosya, tüm proje) + profesyonelleşme commit'i. `google-services.json` commit'lendi (kurallarla korunuyor, gizli değil). **NOT: uzak (GitHub) depo YOK** — istenirse `gh repo create` ile bağlanır.
- **CRASHLYTICS (merkezi loglama):** `firebase_crashlytics ^4.1.3`. `main.dart`: `FlutterError.onError = recordFlutterFatalError` + `PlatformDispatcher.instance.onError → recordError(fatal:true)`. **Web'de desteklenmez → `!kIsWeb` guard.** Android Gradle: `com.google.firebase.crashlytics` plugin (settings + app build.gradle.kts, v3.0.2). Ücretsiz (Blaze gerekmez).
- **GÜVENLİK (telefon sızıntısı):** `AppUser.phoneNumber` `users/{uid}` HERKESE AÇIK dökümanına yazılıyordu (`allow read: if true`); Firestore alan-bazlı okuma kısıtlayamaz → tüm döküman sızar. Düzeltme: (1) `AppUser.toMap`'ten `phoneNumber` çıkarıldı (artık public dökümana yazılmıyor); (2) kural: public dökümana `phoneNumber` yazımı YASAK (create: `!keys().hasAny`; update: `!diff().affectedKeys().hasAny` — dokunulmayan eski alan güncellemeyi bloklamaz); (3) sahibe özel `users/{uid}/private/{doc}` alt-koleksiyonu (`read,write: if isSelf`) — hassas veri buraya. `phoneNumber` şu an hiçbir yerde SET edilmiyordu (hep null), bu yüzden davranış kırılmadı.
- **Doğrulama:** `flutter analyze` **0**; Firebase'siz testler **57/57**; `flutter build web` başarılı.
- ⚠️ **KULLANICI AKSİYONU:** (1) **`firebase deploy --only firestore:rules --project alljob1`** — yeni users guard + private alt-koleksiyon kuralı canlıya. (2) Crashlytics: gerçek cihazda `flutter run` → test çökmesi at (`FirebaseCrashlytics.instance.crash()`) → Console'da göründüğünü doğrula. (3) İstersen GitHub uzak deposu bağla.
- ⏭️ **Önerilen sonraki (ertelendi):** gerçek cursor pagination (`startAfter`+`areaKeys[]`), functions ESLint, CI pipeline. Domain katmanı/tam DDD bu ölçekte önerilmedi (fazla mühendislik).

**Oturum 22 (2026-07-08): FCM push bildirimleri (yeni sohbet mesajı). UYGULANDI ✅ — deploy KULLANICIYA kaldı.**
Yeni sohbet mesajı gelince alıcının cihaz(lar)ına push bildirimi. Kod tarafı uçtan uca hazır.
- **Cloud Function (`functions/index.js`) — yeni `onMessageCreated`:** `chats/{chatId}/messages/{msgId}` onCreate → sohbet dökümanından katılımcıları okur → GÖNDEREN dışındaki alıcıyı bulur → alıcının `users/{uid}.fcmTokens` dizisindeki token'lara `sendEachForMulticast` ile bildirim yollar (başlık = gönderenin adı, gövde = mesaj / "📷 Fotoğraf") → `data:{type:'chat',chatId}` ekler (dokununca sohbete gidilsin) → "kayıtsız/geçersiz" dönen token'ları `arrayRemove` ile temizler. **channelId belirtilmedi** (cihazda olmayan kanal Android 8+'da bildirimi gizler; FCM SDK otomatik varsayılan kanalı kullanır). `node --check` geçti.
- **Flutter push servisi (`lib/features/notifications/data/push_service.dart`, yeni):** `PushService` + `pushServiceProvider`. `registerFor(uid)`: izin iste → token al → `users/{uid}.fcmTokens`'a `arrayUnion` → `onTokenRefresh` dinle. `unregisterFor(uid)`: token'ı `arrayRemove` + `deleteToken`. Ön planda gelen mesaj → in-app SnackBar (`scaffoldMessengerKey`, "Gör" aksiyonu). `onMessageOpenedApp` + `getInitialMessage` → `/chats/{chatId}`'e git. Yalnız `useFirebaseBackend` iken çalışır (mock modda no-op). Web'de VAPID boşsa getToken atlanır.
- **`main.dart`:** top-level `@pragma('vm:entry-point')` arka plan işleyicisi (`onBackgroundMessage`, runApp'ten ÖNCE, ayrı isolate → Firebase yeniden init). Yalnız bayrak açıkken.
- **`app.dart`:** `scaffoldMessengerKey` MaterialApp'a bağlandı; `ref.listen(authStateProvider)` ile giriş olunca token kaydı (+ açılışta zaten oturum açıksa `ref.read` ile ilk kayıt). **NOT (Riverpod tuzağı):** `WidgetRef.listen` `fireImmediately` DESTEKLEMEZ (yalnız provider `Ref.listen`) → ilk değer ayrıca ele alındı.
- **`auth_controller.dart` signOut:** `_repo.signOut()` ÖNCESİ `pushService.unregisterFor(uid)` (uid oturum kapanınca kaybolur; başka hesap bu cihaza bildirim almasın).
- **`web/firebase-messaging-sw.js` (yeni):** web arka plan bildirimleri için servis çalışanı (compat SDK importScripts, `firebase_options.dart web` ile aynı config).
- **pubspec:** `firebase_messaging: ^15.1.6` (çözülen 15.2.10).
- **Kurallar DEĞİŞMEDİ:** `users/{uid}` sahibi zaten `fcmTokens`'ı yazabiliyor → ayrı rules deploy'u gerekmez.
- **Doğrulama:** `flutter analyze` **0 sorun**; Firebase'siz testler **57/57** (7 bilinen `artisan_login`/`my_profile` Firebase kırığı, ilgisiz); `flutter build web` başarılı.
- ✅ **DEPLOY EDİLDİ (2026-07-08, Oturum 24 sonu):** `firebase deploy --only functions --project alljob1` (ben) → **`onMessageCreated` oluşturuldu**, `onReviewCreated`+`onOfferWritten` güncellendi; bu kez sorunsuz (API'ler Oturum 21'den açık). 3 fonksiyon canlı. (Zararsız uyarı: firebase-functions eski sürüm önerisi.) **Android'de push tam çalışır** (token girişte otomatik kaydolur). ⚠️ Kalan opsiyonel: (a) Web push için VAPID anahtarı `push_service.dart` `kWebVapidKey`'e (Console→Cloud Messaging→Web Push certificates). (b) iOS APNs (Windows'ta yapılamaz).
- ⚠️ **Hâlâ bekleyen (önceki):** Google giriş sağlayıcısını Console'da etkinleştir (Oturum 15).

**Oturum 21 (2026-07-08): Cloud Functions — rating + offerCount aggregation CANLI. UYGULANDI ✅**
Blaze açıldığı için sunucu-tarafı aggregation devreye alındı; istemci-tarafı "geçici çözümler" kaldırıldı:
- **`functions/` (yeni, Node 22, Gen 2, `europe-west1`):** `index.js` iki tetikleyici — **`onReviewCreated`** (yeni değerlendirme → `artisanProfiles`'ın `averageRating/totalReviews/totalRatingSum` alanlarını transaction ile increment) + **`onOfferWritten`** (teklif her değişince ilgili ilanın `offerCount`'unu çekilmemiş teklif sayısına göre yeniden hesap). `package.json` + `firebase.json`'a `functions` bölümü.
- **DEPLOY EDİLDİ (ben, birçok denemeyle):** Blaze sonrası ilk Gen 2 deploy 6 Google API'sini açtırdı (kullanıcı 2'sini konsoldan elle açtı: Runtime Config/Eventarc/Cloud Run/Pub/Sub) + Eventarc servis-hesabı IAM yayılması için birkaç dk beklendi. Sonunda `onReviewCreated` + `onOfferWritten` **başarıyla oluşturuldu**; Artifact Registry temizlik politikası `--force` ile ayarlandı (imajlar 1 günde silinir).
- **İstemci temizliği (fonksiyonlar CANLI olduktan SONRA gönderildi):**
  - `firebase_artisan_repository.dart`: **`_ratingSums()` 1000-review taraması TAMAMEN KALDIRILDI** (Oturum 19'un son kalan sızıntısı). Rating artık doğrudan profil dökümanından okunuyor (CF denormalize ediyor). Profil-dökümanı okuma önbelleği (3 dk TTL) + fetch cap korundu; `getArtisanDetail` yorumları yalnızca liste için çekiyor.
  - `firebase_offer_repository.dart`: istemci `FieldValue.increment(offerCount)` (submit + withdraw) **kaldırıldı** — CF tutuyor.
  - `firestore.rules`: `jobs` update'inden `changedOnly(['offerCount'])` **silindi** (güvenlik sıkılaştı; offerCount'u yalnız CF/Admin SDK yazar). **Kural deploy edildi.**
- **Doğrulama:** `flutter analyze` 0 sorun; Firebase'siz testler **57/57**; `flutter build web` başarılı; fonksiyonlar + kurallar canlı.
- ⚠️ **Not (backfill):** CF yalnızca YENİ review'lerde tetiklenir. Deploy'dan ÖNCE var olan review'lerin puanı profile yansımaz (eski profil `averageRating=0` görünebilir). Firestore büyük ölçüde boş olduğundan önemsiz; gerekirse tek seferlik backfill script'i yazılır.
- ⚠️ **Hâlâ bekleyen:** Google giriş sağlayıcısını Console'da etkinleştir (Oturum 15). Sıradaki büyük iş: **FCM push bildirimleri** (yeni mesaj → alıcının token'ına CF ile gönderim; `firebase_messaging` + token kaydı + izin akışı).

**Oturum 20 (2026-07-08): Blaze planı + Cloud Storage CANLI. UYGULANDI ✅**
Kullanıcı Blaze planını açtı + Storage bucket'ını kurdu (`gs://alljob1.firebasestorage.app`). Storage devreye alındı:
- **`useFirebaseStorage = true`** (`backend_config.dart`). Foto yükleme artık gerçek kalıcı Storage URL'leri üretir (eskiden mock, yalnız-oturum). `firebase_options.dart` bucket'ı zaten doğru (`alljob1.firebasestorage.app`).
- **`storage.rules` (yeni):** pazaryeri görselleri kamuya açık OKUMA (misafir de Keşfet'te görür); YAZMA yalnız oturum açmışa + sunucu tarafı tür/boyut sınırı (`image/.*`, <6 MB — istemci sıkıştırmasına ek savunma katmanı). `firebase.json`'a `storage` bölümü eklendi.
- **DEPLOY EDİLDİ (ben çalıştırdım):** `firebase deploy --only storage,firestore:rules,firestore:indexes --project alljob1` → hepsi başarılı. Bu deploy ayrıca **Oturum 19'un bekleyen index'lerini + Oturum 16'nın bekleyen public `jobs` okuma kuralını** da yayınladı. (Uyarı: eski `jobs (category,status)` index'i projede duruyor, zararsız; `--force` ile temizlenebilir.)
- **Doğrulama:** `flutter analyze` 0 sorun. (Storage'ı gerçek cihazda foto yükleyerek test etmek kullanıcıya kaldı.)
- ⚠️ **Kalan bekleyenler:** (1) Google sağlayıcısını Firebase Console'da etkinleştir (Oturum 15'ten). (2) FCM push + Cloud Functions (rating/offerCount aggregation) — artık Blaze açık, yapılabilir; yeni geliştirme işi.

**Oturum 19 (2026-07-08): Firebase maliyet/fatura optimizasyonu (Blaze gerektirmeyen kısım). UYGULANDI ✅**
Kullanıcı sordu: "pagination + cache + görsel sıkıştırma yapalım, ücretlendirme optimizasyonu gerekmez mi?" Teşhis: senin 3 maddenden **görsel yükleme zaten yapılmış** (image_picker maxWidth/quality ile sıkıştırıyordu); asıl fatura sızıntıları **sahte pagination** (Firestore'dan hepsini çekip bellekte bölme) ve **görsel indirme cache'inin olmaması**ydı. Firebase faturası = doküman OKUMA sayısı + Storage bant genişliği. Blaze'siz yapılabilenlerin hepsi uygulandı:
- **Usta araması gerçek okuma azaltma (`firebase_artisan_repository.dart`):** en büyük sızıntı düzeltildi. Eskiden HER arama+HER "daha fazla yükle" `q.get()` ile TÜM `artisanProfiles` koleksiyonunu + `_ratingSums()` ile **1000 review dokümanını** okuyordu (tek arama = 1000+ okuma; loadMore her seferinde tekrar). Artık: örnek-ömrü (singleton provider) önbellek — profil dökümanları profesyon anahtarına göre + `reviews` toplamları, **3 dk TTL** (`_cacheTtl`, `_cachedProfiles`, `_ratingSums` cache). `loadMore` ve ardışık aramalar artık **0 Firestore okuması** yapar. Ayrıca sunucu sorgusuna `.limit(AppConstants.artisanFetchCap=300)` tavanı. `invalidateCache()` metodu eklendi (yazma sonrası elle boşaltma için, opsiyonel). Müsaitlik hesaplanmış alan olduğundan istemci-sıralaması korundu — gerçek `startAfter` cursor'u hâlâ CF+areaKeys[] (Blaze) ölçeğine bağlı.
- **İş ilanı feed'leri sunucu-tarafı limit (`firebase_job_repository.dart`):** `watchOpenJobs` ve `watchNearbyJobs` artık limitsiz `.snapshots()` değil → sunucuda `orderBy('createdAt', descending:true).limit(cap)` (openJobsFetchCap=60, nearbyJobsFetchCap=100). Koleksiyon büyüdükçe okuma sabit kalır. Süre dolumu/coğrafi eşleşme istemcide (cap pay bırakır). Yeni composite index'ler: `jobs (status, createdAt DESC)` ve `jobs (category, status, createdAt DESC)` — eski `(category,status)` bununla değişti (`firestore.indexes.json`).
- **Görsel indirme cache'i (`app_image.dart` + pubspec):** `cached_network_image: ^3.4.1` eklendi; `AppImage` `Image.network` → `CachedNetworkImage` (diske önbellek). Aynı foto her kaydırmada Storage'dan yeniden inmez → Storage bant genişliği faturası düşer (Storage açılınca doğrudan kazanç).
- **Görsel yükleme sıkıştırması sıkılaştırıldı:** tüm `pickImage` çağrıları (profil/iş/sohbet) artık ortak `AppConstants.imagePickMaxWidth=1080` + `imagePickImageQuality=70` (eskiden dağınık 1280/85). 5 MB ham foto → tipik ~150–300 KB.
- **Doğrulama:** `flutter analyze` **0 sorun**; Firebase'siz testler **57/57** (7 bilinen `artisan_login_test`/`my_profile_test` Firebase kırığı — Oturum 12'den, ilgisiz); `flutter build web` başarılı; `flutter pub get` OK.
- ⚠️ **KULLANICI AKSİYONU:** Yeni index'ler için `firebase deploy --only firestore:indexes --project alljob1` (deploy edilene dek Firebase modunda feed sorguları FAILED_PRECONDITION/index hatası verebilir). Bekleyen `firestore:rules` deploy'uyla birlikte yapılabilir.
- ⚠️ **İleride (Blaze gerekli):** gerçek `startAfter` cursor pagination + rating'i CF ile profile denormalize etme (o zaman `_ratingSums` full-scan tamamen kalkar) + `areaKeys[]` ile sunucu-tarafı coğrafi filtre. Bunlar Storage/CF ile aynı Blaze kapısında bekliyor.

**Oturum 18 (2026-07-03): Tasarım yönü v2 — "nefes alan, cam dokunuşlu" yenileme. UYGULANDI ✅**
- Kullanıcı: "tasarımı baştan ele alalım" — Uber/Linear/Revolut/Apple Wallet referanslı; nefes alan kartlar, ince cam (glass) efektleri, hafif gradyanlar, profil etiketleri, yükleme skeleton'ları, sade alt bar. Kararlar (AskUserQuestion): önce HTML prototip → onaylandı; alt bar **3 sade sekme kalsın** (Keşfet/Mesajlar/Profil); cam/gradient **ince & seçici**. Ek istek: sade üst başlıklar (İlanlarım/Mesajlarım/Bildirimler) da yeni dile uyarlandı. Kullanıcı "tam yetki, onay isteme" dedi.
- **HTML prototip yayınlandı** (artifact, scratchpad `design-v2.html`): palet, önce/sonra usta kartı, Keşfet, Usta Profili (etiketler + cam stat kartı), İş İlanları, skeleton.
- **Palet (`app_colors.dart`):** zemin `background` → **#FAFAFB** (serin beyaz), yeni `hairline` (#EEF0F3, ince kart kenarı), ortak `availableRing` gradyanı (kart+profil paylaşır).
- **Tema (`app_theme.dart`):** yeni `floatShadow` (yüzen öğeler), kart kenarı açık modda `hairline`'a indi, kart radius 18.
- **Yeni ortak widget'lar:** `core/widgets/skeleton.dart` (`Skeleton`/`Skeleton.circle` shimmer + `SkeletonList` hazır liste); `core/widgets/gradient_app_bar.dart` (`GradientAppBar` — lacivert gradyan + turuncu radial ışık + beyaz metin, alttan yuvarlak, drop-in `AppBar` yerine).
- **`MainBottomBar` (`role_bottom_bar.dart`) yeniden yazıldı:** NavigationBar → **yüzen pill** (kenardan boşluklu, radius 24, `floatShadow`, `maxWidth 480` ortalı). API/sekmeler aynı (Keşfet/Mesajlar/Profil, mesaj rozeti) — ekranlar değişmedi. `bottomNavigationBar` yuvasında kalır (extendBody YOK; içeriği örtmez).
- **`ArtisanCard`:** yatay-kompakttan **nefes alan beyaz karta** (radius 20 + softShadow): üst satır (halkalı avatar + ad/doğrulama + müsait pill) → hairline ayraç → puan satırı (★ · N değerlendirme · N yıl · chevron). Grid `mainAxisExtent` 96→134.
- **Keşfet:** yükleme durumları `CircularProgressIndicator` → `SkeletonList`.
- **Usta Profili:** hero'ya **değerlendirmelerden türeyen olumlu etiket çipleri** (`_topPositiveTags`, en sık 4; cam `_HeroTag`). Cam stat kartı zaten vardı.
- **İlan kartı (`NearbyJobCard`):** başa **meslek emojisi rozeti** (`jobCategoryEmoji`, 12 meslek→emoji), meta satırı "📍 ilçe · N dk önce"; açıklama+CTA+ilgi rozeti korundu.
- **İkincil başlıklar → `GradientAppBar`:** İlanlarım, İletişimlerim, Favorilerim, Hizmetlerim, Bildirimler, Mesajlar, İlan Detayı, İş İlanı Ver, Premium Üyelik, Profili Düzenle (ikon + isteğe bağlı alt satır). Liste ekranlarının yükleme durumları da `SkeletonList`.
- **Doğrulama:** `flutter analyze` **0 sorun**; Firebase'siz testler **57/57**; `flutter build web` **başarılı**. (7 test hatası = Oturum 12'den beri bilinen `artisan_login_test`+`my_profile_test` Firebase kırığı, tasarımla ilgisiz.)
- Marka açık temaya kilitli (telefon hep açık). ⚠️ Bekleyenler önceki oturumlardan aynen duruyor: Oturum 16 kural deploy'u + Google sağlayıcısını etkinleştirme.
- **Oturum 18a — HATA DÜZELTMESİ (kullanıcı "ortada sadece Keşfet/Mesajlar/Profil, başka bişey yok"):** Yeni yüzen `MainBottomBar`'daki `Center`, `bottomNavigationBar` yuvasında dikeyde tüm boş yüksekliği kaplıyordu → 66px bar ekranın ortasına gidip gövdeyi eziyordu. Çözüm: `Center` → `Align(alignment: bottomCenter, heightFactor: 1.0)` (dikeyde içeriğe sarılır). analyze temiz. **Ders:** `bottomNavigationBar` içinde `Center`/`Align` kullanınca `heightFactor: 1.0` şart, yoksa dikeyde genişler.
- **Oturum 18b — Usta kartı overflow düzeltmesi:** Keşfet ızgara hücresi `mainAxisExtent` 134→**152** (yeni ferah kart taşıyordu, alttaki sarı şerit). Puan satırındaki "N değerlendirme" `Flexible`+ellipsis (dar telefon yatay taşması).
- **Oturum 18c — Moda göre 4. sekme (kullanıcı isteği):** Alt bar artık moda duyarlı. `MainTab`'a **`work`** eklendi: müşteri = **İlanlarım** (`/jobs/mine`, campaign ikonu), usta = **İşler** (`/panel/jobs`, handyman ikonu); misafirde gizli (`showWork = user != null`). Sekmeler: Keşfet · [work] · Mesajlar · Profil. `my_jobs_screen` + `nearby_jobs_screen`'e `bottomNavigationBar: MainBottomBar(current: MainTab.work)` eklendi (artık sekme kökü). Drawer'dan tekrar eden girişler kaldırıldı (müşteri "İlanlarım", usta "Hizmetlerim"); "İş İlanı Ver"/"Favorilerim"/"İletişimlerim" vb. drawer'da kaldı. Not: müşteri work'ü top-level (geri oksuz temiz sekme); usta `/panel/jobs` nested olduğu için panele geri oku çıkar (küçük asimetri, kabul edildi). analyze 0.

**Oturum 17e (2026-07-03): Usta paneli sadeleştirme ("çok kötü ve karışık" geri bildirimi).**
- Panel gövdesi 7-8 ayrı karttan 4-5 net bloğa indi. Yeni düzen: (profil eksikse uyarı) → **_StatusCard** → **_WorkflowCard** → Hakkımda → Değerlendirmeler → Müşteri Modu kartı (en alta taşındı).
- **_StatusCard (yeni):** Müsaitlik + Premium tek kartta iki kompakt satır. Büyük `_PremiumCard` SİLİNDİ (yönetim zaten `/panel/premium` sayfasında; satırdaki "Yönet / Premium Ol" oraya gider). `_AvailabilityCard` SİLİNDİ (satıra dönüştü; "Düzenle" → panelEdit).
- **_WorkflowCard (yeni):** `_QuickStatsRow` (3 istatistik kartı) + `_NearbyJobsSection` (3 ilanlık önizleme) SİLİNDİ; yerine iki tıklanabilir gezinme satırı: "Yakınımdaki İşler" (sayı rozeti → panelJobs) ve "İletişimlerim" (bekleyen sayısı → panelOffers). **"Aktif İş" istatistiği kullanıcı isteğiyle KALDIRILDI** ("fonksiyonu yok") — assignedJobsProvider paneldeki kullanımı kalktı (bildirimler ekranında hâlâ kullanılıyor).
- analyze 0, 57/57 test, web build OK.

**Oturum 17d (2026-07-03): "İki profil sayfası" kurgu düzeltmesi.**
- Kullanıcı şikâyeti: usta modunda alt bar Profil → panel (genel bilgiler), ama hero'daki profil FOTOĞRAFINA basınca ikinci bir "profil sayfası" (Profili Düzenle formu) açılıyordu — iki profil sayfası hissi.
- Düzeltme: `_HeroAvatar` artık salt görsel (tıklanamaz, kalem rozeti kaldırıldı). Düzenlemeye giden görünür yollar: hero'daki "Profili Düzenle" butonu, ☰ menüdeki "Profili Düzenle" satırı ve bölümlerin "Düzenle" aksiyonları. "Dükkânımı Gör" (müşteri gözünden önizleme) etiketli buton olarak duruyor — bilinçli.
- analyze 0, 57/57 test, web build OK.

**Oturum 17c (2026-07-03): Çapraz mod mesaj rozeti + FCM kararı.**
- **Çapraz mod rozeti (kullanıcı isteği):** karşı moda okunmamış mesaj düşerse ☰ menü düğmesinde **kırmızı nokta** (`DrawerMenuButton`, üç hero'daki düz IconButton'ların yerini aldı) + menüdeki "Usta/Müşteri Moduna Geç" satırında **sayılı kırmızı rozet**. Yeni provider'lar (`chat_providers.dart`): `unreadBySideProvider` (okunmamışları `thread.artisanUid == uid` ile usta/müşteri tarafına ayırır) + `otherModeUnreadProvider` (aktif modun karşısı; usta profili yoksa 0). Mesajlar sekmesi rozeti toplamı göstermeye devam eder (sohbet listesi zaten iki tarafı birleşik listeler). Test: `dual_role_test.dart`'a taraf ayrımı testi (57/57).
- **FCM (telefona push) YAPILAMADI — Blaze engeli:** gerçek push bildirimi, yeni mesajda sunucudan gönderim ister → Cloud Functions (messages onCreate → alıcının FCM token'ına gönder) → **Blaze planı gerekli** (Storage gibi). Blaze'e geçilince yapılacaklar: `firebase_messaging` paketi + token'ı `users/{uid}`'e kaydet + CF gönderici + bildirim izin akışı. Kullanıcıya iletildi.

**Oturum 17b (2026-07-03): Ortak alt bar + hamburger menü (kullanıcı önerisi).**
- **`MainBottomBar`** (`role_bottom_bar.dart` yeniden yazıldı; eski Customer/Artisan/RoleBottomBar sınıfları SİLİNDİ): her iki modda ve misafirde ORTAK 3 sekme — **Keşfet / Mesajlar / Profil**. Usta da Keşfet'i görür. Profil hedefi moda göre: müşteri → `/profile`, usta → `/panel`, misafir → login. Mesajlar rozeti korundu (misafirde 0).
- **`AppMenuDrawer`** (`core/widgets/app_menu_drawer.dart`, yeni): sol üst 3 çizgi menü; içerik duruma göre — misafir: Giriş/Kayıt; müşteri modu: İş İlanı Ver, İlanlarım, Favorilerim + (Usta Moduna Geç | Hizmet Vermeye Başla); usta modu: Hizmetlerim, İletişimlerim, Bildirimler, Premium, Profili Düzenle + Müşteri Moduna Geç; oturum varsa Çıkış Yap. Async işlemlerde router/messenger await ÖNCESİ yakalanıyor (drawer kapanınca context ölür).
- **Hamburger butonları:** Keşfet hero'su (marka satırının solu), müşteri profil hero'su, usta panel hero'su (müsaitlik switch'inin solu); Mesajlar'da AppBar drawer ikonu otomatik.
- **İkincil ekranlar push sayfası oldu** (alt bar kaldırıldı, AppBar geri okuyla): İlanlarım, Favorilerim, Hizmetlerim (yakındaki işler), İletişimlerim, Bildirimler. Drawer `context.push` kullanır → geri tuşu hub'a döner.
- Doğrulama: analyze 0, 56/56 test, web build OK.

**Oturum 17 (2026-07-03): Tek hesap, çift rol sistemi.**
Kalıcı/değişmez rol modeli kaldırıldı; kullanıcı tek hesapla hem müşteri hem usta olabilir. "Her İkisi" modu bilinçli olarak YOK (iki mod + tek dokunuş geçiş); kullanıcı "sonra bazı değişiklikler yaparız" dedi — kurgu revizyonları beklenebilir.
- **`AppUser`:** `role` alanı yerine **`hasArtisanProfile: bool`** (usta profili açıldı mı — kalıcı) + **`activeMode: UserRole`** (arayüz modu — değiştirilebilir). `isArtisan/isCustomer` artık AKTİF MODA bakar (UI kapıları otomatik uyum sağladı). Geriye dönük uyum: eski `role: artisan` dökümanı → `hasArtisanProfile=true, activeMode=artisan`; `toMap` eski istemciler için `role`'ü de yazar.
- **`AuthRepository`:** `register` ROLSÜZ (herkes müşteri modunda başlar), `signInWithGoogle` parametresiz (Google'da rol sorunu kökten çözüldü). Yeni: **`becomeArtisan()`** (hasArtisanProfile=true + usta moduna geç) ve **`setActiveMode(mode)`** (usta modu hasArtisanProfile ister, yoksa `AuthException.noArtisanProfile`). Mock + Firebase impl. **Firebase'de kritik detay:** `userChanges()` Firestore'u görmediği için `_manualUpdates` broadcast controller'ı `authStateChanges()` akışına birleştirildi — mod değişince router/UI anında güncellenir.
- **Kayıt akışı:** rol seçim ekranı SİLİNDİ (`role_selection_screen.dart`, `/role-selection` rotası). Kayıt tek tip; giriş ekranındaki "Yeni Hesap Oluştur" doğrudan `/register`'a gider.
- **Router:** "usta yalnızca /panel'de yaşar" HAPSİ KALKTI. Splash/auth-sonrası yönlendirme aktif moda göre; `/panel*` yalnızca `hasArtisanProfile` olana açık; gerisi serbest (menüleri UI modu yönetir). Alt barlar zaten `isArtisan` (mod) bazlı — değişmedi.
- **Profil ekranları:** Müşteri profilinde `_ArtisanModeCard` — profil yoksa **"Hizmet Vermeye Başla"** (onay diyaloğu → becomeArtisan → `/panel/edit`'e gider, meslek+bölge doldurur), varsa **"Usta Moduna Geç"**. Usta panelinde `_CustomerModeCard` — **"Müşteri Moduna Geç"** → keşfete döner.
- **Kendi-kendine etkileşim guard'ları (çift rolün yan etkileri):** kendi usta profilinde "Sohbet Başlat" gizli; kendi profiline favori butonu gizli; usta feed'i kullanıcının müşteri olarak verdiği KENDİ ilanlarını elemez oldu (`nearbyJobsProvider` filtresi). Kendine değerlendirme zaten sohbet-geçmişi guard'ıyla imkânsız. İlan detayında sahiplik kontrolü usta bölümünden ÖNCE geldiğinden kendi ilanına "İletişime Geç" zaten çıkmaz.
- **chat_screen:** "müşteri tarafı mıyım" tespiti moda değil THREAD'e bakar (`thread.artisanUid != user.uid`) — çift rollü kullanıcı hangi modda olursa olsun doğru davranır.
- **Firestore kuralları:** DEĞİŞİKLİK GEREKMEDİ — kurallar zaten `isSelf`/sahiplik bazlı; `users` dökümanını sahibi güncelleyebiliyor. (Oturum 16'nın `jobs` okuma kuralı deploy'u hâlâ bekliyor.)
- **Test:** yeni `dual_role_test.dart` (6 test: yeni kullanıcı varsayılanları, legacy `role` eşleme, roundtrip, kayıt→becomeArtisan→mod geçişleri, kalıcılık, demo usta). `my_profile_test` yeni alanlarla güncellendi (ama Firebase bağımlılığı nedeniyle Oturum 12'den beri kırık olmaya devam ediyor).
- **Doğrulama:** `flutter analyze` 0 sorun; Firebase'siz testler **56/56**; `flutter build web` başarılı.
- **⚠️ Firebase modunda dikkat:** mevcut Firestore'daki eski kullanıcılar dokunulmadan çalışır (fromMap eşlemesi okuma anında). Mock demo hesapları: `musteri@test.com` (düz kullanıcı) / `usta@test.com` (usta profili + usta modu), şifreler `123456`.

**Oturum 16 (2026-07-03): Keşfet ekranında ustaların yanında iş ilanları.**
- **`JobRepository.watchOpenJobs({limit=30})`:** tüm açık + süresi dolmamış ilanlar, en yeni en üstte (meslek/bölge filtresi YOK — herkese açık panel). Mock + Firebase impl (tek eşitlik filtresi `status==open`, composite index gerekmez; eleme/sıralama/limit istemcide). `openJobsProvider`.
- **Keşfet düzeni:** geniş ekranda (≥1000px) usta ızgarasının HEMEN YANINDA 400px "İş İlanları" paneli (dikey ayraçla); dar ekranda hero altında `SegmentedButton` ile **Ustalar / İş İlanları** görünüm geçişi. Panel: başlık + adet rozeti + kart listesi; boş/hata durumları mevcut `_Centered` ile.
- **`NearbyJobCard` `job_widgets.dart`'a taşındı** (+`ctaText` parametresi: usta feed'inde "İletişime Geç", keşfette "Detayı Gör"; konum satırı il/ilçe; alt satıra `OfferCountBadge` eklendi). `nearby_jobs_screen.dart` ve `artisan_home_screen.dart` importları güncellendi.
- **İlan detayı üçüncü taraf guard'ı:** ilan sahibi olmayan MÜŞTERİ artık usta arayüzünü ("İletişime Geç") değil salt-okunur bilgi kartını görür ("Bu ilan başka bir müşteriye ait…"). Misafir karta tıklayınca `/jobs/...` needsLogin ile girişe yönlenir (mevcut davranış).
- **firestore.rules:** `jobs` okuma `isSignedIn()` → **herkese açık** (`if true`) — misafir de Keşfet'te ilanları görsün (pazaryeri kamu içeriği). ⚠️ **KULLANICI AKSİYONU: `firebase deploy --only firestore:rules --project alljob1`** (deploy edilene dek Firebase modunda misafir ilan paneli PERMISSION_DENIED görür; giriş yapmış kullanıcıda sorun yok).
- **Test:** `watchOpenJobs` 2 yeni test; ayrıca ÖNCEDEN VAR OLAN flaky "acil ilan feed başında gelir" testi deterministikleştirildi (iki ilan aynı milisaniyede oluşunca `createdAt` eşitliği sıralamayı belirsizleştiriyordu — artık açık `createdAt` veriliyor).
- **Doğrulama:** `flutter analyze` 0 sorun; Firebase'siz testler **50/50**; `flutter build web` başarılı.

**Oturum 15 (2026-07-02): Kullanıcının 14 maddelik listesi (müşteri 10 + usta 3 + mesaj hatası) uygulandı.**
- **Hata teşhisi (mesajlar ustada görünmüyor + favoriler bozuk):** Firestore REST ile gerçek test hesapları açılıp canlı kurallara karşı uçtan uca denendi (müşteri sohbet başlat → mesaj → USTA sohbet listesi sorgusu → usta cevap; favori ekle/listele/sil). **HEPSİ GEÇTİ** — backend/kurallar sağlıklı. Sorunlar büyük olasılıkla Oturum 14b kural deploy'u ÖNCESİNDEN kalmaydı; kullanıcı yeniden test etmeli. Bilinen kısıt: sohbette **fotoğraf** mesajları Storage kapalıyken (`useFirebaseStorage=false`, Blaze yok) karşı cihazda görünmez. (Not: teşhisin bıraktığı `chats/chat_PYW...__GUv...` dökümanı silinemedi — kural delete:false; konsoldan silinebilir, zararsız. Test auth hesapları silindi.)
- **Coğrafi veri (#5-6-7):** `districts.json` 81 il / **970 ilçe** ile yeniden üretildi (kaynak: berkaycatak/turkiye_il_ilce_json, Türkçe başlık düzenine çevrildi, il içi alfabetik, Merkez en üstte). **Mahalle seçimi tamamen kaldırıldı** (keşfet filtresi, ilan verme, usta bölge düzenleyici). `ServiceArea.neighborhood` geriye dönük uyum için opsiyonel kaldı (eski Firestore kayıtları okunur); `key`/`==` il+ilçe düzeyine indi; `labelTR` eklendi. `ArtisanFilter`'dan neighborhood kalktı.
- **Keşfet yeniden (#1):** hero'da **metin arama kutusu** (yazdıkça 400ms debounce ile arar; ad VEYA meslek adı, Türkçe İ/ı duyarlı `ArtisanFilter.query/matchesQuery`) + yanında **"Detaylı" butonu** → mevcut il/ilçe/meslek filtreleri **bottom sheet açılır pencerede** (`detailed_search_sheet.dart`), her dropdown'da **"Tümü"** seçeneği (null=filtre yok), aktif filtre sayısı rozeti + Temizle.
- **Rol bazlı görünürlük (#2):** "İş İlanı Ver" yalnızca oturum açmış MÜŞTERİDE görünür (hero'da). İlanlarım/Favoriler artık alt barda (yalnız müşteri). Misafir yalnızca arama + "Giriş Yap" görür.
- **Müşteri alt bar (#9):** `core/widgets/role_bottom_bar.dart` — Keşfet / İlanlarım / Mesajlar (okunmamış rozetli) / Favoriler / Profil. Keşfet, İlanlarım, Mesajlar, Favoriler, Profil ekranlarına takıldı.
- **Müşteri profil sayfası (#8):** `/profile` → `customer_profile_screen.dart`: hero (avatar+ad+e-posta), **gerçek istatistikler** (toplam/aktif/tamamlanan ilan + favori sayısı), hesap bilgileri kartı, Çıkış Yap. Router: needsLogin'e `/profile` eklendi.
- **Mesajlarda avatar (#10):** sohbette karşı tarafın mesajlarının başında yuvarlak avatar + AppBar başlığında avatar; müşteri tarafında dokununca usta profiline gider. `chat_icon_button.dart` silindi (alt bar rozetli ikonla değişti).
- **Google ile giriş (#3):** `AuthRepository.signInWithGoogle({roleIfNew})` — web'de `signInWithPopup`, mobilde `signInWithProvider` (ek paket YOK). İlk girişte `users/{uid}` müşteri rolüyle açılır; mevcut hesabın rolü korunur. Giriş ekranına "Google ile devam et" butonu (elle çizilmiş G logosu). Mock impl + iptal hata eşlemeleri eklendi. **⚠️ KULLANICI AKSİYONU: Firebase Console → Authentication → Sign-in method → Google'ı ETKİNLEŞTİR** (yoksa giriş "Bir hata oluştu" verir).
- **Usta alt bar (usta #1):** Profil (/panel) / Hizmetlerim (/panel/jobs, AppBar'dan İletişimlerim'e geçiş) / Mesajlarım / Bildirimler (/panel/notifications — yeni `artisan_notifications_screen.dart`: FCM gelene dek bölgedeki yeni ilanlar + seçilme olaylarından türetilmiş akış). Hero'daki bildirim+mesaj ikonları kaldırıldı.
- **Usta panel sadeleşti (usta #2):** "İşlerim" galerisi ve "Hizmet Bölgelerim" bölümleri ana ekrandan KALDIRILDI (düzenleme ekranında duruyorlar).
- **İlan sıralaması (usta #3):** feed artık **salt en yeni en üstte** (acil-önce sıralama kaldırıldı; acil rozeti duruyor) — mock + firebase.
- **Doğrulama:** `flutter analyze` 0 sorun; Firebase'siz testler **48/48** (yeni: metin sorgusu 2 test; sayfalama testi ilçe düzeyine uyarlandı); `flutter build web` başarılı. `artisan_login_test`/`my_profile_test` Oturum 12'den beri bilinen kırık (provider override yok → gerçek Firebase'e gidiyor).

**Oturum 14 (2026-07-02): Çift taraflı pazaryeri — İş İlanları + Teklifler (5 aşama, TAMAM).**
Uygulama tek yönlü usta rehberinden dinamik pazaryerine dönüştü. İki akış birlikte: **Doğrudan İletişim** (usta profilinden sohbet, korundu) + **İş İlanı → Teklif** (sohbet yalnızca teklif seçilince açılır, #6). Plan dosyası: `C:\Users\Okul\.claude\plans\mutable-juggling-parrot.md`. Doğrulama: `flutter analyze` 0 sorun, **45/45 Firebase'siz test** (yeni `jobs_test.dart` 12 test), `flutter build web` başarılı.

- **Aşama A — Veri katmanı:** modeller `job.dart` (Job + JobStatus/JobPriceType/JobDuration/JobCancelReason enumları), `offer.dart` (Offer + OfferStatus, tekillik `Offer.idFor=jobId__artisanId` #1), `favorite.dart`. 3 repo arayüzü + Mock + Firebase: `features/jobs/data/{job,offer}_repository.dart` (+mock/firebase), `features/favorites/data/favorite_repository.dart`. Provider'lar `job_providers.dart`/`favorite_providers.dart` (`useFirebaseBackend` ile mock/firebase). `MockDatabase` genişletildi (jobs/offers/favorites map + `changes` tick stream + `notify()` + 3 örnek ilan tohumu). `AppConstants` (maxJobPhotos=5 #9, başlık/açıklama/not limitleri). `firestore.rules` + `firestore.indexes.json` güncellendi.
- **Aşama B — Müşteri:** `create_job_screen.dart` (/jobs/new: başlık, kategori, il/ilçe/mahalle, açıklama, foto ≤5, ☑ACİL, süre 24s/3g/7g varsayılan 3g #2, fiyat "Bütçem var"/"Keşif Gerekli" #8), `my_jobs_screen.dart` (/jobs/mine: durum çipi + "N teklif geldi" rozeti #3). Keşfet hero'suna hızlı eylemler (İş İlanı Ver / İlanlarım / Favorilerim). `favorites_screen.dart` (/favorites).
- **Aşama C — Usta:** `nearby_jobs_screen.dart` (/panel/jobs: meslek+bölge eşleşen açık ilanlar, acil kırmızı #urgent), `my_offers_screen.dart` (/panel/offers). `job_detail_screen.dart` usta teklif formu (fiyat/Keşif + not, Güncelle/Geri Çek #7). Usta ana ekranına hızlı istatistik kartları (#12: Yakında İş / Bekleyen Teklif / Aktif İş — hepsi gerçek veri) + "Yakınımdaki İş İlanları" önizleme (ilk 3).
- **Aşama D — Döngü:** `job_detail_screen.dart` müşteri teklif listesi (usta özet kartı #5 → profile git), teklif seç → sohbet açılır (`chatRepository.startChat`) + ilan kapanır + diğerleri reddedilir (#6). Yaşam döngüsü stepper (Açık→Usta Seçildi→İş Sürüyor→Tamamlandı→Değerlendirildi #4), iki taraflı tamamlama (`confirmDone` #10), tamamlanınca müşteri değerlendirir (mevcut `ReviewScreen` + opsiyonel `jobId` → `markRated`), müşteri iptali (bottomsheet 3 neden #11).
- **Aşama E — Favoriler + cila:** `favorite_button.dart` (kalp; kart sağ üstü + profil hero'su; misafir→login, usta→gizli #14). Acil rozeti (`UrgentBadge`) + Expired gösterimi (`Job.effectiveStatus`, feed'den elenir) tutarlı.

**⚠️ KULLANICI AKSİYONU — Firestore kural/index deploy (izin gerekiyor):**
`firebase deploy --only firestore:rules,firestore:indexes --project alljob1`
Bu, jobs/offers/favorites kurallarını + `jobs (category,status)` index'ini yayınlar. Ayrıca **Oturum 13'ten bekleyen chat `members` + review kuralları** da bununla birlikte gider. Deploy edilene dek Firebase modunda ilan/teklif/favori işlemleri PERMISSION_DENIED verebilir.

**Notlar:**
- `offerCount` Cloud Functions gelene dek istemci `FieldValue.increment` ile güncelliyor; kural yalnızca bu alanın değişmesine izin veren `changedOnly(['offerCount'])` satırıyla korunuyor (CF gelince kaldırılacak).
- Feed coğrafi eşleşme MVP: sunucuda kategori+durum, istemcide bölge (il+ilçe). Ölçekleme (areaKeys[] array-contains) ileride.
- "Profil görüntüleme" istatistiği gerçek sayaç istediğinden (rules non-owner yazımı engelliyor) dashboard'a eklenmedi; yerine türetilebilen gerçek sayılar gösteriliyor.
- Usta ilan detayına erişebilsin diye router `/jobs/:jobId` ustaya açıldı; `/jobs/new` ve `/jobs/mine` müşteriye özel.

---

**Oturum 13 (2026-07-02): Profesyonel tasarım sistemi** — Inter fontu, elle seçilmiş renk paleti, baştan yazılmış tema, `BrandMark`, lacivert hero'lu keşfet ekranı, yenilenen splash/rol seçimi/giriş/kayıt ekranları. Detay aşağıda Oturum 13 girdisinde.

**AŞAMA 4 (Mesajlaşma + maskeleme + değerlendirme) — TAMAM ve doğrulandı:**
- ✅ Sohbet modeli (`lib/data/models/chat.dart`: `ChatMessage`, `ChatThread`) + repo soyutlaması `ChatRepository` ve `MockChatRepository` (`lib/features/chat/data/chat_repository.dart`) — bellek içi gerçek-zamanlı stream taklidi (`watchThreads`/`watchMessages`).
- ✅ Sohbet listesi ekranı (`chat_list_screen.dart`) + gerçek-zamanlı mesajlaşma ekranı (`chat_screen.dart`: metin + foto baloncukları, otomatik alta kaydırma). Müşteri için ÜCRETSİZ (kredi YOK).
- ✅ **İletişim maskeleme** (`lib/core/utils/contact_masker.dart`): telefon/e-posta/URL/sosyal medya (@kullanıcı, whatsapp/telegram/instagram) otomatik `•••` olur; gönderirken uyarı gösterilir. Maskeleme `sendMessage` içinde uygulanır.
- ✅ "Sohbet Başlat" butonu usta profil sayfasına bağlandı (misafir → `/login`, müşteri → sohbet aç). Usta ana ekranı + müşteri dashboard'da "Mesajlar" ikonu → `/chats`.
- ✅ İş sonu değerlendirme ekranı (`review_screen.dart`): 1–5 yıldız + `ReviewTags` hazır etiket seçimi, serbest metin yok. `MockDatabase.addReview` ortalama puanı günceller.
- ✅ Rotalar: `/chats`, `/chats/:chatId`, `/review/:uid` (hepsi giriş gerektiren korumalı bölge).
- ✅ `flutter analyze`: **0 sorun**. `flutter test`: **37/37 geçti** (chat + maskeleme testleri dahil: `chat_review_test.dart`, `contact_masker_test.dart`).

**Aşama 4 sonrası mock rötuşları (Firebase öncesi) — TAMAM:**
- ✅ **Değerlendirme yalnızca sohbet geçmişi olana açık** (PRD §5): `ChatRepository.hasChatBetween` + `ReviewScreen` guard.
- ✅ **Premium yönetimi** (PRD §6): usta panelinde Premium kartı + `MyProfileController.setPremium` (ilk yıl ücretsiz).
- ✅ **Sohbet UX:** okunmamış rozeti (liste + AppBar `ChatIconButton`), okundu bilgisi (tek/çift tik), tarih ayraçları. Repo: `markRead/unreadCount/lastReadAt`, `totalUnreadProvider`.
- ✅ **Premium arama etkisi:** `AppConstants.firstYearFreePremium` bayrağı; `false` → yalnızca müsait+Premium listelenir.
- ✅ **Sertifika yükleme/görüntüleme:** usta panelinde sertifika bölümü + müşteri profilinde küçük resim + tam ekran görüntüleme.
- ✅ `flutter test`: **40/40**, `flutter analyze`: 0 sorun.

**PRD v4.0 güncellemesi (son sürüm) — yapılan kod değişiklikleri:**
- ✅ `PRD.md` eklendi (v4.0, son sürüm). Sürüm notu içerir.
- ✅ **Kredi sistemi kaldırıldı:** `ArtisanProfile.creditBalance` ve `AppConstants.messageInitiationCreditCost` / `maxReviewLength` silindi. Gelir modeli yalnızca Premium.
- ✅ **Canlı müsaitlik + çalışma takvimi:** yeni `availability.dart` (`WeeklySchedule`, `DayAvailability`, `AvailabilityMode`). `ArtisanProfile`'a `alwaysAvailable`, `manualPause`, `weeklySchedule`, `createdAt` + `isAvailable`/`isNewArtisan` hesap alanları.
- ✅ **Arama sıralaması** premium-önce → **müsait-önce** (puana göre) olarak değişti (PRD §3, ilk 1 yıl modeli).
- ✅ **"Yeni Usta" rozeti:** ilk 15 gün (`AppConstants.newArtisanVisibilityDays`), puana yansımaz. Kartta rozet.
- ✅ **Değerlendirme:** `Review.comment` (serbest metin) kaldırıldı → `Review.tags` (hazır etiketler). `ReviewTags.positive/negative` sabit listeleri. Profil ekranında etiket çipleri.
- ✅ **Usta paneli:** müsaitlik bölümü (SegmentedButton: Her zaman / Haftalık / Kapalı) + haftalık gün-saat düzenleyici (switch + saat seçici). Controller'da `setAvailabilityMode`, `toggleScheduleDay`, `setScheduleDayHours`.
- ✅ Kart + müşteri profilinde "Şu an müsait / müsait değil" göstergesi.

**PRD v4.0 TAM/SON metin uyumu (ikinci geçiş):**
- ✅ `PRD.md` kullanıcının verdiği tam v4.0 metniyle yeniden yazıldı (Ekran A–F, tüm detaylar).
- ✅ **Opsiyonel/bağımsız filtreler (Keşfet):** İl/İlçe/Mahalle/Meslek artık zorunlu değil. Yeni `ArtisanFilter` (hepsi nullable). `ArtisanRepository.searchArtisans({filter, offset, limit})` imzası değişti; mock kısmi eşleşme yapıyor. `CustomerFilter.toArtisanFilter()`, controller opsiyonel filtreyle çalışıyor, "Usta Bul" her zaman aktif (boş filtre = Türkiye geneli).
- ✅ **Değerlendirme etiketleri** PRD'deki kesin listelerle güncellendi (`ReviewTags.positive` 8, `.negative` 8 etiket).
- ✅ **Çalışma takvimi serileştirme** Firestore şekline hizalandı: gün-adlı map (`monday`..`sunday`) + `"HH:mm"` string, kapalı günde yalnızca `enabled:false`. `WeeklySchedule.toMap/fromMap`, `DayAvailability.toMap/fromMap(weekday, ...)` + `parseMinute`.
- ✅ `flutter analyze`: **0 sorun**. `flutter test`: **25/25 geçti** (opsiyonel filtre + takvim serileştirme roundtrip testleri dahil).

---

### Aşama 1-3 özeti

**Tamamlanan: AŞAMA 1 + AŞAMA 2 + AŞAMA 3**

Aşama 1 özet: Flutter projesi (Android/iOS/Web), Riverpod+GoRouter, tema, `Validators`, modeller, statik JSON veri + `LocalDataService`, uçtan uca auth akışı (Splash→Rol→Kayıt/Giriş→Dashboard) + auth guard + rol izolasyonu.

**AŞAMA 2 — yeni eklenenler:**
- ✅ `Review` modeli (maskeli ad: "A***").
- ✅ Usta veri soyutlaması: `ArtisanRepository` (+ `ArtisanSummary`, `ArtisanDetail`, `ArtisanSearchPage`) ve `MockArtisanRepository` (25 boyacı Dikkaldırım + örnekler, sabit tohum). `artisan_providers.dart`.
- ✅ Müşteri Dashboard: kademeli dropdown (il→ilçe→mahalle→meslek; üst değişince alt sıfırlanır), "Usta Bul" (filtre tamamsa aktif).
- ✅ Usta listeleme: kart (avatar/ad/meslek/deneyim/puan), "Öne Çıkan" premium rozeti, **sıralama** (premium önce, grup içinde puana göre), **pagination** (20'şer, scroll ile loadMore).
- ✅ Usta profil sayfası (salt okunur): kapak+doğrulama tiki, hakkımda, hizmet bölgeleri (chip), sertifikalar, yorumlar (tarihli), sabit "Sohbet Başlat" (Aşama 4'e stub). Telefon/e-posta GÖSTERİLMEZ.
- ✅ Rota: `/customer/artisan/:uid`. `main.dart`'ta `tr_TR` tarih locale init.
- ✅ `flutter analyze`: **0 sorun**. `flutter test`: **11/11 geçti** (filtre/sıralama/sayfalama testleri dahil).

**AŞAMA 3 — yeni eklenenler:**
- ✅ `image_picker` eklendi. `StorageRepository` soyutlaması + `MockStorageRepository` (bellek içi, `local://` handle). `AppImage` widget (network + local:// + placeholder, platformdan bağımsız `Image.memory`).
- ✅ `MyProfileRepository` (ustanın KENDİ profili get/save) + mock. `AuthRepository.updateUserProfile` (ad/foto) eklendi.
- ✅ `MyProfileController` (AsyncNotifier): taslak yükle, alanları düzenle, bölge ekle/çıkar (dedupe), foto ekle/çıkar, kaydet.
- ✅ Usta Profil Düzenleme Paneli (`ArtisanProfileEditScreen`, artık usta ana ekranı): profil foto (kamera butonu), ad-soyad, meslek (tek seçim), deneyim, hakkımda (≤500 sayaç), **çoklu hizmet bölgesi** (il→ilçe→mahalle seç + Ekle, chip + sil), iş fotoğrafları (yatay galeri + ekle/sil), Kaydet (validasyonlu).
- ✅ Eski `artisan_dashboard_screen.dart` silindi. `flutter analyze`: **0 sorun**. `flutter test`: **15/15 geçti**.

**Demo hesaplar (mock):** Müşteri `musteri@test.com` / Usta `usta@test.com` — ikisi de `123456`.
**Demo arama:** İl=Bursa, İlçe=Osmangazi, Mahalle=Dikkaldırım, Meslek=Boyacı Ustası → 26 sonuç (premium önce).

**AŞAMA 5 — Firebase: BAĞLANDI VE CANLI (Oturum 12).** Uygulama artık `alljob1` projesine bağlı; `useFirebaseBackend = true`. Storage hariç (Blaze/kart sonra).
- [x] Backend bayrağı + tüm Firebase repo implementasyonları + provider geçişi + main.dart init + kurallar/index + rehber.
- [x] **CLI kuruldu (Oturum 12):** Node v24.18.0 / npm 11.16.0, firebase-tools 15.22.4 (global PATH), flutterfire_cli 1.4.0 (`%LOCALAPPDATA%\Pub\Cache\bin` PATH'e eklendi). Flutter 3.38.7.
- [x] **Firebase bağlandı (Oturum 12):** Proje `alljob1` (proje no 839781526307). Auth (E-posta/Şifre) + Firestore (default db) etkin. `firebase login` OK. PowerShell ExecutionPolicy CurrentUser=RemoteSigned yapıldı (firebase.ps1 engeli için).
- [x] `flutterfire configure --project=alljob1 --platforms=android,web,ios` → `lib/firebase_options.dart` gerçek anahtarlar + `android/app/google-services.json` + `firebase.json`. iOS için GoogleService-Info.plist YOK (Windows, iOS build zaten yapılamaz).
- [x] `useFirebaseBackend = true` (`useFirebaseStorage = false` — Storage Blaze ister, sonra). `flutter pub get` + `analyze` temiz.
- [x] `firebase.json`'a firestore bölümü + `.firebaserc` (default=alljob1) eklendi → `firebase deploy --only firestore:rules,firestore:indexes` BAŞARILI (kurallar derlendi+yayınlandı, indexler yüklendi).
- [ ] **(Kullanıcı) DOĞRULAMA:** `flutter run -d chrome` → YENİ hesap kaydı (mock demo hesapları ARTIK YOK, Firestore boş — seed veri yok). İlk usta profili oluşunca aramada görünür.
- [ ] Blaze planı + kart → Storage'ı aç (`useFirebaseStorage = true`) → gerçek foto URL'leri.
- [ ] Cloud Functions: puan hesabı (reviews onCreate) + `ReviewRepository` soyutlaması (review yazımını Firestore'a taşı).
- [ ] Usta ana ekranı yorumlarını `reviews` sorgusundan oku (şu an mockDatabaseProvider).
- [ ] FCM bildirimleri (yeni mesaj/değerlendirme).
- [ ] Geo arama ölçekleme (`areaKeys[]` + array-contains + startAfter).

**Dikkat / Açık konular:**
- ~~Mock veri izolasyonu~~ **ÇÖZÜLDÜ:** Artık tek ortak `MockDatabase` (`lib/data/local/mock_database.dart`, `mockDatabaseProvider`) var; usta panelinden kaydedilen profil müşteri aramasında da görünüyor. Firebase gelince bu sınıf Firestore ile değişecek.
- **Firebase henüz bağlı DEĞİL.** Node + Firebase CLI kurulu değil. Firebase bağlanınca: `flutterfire configure` → `firebase_options.dart`, `main.dart`'ta `Firebase.initializeApp()`, mock repo'ları Firebase implementasyonlarıyla değiştir.
- `neighborhoods.json` şimdilik **tek test mahallesi** içeriyor (Dikkaldırım / Osmangazi / Bursa) — mahalleler PRD §3'e göre ileride Firestore'dan lazy loading ile çekilecek. `districts.json` örnek veri.
- Java 8 kurulu — Android APK build için JDK 17 gerekebilir (ileride kontrol et).

---

## 📜 Oturum Geçmişi (en yeni en üstte)

### 2026-08-06 — Oturum 81 (Karşılıklı değerlendirme çıkmazı + Obsidian mimari kasası — detay yukarıda "Son Durum")
Değerlendirme akışında 3 kırık nokta: (1) müşteri hiç yazmadan işi verirse seçilen usta sohbete yazamıyordu → `markCustomerStarted`; (2) "Değerlendir" şeridi `jobByChatIdProvider`'a bağlı olduğu için hiç çizilmiyordu → `thread.jobId` + `jobProvider`; (3) şerit `rated` durumunu tanımadığından ikinci taraf için kayboluyordu. Kural/CF deploy gerekmedi. + `vault/` mimari kasası (18 not) ve `CLAUDE.md`. 319/319 test, analyze 0.
**Sıradaki adım (kullanıcı):** cihazda uçtan uca karşılıklı değerlendirme testi.

### 2026-07-08 — Oturum 29 (Mesajlar IG dili + kompakt kartlar — detay yukarıda "Son Durum → Oturum 29")
Sohbet listesi: arama + kompakt satır + mavi okunmamış noktası. Sohbet: mesaj gruplama (avatar grup sonunda), 20px baloncuk, appbar/avatar → profil (müşteri için mini profil sheet). Usta kartı tek satır (grid 152→84), ilan kartı tek satır. analyze 0, 68/68.
**Sıradaki adım (kullanıcı):** hot restart → Mesajlar + Keşfet kartlarını dene; birikmiş oturumlar (27/28/28b/29) topluca commit bekliyor.

### 2026-07-08 — Oturum 28 (Yeni ilan → usta push bildirimi — detay yukarıda "Son Durum → Oturum 28")
CF `onJobCreated`: ilan verilince aynı il + aynı meslek ustalarının token'larına FCM push (ilan sahibi hariç, token temizlikli). push_service `job` tipini ilan detayına yönlendirir. Deploy EDİLDİ (DNS flush gerekti). analyze 0, 68/68.
**Sıradaki adım (kullanıcı):** Android'de uçtan uca push testi; Oturum 27 profil tasarımını beğenince hepsini birlikte commit et.

### 2026-07-08 — Oturum 27 (Tek birleşik profil sayfası — detay yukarıda "Son Durum → Oturum 27")
Kullanıcı "profil sayfaları çorba" dedi → müşteri profili + usta paneli SİLİNDİ, yerine tek `ProfileScreen` (/profile, iki modda da): hero + Müşteri|Usta mod anahtarı + gruplu menü satırları. /panel → /profile redirect (alt rotalar duruyor); splash/auth hedefi hep Keşfet; drawer mükerrerleri temizlendi; edit ekranından çıkış ikonu kalktı, Mavi Tik kartı forma sonuna indi. analyze 0, 68/68, web build OK.
**Sıradaki adım (kullanıcı):** hot restart → iki modda profil sekmesini, mod anahtarını ve tüm satır hedeflerini dene; tasarımı beğenmezsen ince ayar yapılır.

### 2026-07-08 — Oturum 26 (Profil yüklenemedi + oturum sızıntısı + SMS bölge — detay yukarıda "Son Durum → Oturum 26")
`MyProfileController.build` read→watch(uid'e select) — kalıcı "Profil yüklenemedi" + hesaplar arası taslak sızıntısı düzeldi. SMS bölge izin listesi BOŞTU → REST ile TR eklendi (telefon doğrulama sunucu tarafı çalışıyor; REST testi OK); `operation-not-allowed` bölge/sağlayıcı ayrımı + `regionBlocked` mesajı. analyze 0, 68/68 test.
**Sıradaki adım (kullanıcı):** hot restart → profil sayfası (çıkış/farklı hesap dahil) + telefon doğrulama (no `5550000000`, kod `123456`) uçtan uca dene.

### 2026-07-08 — Oturum 25 (Kırık test temizliği + hata mesajı cilası — detay yukarıda "Son Durum → Oturum 25")
7 eski kırık test düzeltildi (mockBackendOverrides ile Firebase repo'ları mock'a), artisan_login testi güncel yönlendirmeye göre yenilendi, PushService lazy yapıldı (test-güvenli). chat/favori hata mesajları profesyonelleştirildi. analyze 0, **68/68 test (kırık YOK)**, web build OK. Commit 28eea93 push edildi.
**Sıradaki adım (kullanıcı):** telefon doğrulama + push'u gerçek Android cihazda uçtan uca test. Kalan opsiyonel: web FCM VAPID, Google sağlayıcısı, gerçek cursor pagination / functions ESLint / CI.

### 2026-07-08 — Oturum 24 (Telefon doğrulama + mavi tik — detay yukarıda "Son Durum → Oturum 24")
Kullanıcı telefon doğrulamalı mavi tik istedi (opsiyonel, herkes). Firebase Phone Auth ile telefon hesaba bağlanır → jeton phone_number claim'i → kural isVerified/phoneVerified yazımını buna bağlar (güvenli tik, CF yok). PhoneVerificationRepository (mock kodu 123456) + sheet UI + ortak VerificationTile (müşteri profil + usta edit). AppUser.phoneVerified, setPhoneVerified (numara private alt-koleksiyona), markVerified. analyze 0, 61/61, web build OK.
**Sıradaki adım (kullanıcı):** `firebase deploy --only firestore:rules --project alljob1` + Console'da Phone sağlayıcısını aç + Android SHA parmak izlerini ekle (ben signingReport çalıştırabilirim) + test numarası ekle. (Bekleyen: Oturum 22 `firebase deploy --only functions`; Google sağlayıcısı.)

### 2026-07-08 — Oturum 23 (Git + Crashlytics + güvenlik — detay yukarıda "Son Durum → Oturum 23")
Kullanıcı profesyonel standartlar listeledi + "sen öner". Röntgen sonucu gerçek açıklar giderildi: git init + 2 commit (+.gitignore/.gitattributes), firebase_crashlytics (main.dart hata yakalama, web'de kapalı, Android gradle plugin), users telefon sızıntısı (toMap'ten çıkar + kural yasağı + private alt-koleksiyon). analyze 0, 57/57, web build OK.
**Sıradaki adım (kullanıcı):** `firebase deploy --only firestore:rules --project alljob1` (yeni users kuralı). Crashlytics'i gerçek cihazda doğrula. İstersen GitHub remote bağla. (Bekleyen: Oturum 22'nin `firebase deploy --only functions`; Google sağlayıcısı.)

### 2026-07-08 — Oturum 22 (FCM push bildirimleri — detay yukarıda "Son Durum → Oturum 22")
Kullanıcı: "FCM push ile devam edelim, eksik bir şey kalmasın." Uygulandı: CF `onMessageCreated` (yeni mesaj → alıcının `fcmTokens`'larına push + geçersiz token temizliği), Flutter `PushService` (izin/token kaydı-silme/ön plan SnackBar/tıklayınca sohbete gitme), `main.dart` arka plan işleyicisi, `app.dart` giriş→token / `auth_controller` çıkış→token silme, `web/firebase-messaging-sw.js`, `firebase_messaging` paketi. Kurallar değişmedi. analyze 0, 57/57, web build OK.
**Sıradaki adım (kullanıcı):** `firebase deploy --only functions --project alljob1` (yeni `onMessageCreated`) → gerçek Android cihazda iki hesapla test. Web push için VAPID anahtarını `kWebVapidKey`'e ekle. Google sağlayıcısını Console'da aç (hâlâ bekliyor).

### 2026-07-08 — Oturum 21 (Cloud Functions canlı — detay yukarıda "Son Durum → Oturum 21")
Blaze sonrası sunucu aggregation devreye alındı. `functions/index.js`: `onReviewCreated` (rating→profile) + `onOfferWritten` (offerCount yeniden hesap), Node 22 Gen 2 `europe-west1`. Deploy zorlu geçti (6 API elle/otomatik açıldı, Eventarc IAM yayılması beklendi) ama başarılı. İstemci temizliği fonksiyonlar canlı olunca gönderildi: rating 1000-review taraması kaldırıldı (profilden okunuyor), offerCount istemci increment'i kaldırıldı, `changedOnly(['offerCount'])` kuralı silindi + deploy. analyze 0, 57/57, web build OK.
**Sıradaki adım (kullanıcı):** `flutter run` ile dene (değerlendirme yap → ustanın puanı güncelleniyor mu; teklif ver/geri çek → "N usta ilgilendi" sayacı doğru mu). Google sağlayıcısını Console'da aç. Sonra istenirse FCM push.

### 2026-07-08 — Oturum 20 (Blaze + Storage canlı — detay yukarıda "Son Durum → Oturum 20")
Kullanıcı Blaze'i açtı + Storage bucket'ını kurdu (`gs://alljob1.firebasestorage.app`). `useFirebaseStorage=true` yapıldı, `storage.rules` yazıldı (public read / auth write + tür-boyut sınırı), firebase.json'a storage eklendi. `firebase deploy --only storage,firestore:rules,firestore:indexes` çalıştırıldı (ben) → hepsi başarılı; Oturum 16 kuralı + Oturum 19 index'leri de bununla yayınlandı. analyze 0.
**Sıradaki adım (kullanıcı):** `flutter run -d chrome` (veya cihaz) ile foto yüklemeyi uçtan uca dene (profil/iş/sohbet fotoğrafı → gerçek Storage URL'i). Google sağlayıcısını Console'da etkinleştir. Sonra istenirse FCM/Cloud Functions.

### 2026-07-08 — Oturum 19 (Maliyet/fatura optimizasyonu — detay yukarıda "Son Durum → Oturum 19")
Kullanıcı Firebase ücretlendirme optimizasyonunu sordu (pagination/cache/görsel). Blaze'siz yapılabilenlerin hepsi uygulandı: usta aramasında profil+rating önbelleği (3 dk TTL) → loadMore artık 0 okuma; iş feed'lerinde sunucu-tarafı orderBy+limit + yeni composite index'ler; `cached_network_image` ile görsel indirme cache'i; ortak sıkı görsel sıkıştırma (1080/q70). analyze 0, 57/57 test, web build OK.
**Sıradaki adım (kullanıcı):** `firebase deploy --only firestore:indexes,firestore:rules --project alljob1` (yeni index'ler + Oturum 16'dan bekleyen kural) → `flutter run -d chrome` ile dene. Bekleyen: Google sağlayıcısını Firebase Console'da etkinleştir.

### 2026-07-03 — Oturum 17c (Çapraz mod mesaj rozeti — detay yukarıda "Son Durum → Oturum 17c")
Kullanıcı istedi: "mesaj gelince iki modda da telefona bildirim + karşı moda mesaj gelirse ☰ üzerinde/mod geçiş düğmesinde kırmızı işaret." Rozet kısmı yapıldı (DrawerMenuButton kırmızı nokta + menüde sayılı rozet, unreadBySideProvider/otherModeUnreadProvider). FCM push Blaze planı gerektirdiği için ertelendi (yapılacaklar listesi yukarıda). analyze 0, 57/57, web build OK.

### 2026-07-03 — Oturum 17b (Ortak alt bar + hamburger menü — detay yukarıda "Son Durum → Oturum 17b")
Kullanıcı önerdi: "ortak olanlar (Keşfet/Mesajlar/Profil) alt barda kalsın, diğerleri sol üstte 3 çizgi menüye; usta da Keşfet'i görsün." Uygulandı: MainBottomBar (tek ortak bar), AppMenuDrawer (mod bazlı menü), ikincil ekranlar push sayfası. analyze 0, 56/56, web build OK.
**Sıradaki adım (kullanıcı):** `flutter run -d chrome` ile yeni gezinmeyi dene. Kullanıcının bahsettiği diğer "kurgusal hata" düzeltmeleri sırada.

### 2026-07-03 — Oturum 17 (Tek hesap, çift rol — detay yukarıda "Son Durum → Oturum 17")
Kullanıcı "tek hesap, çift rol" kurgusunu onayladı ("evet mantıklı, sonrasında bazı değişiklikler de yaparız — kurgusal hatalar var"). Uygulandı: AppUser'da hasArtisanProfile+activeMode, rolsüz kayıt, becomeArtisan/setActiveMode, rol seçim ekranı silindi, router mod bazlı, profil ekranlarında "Hizmet Vermeye Başla"/mod geçiş kartları, kendi-kendine etkileşim guard'ları. analyze 0, 56/56 test, web build OK. Kural değişikliği gerekmedi.
**Sıradaki adım (kullanıcı):** `flutter run -d chrome` ile dene: yeni kayıt → Profil → "Hizmet Vermeye Başla" → meslek+bölge kaydet → modlar arasında gidip gel. Kullanıcının bahsettiği "kurgusal hata" düzeltmeleri gelecek oturumda. Bekleyenler: Oturum 16 kural deploy'u + Google sağlayıcısını etkinleştirme.

### 2026-07-03 — Oturum 16 (Keşfette iş ilanları paneli — detay yukarıda "Son Durum → Oturum 16")
Kullanıcı: "ustaların hemen yanında başkalarının verdiği ilanları görelim." Yapıldı: `watchOpenJobs` + `openJobsProvider`, keşfette geniş ekranda yan panel / dar ekranda Ustalar-İlanlar geçişi, ortak `NearbyJobCard` (ctaText), ilan detayında üçüncü taraf müşteri guard'ı, jobs okuma kuralı herkese açıldı.
**Sıradaki adım (kullanıcı):** `firebase deploy --only firestore:rules --project alljob1` (misafirin ilan görmesi için) + `flutter run -d chrome` ile dene. Oturum 15'ten bekleyen: Google sağlayıcısını Firebase Console'da etkinleştir.

### 2026-07-02 — Oturum 15 (UX yenilemesi: 14 madde — detay yukarıda "Son Durum → Oturum 15")
Kullanıcı 14 maddelik liste verdi ("tam yetki"): metin arama + detaylı arama popup, rol bazlı görünürlük, Google girişi, mahalle kaldırma, il/ilçe Tümü + 970 ilçe, müşteri profil sayfası + alt bar, mesaj avatarı→profil, usta alt bar + bildirimler ekranı + panel sadeleştirme, feed en-yeni-üstte, mesaj/favori hata teşhisi (backend REST ile doğrulandı — sorun kural deploy'u öncesindenmiş).
**Sıradaki adım (kullanıcı):** 1) Firebase Console → Authentication → **Google sağlayıcısını etkinleştir**. 2) `flutter run -d chrome` ile akışları dene (özellikle: usta hesabıyla Mesajlarım + müşteri favoriler — bizim canlı testimizde backend sorunsuzdu). 3) İstersen Firestore konsolundan `chats/chat_PYW...__GUv...` teşhis dökümanını sil.

### 2026-07-02 — Oturum 14b (revizyon: teklif → "İletişime Geç" + kart düzeni + kural deploy)
Kullanıcı geri bildirimi sonrası iki değişiklik + deploy:
1. **Kural deploy (yapıldı):** `firebase deploy --only firestore:rules,firestore:indexes` çalıştırıldı. İlk denemede favori/teklif PERMISSION_DENIED verdi → **kural hatası bulundu:** `submitOffer`/favori toggle yazmadan önce `get()` yapıyor; döküman yoksa kuralda `resource == null` olup `resource.data...` reddediyordu. `offers` ve `favorites` read kurallarına `resource == null ||` guard eklendi ve **yeniden deploy edildi.** Artık çalışıyor.
2. **Teklif sistemi kaldırıldı → "İletişime Geç" (kullanıcı: "teklif olayı olmasın").** Karar: Orta seçenek — usta ilanı görüp doğrudan sohbet açar + müşteri ilanında "İlgilenen Ustalar" listelenir, müşteri birini seçip tamamlama/puanlama döngüsünü sürdürür (fiyat yok). Uygulama: `offers` altyapısı korundu ama "ilgi kaydı" olarak yeniden çerçevelendi. Usta `job_detail`'de fiyat/not formu yerine **"İletişime Geç"** (ilgi kaydı `submitOffer` + `startChat` → sohbete git) + "Geri Çek". Müşteri "Gelen Teklifler" → **"İlgilenen Ustalar"**: her kartta usta özeti (#5) + **Sohbet** + **Ustayı Seç** (fiyat gösterimi kaldırıldı). `Offer`'a `jobTitle` denormalize alanı eklendi (usta "İletişimlerim" listesi için). Metinler güncellendi (teklif→ilgilenen/iletişim): `OfferCountBadge` "N usta ilgilendi", dashboard "İletişimde", nearby kart "İletişime Geç", "Tekliflerim"→"İletişimlerim". `offerPriceLabel` kaldırıldı.
3. **Müşteri usta kartları büyütüldü** (grid maxCrossAxisExtent 200→260, mainAxisExtent 232→296) ve **favori kalp butonu** kompaktlaştırıldı (`FavoriteButton.compact`: küçük, beyaz yarı saydam daire, kart köşesine oturuyor — artık dışarı taşmıyor).
Doğrulama: analyze 0, 17/17 test (jobs+widget), web build OK.

### 2026-07-02 — Oturum 14 (Çift taraflı pazaryeri: İş İlanları + Teklifler)
Kullanıcı, uygulamayı statik usta rehberinden çift taraflı pazaryerine dönüştüren detaylı bir doküman + 14 madde karar verdi. Plan onaylandı (`.claude/plans/mutable-juggling-parrot.md`), 5 aşama sırayla uygulandı. Ayrıntı yukarıda "Son Durum → Oturum 14" bölümünde.
**Yapılanlar (özet):** jobs/offers/favorites modelleri + repo (mock+firebase) + provider'lar; Firestore rules/indexes; müşteri ilan oluştur/İlanlarım; usta Yakındaki İşler feed + teklif ver/güncelle/geri çek + dashboard istatistikleri; teklif seçimi→sohbet + yaşam döngüsü stepper + iki taraflı tamamlama + puanlama + iptal; favori kalp toggle. analyze 0, 45/45 test, web build OK.
**Sıradaki adım (kullanıcı):** `firebase deploy --only firestore:rules,firestore:indexes --project alljob1` çalıştır → `flutter run -d chrome` ile uçtan uca dene (müşteri ilan aç → usta feed → teklif → seç → sohbet → tamamla → puanla). Sonra istenirse: offerCount/rating için Cloud Functions, FCM bildirimleri, geo ölçekleme.

### 2026-07-02 — Oturum 13 (Profesyonel tasarım yenilemesi)
Kullanıcı "tasarım profesyonel görünmüyor, renkler/butonlar/kartlar kötü" dedi → kapsamlı tasarım sistemi yenilemesi yapıldı.

**Yapılanlar:**
- **Inter fontu** eklendi (assets/fonts/, 400–800 ağırlıklar; Google Fonts'tan indirildi, pubspec'e `fonts:` bölümü). Tüm tema `fontFamily: 'Inter'`.
- **Renk paleti baştan** (`app_colors.dart`): seed türetmesi yerine elle seçilmiş palet — primary #EA580C (olgun turuncu), secondary #15304B (lacivert), ink/inkMuted/inkFaint metin tonları, semantik renkler (+surface çiftleri), premium altın, `heroGradient` + `brandGradient` gradyanları.
- **Tema baştan yazıldı** (`app_theme.dart`): elle kurulmuş açık+koyu `ColorScheme`, Inter tipografi ölçeği (sıkı letter-spacing, güçlü başlık ağırlıkları), rafine bileşen temaları (AppBar alt çizgili beyaz, 12px input/buton radius, dolgu inputlar, kart 16px + ince kenar, chip/dialog/bottomsheet/snackbar/segmented/badge/tooltip). `AppTheme.softShadow` ortak gölge. `AppTheme.fontFamily` sabiti.
- **`BrandMark`** widget'ı (`core/widgets/brand_mark.dart`): turuncu gradyan yuvarlatılmış kare logo rozeti — splash/giriş/başlıklarda ortak.
- **Keşfet ekranı yeniden tasarlandı:** AppBar kaldırıldı; lacivert gradyan hero başlık (marka satırı + karşılama metni + eylemler) içinde gölgeli beyaz filtre kartı; sonuç alanında "Ustalar" başlığı + adet rozeti; boş/hata durumları ikon dairesiyle rafine.
- **Usta kartı rötuşları:** premium rozeti altın, "Yeni" rozeti mavi `auto_awesome`, kapalı durumu onSurfaceVariant. Grid `mainAxisExtent` 232'ye çıktı.
- **Splash:** tam ekran lacivert gradyan + BrandMark + beyaz metin/spinner.
- **Rol seçimi:** lacivert hero (BrandMark + başlık) + gölgeli rol kartları (renkli ikon kutuları).
- **Giriş/Kayıt:** ortalanmış (maxWidth 440) marka başlıklı düzen, form alanları gölgeli beyaz kart içinde, şeffaf AppBar (yalnız geri oku), kayıtta rol chip'i.

**Doğrulama:** `flutter analyze` 0 sorun. Firebase'ten bağımsız 33/33 test geçti (`widget/availability/artisan_search/contact_masker/chat_review`). `flutter build web` başarılı.

**Aynı oturum, 2. tur (kullanıcı geri bildirimi):**
- **Arka plan beyaz yapıldı** (`AppColors.background = Colors.white`).
- **Usta kartı tamamen yeniden yazıldı:** yumuşak gölgeli beyaz kart, canlı gradyan halkalı yuvarlak avatar (müsait=yeşil gradyan halka), fotoğraf yoksa turuncu marka gradyanı üzerinde baş harfler, amber zeminli puan rozeti (★ 4.8 (12)), renkli yüzeyli durum pill'leri. Usta profil ekranı başlık avatarı da aynı canlı halkalı stile geçirildi.
- **SOHBET İZİN HATASI DÜZELTİLDİ** ("the caller does not have permission..."): `watchThreads`'in `array-contains` + kuraldaki `in resource.data.participants` ispatı kural motorunda güvenilir değil → **üyelik haritası desenine geçildi**: chat dökümanına `members: {uid: true}` alanı eklendi; sorgu `where('members.<uid>', isEqualTo: true)` (eşitlik → otomatik index, `orderBy` kaldırıldı, sıralama istemcide); kurallar `members[request.auth.uid] == true || uid in participants` (`isMember`). Eski dökümanlar ilk `sendMessage`'da chatId'den türetilen members ile iyileştiriliyor; müşteri "Sohbet Başlat" dediğinde de `startChat` merge'i ekliyor. Sohbet listesi hata ekranı artık gerçek hata mesajını gösteriyor.
- **⚠️ KURAL DEPLOY EDİLMEDİ (izin gerekti):** kullanıcı çalıştırmalı → `firebase deploy --only firestore:rules --project alljob1`

**Aynı oturum, 3. tur (kullanıcı: "mesajlar hâlâ yok, değerlendirmeler yansımıyor, beyaz arka plan gelmedi"):**
- **Tema `ThemeMode.light`'a sabitlendi** (`app.dart`) — kullanıcının cihazı koyu moddaydı; `system` modu koyu temayı açıp "beyaz arka plan gelmedi" şikâyetine yol açıyordu.
- **Değerlendirmeler Firestore'a bağlandı:** yeni `ReviewRepository` (`lib/features/review/data/review_repository.dart`; Mock + Firebase impl, `reviewRepositoryProvider`, `artisanReviewsProvider`). `ReviewScreen` artık repo üzerinden yazıyor (async + spinner + hata mesajı; chatId `FirebaseChatRepository.chatIdFor`). Usta paneli değerlendirmeleri `artisanReviewsProvider`'dan okuyor (mockDatabase bağımlılığı kalktı); hero karttaki puan/adet değerlendirmelerden hesaplanıyor.
- **Puan toplamları CF gelene dek okumada hesaplanıyor:** `FirebaseArtisanRepository._ratingSums()` (tüm reviews tek sorgu → uid bazında sum/count) arama sonuçlarına; `getArtisanDetail` kendi reviews sorgusundan profile `copyWithRating` uyguluyor. Kurallar artisanProfiles puan alanlarını istemciden korumaya devam ediyor.
- **Giriş ekranı zenginleştirildi:** lacivert gradyan hero (BrandMark + "Tekrar hoş geldiniz"), gölgeli form kartı, "veya" ayracı + "Yeni Hesap Oluştur" outlined butonu.
- **Usta profil sayfası (müşteri görünümü) zenginleştirildi:** AppBar yerine tam genişlik lacivert hero (geri oku, canlı halkalı avatar, ad+doğrulama tiki, meslek, müsaitlik pill'i, beyaz Puan/Değerlendirme/Deneyim istatistik kartı); bölümler ikonlu başlıklı beyaz kartlara taşındı (`_Section`).
- Doğrulama: analyze 0 sorun, 33/33 Firebase'siz test, web build OK.
- **⚠️ Kural deploy'u yine izinle engellendi — kullanıcı çalıştırmalı.** Eski chat dökümanları deploy sonrası müşteri "Sohbet Başlat"a tekrar bastığında/yeni mesajda `members` alanı kazanıp listelerde görünür.

**Notlar / Engeller:**
- **ÖNCEDEN VAR OLAN test kırığı (tasarımla ilgisiz):** `artisan_login_test.dart` + `my_profile_test.dart` — Oturum 12'de `useFirebaseBackend = true` yapıldığından beri bu testler provider override kullanmadıkları için gerçek Firebase repo'larına gidip "[core/no-app] No Firebase App" hatası alıyor. Çözüm: testlerde repo provider'larını mock ile override etmek veya test ortamında bayrağı false'a çekmek.
- Firestore'daki chats composite index'i (participants CONTAINS + updatedAt DESC) artık kullanılmıyor; zararsız, ileride temizlenebilir.

### 2026-07-01 — Oturum 12 (Firebase CLI kurulumu + BAĞLANTI TAMAM)
Kullanıcı Node kurdu (v24.18.0 / npm 11.16.0) + Firebase konsolunda `alljob1` projesini oluşturmuş. Bu oturumda uygulama tamamen Firebase'e bağlandı ve canlıya alındı.

**Yapılanlar:**
- CLI: `npm i -g firebase-tools` → 15.22.4; `dart pub global activate flutterfire_cli` → 1.4.0; `%LOCALAPPDATA%\Pub\Cache\bin` PATH'e eklendi.
- Konsol (kullanıcı): Auth → E-posta/Şifre etkin; Firestore → default db oluşturuldu (production mode). Storage → Blaze/kart istedi, ATLANDI (sonra).
- `firebase login` (ntflx Google hesabı). PowerShell `firebase.ps1` "running scripts disabled" hatası → `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ile çözüldü.
- `flutterfire configure --project=alljob1 --platforms=android,web,ios --yes` → firebase_options.dart (web/android/ios gerçek anahtarlar, projectId alljob1) + google-services.json + firebase.json üretildi.
- `useFirebaseBackend = true` (useFirebaseStorage = false bırakıldı). pub get + analyze temiz.
- firebase.json'a firestore bölümü + .firebaserc yazıldı → `firebase deploy --only firestore:rules,firestore:indexes` başarılı.

**ÖNEMLİ — Firebase moduna geçişin sonuçları:** Firestore BOŞ (mock seed verisi yok, 12 meslekteki demo ustalar yok). Firebase Auth BOŞ (mock demo hesapları `musteri@test.com`/`usta@test.com` ARTIK ÇALIŞMAZ). Kullanıcı uygulamada YENİ hesap kaydı yapmalı; ilk usta profili kaydedilince aramada görünür.

**Sıradaki adım (kullanıcı):** `flutter run -d chrome` ile çalıştır → yeni hesap kaydet → akışı doğrula. Sonra Blaze + Storage; ardından kalan CF işleri (aşağıda).

### 2026-07-01 — Oturum 11 (AŞAMA 5 — Firebase kod hazırlığı)
Kullanıcı "evet geçelim" dedi. Makinede Node/Firebase CLI/flutterfire **kurulu değil** (yalnızca Dart). Kullanıcı "kod hazırlığını şimdi yap" seçti → tüm kod tarafı yazıldı, build mock'la yeşil.

**Yapılanlar:**
- **Tek anahtar:** `lib/core/config/backend_config.dart` → `useFirebaseBackend` (varsayılan `false`).
- **pubspec:** firebase_core/auth, cloud_firestore, firebase_storage eklendi (`pub get` başarılı: core 3.15.2, auth 5.7.0, firestore 5.6.12, storage 12.4.10).
- **Firebase implementasyonları** (arayüzlerin arkasında): `firebase_auth_repository`, `firebase_storage_repository`, `firebase_my_profile_repository`, `firebase_artisan_repository`, `firebase_chat_repository`.
- **Provider'lar** bayrağa göre mock/Firebase seçiyor (auth/storage/myProfile/artisan/chat).
- **main.dart** bayrak açıkken `Firebase.initializeApp(DefaultFirebaseOptions.currentPlatform)`.
- **firebase_options.dart** placeholder (flutterfire üretince üzerine yazılır; kullanılırsa anlaşılır hata).
- **firestore.rules** (katılımcı bazlı sohbet, profil sahipliği, puanlama alanı koruması) + **firestore.indexes.json** (reviews, chats).
- **FIREBASE_KURULUM.md**: adım adım CLI kurulumu + veri modeli + kalan CF işleri.
- `flutter analyze`: **0 sorun**. `flutter test`: **40/40**.

**Sıradaki adım (kullanıcı aksiyonu):** Node + firebase-tools + flutterfire kur → Firebase projesi + `flutterfire configure` → `useFirebaseBackend = true`. Detay: FIREBASE_KURULUM.md.

**Kalan CF/refactor işleri (FIREBASE_KURULUM.md §"kalan işler"):** puan hesabı (reviews onCreate CF) + `ReviewRepository` (review_screen şu an mockDatabaseProvider'a yazıyor); usta ana ekranı yorumları (mockDatabaseProvider'dan okuyor); okunmamış kesin sayı (CF); geo arama ölçekleme; FCM bildirimleri.

### 2026-07-01 — Oturum 10 (Firebase öncesi rötuşlar — sırayla)
Kullanıcı "sırayla yapalım" dedi; Firebase öncesi mock rötuş listesi sırayla yapılıyor.

**#1 — Sohbet UX rötuşları (TAMAM):**
- Okunma takibi repo'ya eklendi: `ChatRepository.markRead / unreadCount / lastReadAt`; `MockChatRepository._lastRead` (chatId→uid→zaman). `markRead` hem thread hem mesaj akışını yeniden yayıyor.
- **Okunmamış rozeti:** sohbet listesinde adet rozeti + kalın satır; AppBar "Mesajlar" ikonunda `Badge` (`ChatIconButton`, usta + müşteri ortak). `totalUnreadProvider`.
- **Okundu bilgisi:** gönderenin baloncuğunda tek tik (gönderildi) / çift mavi tik (okundu) — `ChatThread.otherUid` + `lastReadAt`.
- **Tarih ayraçları:** mesaj akışında Bugün/Dün/tarih çipleri (`_DateChip`, `_sameDay`).

**#2 — Premium'un aramaya etkisi (TAMAM):**
- `AppConstants.firstYearFreePremium` bayrağı eklendi (varsayılan `true` = ilk yıl herkes görünür, demo bozulmaz).
- `MockArtisanRepository.searchArtisans`: bayrak `false` olunca (1. yıldan sonra, PRD §3) aramada **yalnızca müsait + aktif Premium** ustalar gösteriliyor.

**#3 — Sertifika yönetimi (TAMAM):**
- Controller'a `addCertificate/removeCertificate`. Usta düzenleme panelinde "Sertifikalar ve Belgeler" bölümü (görsel yükle/sil; `_pickImage` genelleştirildi, `_pickPhoto` kaldırıldı).
- Müşteri profilinde sertifikalar gerçek küçük resim olarak (yatay liste); dokununca tam ekran `InteractiveViewer` diyalogu (`_showCertificate`).

**Doğrulama:** `flutter analyze`: **0 sorun**. `flutter test`: **40/40 geçti** (sertifika + premium + okunmamış testleri dahil).

### 2026-07-01 — Oturum 9 (Aşama 4 doğrulama + değerlendirme kuralı + Premium yönetimi)
**Yapılanlar:**
- Önceki oturumda yazılan **Aşama 4 (Mesajlaşma)** kodu gözden geçirildi ve doğrulandı: sohbet modeli/repo, sohbet listesi + mesajlaşma ekranları, iletişim maskeleme, "Sohbet Başlat" bağlantısı, `/chats` erişim ikonları, etiket tabanlı değerlendirme ekranı — hepsi bağlı ve çalışıyor.
- **Değerlendirme kuralı zorlandı (PRD §5, Ekran F):** `ChatRepository.hasChatBetween(customerUid, artisanUid)` eklendi; `ReviewScreen` sohbet geçmişi yoksa "Önce sohbet gerekiyor" ekranı gösteriyor (değerlendirme engelli).
- **Premium yönetimi eklendi (PRD §6):** `MyProfileController.setPremium(bool)` (ilk yıl ücretsiz, 1 yıl geçerlilik) + usta ana ekranında `_PremiumCard` (durum + "Premium'a Geç (Ücretsiz)" / "Premium'u Kapat", geçerlilik tarihi).
- Eski metin düzeltmesi: usta ana ekranı bildirim uyarısı "Aşama 4'te gelecek" → "yakında (FCM) gelecek".
- `flutter analyze`: **0 sorun**. `flutter test`: **37/37 geçti** (yeni `hasChatBetween` testi dahil).

**Sıradaki adım:** Aşama 5 — Firebase entegrasyonu (Auth/Firestore/Storage/FCM). Firebase öncesi mock işleri büyük ölçüde bitti.

**Notlar / Engeller:**
- Firebase hâlâ bağlı değil; Node + Firebase CLI kurulumu gerekiyor (kullanıcı en sona bırakmak istedi).
- `ArtisanProfile.copyWith` nullable `premiumExpiresAt`'i null'a çekemiyor (?? davranışı); Premium kapatınca `isPremium=false` yetkili olduğundan sorun değil.

### 2026-07-01 — Oturum 8 (usta girişi düzeltmesi)
**Bulunan/düzeltilen hatalar (usta girişi widget testiyle yakalandı, `test/artisan_login_test.dart`):**
1. **Yönlendirme:** Misafir keşif ekranındayken usta giriş yapınca panele GİTMİYORDU (redirect `/` için ustaya `null` dönüyordu). Kural değişti: **usta yalnızca `/panel` altında olabilir; başka yerdeyse panele yönlenir** → giriş nereden olursa olsun panele gider.
2. **Layout:** Tema'daki `FilledButton.minimumSize: Size.fromHeight(52)` genişliği SONSUZ yapıyordu; `Row` içindeki satır-içi buton (usta ana ekranı "Tamamla") taşma/hata veriyordu. Tema `Size(64,52)` yapıldı; `AppButton` tam genişliği kendi içinde (`SizedBox(width: infinity)`) garantiliyor.
- `flutter analyze`: 0 sorun. `flutter test`: **27/27** (yeni usta-giriş widget testi dahil).

### 2026-07-01 — Oturum 7 (UX kurgu: misafir-önce + ortak DB + usta ana ekranı + tema)
**Yapılanlar:**
- **Ortak veritabanı:** `lib/data/local/mock_database.dart` (`MockDatabase` + `mockDatabaseProvider`). `MockArtisanRepository` ve `MockMyProfileRepository` artık AYNI veriyi kullanıyor → **kaydedilen usta profili aramada görünüyor** (regresyon testi eklendi). `saveMyProfile` artık uid/displayName/foto/profile alıyor.
- **Misafir-önce akış (sahibinden gibi):** Açılışta direkt usta listesi (`initState`'te otomatik arama). Rotalar yeniden düzenlendi: `/`=keşif (herkese açık), `/artisan/:uid`=herkese açık profil, `/panel`(+`/edit`)=usta. Misafir iletişime geçmek isteyince ("Sohbet için giriş yap") `/login`'e yönlenir. Dashboard app bar: misafirde "Giriş Yap", müşteride çıkış.
- **Usta ana ekranı** (`artisan_home_screen.dart`): sol üstte yuvarlak avatar→Profili Düzenle, sağ üstte bildirim+mesaj, ortada ad; gövdede hero kart, müsaitlik kartı, işler galerisi, hakkımda, hizmet bölgeleri, değerlendirmeler. Düzenleme ayrı sayfa (`/panel/edit`).
- **Tema yenilendi:** ferah zemin (#F7F8FA), beyaz kartlar (ince kenarlı), canlı turuncu filled butonlar (radius 14), belirgin input kenarları.
- `flutter analyze`: 0 sorun. `flutter test`: **26/26**. `flutter build web`: başarılı.
**Sıradaki adım:** Aşama 4 — Mesajlaşma + maskeleme + etiket tabanlı değerlendirme ekranı.

### 2026-07-01 — Oturum 6 (usta bulmuyor fix + modern responsive tasarım)
**Yapılanlar:**
- **"Usta bulmuyor" düzeltildi:** Mock veride yalnızca 3 meslek vardı. Artık 12 mesleğin tümüne + birden fazla ile (Bursa/İstanbul/Ankara/İzmir) yayılmış zengin demo verisi üretiliyor; her meslek/bölge seçiminde sonuç geliyor. `_professionNames` 12 mesleğe genişletildi. Regresyon testi eklendi ("her meslek en az bir usta").
- **Responsive altyapı:** `core/widgets/responsive_center.dart` (`ResponsiveCenter` + `Breakpoints`). Geniş ekranda içerik ortalanır ve maks. genişlikle sınırlanır.
- **Dashboard yeniden tasarlandı:** filtreler geniş ekranda 2 sütun; sonuçlar responsive **kart ızgarası** (1/2/3 sütun, `SliverGrid`). "Usta Bul" her zaman aktif.
- **Usta kartı** modern/kompakt yeniden yazıldı (avatar + bilgi + müsaitlik pill'i + rozetler), grid'de taşmayacak sabit yükseklikle.
- Usta profil ekranı ve usta paneli de `ResponsiveCenter` ile sınırlandı.
- `flutter analyze`: 0 sorun. `flutter test`: **25/25 geçti**.
**Sıradaki adım:** Aşama 4 — Mesajlaşma + maskeleme + etiket tabanlı değerlendirme ekranı.

### 2026-07-01 — Oturum 5 (PRD v4.0 tam/son uyumu)
**Yapılanlar:** Proje PRD v4.0'a (son/tam sürüm) göre güncellendi.
- 1. geçiş: `PRD.md` eklendi; kredi kaldırıldı (gelir yalnızca Premium); canlı müsaitlik + çalışma takvimi modeli (`availability.dart`) + usta paneli düzenleyici; arama müsait-önce; "Yeni Usta" rozeti (15 gün); değerlendirme → hazır etiketler.
- 2. geçiş (kullanıcı tam metni verince): `PRD.md` tam metinle yeniden yazıldı; **opsiyonel/bağımsız filtreler** (`ArtisanFilter`, searchArtisans yeni imza, "Usta Bul" her zaman aktif); değerlendirme etiketleri kesin listelerle; çalışma takvimi Firestore serileştirme şekli (gün-adlı + HH:mm).
- `neighborhoods.json` tek test mahallesine (Dikkaldırım) indirildi.
- 25/25 test geçti, analyze temiz.
**Sıradaki adım:** Aşama 4 — Mesajlaşma (kredisiz) + iletişim maskeleme + etiket tabanlı değerlendirme ekranı.

### 2026-07-01 — Oturum 4 (Aşama 3)
**Yapılanlar:** Usta tarafı tamamlandı — storage soyutlaması + AppImage, MyProfile repo/controller, usta profil düzenleme paneli (profil bilgileri + çoklu hizmet bölgesi + fotoğraf yükleme). Router'daki splash takılma hatası düzeltildi. 15/15 test geçti.
**Sıradaki adım:** Aşama 4 — Mesajlaşma (sohbet listesi + real-time mesajlaşma + kredi entegrasyonu).

### 2026-07-01 — Oturum 3 (Aşama 2)
**Yapılanlar:** Müşteri tarafı tamamlandı — usta repo soyutlaması + mock, kademeli filtre, listeleme (premium sıralama + pagination), salt-okunur usta profil sayfası. 11/11 test geçti.
**Sıradaki adım:** Aşama 3 — Usta profil düzenleme paneli (çoklu hizmet bölgesi, fotoğraf yükleme).

### 2026-07-01 — Oturum 2 (Aşama 1)
**Yapılanlar:**
- Tüm Aşama 1 altyapısı kuruldu (yukarıdaki Son Durum listesi). ~25 dosya.
- Uçtan uca auth akışı + temiz mimari + testler.

**Sıradaki adım:** Aşama 2 — Müşteri tarafı (filtreleme + listeleme + profil).

### 2026-07-01 — Oturum 1
- İlerleme notları defteri (`ILERLEME_NOTLARI.md`) oluşturuldu.

---

## 🧩 Şablon (yeni oturum eklerken kopyala)

```
### YYYY-MM-DD — Oturum N
**Yapılanlar:**
- ...

**Sıradaki adım:**
- ...

**Notlar / Engeller:**
- ...
```

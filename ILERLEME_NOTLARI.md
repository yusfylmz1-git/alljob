# 📓 İlerleme Notları (Proje Defteri)

> Bu dosya, geliştirme sırasında **kaldığımız yeri** kaydetmek içindir.
> Tokenlar bittiğinde veya yeni bir oturuma başladığımızda, buradan kaldığımız
> yerden devam edebiliriz. Her oturum sonunda "Son Durum" bölümünü güncelle.

---

## 🎯 Proje Hakkında
- **Proje adı:** Usta Cepte (`usta_cepte`) — hizmet pazaryeri uygulaması
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

**Tarih:** 2026-07-09

**Tamamlanan: AŞAMA 1–5 + PRD v4.0 + FIREBASE CANLI + ÇİFT TARAFLI PAZARYERI + OTURUM 15 (UX) + OTURUM 16 (Keşfette ilan paneli) + OTURUM 17 (TEK HESAP, ÇİFT ROL) + OTURUM 18 (TASARIM v2) + OTURUM 19 (MALİYET/FATURA OPTİMİZASYONU) + OTURUM 20 (BLAZE + STORAGE CANLI) + OTURUM 21 (CLOUD FUNCTIONS CANLI) + OTURUM 22 (FCM PUSH) + OTURUM 23 (GIT + CRASHLYTICS + GÜVENLİK) + OTURUM 24 (TELEFON DOĞRULAMA + MAVİ TİK) + OTURUM 25 (KIRIK TEST TEMİZLİĞİ — 68/68) + OTURUM 26 (PROFİL YÜKLENEMEDİ + OTURUM SIZINTISI + SMS BÖLGE DÜZELTMESİ) + OTURUM 27 (TEK BİRLEŞİK PROFİL SAYFASI) + OTURUM 28 (YENİ İLAN → USTA PUSH BİLDİRİMİ, CANLI) + OTURUM 29 (MESAJLAR IG DİLİ + KOMPAKT KARTLAR)**

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

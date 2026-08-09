# Cihaz testi bulguları — yapılacaklar

Durum: 2026-08-09. Regresyon testleri: `test/test_bulgulari_2026_08_09_test.dart`,
`test/premium_musaitlik_kapisi_test.dart`, `test/hesap_silme_kapsami_test.dart`.

---

## ✅ Tamamlandı

**1. Onboarding'e Kolay İş tanıtımı** — *(bekliyor, aşağıda)*

**2. Müşteri kendi ilanlarını görebilmeli/yönetebilmeli.**
Yan menüdeki "İlanlarım" `if (user.isArtisan)` koşuluna bağlıydı — ilanı VEREN
müşteri kendi ilanlarına hiçbir yerden ulaşamıyordu. Koşul kaldırıldı, satır
her iki modda görünüyor. Profildeki "Profilime bak" düğmesi de "İlanlarım"
oldu (kendi profilindeyken profili tekrar açan düğmenin karşılığı yoktu).
→ `app_menu_drawer.dart`, `profile_screen.dart`

**3. Detaylı aramada Temizle filtreyi hemen uygulamıyordu.**
`clearSelections()` yalnız filtre state'ini sıfırlıyor, aramayı tetiklemiyordu;
liste "Usta Bul"a basılana kadar eski sonuçları gösteriyordu. Temizle artık
`search()` de çağırıyor. → `detailed_search_sheet.dart`

**4. Menü açıkken geri tuşu uygulamayı küçültüyordu.**
`MainTabScope` Ana Sayfa'da `canPop: true` veriyordu, yani geri tuşu doğrudan
sisteme gidiyordu — açık çekmece hiç kontrol edilmiyordu. Artık çekmeceli
ekranlarda pop elle ele alınıyor; sıra: **açık menü → seçim modu → yığın →
Ana Sayfa**. Ana Sayfa'ya da `MainTabScope` eklendi (hiç yoktu).
→ `role_bottom_bar.dart` + 6 ekran

**5. İl/ilçe seçiminde klavye kendiliğinden açılıyordu.**
Sheet'in arama kutusunda `autofocus: true` vardı; klavye fırlayıp listenin
yarısını kapatıyordu. Kapatıldı — klavye ancak kutuya dokununca açılır.
→ `searchable_select_field.dart`

**6. Profil düzenlemede kayıt sonrası yönlendirme.**
Kaydettikten sonra formda kalınıyordu ("kaydoldu mu?"). Başarılıysa artık
profile dönülüyor. → `artisan_profile_edit_screen.dart`

**7. Ücretsiz dönem bitince müsaitlik kapanmıyordu.**
Kök neden: `isAvailable` bir Firestore alanı değil, hesaplanan bir getter —
premium durumuna hiç bakmıyordu. **Asıl çözüm kapı mantığı:**
`isAvailableAt` artık premium erişimi yoksa `false` döner. Hiçbir veri
yazılmaz; "Premium beta ücretsiz" anahtarı kapandığı an premium olmayan
ustalar müsait olmaktan çıkar, anahtar geri açılırsa herkes eski hâline
kendiliğinden döner.
**Ek olarak** admin paneline "Toplu Plan" ekranı eklendi (yalnız superadmin):
kampanya bitişi gibi veriyi gerçekten değiştirmek gerektiğinde kullanılır.
Geri alınamaz olduğu için önce zorunlu kuru çalışma (önizleme), sonra ikinci
onay ister; ödemeli aktif aboneleri varsayılan olarak atlar.
→ `artisan_profile.dart`, `adminBulkPlanUpdate` (CF), `admin_bulk_plan_screen.dart`

> ⚠️ Müsaitlik kapısı **yalnız istemcide** çalışır — listeleme/sıralama
> içindir, güvenlik sınırı değildir. Bkz. [[Bilinen-Tuzaklar]].

**8. "İş İlanı Ver" üç ayrı yerdeydi.**
Arama satırının altındaki düğme (Filtreleri temizle'nin dibinde) ve yan
menüdeki satır kaldırıldı; Keşfet'in üst barına tek giriş ikonu eklendi.
Her iki modda görünür — ilan vermek için usta olmak gerekmiyor.
→ `customer_dashboard_screen.dart`, `app_menu_drawer.dart`

**10. Hesap sil tüm verileri silmeli.**
Envanter çıkarıldı: CF sanılandan kapsamlıydı (ilanlar, favoriler, eleman
modülü, ürünler, `users/**` recursive, profil, 6 storage klasörü, Auth).
Uid taşıyan **dört** koleksiyon hiç ele alınmamıştı. Ölçüt iki yönlü —
kişisel veriyi sil, kötüye kullanım kaydını koru:
- `membershipPurchases` → **SİL** (Play token kişisel veri, hesapsız işlevsiz)
- `supportTickets` → uid/email düşer, gövde kalır (iki taraflı yazışma)
- `reports` → **KALIR**; yalnız `reporterUid` düşer. Silinirse "şikayet
  edilince hesabı sil, temize çık" açığı doğar. `reportedUid` kaydın
  kendisidir, dokunulmaz.
- `adminUserNotes` / `premiumOverrides` → denetim izi, dokunulmaz.
Şikayet doküman kimliği `{tip}_{hedef}__{reporterUid}` uid içerir; kuralın
tekillik garantisi buna dayandığı için doküman **taşınmadı**, alan boşaltıldı.
Admin ekranı boş uid yerine "Hesap silindi" gösteriyor.
Mesaj balonları `senderName` denormalize etmiyor (addan sohbet dokümanına
bakılıyor) → sohbet anonimleşince balonlar da anonimleşiyor, ek iş yok.
→ `functions/index.js`, `admin_reports_screen.dart`,
`test/hesap_silme_kapsami_test.dart`, [[Cloud-Functions-Haritasi]]

**9a. Sosyal medya "kaydetmiyor".**
Kök neden yazmada değil **geri okumada**: ortak alanlar 2026-08-08'de
`users`'a taşındı, `artisanProfiles`'taki kopya donduruldu (okunuyor ama
yazılmıyor). Okuma tarafı `users` boşsa donmuş kopyaya düşüyordu — kullanıcı
bağlantıyı **silince** `users` boşalıyor, koşul eski değeri geri getiriyordu.
Aynısı telefon ve hakkımda alanlarında da vardı.
Çözüm: "alan YOK" ile "alan var ama BOŞ" ayrımı. `AppUser.ortakAlanlarGocmus`
alanların **varlığından** türer; göç etmiş kayıtta `users` ne diyorsa odur,
göç etmemiş kayıt eskisi gibi geri düşmeye devam eder.
→ `app_user.dart`, `my_profile_controller.dart`, `mock_auth_repository.dart`,
`test/sosyal_medya_silme_test.dart`, [[Bilinen-Tuzaklar]]

**11. Usta modu kaydetmeden geri basınca açık kalıyordu.**
`becomeArtisan()` modu açıp profil düzenlemeye yönlendiriyor, kullanıcı
meslek/bölge seçmeden geri basınca mod açık kalıyordu (aramada boş usta).
Artık kurulum hiç yapılmamışsa (meslek YOK **ve** bölge YOK) çıkışta mod
müşteriye geri alınır ve sebebi bildirilir. Mevcut bir ustanın profilini
düzenlerken geri basması modunu kapatmaz.
→ `artisan_profile_edit_screen.dart`

---

## ⏳ Kalanlar

**1. Onboarding ekranına Kolay İş çalışma tanıtımı.**
Yeni içerik + tasarım kararı gerektiriyor. `onboarding_screen.dart` (269 st)
hazır bir slayt yapısına sahip; eklenecek slaytların metni/görseli belirlenmeli.

**9b. Telefon doğrulamada `unknown` hatası.**
Kod tarafında görünür hata yok. `unknown` büyük olasılıkla Firebase
yapılandırması: SHA-1/SHA-256 parmak izi, reCAPTCHA/App Check, test numarası.
Cihazdan **konsol logu** gerekiyor — hatanın tam metni olmadan tahmin
yürütmek maliyetli.



  Yeni Test Aşamaları(Yapılacaklar)

  ✅ 1- İlan veren kişinin profil resmi ilan başında gözüksün ve tıklanınca profiline gidebilsin. Aynı şekilde mesajlarda da bu özellik var.
     → İlan kartı artık kategori emojisi yerine **ilanı verenin avatarıyla**
       başlıyor (emoji köşeye rozet olarak indi, bilgi kaybolmadı); avatara
       dokunmak `userProfile` rotasına gidiyor. Sohbet listesindeki avatar da
       tıklanabilir oldu — seçim modunda devre dışı (orada dokunma = seçim).
       Sohbet ekranı başlığı zaten profile gidiyordu, dokunulmadı.
     → `job_widgets.dart`, `chat_list_screen.dart`

  ✅ 2- Mesaj geldiğinde altbarda mesajlar düğmesinin üzerinde 1 rakamı belirmeli anlık olarak gelmiyor. Okunmamış mesaj adedi yazılmalı.
     → Rozet zaten canlı bağlıydı (`totalUnreadProvider`), CF de her mesajda
       sayacı artırıyordu. Kusur **düşürme** tarafındaydı: `markRead`
       `_lastMsgMeta` önbelleğine bakıyordu, ama o önbelleği YALNIZ sohbet
       listesi (`watchThreads`) doldurur. Bildirimden doğrudan sohbete
       girildiğinde önbellek boş → `was == 0` → düşürme hiç çalışmıyor →
       rozet takılı kalıyordu. Artık önbellek soğuksa sohbet dökümanından
       okunuyor.
     → **Karar (kullanıcı):** rozet **sohbet adedi** sayar, mesaj adedi değil
       (WhatsApp/Instagram davranışı). Mock bunu ihlal ediyordu (mesaj
       topluyordu) — parite düzeltildi.
     → `firebase_chat_repository.dart`, `chat_repository.dart` (mock)

  ✅ 3- Keşfette bulunan yukardaki + işaretinin yanına Yeni İlan yazmamız gerekir.
     → Etiket tooltip'ti; dokunmatikte tooltip görünmediği için ikonun ne
       yaptığı belirsizdi. Yazılı "Yeni İlan" etiketine çevrildi.
     → `customer_dashboard_screen.dart`

  Regresyon: `test/test_bulgulari_2026_08_10_test.dart`

  ✅ 4/6- Profilden sohbet et - ilandan sohbet et 2 ayrı mesaj kutusu açıyor.
     → Kök neden: kimlik `chat_{müşteri}__{usta}` idi, yani **role** bağlıydı.
       Rol ise giriş noktasına göre değişiyor: ilan detayında "ilanı veren =
       müşteri", profil ekranlarında "ben = müşteri". Aynı çift farklı
       kapılardan yazınca `chat_A__B` ve `chat_B__A` doğuyordu.
     → **Karar (kullanıcı):** "ne olursa olsun karşıdaki aynı kişiyle tek
       sohbet kutusu". Kimlik artık uid'leri **alfabetik sıralıyor** → çift
       başına kimlik matematiksel olarak tek. Rol bilgisi doküman alanı
       olarak duruyor; kimlikten rol türetme kaldırıldı.
     → Roller İLK açılışta donuyor: aynı kutuya ters yönden girilince
       `startChat` kimlik alanlarını yeniden yazmıyor (önbellek + sunucu).
     → Eski kimlikli sohbetler yerinde kalır ve listede görünür (üyelikle
       sorgulanıyor, kimlik ayrıştırılmıyor). Veri göçü YAPILMADI.
     → ⚠️ KURAL da değişti: `firestore.rules` yalnız `chat_{müşteri}__{usta}`
       sırasını kabul ediyordu. Sıralı kimlikle, ustanın uid'i önce gelen
       HER çiftte sohbet oluşturma permission-denied alacaktı — sohbetlerin
       yaklaşık YARISI açılamazdı. Kural iki sırayı da kabul ediyor; spam
       koruması duruyor (kimlik hâlâ iki tarafın uid'ine çakılı).
     → `firebase_chat_repository.dart`, `chat_repository.dart` (mock),
       `firestore.rules`, [[Sohbet-Mimarisi]] — ✅ DEPLOY EDİLDİ (2026-08-09).

  ✅ 5- Normal ilanda ilçe şartı olmasın.
     → `matchesArtisan` klasik ilanlarda il + ilçe istiyordu; artık İL
       düzeyinde eşleşiyor (Kolay İş zaten öyleydi). İlçe ELEMEZ, yalnız
       "Yakınında" rozeti + sıralama sinyali olarak kalır.
     → Not: sunucu (`onJobCreated` bildirim fan-out'u) ZATEN yalnız ile
       bakıyordu — istemci sunucuyla aynı hizaya geldi, sapma kapandı.
     → İl sınırı ve meslek şartı duruyor. → `job.dart`

  ✅ 7- Bildirim ekranı sadeleşsin + temizleme.
     → Üstteki sabit admin duyurusu ve alttaki "Sizi Takip Edenler" listesi
       kaldırıldı (ikisi de bildirim değildi; takipçiler usta profilinde
       zaten görünüyor). İki ölü widget da silindi.
     → "Temizle" eklendi: geri alınamaz olduğu için onay ister.
     → Kural değişti: `allow delete: if isSelf(uid)` — `create` KAPALI
       kaldığı için sahte bildirim enjeksiyonu açılmıyor. Bildirim türetilmiş
       veridir; kaynak sohbet/ilan kaydı yerinde durur.
     → `notifications_screen.dart`, `notification_repository.dart` (+mock),
       `firestore.rules` — ✅ kural DEPLOY EDİLDİ (2026-08-09).
       (Deploy öncesi "Bildirimler temizlenemedi" hatası veriyordu: canlı
       kural hâlâ `delete: if false` diyordu, istemci permission-denied
       alıyordu. Kural değişikliği canlıya çıkmadan bu özellik çalışmaz.)

  ✅ 8- Müsait değilken usta ilanları görsün + bildirim alsın, mesaj atamasın.
     → Müsaitlik kapısı İKİ yerde listeyi tamamen kapatıyordu (Keşfet
       İlanlar sekmesi + Yakındaki İşler ekranı) ve feed provider'ı da
       boşaltıyordu. Üçü de kaldırıldı; uyarı artık listenin üstünde şerit.
     → Bildirim tarafında değişiklik GEREKMEDİ: CF zaten müsaitliğe bakmıyor.
     → MESAJ kapısı yerinde (`_ArtisanOfferSection`) — asıl kısıt bu.
       Aramada görünmeme kuralı da değişmedi.
     → `job_providers.dart`, `nearby_jobs_screen.dart`,
       `customer_dashboard_screen.dart`

  ✅ 8b- Kapı ATLANABİLİYORDU (kullanıcı bulgusu, 2026-08-10).
     → Liste açılınca ilan kartındaki avatar profile götürüyor; profildeki
       "Sohbet et" düğmesinde müsaitlik kontrolü YOKTU. Yani ilandan mesaj
       atamayan usta, aynı kişinin profiline girip oradan yazabiliyordu.
       Toplam DÖRT giriş varmış, yalnız BİRİ (ilan detayı) kapılıydı.
     → **Profili gizlemek çözüm değil:** deliği kapatmaz (arama, favoriler,
       mevcut sohbet aynı kişiye götürür) ve "ilanı kim verdi" bilgisini
       gereksizce saklar. Kapı gezinmede değil, EYLEMDE olmalı.
     → Ortak kapı: `artisan/application/availability_gate.dart`
       (`artisanAvailabilityAllowsNewChat`). Üç profil yolu buna bağlandı;
       ilan detayı kendi kontrolünü koruyor.
     → Kapsam dar: yalnız USTA modunu ve yalnız YENİ sohbeti bağlar. Müşteri
       muaf; mevcut sohbetler Mesajlar'dan sürer (`canSend` yalnız kilide
       bakar). Profil yüklenmemişse engellemez — kapı kolaylıktır, güvenlik
       sınırı değildir.
     → Regresyon testi `startChat` çağrı SAYISINI sayar: yeni bir giriş
       eklenip kapısı unutulursa test kırılır.
     → `availability_gate.dart`, `artisan_profile_screen.dart`,
       `public_user_screen.dart`, [[Mevcut-Akislar]]

  ✅ 13- Hesap sil çalışmıyordu → **ASIL SEBEP: App Check** (kod değil).
     → ÇÖZÜLDÜ (2026-08-09 17:29). Log: `{"auth":"VALID","app":"VALID"}` →
       `deleteAccount başladı` → `tamamlandı` (4.3 sn, uyarı YOK).
       Debug token Console'a eklendikten sonra çalıştı.
       Not: Console'da App Check kapalı görünüyordu — yanlış Google hesabıyla
       girilmişti; kurulum baştan beri doğruymuş.
     → CF logu (2026-08-09 16:48–16:52, dört deneme):
       `Failed to validate AppCheck token ... Decoding App Check token failed`
       `{"verifications":{"auth":"VALID","app":"INVALID"}}`
       Yani oturum SAĞLAM, **cihaz tanınmıyor**. İstek koda hiç ULAŞMADI.
     → `deleteAccount` `enforceAppCheck: true` taşır. Firestore/Storage
       monitor modunda olduğu için veri okuma çalışmaya devam eder — sorun
       yalnız bu callable'da görünür. İstemci `internal` görüp "Güvenlik
       doğrulaması geçilemedi" der; kod hatası SANILMASIN.
     → **Yapılacak (sende):** logcat'ten `DebugAppCheckProvider` token'ını al
       → Console → App Check → `com.sepettehizmet.app` → Manage debug tokens
       → ekle → uygulamayı tam kapat/aç. Ayrıntı: `docs/OPS_BILLING_APPCHECK.md`
     → Not: ops dokümanı eski paket adını (`com.ustasindan.app`) yazıyordu,
       düzeltildi — yanlış uygulamaya token eklenmesin.

  ✅ 13b- Silmede AYRI bir gerçek hata (App Check aşılınca patlardı).
     → **Bu oturumda ben kırmışım.** 10. maddede eklediğim anonimleştirme
       `writer.update()` kullanıyor; `update` OLMAYAN dokümanda NOT_FOUND
       fırlatır (kullanıcının destek talebi/üyeliği yoksa — çoğu kullanıcı).
       BulkWriter varsayılanı bu hatayı yutmuyor → `close()`tan dışarı
       çıkıyor, **Auth kaydı silinmeden** fonksiyon düşerdi.
     → Sahada henüz PATLAMADI çünkü istekler App Check'e takılıp koda hiç
       ulaşmıyordu (13. madde). App Check düzeltilince ilk gerçek çağrıda
       patlayacaktı — yani iki hata üst üsteydi.
     → Üç koruma: `onWriteError` NOT_FOUND'u yutar · `writer.close()`
       try/catch içinde (anonimleştirme temizliktir, silmenin ön koşulu
       değil) · Auth kaydı zaten yoksa başarı sayılır (yarıda kalan önceki
       deneme kullanıcıyı kilitlemesin).
     → `functions/index.js`, `test/hesap_silme_kapsami_test.dart`
     → ✅ DEPLOY EDİLDİ (2026-08-09).
  ✅ 9- Müşteri ve usta değerlendirme kriterleri aynı kartlardı.
     → Tek düz etiket listesi iki yönde de kullanılıyordu: usta bir müşteriyi
       "Temiz işçilik" veya "Uygun fiyat" diye puanlayabiliyordu — o etiketler
       hizmeti VERENİ tarif eder.
     → Etiketler yöne ayrıldı (`positiveFor`/`negativeFor`). Müşteri tarafında
       ölçülen şey iş ilişkisi: iletişim, ödeme, randevuya sadakat, erişim.
       Her iki yön de 8+8 dengeli.
     → `isNegative` HER İKİ olumsuz listeye bakar: eski değerlendirmeler
       karşı yönün etiketlerini taşıyor, rozet/renk onlarda da doğru olmalı.
     → Ekran yönü gönderimle AYNI kaynaktan alır (`artisanDetailProvider`) —
       ayrışsalardı kullanıcı bir set görüp başka set kaydederdi.
     → Eski kayıttaki "yabancı" etiket listeye eklenir: görünmeseydi kullanıcı
       onu kaldıramadan tekrar kaydederdi.
     → `review.dart`, `review_screen.dart`,
       `test/degerlendirme_yonlu_etiket_test.dart`

  ✅ 10- Meslekleri çeşitlendirelim (örn. avukat).
     → **Avukat ZATEN VARDI** (`lawyer_consult`) — sorun yokluk değil,
       BULUNAMAMAK: 132 meslek düz listedeydi ve sıra inşaat mesleklerine
       göreydi, beyaz yaka hizmetler sona düşüyordu.
     → **Karar (kullanıcı): kategori sistemi.** 13 kategori eklendi
       (İnşaat & Tadilat · Tesisat · Ev · Araç · Teknoloji · Bakım & Sağlık ·
       Eğitim · Profesyonel Hizmetler · Etkinlik · Evcil · Ulaşım · Sanayi ·
       Diğer). Seçim ekranları grup başlığı basıyor; arama yazılınca gruplama
       kapanıyor (sonuç zaten daraldı).
     → 12 yeni meslek: mimar, iç mimar, bilirkişi, web/yazılım, grafik, sosyal
       medya, psikolog, diyetisyen, kişisel antrenör, dil-konuşma terapisti,
       sınav hazırlık, kodlama eğitmeni. Toplam **144**.
     → 4 ad aramaya uygun hale geldi (KOD DEĞİŞMEDİ, göç yok):
       "Hukuki Danışmanlık" → **"Avukat / Hukuki Danışmanlık"**, muhasebeci,
       hemşire, özel ders/öğretmen.
     → Yan bulgu: `professions.json` "Hemen Lazım" derken kod "Kolay İş"
       diyordu (marka değişiminden kalma) — senkronlandı.
     → `professions.json`, `profession.dart`, `local_data_service.dart`,
       `searchable_select_field.dart` (+3 seçim ekranı), `mock_database.dart`,
       `test/meslek_kategori_test.dart`, [[Veri-Modelleri]] 
  ℹ️ 11- "Tanılama satırı" nerede? → **Hesap Ayarları → Bildirim tercihleri**
     ekranının EN ALTI. Kod: `notification_prefs_screen.dart`
     `_PushDiagnosticsCard` (117. satır). Cihaz bildirime kayıtlıysa yeşil
     "kayıtlı" der; değilse SEBEBİNİ yazar (`push.diagnosticsTR`) — en sık
     neden Android 13+ bildirim izninin kapalı olması. "Yeniden dene"
     düğmesi tam orada, kartın içinde: `pushServiceProvider.retry()`
     çağırır, sonucu anlık bildirir.
     Neden var: token kaydı sessizce başarısız oluyordu; uygulama İÇİ
     bildirimler (Admin SDK, token gerekmez) çalışmaya devam ettiği için
     sorun görünmez kalıyordu. Test adımı "ne yazıyor, not alın" diyor —
     cihazda okuyup buraya yazman yeterli. KOD DEĞİŞİKLİĞİ GEREKMİYOR.

  ✅ 12- Destek formu ÇALIŞIYOR (2026-08-09 17:34 logunda `app: VALID`).
     Aynı App Check kapısını taşıyordu; token eklenince o da açıldı.

  ℹ️ 12b- Destek e-postası → **kodda zaten doğru**, değişiklik gerekmedi.
     Uygulama `kLegalContactEmail` kullanıyor (`legal_docs.dart`) =
     `ilandahizmet@gmail.com`; yardım ekranı da bunu gösteriyor. Sitedeki
     üç sayfa (`index.html`, `gizlilik-politikasi.html`, `hesap-silme.html`)
     de aynı adresi kullanıyor.
     Eski adres görüyorsan kaynağı **Firestore**: `adminConfig/runtime`
     içindeki `supportEmail` alanı admin panelinden (Platform ekranı)
     yazılıyor ve koddaki sabiti EZMİYOR — ayrı bir alan. Admin → Platform'dan
     güncellemen yeterli. (Not: `vault/06-Test/default.json` bir ComfyUI
     workflow dosyası, yanlışlıkla kasaya düşmüş — config değil, silinebilir.)


     Yeni yapalacaklar listesi
  ✅ 1- Ana sayfadaki Haftanın Ustası kartı + sistem mesajları.
     → **Asıl kusur boyut değil, ROTASYONUN OLMAMASIYDI** (kullanıcı fark
       etti): kod puana göre sıralayıp `.first` alıyordu, yani puan
       değişmedikçe aynı usta sonsuza kadar kalıyordu. "Haftanın" sözü hiç
       tutulmuyordu. Kartı küçültmek bunu çözmezdi.
     → Gerçek haftalık rotasyon: ISO hafta numarası % aday sayısı. Sunucuya
       alan YAZILMAZ; aynı hafta herkes aynı ustayı görür, hafta dönünce
       liste kayar. Sıralama kararlı (puan, eşitlikte uid) — iki kullanıcı
       aynı hafta farklı usta göremez.
     → Aday havuzu dar: **puan almamış usta seçilmez**. Havuz boşsa bölüm
       tamamen gizlenir.
     → Kart 150px yatay şeritten TEK SATIRA indi (avatar + ad + puan).
     → Sistem duyurusu kartı KALDIRILDI: duyuru keşif içeriği değil,
       bildirimdir — yeri Bildirimler ekranı. Ölü `_DiscoverCard` da silindi.
     → `home_discover.dart`, `test/haftanin_ustasi_test.dart`

  ⏳ 1b- İL BAZLI haftanın ustası — KARAR BEKLİYOR.
     Kullanıcı tereddütte kaldı, uygulanmadı. Seçenekler:
     (a) kullanıcının iline göre ("Bursa'nın Haftanın Ustası"; il yoksa genel)
     (b) il il rotasyon (her hafta başka il, herkes aynı kartı görür)
     Rotasyon artık çalıştığı için "hep aynı usta" sorunu zaten çözüldü;
     il bazlı seçim buna EK bir iyileştirme olur, acil değil.
      
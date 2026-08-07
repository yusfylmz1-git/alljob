# 🐛 Bulgular

> Test sırasında bulunan her şey buraya. Ben düzelttikçe **Durum** sütununu
> güncellerim.

---

## Nasıl bildirilir?

Bana şunu söylemeniz yeterli — ben buraya kaydederim:

> **"5.3.4 çalışmadı — usta hâlâ yazamıyor"**

Faydalı olursa ekleyin: hangi hesap, ekran görüntüsü, hata mesajının aynısı.

---

## Öncelik ölçeği

| | Anlamı | Örnek |
|---|---|---|
| 🔴 **P0** | Kullanıcıyı engelliyor, veri kaybı, gizlilik ihlali | Mesaj gönderilemiyor · telefon numarası herkese açık · takip kayıtları silindi |
| 🟠 **P1** | Bozuk ama etrafından dolaşılabilir | Rozet yanlış sayıyor · liste tazelenmiyor |
| 🟡 **P2** | Cila, rahatsız edici ama işlevsel | Metin taşması · koyu temada soluk renk |

---

## Açık bulgular

| # | Adım | Ne oldu | Öncelik | Durum |
|---|---|---|---|---|
| K-01 | 8.3 | Usta profilinde telefon numarası görünüyor (opt-in özellik) | — | 🤔 **karar bekliyor** |
| K-02 | 2.1 | Profil ekranı karmaşık geliyor; "Vitrini tamamla" kartı fazla dikkat çekiyor | 🟡 P2 | 🤔 **karar bekliyor** |
| K-03 | 1.1 | Onboarding sığ; "nasıl kullanılır" anlatımı eksik | 🟡 P2 | 📋 **planlandı** |
| K-04 | — | Liste açılışında kartlar için "şelale" giriş animasyonu | 🟡 P2 | 📋 **planlandı** |

**Oturum 2 — düzeltme kuyruğu** (öncelik sırasına dizili, hepsi koddan doğrulandı):

| # | Adım | Ne oldu | Öncelik | Durum |
|---|---|---|---|---|
| B-02 | 3.1.5 | Fotoğraf yüklenirken **Kaydet'e basınca beklemiyor** — o foto ilana hiç girmiyor, sessiz veri kaybı | 🟠 P1 | 🔧 **düzeltilecek** |
| B-03 | 2.x | Meslek limiti: Hemen Lazım açıkken **5. meslek seçilemiyor** (sayaç "4/5" derken reddediyor) | 🟠 P1 | 🔧 **düzeltilecek** |
| B-04 | 2.x | Profil kaydetme başarısız — **sebep yazmıyor**, genel mesaj. Gerçek neden teşhis edilemiyor | 🟠 P1 | 🔧 **düzeltilecek** |
| B-05 | 2.x | Profilde "tekrar düzenle" → **ekran donuyor**. B-04'ün devamı olabilir | 🟠 P1 | ⏸️ **B-04'ten sonra** |
| B-06 | 3.1.5 | İlan fotoğrafı **çoklu seçilemiyor** — tek tek eklemek gerekiyor (limit 8) | 🟠 P1 | 🔧 **düzeltilecek** |
| B-07 | 3.5.1 | İlan düzenlemede **yalnız başlık + açıklama** var; fotoğraf/konum/kategori düzenlenemiyor | 🟠 P1 | 🔧 **düzeltilecek** |
| B-08 | 2.x/3.1 | **Kaydet / İlanı yayınla düğmeleri alt menünün altında kalıyor** (bazı telefonlarda erişilemez) | 🟠 P1 | 🔧 **düzeltilecek** |
| B-09 | 3.1.4 | İl seçince **ekran yukarı kayıyor**; ilçeye odaklanmıyor, klavye kapanmıyor | 🟡 P2 | 🔧 **düzeltilecek** |
| B-10 | 3.2.1 | Hemen Lazım'da **otomatik doldurma örnekleri çok aşağıda** — kategori kutusunun hemen altında olmalı | 🟡 P2 | 🔧 **düzeltilecek** |
| B-11 | 3.6.1 | İlan iptal nedenlerinde **"günlük hakkım bitti" gereksiz** — hakkı yoksa zaten ilan açamıyor | 🟡 P2 | 🔧 **düzeltilecek** |
| B-12 | 4.2.5 / 4.5 | **Telefona sistem push'u hiç gelmiyor** — uygulama içi bildirimler çalışıyor | 🔴 P0 | 🔬 **teşhis gerek** |
| B-13 | 5.1 | **Müşteri "Mesaj Gönder"e basınca sohbet açılmıyor** — *"Sohbet açılamadı"*. Akış tam burada kırılıyor | 🔴 P0 | ✅ **düzeltildi** (cihazda doğrulanacak) |
| B-14 | 4.2.5 | Yeni bildirim geldiğinde **zil rozeti (kırmızı) görünmüyor** — bildirime girince mesaj orada | 🟠 P1 | 🔬 **teşhis gerek** |
| B-15 | 1.x | **Hesap değiştirirken `permission-denied`** — program durduruldu. Public `users/{uid}` token temizliği kurala takılıyor | 🔴 P0 | ✅ **düzeltildi** (cihazda doğrulanacak) |
| K-05 | 2.x | Usta hesabı ilk açılışta **Hemen Lazım varsayılan açık** gelsin | 🟡 P2 | 🤔 **karar bekliyor** |
| K-06 | 2.1 | Profil başlığı **usta kartı gibi** olsun: foto solda, yanında isim + Takip Et, altında meslek/telefon | 🟡 P2 | 🤔 **K-02 ile birlikte** |
| K-07 | 3.1.6 | Fiyat tipi ilan formunda yok — ~~bilinçli mi?~~ | — | ✅ **kapandı: bilinçli** |

### B-15 · Hesap değiştirirken permission-denied — 🔴 P0

**Belirti:** Bir hesaptan çıkıp diğerine geçerken
`FirebaseException ([cloud_firestore/permission-denied])`, program durduruldu.

#### Kök neden: `arrayRemove` anahtarı BIRAKIR, kural onu reddeder

Kural, public `users/{uid}` dokümanında `email`/`fcmTokens` için **yalnız
SİLMEYE** izin verir (`firestore.rules:66-73`):

```
&& (!changed.hasAny(['fcmTokens'])
    || !('fcmTokens' in request.resource.data))
```

Yani yazım sonrası anahtar **hiç kalmamalı**. İki temizlik yolu var ve
biri bu şartı sağlamıyor:

| Fonksiyon | Yazım | Sonuç | Kural |
|---|---|---|---|
| `_stripPublicPii` (`push_service.dart:185`) | `FieldValue.delete()` | anahtar **gider** | ✅ geçer |
| `_stripPublicToken` (`:175`) | `FieldValue.arrayRemove([token])` | anahtar **kalır** (boş dizi) | ❌ **reddedilir** |

`arrayRemove` alanı boş diziye indirir ama `'fcmTokens' in
request.resource.data` hâlâ **true** → kural reddeder.

#### Nerede patlıyor?
İki çağrı yolu var, ikisi de `_stripPublicToken`'a ulaşabiliyor:
- **Çıkışta:** `unregisterFor` (`:148`) — ama `catch (e)` yutuyor (`:151`),
  ayrıca `signOut` (`auth_controller.dart:140`) `await` ediyor →
  **çökmemesi gerekir**
- **Girişte:** `_saveToken` → `_stripPublicPii` başarısız olursa
  `catch` içinde `_stripPublicToken`'a **düşüyor** (`:191-194`) →
  ikinci deneme de reddedilir

> [!warning] Kullanıcıya görünen hata muhtemelen GİRİŞ tarafından
> `unregisterFor` hatayı yutuyor; o hâlde yakalanmamış istisna büyük
> olasılıkla `_saveToken` yolundan geliyor (`registerFor`'un `catch`'i
> `_lastError`'a yazar ama bazı yollar dışarı sızabilir). Cihazda hangi
> adımda çıktığı (çıkarken mi, yeni hesap girerken mi) **kesinleştirilmeli**.

#### ✅ Düzeltme (yapıldı)
`_stripPublicToken` artık `FieldValue.delete()` kullanıyor — legacy alanın
tamamen kaldırılması zaten amaç (H2 temizliği); tek bir token'ı diziden
çıkarmanın public dokümanda anlamı yok, orada hiç token durmamalı.
Kullanılmayan `token` parametresi de düştü (`_stripPublicPii` dahil).

**Regresyon testi:** `test/push_public_pii_test.dart` (3 test) — public
`users` yazımlarında `arrayRemove` aranır, `_stripPublicToken`'ın `delete()`
kullandığı doğrulanır, ayrıca kuralın hâlâ "anahtar kalmamalı" dediği
kontrol edilir (kural gevşerse test düşer, gerekçe gözden geçirilir).
Test eski kod geri konarak **kırıldığı doğrulandı** — gerçekten yakalıyor.

**Not:** Bu, B-12'nin (push gelmiyor) kök nedeni de olabilir — `_saveToken`
içinde `_stripPublicPii` patlarsa token yazımı yarıda kalır, `fcmTokens`
private'a hiç yazılmayabilir. **B-15 → B-12 zinciri cihazda kontrol edilecek.**

### B-13 · Sohbet açılamıyor — 🔴 P0, KÖK NEDEN BULUNDU

**Belirti:** Müşteri, "ilan 1 ile ilgilenen usta var" bildirimine tıkladı →
ilan detayı açıldı → **"Mesaj Gönder"** düğmesine bastı →
*"Sohbet açılamadı. E-posta doğrulamanızı kontrol edip tekrar deneyin."*

**Bu, testin ana akışını kesen bir hata.** Müşteri ustayla iletişim kuramazsa
Bölüm 5–7 (mesajlaşma → usta seçimi → tamamlama → değerlendirme) hiç
başlayamaz.

#### Kök neden: e-posta doğrulama kapısı MÜŞTERİ tarafında yok

Sohbet oluşturma kuralı `isEmailVerified()` şartı koşuyor
(`firestore.rules:359-361`). İstemcide bu kapı `ensureEmailVerified()` ile
açılır — **ama iki taraf farklı davranıyor:**

| Taraf | Akış | `ensureEmailVerified` | Sonuç |
|---|---|---|---|
| **Usta** → ilgi bildirir | `job_detail_screen.dart:1736` | ✅ **var** | Kapı açılır, kullanıcı doğrulamaya yönlendirilir |
| **Müşteri** → sohbet açar | `job_detail_screen.dart:363` `_openChat` | ❌ **YOK** | Doğrudan Firestore'a yazar → kural reddeder |

`_openChat` (`:363-374`) doğrudan `startChat`'i çağırıyor; hata
`catch (_)` ile yutulup sabit metin gösteriliyor. Mesaj sebebi **doğru tahmin
ediyor** ama kullanıcıya çıkış yolu sunmuyor — doğrulama e-postası gönderme
akışı hiç açılmıyor.

**Aynı dosyada iki farklı desen** olması bunun gözden kaçmış bir boşluk
olduğunu gösteriyor; usta tarafı düzeltilirken müşteri tarafı unutulmuş.

#### ✅ Düzeltme (yapıldı)
`_openChat` içinde `startChat` çağrısından ÖNCE `ensureEmailVerified(context,
ref, actionLabel: 'ustaya mesaj göndermek')` — usta tarafındaki (`:1736`)
desenin aynısı. E-posta doğrulanmamışsa kullanıcı artık **doğrulama akışına
yönlendiriliyor**, sessiz ret yok.

**`catch` de düzeltildi:** `permission-denied` diğer hatalardan ayrılıyor ve
gerçek hata `debugPrint` ile loglanıyor. Kapı yukarıda geçtiği için artık
"e-postanızı kontrol edin" demek yanıltıcı olurdu; askı/izin mesajı verilir.

#### ⚠️ Cihazda doğrulanacak
Kural listesindeki diğer şartlar da (`chatId` biçimi, `members` haritası,
`participants`) reddedebilir. Sohbet hâlâ açılmıyorsa artık **gerçek hata
logda görünür** — `flutter logs` veya `adb logcat` çıktısındaki
`[chat] startChat hatası:` satırı sebebi söyler.

### B-14 · Bildirim zil rozeti görünmüyor — 🟠 P1

**Belirti:** Yeni bildirim geldiğinde zil ikonunda **kırmızı rozet yok**;
bildirimlere girince mesaj orada duruyor. Yani veri geliyor, **sayaç UI'ya
yansımıyor**.

**İlk bakılacak yer:** `notification_bell.dart` (okunmamış sayacını okur) ve
`users/{uid}/private/chatMeta` — CLAUDE.md kural 3: *"okunmamış sayacı CF'e
aittir"*. Sayaç CF tarafında yazılmıyorsa veya istemci yanlış alanı dinliyorsa
rozet hiç dolmaz.

**B-12 ile ilişkili olabilir:** ikisi de "bildirim var ama kullanıcı görmüyor"
ailesinden. Ortak kök (CF'in bildirim yazma yolu) çıkabilir — B-12 teşhisi
sırasında birlikte bakılmalı.

### B-12 · Sistem push'u gelmiyor — 🔴 P0, ÖNCE TEŞHİS

**Belirti:** Uygulama içi bildirim listesi çalışıyor, tıklayınca doğru ilana
gidiyor ✅ — ama **telefonun kendi bildirim çekmecesine hiçbir şey düşmüyor**.
İki ayrı cihazda, ilan oluşturma senaryosunda doğrulandı.

**Bu ayrım tam olarak kodun uyardığı tuzak** (`push_service.dart:94-100`):
> *"Token yazımı App Check reddi / kural hatası / ağ yüzünden düşerse uygulama
> 'çalışıyor' görünür ama `fcmTokens` boş kalır ve sistem push'u HİÇ gelmez —
> in-app bildirimler Admin SDK ile yazıldığı için çalışmaya devam eder, bu da
> sorunu görünmez kılar."*

In-app çalışıp sistem push'unun gelmemesi ⇒ **`fcmTokens` büyük olasılıkla boş**.
CF tarafı sağlam görünüyor (`functions/index.js:375` token yoksa
*"Push skip {uid}: cihaz token'ı YOK"* loglar).

#### Kod düzeltmesi DEĞİL olabilir — önce ölçün

Bu bulguyu diğerleri gibi kuyruğa atmadan önce **tanılama okunmalı**; sebep
yapılandırma da olabilir (izin, App Check, google-services.json).

**1. Uygulamada:** Ayarlar → Bildirimler ekranı (`notification_prefs_screen`)
→ en alttaki **tanılama satırı** ne yazıyor? Dört olasılık:

| Satır | Anlamı | Yapılacak |
|---|---|---|
| "Bildirimler açık (cihaz kayıtlı)" | Token YAZILMIŞ → sorun cihaz/kanal veya CF tarafında | Aşağıdaki 2. adıma geç |
| "Bildirim izni kapalı…" | Android 13+ POST_NOTIFICATIONS reddedilmiş | Sistem ayarından aç → "Yeniden dene" |
| "Cihaz bildirimlere kaydedilemedi: …" | **Gerçek hata burada yazıyor** | Metni aynen not al — teşhis bu |
| "Bildirim durumu bilinmiyor" | `registerFor` hiç çalışmamış | Giriş akışını incele |

**2. Sunucuda:** `firebase functions:log` → *"Push skip"* satırı var mı?
- Varsa → token yok, sorun **istemcide** (yukarıdaki tanılama söyler)
- Yoksa ve gönderim loglanıyorsa → token var, sorun **cihazda** (bildirim
  kanalı, pil optimizasyonu, MIUI kısıtı)

#### Xiaomi/MIUI şüphesi
Cihaz **Xiaomi 22101316G / Android 14** (oturum 1 notu). MIUI arka plan
bildirimlerini agresif kısar; "Otomatik başlatma" kapalıysa uygulama kapalıyken
push düşmez. **Ayrı bir marka tuzağı** — kodda düzeltilecek bir şey olmayabilir.
Test: uygulama **açıkken** başka cihazdan ilan oluşturun; bildirim geliyorsa
sorun MIUI kısıtı, gelmiyorsa token/kayıt sorunu.

**Not:** Debug imzalı APK + App Check birlikte de token yazımını engelleyebilir
(App Check reddi → `_lastError` dolar). Tanılama satırı bunu ayırt eder.

### Oturum 2 bulguları — kök neden analizi

> Hepsi koddan doğrulandı; düzeltme sırasında yeniden araştırmaya gerek yok.

#### B-02 · Yükleme sürerken kaydet (veri kaybı)
`_submit()` yalnız `_submitting`'i kontrol ediyor, `_uploadingPhoto`'ya
**hiç bakmıyor** (`create_job_screen.dart:113`). Yükleme yarıdayken kaydedilirse
o fotoğraf `_photos`'a hiç eklenmez → ilana girmez, uyarı da çıkmaz.

**Tuhaflık:** geri tuşu bu durumu doğru ele alıyor (`busy = _uploadingPhoto ||
_submitting`, `:217`) ama kaydet düğmesi aynı korumayı almamış.

**Düzeltme:** `_submit()` başına `if (_uploadingPhoto)` → uyarı + return.

#### B-03 · Meslek limiti Hemen Lazım'ı sayıyor
Hemen Lazım depoda ayrı bayrak değil, `professions` dizisinde
`kOtherProfession` kodu olarak tutuluyor — bu yüzden meslek sayısına karışıyor.

**Tutarsızlık iki yerde:**
| Yer | Hemen Lazım'ı | Sonuç |
|---|---|---|
| Sayaç (`artisan_profile_edit_screen.dart:1099-1101`) | **eliyor** | "4/5 seçili" yazıyor |
| Limit kontrolü (`:458-461`) | **elemiyor** | 5.'yi reddediyor |
| `toggleProfession` (`my_profile_controller.dart:104-108`) | **elemiyor** | sessizce `return` |

`setQuickSupportEnabled` yorumu (`my_profile_controller.dart:130`) zaten
*"[maxProfessions] sınırı Hemen Lazım'ı ENGELLEMEZ"* diyor — niyet doğruymuş,
`toggleProfession` bunu uygulamamış.

**Düzeltme:** her iki sayma yerinde de `kOtherProfession`/`kQuickSupportCategory`
filtrelensin. Tek doğru kaynak: `professionCodes`'u filtreleyen bir getter.

#### B-04 · Kaydetme hatası sebep vermiyor — sosyal medya DEĞİL
**Kullanıcı şüphesi test edildi, doğrulanmadı.** `normalizeHandle` /
`normalizeWebsite` / `normalizeWhatsapp` (`social_links.dart:51-103`) girdiyi
kuralın istediği biçime çeviriyor (URL → kullanıcı adı, `https://` ekler).
`socialLinksOk` (`firestore.rules:193-212`) ihlali beklenmez.

**Asıl sorun mesajın kendisi:** `save()` hatayı `AsyncValue.guard` içinde yutup
yalnız `false` dönüyor (`my_profile_controller.dart:328-342`); ekran sabit
*"Kaydetme başarısız, tekrar deneyin."* yazıyor (`:312`). Gerçek sebep
hiçbir yere yazılmıyor — log'a bile.

**Diğer aday:** `serviceProvincesOk` (`firestore.rules:180-188`) —
`serviceProvinces.size() <= serviceAreas.size()` şartı. Bölge/il seçimi bu
dengeyi bozduysa kural reddeder.

**Düzeltme sırası:** önce hata mesajını görünür yap (kendi başına doğru bir
düzeltme — kullanıcı neden kaydedemediğini bilmeli), sonra cihazda tekrar
dene, gerçek sebeple B-04/B-05'i kapat.

#### B-07 · Düzenleme kapsamı dar — sunucu tarafı hazır
`_EditJobSheet` yalnız başlık+açıklama taşıyor; `updateJobContent` imzası da
öyle (`job_repository.dart:96-101`: `title`, `description`, `budget`).

**İyi haber:** `firestore.rules` fotoğrafı yasaklamıyor — `photos` create
allowlist'inde (`:630`), update'te içerik kilidi yok. İş yalnızca istemcide.

#### K-07 · Fiyat tipi formda yok — ✅ KAPANDI (bilinçli tasarım)
`create_job_screen.dart:154` → `priceType: JobPriceType.inspection` sabit;
her ilan "Keşif Gerekli" doğuyor.

**Karar (kullanıcı, oturum 2):** Fiyat seçeneği **bilerek kaldırılmıştı**,
geri gelmeyecek. Hata değil. Test adımı **3.1.6 plandan düşürüldü**.

> [!warning] Kod hâlâ iki seçeneği taşıyor
> `JobPriceType` enum'ı ve `Job.budget` alanı duruyor; `updateJobContent`
> imzasında da `budget` parametresi var (`job_repository.dart:96-101`).
> Ölü kod değil — eski ilanlar bütçeli olabilir, `apiValue` göçü de riskli
> (CLAUDE.md kural 6). **Dokunulmayacak**, yalnız form seçenek sunmuyor.

### K-04 · Liste giriş animasyonu (şelale) — PLAN

**Durum:** Dokunma yaylanması (`TapScale`) **yapıldı** (`3a18eb0`). Şelale
animasyonu bekliyor.

**İstenen:** Liste açılınca kartlar hep birden değil, yukarıdan aşağıya
sırayla süzülerek görünsün.

**İki gerçek risk — naif uygulama kötü sonuç verir:**

1. **Tekrar oynatma.** Listeler `ListView.builder` kullanıyor; kaydırıp geri
   dönünce widget yeniden kurulur. `index × gecikme` yazılırsa kartlar her
   dönüşte tekrar animasyon oynatır → sinir bozucu.
   **Çözüm:** yalnız **ilk yüklemede** ve yalnız **ilk ~8 kart**; sonrakiler
   anında görünsün.
2. **Gecikme hissi.** 50 ms × 10 kart = yarım saniye; kullanıcı listeyi geç
   görmüş hisseder. **30–40 ms** ve **maks 6–8 kart** sınırı gerekir.

**Yaklaşım:** Tek paylaşılan widget yaz (`ListEnter` gibi), her ekranda ayrı
ayrı değil — yoksa 21 dosyaya dağılmış tutarsız animasyonlar olur.

**Mevcut dil:** Sohbetteki `_MessageEnter` (`chat_screen.dart`, 280 ms
`easeOutCubic`) aynı hareket dilini kullanıyor; listelerde de ona uyulmalı.

### K-03 · Onboarding + Yardım zenginleştirme — PLAN

**Karar:** Kısa onboarding + zengin Yardım. (Kullanıcı seçimi.)

**Gerekçe:** Onboarding'in düşmanı uzunluktur — 3 sayfayı 8'e çıkarırsak
kullanıcı "atla"ya basar ve hiçbirini okumaz. Detay, ihtiyaç anında
okunabileceği yerde (Yardım) durmalı.

**Şişme endişesi ölçüldü — sorun değil:**
| | Mevcut | Sonrası (tahmin) |
|---|---|---|
| Onboarding kodu | 297 satır | ~500 satır |
| Yardım kodu | 458 satır | ~700 satır |
| APK | 91 MB | +0.1 MB'tan az (kod, görsel değil) |

64K satırlık projede ~450 satır = **%0.7**. Şişme değil.

#### Faz 1 — Onboarding (3 sayfa KALSIN, kalitesi artsın)
Mevcut içerik zaten iyi (`onboarding_screen.dart:26-47`): "Aradığın usta
bölgende" / "İlanını ver ustalar gelsin" / "Usta mısın? Vitrinini aç".
- Sayfa **sayısını artırma**; görsel anlatımı güçlendir (ikon → küçük illüstrasyon
  veya animasyon)
- Son sayfaya *"Nasıl kullanılır?"* bağlantısı ekle → Yardım'a götürsün
- Atla düğmesi her zaman erişilebilir kalsın

#### Faz 2 — Yardım ekranı (asıl iş burada)
Şu an düz SSS listesi. Eklenecek: **rol bazlı adım adım rehberler**.
```
Yardım
├── 🚀 Nasıl başlarım?        ← YENİ, rehber formatı
│   ├── Müşteriysen: ilan ver → usta seç → değerlendir
│   └── Ustaysan: vitrin aç → ilgi bildir → işi tamamla
├── ❓ SSS                     ← mevcut, kategorili
└── 📞 Destek                  ← mevcut
```
Rehber içeriği ekran görselleriyle desteklenirse çok daha etkili olur.

#### Faz 3 (opsiyonel) — Bağlam içi ipuçları
Kullanıcı bir ekranı ilk kez açtığında tek seferlik ipucu balonu.
En etkili öğretme yöntemi ama en çok iş — Faz 1-2'den sonra değerlendirilsin.

> [!note] ui-ux-pro-max skill'i
> Bu iş için **fikir kaynağı** olarak mantıklı (onboarding kalıpları, tipografi,
> animasyon önerileri) ama **kod üretici** olarak değil — projenin kendi
> `AppPalette`/`AppTheme` sistemi var, yeni palet dayatması zarar verir.
> Kurulum: `npm i -g ui-ux-pro-max-cli && uipro init --ai claude`

### K-02 · Profil ekranı sadeleştirme — UX kararı

**Kullanıcı geri bildirimi:** *"müşteri ve usta profilleri farklı biliyorum ama
çok karmaşık. Vitrini düzenle de göze çok dikkat çekiyor."*

**Ekran görüntülerinden tespit — tasarım aslında iyi:**
Müşteri/Usta sekmesi net, renk kodlaması (mavi=müşteri / yeşil=usta) akıllıca,
alt bar role göre değişiyor. Sorun genel karmaşa değil, **üç nokta**:

#### 1. "Vitrini tamamla" kartı görsel olarak baskın 🟡
Turuncu/amber blok, ilerleme çubuğu, 6 rozet, büyük CTA — ekranın yarısını
kaplıyor ve **her açılışta** aynı yoğunlukta. Vurgu bilinçliydi (ustayı profil
tamamlamaya itmek) ama ölçek yanlış.

**Öneri:** İlerledikçe sönükleşsin.
- %0–50 → şu anki hâli (yeni usta gerçekten yönlendirilmeli)
- %51–99 → tek satır: *"Vitrin %67 — Hakkımda eksik"* + küçük "Tamamla" bağlantısı
- %100 → kart tamamen kalksın
- Rozetleri her zaman göstermek yerine **yalnız sıradaki adımı** yaz

#### 2. ARAÇLAR bölümü iki rolde de tekrar ediyor 🟡
`profile_screen.dart:92-120` — "Usta Çantası" ve "Ajanda" hem müşteri hem usta
modunda **aynen** görünüyor. Rol değiştirince değişmeyen bir blok, "karmaşık"
hissinin bir kaynağı: kullanıcı neyin role ait olduğunu ayırt edemiyor.

Ayrıca **isim tutarsızlığı**: müşteri modunda "Usta Çantası" yazıyor — müşteri
neden usta çantası görsün? (Araçlar herkese açık olabilir ama ismi rolü ima
ediyor.)

**Öneri:** Ya araçları rol-bağımsız ayrı bir sekmeye/menüye taşı, ya da müşteri
modunda gizle. En azından müşteri modunda adı nötrleştir ("Hesap Araçları").

#### 3. Vitrin düzenleme formu tek parça 🟡
`artisan_profile_edit_screen.dart` — 1601 satır, tek uzun form: fotoğraf,
hakkında, meslek, bölge, iş fotoğrafları, çalışma saatleri, **5 sosyal medya
alanı**, telefon anahtarı. `focusStep` deep-link'i var ama form yine bütün
hâlinde açılıyor.

**Öneri:** Sosyal medyayı katlanabilir *"Sosyal medya (isteğe bağlı)"*
bölümüne al — çoğu usta hiçbirini doldurmuyor, 5 alan boş yer kaplıyor.

> [!note] Ne zaman yapılmalı?
> **Test bittikten sonra.** Şimdi dokunulursa bölüm 2–9 yeni bir arayüzde test
> edilir ve karşılaştırma zemini kaybolur. K-01 ile birlikte topluca ele alınsın.

### K-01 · Vitrin telefonu — ürün kararı (hata DEĞİL)

**Durum:** Kod doğru çalışıyor, bilinçli tasarım. Karar sizin.

Ustanın profil düzenlemede açık bir anahtarı var: *"Telefon numaram profilimde
görünsün"*. Varsayılan **kapalı**. Üç şart birden: usta açmış + telefon
doğrulanmış + dolu (`ArtisanProfile.hasPublicPhone`). Kapatınca numara
veritabanından **silinir**, sadece gizlenmez.

**Gerilim:** Sohbette telefon yazmak maskeleniyor ([[Mimari-Kararlar]] ADR-10 —
"iş platform içinde kalmalı") ama profilde tek dokunuşla arama tuşu var. Usta
maskelemeye takılmadan aynı sonuca ulaşıyor. Komisyon/güvence modeli varsa bu
kapı onu delik bırakır.

**Seçenekler:**
| | Ne yapılır | Sonuç |
|---|---|---|
| A | Olduğu gibi bırak | Tasarım zaten sağlam; platform dışı iletişim serbest |
| B | Özelliği kaldır | Tutarlılık sağlanır; ustanın tercihi elinden alınır |
| C | Yalnız **Pro üyelere** aç | Kaçak yerine gelir kalemi olur |
| D | Yalnız **işi verilmiş müşteriye** göster | Eşleşme platformda kalır, iletişim serbestleşir |

**İlgili dosyalar:**
- `lib/data/models/artisan_profile.dart:82-98` — `showPhoneOnProfile`, `hasPublicPhone`
- `lib/features/artisan/presentation/artisan_profile_edit_screen.dart:785-800` — anahtar
- `lib/features/customer/presentation/artisan_profile_screen.dart:711` — vitrin gösterimi
- `lib/features/artisan/application/my_profile_controller.dart:282` — kaydetme

---

## Kapatılanlar

| # | Adım | Ne oldu | Nasıl çözüldü | Commit |
|---|---|---|---|---|
| B-01 | 1.2.5 | Misafir Mesajlar'a basıp giriş ekranına düşünce, **donanım geri tuşu uygulamayı küçültüyordu** (ana ekrana dönmesi gerekirdi) | `LoginScreen` + `PackageSelectScreen`'e `PopScope` | `fca9064` |
| B-15 | 1.x | Hesap değiştirirken `permission-denied`, program durdu | `_stripPublicToken` → `arrayRemove` yerine `delete()` (anahtar kalmamalı) + 3 regresyon testi | `4e69b0a` |
| B-13 | 5.1 | Müşteri "Mesaj Gönder" → *"Sohbet açılamadı"*; tüm mesajlaşma akışı bloke | `_openChat`'e eksik `ensureEmailVerified` kapısı + `catch` sebebi ayırıyor | `4e69b0a` |

### B-01 · Giriş ekranında donanım geri tuşu

**Kök neden:** Bu ekrana `redirect` ile geliniyor (misafir korumalı bölgeye
dokunur → router yönlendirir). Yönlendirme **geçmiş yığını bırakmaz**, yani
`canPop()` false. Ekrandaki `BackButton` bunu zaten ele alıyordu
(`canPop ? pop : go(home)`) ama **donanım geri tuşu o mantığı hiç görmüyordu** —
doğrudan sisteme düşüp uygulamayı küçültüyordu.

**Çözüm:** `PopScope(canPop: false)` + elle yönlendirme. Mantık tek metotta
(`_goBack`), ekran düğmesi de ona bağlandı.

`PackageSelectScreen` de aynı boşluktaydı, birlikte düzeltildi — ama davranışı
farklı: `changing` modunda profile döner, **ilk zorunlu seçimde geri tuşu
hiçbir şey yapmaz** (plan seçmeden ilerlenemez, ama uygulama da küçülmez).

---

## 📋 Test oturumu kaydı

Her oturumun sonunda nerede kaldığımızı buraya yazın.

### Oturum 1 — 2026-08-07
- **Tamamlanan:** Bölüm 1 (Giriş ve Hesap) ✅ · Bölüm 2 (Profil ve Rol) ✅
- **🔜 KALINAN YER: Bölüm 3 — [[03-Ilanlar-Musteri]]** (hiç başlanmadı)
- **Düzeltilenler:** B-01 (`fca9064`) · SSS "Eleman" kategorisi (`4e28ea4`) ·
  kartlara TapScale (`3a18eb0`)
- **Karar/plan bekleyen:** K-01 · K-02 · K-03 · K-04
- **⚠️ Telefonda yeni derleme gerekiyor** — TapScale ve SSS düzeltmesi
  cihazdaki sürümde yok
- **Not:** Cihaz Xiaomi 22101316G / Android 14. APK kullanıcı tarafından
  kendi imzasıyla kuruluyor — ajanın derlediği debug imzalı APK çakışıyor
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Düzeltme sonrası kurulumu kullanıcı
  yapmalı.

> [!important] Sonraki oturumda buradan devam
> **Bölüm 3'ten başla.** İlan akışı sistemin merkezi — bölüm 3→4→5→6→7 zinciri
> birbirine bağlıdır, tek oturumda yapmak en verimlisi (~1.5 saat).
>
> **Gerekli hazırlık:** İkinci Google hesabı. Bölüm 4'ten itibaren usta ve
> müşteri ayrı hesaplar olmalı; ustanın kendi ilanına ilgi bildirmesi mümkün
> değil.
>
> **Kritik doğrulamalar** (henüz hiç cihazda test edilmedi):
> - 5.3 — müşteri hiç yazmadan işi verirse usta sohbete yazabiliyor mu?
> - 7.2 — müşteri puan verdikten sonra ustanın "Değerlendir" şeridi duruyor mu?

### Oturum 2 — 2026-08-07
- **Tamamlanan:** Bölüm 3 (İlanlar — Müşteri) ✅ · Bölüm 4 (İlanlar — Usta) ✅ ·
  Bölüm 2'ye dönüş (vitrin düzenleme)
- **🔜 KALINAN YER: Bölüm 5 — [[05-Mesajlar]] ⭐** (34 adım, ~30 dk)
- **Yöntem kararı:** Test sürerken kod değiştirilmiyor. Bulgular biriktirilip
  **test bitince sırayla** düzeltilecek — yoksa her düzeltme sonrası yeni
  derleme gerekir ve karşılaştırma zemini kayar.
- **Yeni bulgular:** B-02…B-11 (hata) · K-05, K-06, K-07 (karar)
- **Doğrulananlar:** ilan limiti 5 ✅ · düzenle/sil ✅ · Hemen Lazım ilanı ✅ ·
  boş alan uyarısı ✅ · süre ✅ · ilan durumu ✅ · foto loading+büyütme ✅ ·
  ikinci hesapla ilan görme ✅ · iptal nedeni sheet'i ✅
- **Bölüm 3'te atlanan:** 3.1.6 (fiyat tipi — K-07 kararına bağlı) ·
  3.4.5 + 3.6.3 (usta hesabı gerek → Bölüm 4'te doğrulanacak)
- **Kullanıcı geri bildirimi:** "usta kartları ve ürünler basıldı hissi
  veriyor, güzel" — TapScale + şelale animasyonu cihazda onaylandı ✅

**Bölüm 4 sonucu:** 20 adımın 16'sı geçti, akış **temiz**. İlgi bildirme
tekilliği (4.2.3), geri çekme/tekrar bildirme (4.3), yönlendirme (4.5.3)
hepsi doğru. Tek bulgu **B-12 (push)** — ama o 🔴 P0.

> [!important] Sonraki oturumda buradan devam
> **Bölüm 5'ten başla** ([[05-Mesajlar]] ⭐, 34 adım ~30 dk) — testin **en
> kritik bölümü**. Karşılıklı değerlendirme çıkmazının doğrulaması burada
> (5.3: müşteri hiç yazmadan işi verirse usta yazabiliyor mu?).
>
> Bölüm 5'te kapatılacak devir adımları: **3.6.3** (iptal edilen ilan usta
> feed'inden düştü mü) · **4.4.3** (seçilmeyen usta "Reddedildi" oluyor mu).
>
> **B-12 ölçümü** (5 dk, teste paralel): Ayarlar → Bildirimler → tanılama
> satırını okuyun. Sonuç düzeltmenin ne olduğunu belirler — kod mu, izin mi,
> MIUI mi. Detay: B-12 notu.
>
> Test bitince (bölüm 5→9) düzeltme kuyruğu: **B-13 (P0) → B-12 (P0) →
> B-14 → B-02 → B-03 → B-04/B-05 → B-06 → B-07 → B-08 → B-09 → B-10 →
> B-11**, sonra K-05/K-06.

> [!warning] ⛔ B-13 Bölüm 5'i BLOKLUYOR — istisna gerekebilir
> "Test sürerken kod değiştirilmiyor" kuralı bu bulguda tıkanıyor: müşteri
> sohbeti açamazsa Bölüm 5 (34 adım), 6 (22) ve 7 (20) — **76 adım** hiç
> test edilemez. Testin ana hedefi (5.3 / 7.2 karşılıklı değerlendirme
> çıkmazı) da bu akışın içinde.
>
> **Önce şu ayrım yapılmalı:** hesabın e-postası gerçekten doğrulanmamış
> olabilir (Google girişinde genelde otomatik `true` gelir, ama her zaman
> değil). Öyleyse **kod hatası değil** — doğrulama yapılıp test sürdürülür,
> B-13 yalnız "kapı açılmıyor" UX eksiği olarak kuyrukta kalır.
>
> Doğrulanmışsa ⇒ gerçek kural reddi ⇒ B-13 **hemen** düzeltilmeli, yoksa
> test buradan devam edemez.

---

## Bulgu şablonu

```
### B-01 · [adım no] — kısa başlık
**Ne bekledim:**
**Ne oldu:**
**Hangi hesap:** müşteri / usta
**Tekrarlanıyor mu:** evet / hayır / bazen
**Öncelik:** P0 / P1 / P2
**Durum:** açık / inceleniyor / düzeltildi
```

---
İlgili: [[00-TEST-PLANI]] · [[Bilinen-Tuzaklar]]

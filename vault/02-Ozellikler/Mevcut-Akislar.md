# Mevcut Akışlar — ürün bugün ne yapıyor?

> Çıkarım tarihi: **2026-08-09** (oturum 83, Tur B sonrası).
> Kaynak: rotalar, kapı koşulları ve model kuralları doğrudan koddan okundu.
> Bu not `vault/06-Test/` defterinin dayanağıdır — biri değişirse diğeri de
> değişmeli.

45.2K satır Dart · 188 dosya · 18 modül.

## Kim ne görebilir?

Üç kullanıcı hali vardır ve **rol bir anahtar değil, bir moddur** — aynı hesap
hem müşteri hem usta olabilir.

| Hal | Nasıl olunur | Ne değişir |
|---|---|---|
| **Misafir** | Giriş yapmadan | Keşfet + ilan listesi + profiller görünür. Mesaj/ilan/değerlendirme → `/login` |
| **Müşteri** | Giriş yapınca (varsayılan) | İlan verir, ustaya mesaj atar, değerlendirir |
| **Usta** | Profilde usta vitrini doldurulunca | Yukarıdakilerin **hepsi** + "İşler" sekmesi + ilanlara mesaj atma |

> [!important] Tek profil tasarımı
> Başkasının profili de kendi profilin gibi görünür (`core/widgets/profile_header.dart`).
> Tek fark düğmeler: kendi profilinde "Düzenle | Bak", başkasınınkinde
> "Mesaj | Takip et".

## Alt bar — 5 sekme

`MainTab` = home · explore · work · chats · profile
(`core/widgets/role_bottom_bar.dart`)

| Sekme | Rota | Görünürlük |
|---|---|---|
| Ana Sayfa | `/` | Herkes |
| Keşfet | `/explore` | Herkes |
| **İşler** | `/panel/jobs` (usta) · `/jobs/mine` (müşteri) | Role göre HEDEF değişir |
| Mesajlar | `/chats` | Girişli |
| Profil | `/profile` | Herkes (misafirde giriş çağrısı) |

> Geri tuşu: Ana Sayfa'da sistemden çıkar, diğer sekmelerde önce Ana Sayfa'ya
> döner (sekme geçişi `context.go` — geçmiş yığını bırakmaz).

## Keşfet — 3 sekme

| Sekme | İçerik | Kapı |
|---|---|---|
| Ustalar | Usta arama | Yok |
| İlanlar | İş ilanları | **Giriş + usta modu** |
| **Mağaza** | Ürünler \| Talepler | **Yok** — misafir dâhil |

Mağaza 2026-08-10'da eklendi. Kapısı bilerek yoktur: herkes satabildiği için
herkes bakabilmeli. Yazma yolları router'da oturum ister.

**Talepler** = "şu ürüne ihtiyacım var" ilanları (`jobs` içinde
`product_request` kategorisi). Bunlar **usta feed'ine düşmez**. Bildirim
aynı il + `productCategoryCode` satıcılarına **anlık** gider
(`notifyProductRequestSellers`); akşam 19:00 özeti
(`sendProductRequestDigest`) anlık kaçıranları tamamlar. Tercih:
`productDigest`.

## Açılış kapıları — sırayla

`app_router.dart` global `redirect`. **Sıra önemlidir**, üstteki alttakini ezer:

1. Oturum yükleniyor → `/splash`
2. **Zorunlu güncelleme** (`isClientBelowMinVersion`) → `/force-update`
3. **Bakım modu** → `/maintenance`
4. **Onboarding görülmedi** → `/onboarding`
5. **Askıya alınmış hesap** → `/suspended`
6. `/register` → `/login` (kayıt ayrı ekran değil)
7. `/panel` → `/profile` (eski panel birleşik profile taşındı)

## İlan yaşam döngüsü — ÜÇ durum

```
[oluştur] → open ──(süre dolar)──→ expired
              └──(sahibi kaldırır)──→ cancelled
```

**İlan bir DUYURUDUR.** Usta atanmaz, "tamamlandı" denmez. Usta ilan sahibine
**doğrudan mesaj atar**; anlaşma taraflar arasındadır.
→ [[Is-Akisi-Durum-Makinesi]]

### İlan verme kapıları
| Kural | Değer | Nerede kesilir |
|---|---|---|
| Aynı anda açık ilan | **5** | Kural (`openJobQuotaOk`) — sayacı CF yazar |
| Günlük ilan hakkı | **10** | CF (kural gün bilgisi tutamaz) |
| Fotoğraf | **5** | İstemci + kural |
| Başlık / açıklama | 80 / 600 karakter | İstemci + kural |
| Düzenleme penceresi | **1 saat**, yalnız `open` | İstemci keser, kural `open` doğrular |

### Usta ilana mesaj atarken — DÖRT kapı
`job_detail_screen.dart` → `_messageOwner()`:
1. Hesap askıda değil (`user.suspended`)
2. Usta **müsait** (`profile.isAvailable`)
3. İlan ustayla **eşleşiyor** (`job.matchesArtisan` — meslek + İL)
4. E-posta **doğrulanmış** (`ensureEmailVerified`)

> [!warning] Müsaitlik yalnız MESAJI kapatır, listeyi DEĞİL (2026-08-10)
> Müsait olmayan usta ilanları **görür** ve bildirim **alır** — yalnız mesaj
> atamaz. Eskiden feed provider'ı ve iki ekran listeyi tamamen kapatıyordu;
> usta müsaitliğini açmadan piyasada ne olduğunu göremiyordu. Aramada
> görünmeme kuralı ise DEĞİŞMEDİ (`isAvailableAt` filtresi yerinde).

### Sohbet başlatan DÖRT yol — hepsi kapılı

Kapı gezinmede değil, **eylemde** durur. Sohbeti başlatan her giriş
`artisanAvailabilityAllowsNewChat` çağırmalıdır
(`artisan/application/availability_gate.dart`):

| Giriş | Dosya |
|---|---|
| İlan detayı → "Mesaj gönder" | `job_detail_screen.dart` (kendi kontrolü) |
| Usta profili → sohbet barı | `artisan_profile_screen.dart` |
| Usta profili → foto hızlı menü | `artisan_profile_screen.dart` |
| Genel kullanıcı profili | `public_user_screen.dart` |

> [!warning] Profili gizlemek çözüm DEĞİLDİR
> Liste açılınca ilan kartındaki avatar profile götürüyor ve kapı orada
> yoktu: ilandan mesaj atamayan usta profile geçip yazabiliyordu. Akla ilk
> gelen çözüm "avatarı tıklanamaz yap" olur — ama deliği kapatmaz (arama,
> favoriler, mevcut sohbet aynı kişiye götürür) ve meşru bir bilgiyi —
> ilanı kimin verdiğini — gereksizce saklar. Yeni bir `startChat` girişi
> eklersen kapıyı da ekle; regresyon testi çağrı sayısını sayar.

## Kolay İş (`quick_support`)

Normal ilandan iki farkı var:
- Süre **her zaman 1 gün** (`JobDuration.day1`)
- Meslek eşleşmesi gevşek: `kOtherProfession` veya `quick_support` taşıyan
  usta alır

> [!note] Bölge farkı KALKTI (2026-08-10)
> Eskiden yalnız Kolay İş il geneline giderdi, normal ilan ilçe şartı arardı.
> Artık **her ilan İL düzeyinde** eşleşir — ilçeye kısılan ilanlar çoğu
> ilçede alıcısız kalıyordu. İlçe elemez, yalnız "Yakınında" rozeti ve
> sıralama sinyalidir (`isNearbyForAreas`). Sunucu tarafı (`onJobCreated`
> bildirim fan-out'u) zaten yalnız ile bakıyordu; istemci ona hizalandı.

> Depolama kodu `quick_support` **değişmedi** (marka değişse de veri sabit).
> Ana sayfada kendi tam genişlikli kartı var.

## Sohbet — kişi başına TEK kutu

Kimlik: `chatIdFor(müşteri, usta)` — **`jobId` almaz**. Aynı çift kaç ilan
konuşursa konuşsun tek sohbette buluşur.

`canSend(uid) => !isLocked` — **serbest**. Eskiden "iletişimi müşteri başlatır"
kuralı vardı, kalktı. Kilit yalnız yönetici/arşiv kaynaklı.

| Kural | Değer |
|---|---|
| Mesaj uzunluğu | 4000 karakter |
| İki mesaj arası | 1.2 saniye |
| Dakikada en fazla | 20 mesaj |

İletişim maskeleme: telefon/e-posta/sosyal medya deseni mesajda maskelenir
(`core/utils/contact_masker.dart`). → [[Sohbet-Mimarisi]]

## Değerlendirme — kişiye, ilana değil

Kimlik: **`rev_{yazan}__{hedef}`** (`reviewDocId`). Deterministik olduğu için
bir kişi bir kişiyi **yalnızca bir kez** değerlendirir; ikinci gönderim aynı
dokümanı **günceller** ("Değerlendirmeyi Güncelle" başlığı çıkar, form eski
puanla dolu gelir).

> [!warning] Şu an HİÇBİR koşul yok
> Sohbet şartı bile aranmıyor — kullanıcı kararı. Sahte hesapla puan
> manipülasyonuna açık; altyapı (`hasChatBetween`) hazır, v2'de eklenebilir.

`docIdFor(chatId, dir)` modelde duruyor ama **yeni kayıtlar kullanmaz** —
eski `chatId` tabanlı kayıtları okumak için. → [[Degerlendirme-Sistemi]]

## Premium

- Ürün kimliği `sepette_hizmet_pro_monthly` — Play/App Store kaydı yokken
  `usta_cepte_*` buraya çekildi. Console'da ürün açıldıktan sonra **ASLA
  değişmez** (değiştirmek satın alma kaybettirir). Görünen marka İlanda Hizmet.
- `premiumFreeDuringBeta = true` → beta boyunca herkes Pro
- `isPremium` / `premiumExpiresAt` **yalnız sunucu** yazar

## Sayaçları kim yazar?

**İstemci hiçbirini yazmaz** — hepsi CF'ye ait:
ortalama puan · `reviewCount` · `completedJobs` · okunmamış sayacı ·
`openCount` (açık ilan limiti).

## Admin paneli — AYRI uygulama

`lib/main_admin.dart` · kendi Hosting sitesi (`alljob1-admin`).
Admin kodu tüketici binary'sine **hiç girmez**.

12 sekme: Özet · Şikayetler · Kullanıcılar · Ustalar · İlanlar · Yorumlar ·
Destek · Bildirim · Platform · *(superadmin)* Kadro · Denetim · Sistem

> [!warning] Sekme indeksleri elle eşlenir
> `admin_app.dart` içindeki `pages` ve `destinations` listeleri **paralel**;
> dashboard'daki `onOpenSection(i)` çağrıları da o indekslere bakar. Sekme
> ekler/çıkarırsan üçünü birden güncelle.

Hakemlik (anlaşmazlık) sekmesi 2026-08-09'da **kalktı** — `JobStatus.disputed`
diye bir durum yok. Kullanıcı şikayeti `reports` koleksiyonundan akmaya devam
ediyor.

## Web varlıkları — İKİ ayrı site

| Site | Kaynak | İçerik |
|---|---|---|
| `alljob1` | `hosting/` | Tanıtım + yasal metinler (el yazımı HTML) |
| `alljob1-admin` | `build/web` | Admin paneli (Flutter web) |

`hosting/` içindeki **yasal metinler koddaki gerçek davranışı anlatmak
zorundadır** — özellikle `hesap-silme.html` ve `gizlilik-politikasi.html`
`deleteAccount` CF'i ile birebir tutmalı. → [[Cloud-Functions-Haritasi]]

---
İlgili: [[Is-Akisi-Durum-Makinesi]] · [[Sohbet-Mimarisi]] · [[Degerlendirme-Sistemi]] · [[Navigasyon-ve-Rotalar]] · [[Guvenlik-Kurallari]]

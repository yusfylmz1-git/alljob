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
3. İlan ustayla **eşleşiyor** (`job.matchesArtisan` — meslek + bölge)
4. E-posta **doğrulanmış** (`ensureEmailVerified`)

## Kolay İş (`quick_support`)

Normal ilandan üç farkı var:
- Süre **her zaman 1 gün** (`JobDuration.day1`)
- **İL geneline** gider (normal ilan ilçe şartı arar)
- Meslek eşleşmesi gevşek: `kOtherProfession` veya `quick_support` taşıyan
  usta alır

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

- Ürün kimliği `usta_cepte_pro_monthly` — **ASLA değişmez** (marka üç kez
  değişti, kimlik ilk adında; değiştirmek satın alma kaybettirir)
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

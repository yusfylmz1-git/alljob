# 📐 PLAN · Profil sadeleştirme + rol ayrımının kaldırılması

> **Durum:** planlandı, uygulanmadı. Kullanıcı kararı 2026-08-07.
> İlgili bulgular: **B-16** (mod belirsizliği) · **K-02** (profil karmaşık) ·
> **K-06** (usta kartı görünümü) · K-12 sonrası.

---

## Ana fikir

**Rol ayrımı kalkıyor.** Artık "müşteri ekranı / usta ekranı" yok — herkes
**aynı ekranı** görür; usta modu açıksa **ek modüller belirir**.

Bu, B-16'nın (*"usta modunda mıyım müşteri modunda mıyım anlamıyorum"*)
kök çözümü: iki ayrı arayüz yerine tek arayüz + görünür ekler.

---

## 1. Alt bar

| | Şimdi | Sonra |
|---|---|---|
| Sekmeler | Ana Sayfa · Keşfet · **İlanlarım/İşler** · Mesajlar · Profil | Ana Sayfa · Keşfet · Mesajlar · Profil |
| Usta modunda | (aynı 5, "work" sekmesi role göre ad değiştirir) | **+ İlanlar** (5. sekme belirir) |

`MainTab.work` role göre ad değiştiriyordu (`İlanlarım` ⇄ `İşler`) — bu B-16'nın
kaynaklarından biriydi. Yeni düzende sekme **yalnız usta modunda var**.

⚠️ **Dikkat:** Müşterinin kendi ilanlarına erişimi kaybolmamalı. "İlanlarım"
profil ekranına taşınıyor (madde 2).

## 2. Profil ekranı — sadeleşme

**Kalacak:**
- Instagram tarzı başlık: avatar + 3'lü sayaç + isim/rozet + bio
- **İlanlarım** · **İşlerim**
- Takipçi / Takip edilenler (mevcut `favorites` altyapısı)
- Fotoğraf yükleme

**Taşınacak → yan menü (☰):**
- `HESABIM` grubunun tamamı: Çıkış Yap · Hesabı Sil · telefon doğrulama vb.

**Koşullu (yalnız usta modu):**
- Vitrin/dükkân modülleri, "Profili Düzenle" içindeki usta ayarları

## 3. "Profili Düzenle" birleşiyor

Tek giriş; içerik role göre:
- Usta modu **kapalı** → yalnız hesap alanları (ad, foto, telefon)
- Usta modu **açık** → mevcut `artisan_profile_edit_screen` alanları da burada

## 4. Müşteri sayaçları herkese açık olacak ⚠️

**Kullanıcı kararı:** müşteri sayacı (tamamlanan iş, değerlendirme) herkese
görünür olsun.

> [!warning] Bu bir GİZLİLİK KARARI değişikliğidir — CF + kural işi
> Şu an müşteri puanı ve iş sayacı `users/{uid}/private/rating` ve
> `private/jobStats` altında; kural `allow read: if isSelf(uid)` diyor
> (ADR-11: *"hassas veri private altına"*).
>
> Herkese açmak için:
> 1. **Yeni CF** — sayaçları public `users/{uid}` dokümanına da yazsın
>    (`completedJobsAsCustomer`, `reviewCountAsCustomer`, `ratingAsCustomer`)
> 2. **Kural** — bu alanlar istemciden yazılamaz olmalı (sayaç bütünlüğü,
>    CLAUDE.md kural 3)
> 3. **Geri dolum** — mevcut kullanıcılar için tek seferlik script
> 4. **Deploy** — functions + rules
>
> `jobStats.openCount` **açık ilan** sayısıdır, "toplam ilan" değil. Yeni
> sayaç gerekiyor.

---

## Uygulama sırası (önerilen)

| Faz | İş | Risk |
|---|---|---|
| **1** | Alt bar: work sekmesi → yalnız usta modunda "İlanlar" | Düşük |
| **2** | Profil: HESABIM → yan menüye taşı | Düşük |
| **3** | Profil başlığı: Instagram düzeni (avatar + sayaç + bio) | Orta |
| **4** | "Profili Düzenle" birleştirme | Orta |
| **5** | Usta profili (`artisan_profile_screen`): grid/sekme düzeni | Orta |
| **6** | Müşteri sayaçları: CF + kural + geri dolum + deploy | **Yüksek** |

**Faz 6 ayrı ele alınmalı** — tek backend işi ve deploy gerektiriyor.
Faz 1-5 yalnız istemci, testle doğrulanabilir.

---

## ⚠️ Test akışıyla çakışma

Kalan **~81 test adımı** (Bölüm 6·7·8·9) bu değişiklikten **etkilenir**:
alt bar, profil ekranı ve gezinme değişiyor.

**Karar gerekiyor:**
- **A)** Önce test bitsin (~1.5 saat), sonra dönüşüm → karşılaştırma zemini korunur
- **B)** Önce dönüşüm, testler yeni arayüzde yapılır → 6.x/7.x adımları
  yeniden yazılmalı

Bölüm 6 ve 7 iş akışını test ediyor (tamamlama, değerlendirme) — bunlar
profil/alt bar değişikliğinden **az** etkilenir. Bölüm 9 (yan modüller)
**çok** etkilenir.

---
İlgili: [[99-BULGULAR]] · [[00-TEST-PLANI]] · [[Mimari-Kararlar]] ADR-11

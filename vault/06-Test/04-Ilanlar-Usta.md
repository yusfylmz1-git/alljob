# 4 · İlanlar — Usta Tarafı

**Kapsam:** İlan keşfi, ilgi bildirme, geri çekme, bildirimler.
**Hangi hesap:** Usta

> [!important] Usta **teklif vermez, ilgi bildirir**
> Akış "İletişime Geç" düğmesiyle çalışır: bu hem bir ilgi kaydı oluşturur hem
> de müşteriye bildirim gönderir. **İlk mesajı müşteri yazar** — usta doğrudan
> mesaj atamaz. Bu bilinçli bir tasarım (spam engeli).

---

## 4.1 İlan keşfi

- [x] **4.1.1** Usta modunda **yakındaki işler / iş ilanları** listesi görünüyor
- [x] **4.1.2** Müşteri hesabıyla açtığınız ilan **listede çıkıyor**
- [x] **4.1.3** Filtreler çalışıyor (kategori, il/ilçe)
- [x] **4.1.4** İlan detayı açılıyor, müşteri bilgileri görünüyor
- [x] **4.1.5** İlan fotoğrafları açılıyor

## 4.2 İlgi bildirme ⭐

- [x] **4.2.1** İlan detayında **"Bildirim Gönder"** düğmesi var
      *(metin güncellendi — "İletişime Geç" değil, bilinçli)*
- [x] **4.2.2** Basınca ilgi kaydediliyor, *"müşterinin mesajı bekleniyor"* ✅
- [x] **4.2.3** ⚠️ İkinci kez basılamıyor — tekillik **doğru çalışıyor** ✅
- [x] **4.2.4** Müşteri tarafında **"İlgilenen Ustalar"da görünüyor** ✅
      *(3.4.5 de bununla kapandı)*
- [x] **4.2.5** Müşteriye bildirim → **uygulama içi ✅ · telefon push'u ❌**
      → ⚠️ **B-12** (🔴 P0)

> [!warning] Kritik davranış
> Usta ilgi bildirdikten sonra **sohbete yazamaz**. Müşteri ilk mesajı yazana
> kadar giriş kutusu yerine *"İletişimi müşteri başlatır"* şeridi görünmeli.
> Bu [[05-Mesajlar]] içinde test ediliyor.

## 4.3 İlgi geri çekme

- [x] **4.3.1** Verilen ilgi geri çekilebiliyor ✅
- [x] **4.3.2** Geri çekince müşterinin listesinden düşüyor ✅
- [x] **4.3.3** ⚠️ Geri çekip **tekrar** ilgi bildirilebiliyor ✅

## 4.4 Tekliflerim / İşlerim

- [x] **4.4.1** "İlgilendiğim İşler" sekmesinde görünüyor ✅
- [x] **4.4.2** Durum doğru ("Bekliyor")
- [ ] **4.4.3** Seçilmediğiniz ilan **"Reddedildi"** oluyor
      → ⏭️ **Bölüm 5'te** (müşteri başka ustayı seçince dolar)

## 4.5 Bildirimler

- [ ] **4.5.1** Yeni ilan açılınca **push** geliyor mu? → ❌ **B-12** (🔴 P0)
- [x] **4.5.2** Bildirim listesinde görünüyor ✅ (uygulama içi)
- [x] **4.5.3** Bildirime tıklayınca **doğru ilana** gidiyor ✅
- [ ] **4.5.4** Uygulama kapalıyken de push geliyor mu? → ❌ **B-12**

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| İlan usta feed'inde çıkmıyor | Ustanın mesleği ve bölgesi ilanla eşleşiyor mu? |
| İkinci kez ilgi → sayaç 2 oluyor | ⚠️ Tekillik bozuk — bildir |
| Push hiç gelmiyor | Bildirim izni verildi mi? Ayarlardan kontrol |
| "İletişime Geç" sonrası sohbete düşüyor ama yazamıyor | ✅ **Doğru davranış** |
| Usta doğrudan mesaj yazabiliyor | ⚠️ **Kural ihlali — hemen bildir** |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[05-Mesajlar]]

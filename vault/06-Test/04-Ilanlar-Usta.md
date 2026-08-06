# 4 · İlanlar — Usta Tarafı

**Kapsam:** İlan keşfi, ilgi bildirme, geri çekme, bildirimler.
**Hangi hesap:** Usta

> [!important] Usta **teklif vermez, ilgi bildirir**
> Akış "İletişime Geç" düğmesiyle çalışır: bu hem bir ilgi kaydı oluşturur hem
> de müşteriye bildirim gönderir. **İlk mesajı müşteri yazar** — usta doğrudan
> mesaj atamaz. Bu bilinçli bir tasarım (spam engeli).

---

## 4.1 İlan keşfi

- [ ] **4.1.1** Usta modunda **yakındaki işler / iş ilanları** listesi görünüyor
- [ ] **4.1.2** Müşteri hesabıyla açtığınız ilan **listede çıkıyor**
  - Çıkmıyorsa: meslek eşleşmesi ve bölge filtresini kontrol edin
- [ ] **4.1.3** Filtreler çalışıyor (kategori, il/ilçe)
- [ ] **4.1.4** İlan detayı açılıyor, müşteri bilgileri görünüyor
- [ ] **4.1.5** İlan fotoğrafları açılıyor

## 4.2 İlgi bildirme ⭐

- [ ] **4.2.1** İlan detayında **"İletişime Geç"** düğmesi var
- [ ] **4.2.2** Basınca ilgi kaydediliyor, **onay mesajı** çıkıyor
- [ ] **4.2.3** ⚠️ **Aynı ilana ikinci kez** basın → ikinci kayıt oluşmamalı
      (güncelleme olmalı, sayaç 1'de kalmalı)
- [ ] **4.2.4** Müşteri tarafında **"İlgilenen Ustalar"da görünüyor**
      (müşteri hesabıyla doğrulayın)
- [ ] **4.2.5** Müşteriye **bildirim/push** gitti mi?

> [!warning] Kritik davranış
> Usta ilgi bildirdikten sonra **sohbete yazamaz**. Müşteri ilk mesajı yazana
> kadar giriş kutusu yerine *"İletişimi müşteri başlatır"* şeridi görünmeli.
> Bu [[05-Mesajlar]] içinde test ediliyor.

## 4.3 İlgi geri çekme

- [ ] **4.3.1** Verilen ilgi geri çekilebiliyor
- [ ] **4.3.2** Geri çekince müşterinin listesinden düşüyor
- [ ] **4.3.3** ⚠️ Geri çekip **tekrar** ilgi bildirebiliyor musunuz?
      (yeniden aktifleşmeli)

## 4.4 Tekliflerim / İşlerim

- [ ] **4.4.1** "Tekliflerim" listesi ilgi bildirdiğiniz ilanları gösteriyor
- [ ] **4.4.2** Durum doğru ("Bekliyor" / "Kabul edildi" / "Reddedildi")
- [ ] **4.4.3** Seçilmediğiniz ilan **"Reddedildi"** oluyor
      (müşteri başka ustayı seçince)

## 4.5 Bildirimler

- [ ] **4.5.1** Yeni ilan açılınca **push** geliyor mu? (uygun meslek/bölgede)
- [ ] **4.5.2** Bildirim listesinde görünüyor
- [ ] **4.5.3** Bildirime tıklayınca **doğru ilana** gidiyor
- [ ] **4.5.4** Uygulama kapalıyken de push geliyor mu?

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

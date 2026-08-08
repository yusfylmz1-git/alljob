# 4 · Takip Sistemi ⭐

**Kapsam:** Takip et/bırak, iki sekmeli liste, karşılıklı rozet, genel profil,
takip bildirimi.
**Hesap:** A + B · **Süre:** ~20 dk

> [!important] Tamamen yeni
> Eskiden yalnız **müşteri → usta** takip edilebiliyordu. Artık **herkes
> herkesi** takip eder (Instagram gibi).

---

## 4.1 Takip et / bırak

- [ ] **4.1.1** Usta profilinde sağ üstte **kalp** düğmesi var
- [ ] **4.1.2** Dokununca takip başlıyor, *"Takip ediliyor."* mesajı
- [ ] **4.1.3** Kalp dolu hale geliyor
- [ ] **4.1.4** Tekrar dokununca takipten çıkıyor
- [ ] **4.1.5** ⚠️ **Kendi profilinizde kalp GÖRÜNMEMELİ**
- [ ] **4.1.6** ⭐ **Usta modu AÇIKKEN de takip edebiliyorsunuz**
      *(eskiden usta modunda düğme hiç görünmüyordu)*

## 4.2 Takip listesi — iki sekme

- [ ] **4.2.1** Profildeki **"takip"** sayacına dokunun → liste açılıyor
- [ ] **4.2.2** İki sekme var: **Takipçiler | Takip**
- [ ] **4.2.3** "Takip" sekmesi takip ettiklerinizi gösteriyor
- [ ] **4.2.4** ⭐ Profildeki **"takipçi"** sayacına dokunun →
      **Takipçiler sekmesi açık** gelmeli
      *(eskiden yanlış liste açılıyordu)*
- [ ] **4.2.5** Boş listede açıklayıcı metin çıkıyor
- [ ] **4.2.6** Listedeki satırda ad + fotoğraf görünüyor
- [ ] **4.2.7** Usta takip edildiyse **meslek + puan** satırı da var
- [ ] **4.2.8** Sıradan kullanıcı takip edildiyse **meslek satırı YOK**
- [ ] **4.2.9** Aşağı çekince yenileme çalışıyor

## 4.3 Genel kullanıcı profili (`/u/:uid`)

> Usta vitrini **olmayan** kişiler için yeni ekran.

- [ ] **4.3.1** Takip listesinden bir **usta olmayan** kişiye dokunun
- [ ] **4.3.2** ⭐ Profil açılıyor ve **BOŞ DEĞİL** — avatar, ad, sayaçlar var
      *(eskiden usta profili ekranı açılıp boş görünüyordu)*
- [ ] **4.3.3** "Bu kullanıcı henüz usta vitrini açmamış" yazısı var
- [ ] **4.3.4** **Takip Et** ve **Mesaj Gönder** düğmeleri çalışıyor
- [ ] **4.3.5** ⚠️ **E-posta / telefon GÖRÜNMEMELİ**
- [ ] **4.3.6** Usta olan birine dokununca **zengin usta profili** açılıyor
      (otomatik devretme)
- [ ] **4.3.7** Kendi profilinize girerseniz takip/mesaj düğmeleri gizli

## 4.4 Karşılıklı takip rozeti

**Hazırlık:** B hesabı A'yı takip etsin.

- [ ] **4.4.1** A hesabıyla B'nin profiline girin
- [ ] **4.4.2** ⭐ Ad altında **"Seni takip ediyor"** rozeti görünüyor
- [ ] **4.4.3** B takipten çıkınca rozet **kayboluyor**
- [ ] **4.4.4** Kendi profilinizde rozet görünmüyor

## 4.5 Takip bildirimi

> ⚠️ **İki cihaz gerekir** — tek cihazda tam test edilemez.

- [ ] **4.5.1** B, A'yı takip etsin
- [ ] **4.5.2** A'nın **bildirim listesinde** "Yeni takipçi" görünüyor
- [ ] **4.5.3** Bildirime dokununca **B'nin profili** açılıyor
- [ ] **4.5.4** A'nın telefonuna **push** geliyor *(2. cihaz)*
- [ ] **4.5.5** ⭐ B takipten çıkıp **tekrar takip etsin** → listede
      **tek satır** kalmalı (mükerrer bildirim yok)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Takipçi sayacı yanlış liste açıyor | ⚠️ Regresyon — bildir |
| Usta olmayan profil boş | ⚠️ `/u/:uid` devretmesi bozuk |
| Usta modunda kalp yok | ⚠️ Eski kısıt geri gelmiş |
| Takip-bırak-takip → 2 bildirim | ⚠️ Deterministik kimlik bozuk |
| Profilde e-posta görünüyor | 🔴 **Gizlilik — hemen bildir** |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[05-Ilan-Verme]]

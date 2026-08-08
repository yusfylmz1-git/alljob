# 8 · Güvenlik ve Şikayet

**Kapsam:** Engelleme, şikayet, gizlilik, hesap silme.
**Hangi hesap:** İkisi de · **Bağımsız** — istediğiniz zaman

---

## 8.1 Kullanıcı engelleme

- [ ] **8.1.1** Sohbet menüsünden **"Kullanıcıyı Engelle"** var
- [ ] **8.1.2** Engelleyince onay soruluyor
- [ ] **8.1.3** ⚠️ Engellenen kişi size **mesaj yazamıyor**
      (karşı hesapla deneyin — net bir engel olmalı)
- [ ] **8.1.4** Engellenen sohbet listenizden gizleniyor
- [ ] **8.1.5** **Engeli kaldır** çalışıyor, sohbet geri geliyor
- [ ] **8.1.6** Profil → **Engellenenler** listesi doğru gösteriyor

## 8.2 Şikayet

- [ ] **8.2.1** Sohbet menüsünden **"Şikayet Et"** var
- [ ] **8.2.2** Şikayet nedeni seçilebiliyor
- [ ] **8.2.3** Gönderilince onay mesajı çıkıyor
- [ ] **8.2.4** İlan/ürün/usta profilinden de şikayet edilebiliyor

## 8.3 Gizlilik ⭐

- [ ] **8.3.1** ⚠️ Telefon numaranız **başkasının gördüğü profilde YOK**
      (karşı hesapla profilinize bakın)
- [ ] **8.3.2** ⚠️ E-posta adresiniz başkasına **görünmüyor**
- [ ] **8.3.3** Sohbette iletişim bilgisi **maskeleniyor** (→ [[05-Mesajlar]] 5.6)

> [!warning] Bunlardan biri görünüyorsa
> Ciddi bir gizlilik sorunudur — hemen bildirin. Firestore alan bazlı gizleme
> yapamaz, o yüzden hassas veri ayrı bir yerde tutulmalı.

## 8.4 Hesap silme

> ⚠️ **Dikkat:** Gerçekten siler. Test hesabıyla yapın, ana hesapla değil.

- [ ] **8.4.1** Profil/ayarlardan **hesap silme** bulunabiliyor
- [ ] **8.4.2** Uyarı ve onay isteniyor (tek tıkla silinmemeli)
- [ ] **8.4.3** Silince oturum kapanıyor
- [ ] **8.4.4** Aynı hesapla tekrar giriş → **yeni/boş hesap** gibi davranıyor

## 8.5 Yasal metinler

- [ ] **8.5.1** Gizlilik politikası, kullanım koşulları, KVKK açılıyor
- [ ] **8.5.2** Metinler okunabilir (boş sayfa değil)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| ⚠️ Telefon/e-posta başkasına görünüyor | **Gizlilik — en yüksek öncelik** |
| Engellenen kişi hâlâ mesaj yazabiliyor | ⚠️ Güvenlik — bildir |
| Şikayet gönderilmiyor | Hata mesajı ne diyor |
| Hesap silindi ama veriler duruyor | Hangi veri (ilan, mesaj, profil) |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[09-Yan-Moduller]]

# 2 · Profil ve Rol

**Kapsam:** Tek hesap iki rol (müşteri ↔ usta), usta profili açma, telefon
doğrulama.

> [!info] Tek hesap, çift rol
> Kullanıcı hem müşteri hem usta olabilir. `activeMode` arayüz modunu belirler;
> `hasArtisanProfile` usta profili açıp açmadığını. Rol değiştirmek **yeni hesap
> açmak değildir** — aynı hesap görünüm değiştirir.

---

## 2.1 Profil sayfası

- [ ] **2.1.1** Menü/alt bardan **Profil** açılıyor
- [ ] **2.1.2** Ad, fotoğraf, e-posta doğru görünüyor
- [ ] **2.1.3** Profil düzenleme açılıyor, **kaydetme çalışıyor**
- [ ] **2.1.4** Kaydettikten sonra değişiklik **hemen** görünüyor
      (geri gidip gelmeye gerek kalmadan)

## 2.2 Rol değiştirme

- [ ] **2.2.1** Müşteri ↔ Usta geçiş düğmesi/sekmesi bulunabiliyor
- [ ] **2.2.2** Usta moduna geçince **alt bar / menü değişiyor**
      (usta paneli, işlerim, tekliflerim gibi)
- [ ] **2.2.3** Müşteri moduna dönünce eski görünüm geliyor
- [ ] **2.2.4** ⚠️ Rol değiştirince **oturum kapanmıyor**, veri kaybolmuyor

## 2.3 Usta profili açma

> İlk kez usta olacak hesapla yapın. Zaten usta profili varsa 2.4'e geçin.

- [ ] **2.3.1** "Usta ol / Usta profili oluştur" akışı başlatılabiliyor
- [ ] **2.3.2** **Meslek seçimi** çalışıyor (arama/liste)
- [ ] **2.3.3** **Hizmet bölgesi** seçilebiliyor (il/ilçe)
- [ ] **2.3.4** Zorunlu alanlar boşken **kaydet engelleniyor**, uyarı net
- [ ] **2.3.5** Kaydedince usta profili oluşuyor ve **Keşfet'te görünüyor**
      (diğer hesapla arayıp doğrulayın)

## 2.4 Usta profil düzenleme

- [ ] **2.4.1** Profil fotoğrafı yüklenebiliyor
- [ ] **2.4.2** Açıklama/deneyim yılı düzenlenebiliyor
- [ ] **2.4.3** **Müsaitlik takvimi** (çalışma saatleri) ayarlanabiliyor
- [ ] **2.4.4** "Şu an müsait değilim" (paused) modu çalışıyor
- [ ] **2.4.5** Değişiklikler **karşı taraftan** görünüyor (diğer hesapla bak)

## 2.5 Telefon doğrulama (mavi tik)

- [ ] **2.5.1** Telefon doğrulama akışı başlatılabiliyor
- [ ] **2.5.2** SMS geliyor, kod girilince doğrulanıyor
- [ ] **2.5.3** Doğrulanınca **mavi tik / rozet** görünüyor
- [ ] **2.5.4** ⚠️ Telefon numarası **herkese açık profilde görünmemeli**
      (gizlilik — hassas veri ayrı yerde tutulur)

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Rol değişince ekran boş kalıyor | Hangi modda, hangi ekran |
| Profil kaydı "kaydedildi" diyor ama değişmiyor | Tazeleme sorunu — önemli |
| Usta profili Keşfet'te çıkmıyor | Arama/filtre mi, kayıt mı? |
| Telefon numarası profilde görünüyor | ⚠️ **Gizlilik sorunu — hemen bildir** |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[03-Ilanlar-Musteri]]

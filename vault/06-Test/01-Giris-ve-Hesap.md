# 1 · Giriş ve Hesap

**Kapsam:** İlk açılış, Google girişi, e-posta doğrulama, oturum kalıcılığı, çıkış.

---

## 1.1 İlk açılış (temiz kurulum)

> Uygulamayı sildiyseniz veya ilk kez kuruyorsanız.

- [ ] **1.1.1** Uygulama açılıyor, çökmüyor
- [ ] **1.1.2** **Tanıtım (onboarding) ekranı** geliyor
  - Cihazda **bir kez** gösterilir, oturumdan bağımsız
- [ ] **1.1.3** Tanıtımı geçince ana ekran açılıyor
- [ ] **1.1.4** Uygulamayı kapatıp açın → tanıtım **tekrar gelmemeli**

## 1.2 Misafir gezinme (giriş yapmadan)

Misafir bazı yerleri görebilir, bazılarında girişe yönlendirilir.

- [ ] **1.2.1** Ana ekran ve **Keşfet** açılıyor
- [ ] **1.2.2** Bir **usta profiline** girilebiliyor
- [ ] **1.2.3** **Hemen Lazım** vitrini (`/jobs/quick`) görünüyor
- [ ] **1.2.4** Bir **ürün detayı** açılabiliyor
- [ ] **1.2.5** ⚠️ **Mesajlar**a basınca → **giriş ekranına** yönlendiriyor
- [ ] **1.2.6** ⚠️ **Favoriler / Bildirimler / Profil** → giriş ekranı

> Beklenen: misafir keşfedebilir, işlem yapamaz.

## 1.3 Google ile giriş

- [ ] **1.3.1** Giriş ekranında **Google ile Giriş** düğmesi çalışıyor
- [ ] **1.3.2** Google hesap seçici açılıyor
- [ ] **1.3.3** Hesap seçince uygulamaya dönüyor, **ana ekran** açılıyor
- [ ] **1.3.4** Kullanıcı adı/fotoğrafı doğru görünüyor (profil veya menüde)
- [ ] **1.3.5** ❌ **İptal ederseniz** (hesap seçmeden geri) → uygulama takılmıyor,
      giriş ekranında kalıyor, hata mesajı anlaşılır

## 1.4 E-posta doğrulama kapısı

> Google girişinde e-posta genelde **zaten doğrulanmış** gelir. Doğrulanmamışsa
> ilan açma ve usta iletişimi **engellenir**.

- [ ] **1.4.1** Profil/menüde e-posta doğrulama durumu görünüyor mu?
- [ ] **1.4.2** Doğrulanmamışsa → doğrulama isteme ekranı/kartı çıkıyor mu?
- [ ] **1.4.3** ⚠️ Doğrulanmamış hesapla **ilan açmayı** deneyin → net bir
      uyarı almalı, sessizce başarısız **olmamalı**

## 1.5 Oturum kalıcılığı

- [ ] **1.5.1** Uygulamayı tamamen kapatıp açın → **oturum açık kalmalı**
      (tekrar giriş istememeli)
- [ ] **1.5.2** Telefonu uçak moduna alıp açın → çevrimdışı uyarısı çıkıyor mu?
- [ ] **1.5.3** İnternet gelince kendini toparlıyor mu?

## 1.6 Çıkış

- [ ] **1.6.1** Menüden **Çıkış Yap** çalışıyor
- [ ] **1.6.2** Çıkınca ana ekrana (misafir görünümü) dönüyor
- [ ] **1.6.3** Çıktıktan sonra **Mesajlar**a basınca giriş istiyor

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Giriş sonrası boş/beyaz ekran | Hangi ekranda kaldığını yaz |
| "permission-denied" benzeri hata | Ekran görüntüsü al — kural sorunu olabilir |
| Tanıtım her açılışta geliyor | Cihaz belleği yazılmıyor demektir |
| Oturum kendiliğinden kapanıyor | Bilinen bir tuzak — hemen söyleyin |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[02-Profil-ve-Rol]]

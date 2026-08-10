# İlanda Hizmet — Sıralı Test Adımları

| Alan | Değer |
|---|---|
| **Amaç** | Play Store öncesi sistemi baştan sona elle doğrulamak |
| **Tarih** | 2026-08-10 |
| **Dal** | `hemen-lazim` |
| **Admin canlı** | https://alljob1-admin.web.app |
| **Tanıtım** | https://www.ilandahizmet.com (veya Firebase hosting) |
| **Nasıl kullanılır** | Yukarıdan aşağı **sırayla** ilerle. Her maddeyi bitirince `[x]` yap. Takılırsan madde numarası + ekran + hata yaz. |

> Bu dosya **cihaz / tarayıcı test senaryosudur**.  
> Birim testlerin (`flutter test`) yerini tutmaz; onların yanında koşulur.

---

## Nasıl işaretlenir?

- `[ ]` = henüz yapılmadı  
- `[x]` = geçti  
- `[!]` = hata / bloke (not düş)  
- Cihaz: mümkünse **Android fiziksel cihaz** + bir kez **Chrome web** (admin)  

**Hazır hesap önerisi (önceden aç):**

| Rol | Not |
|---|---|
| A — Müşteri | Yeni e-posta, usta profili yok |
| B — Usta | Usta vitrini açık, meslek + il seçili, mümkünse telefon doğrulu |
| C — Admin | Superadmin claim (`alljob1-admin`) |
| İki cihaz / iki tarayıcı | Sohbet ve bildirim için ideal |

---

# BÖLÜM 0 — Başlamadan önce (ortam)

### 0.1 Kod ve sürüm
- [ ] `git status` temiz veya bilinen değişiklikler not edildi
- [ ] Branch: `hemen-lazim` (veya test ettiğin sürüm not edildi)
- [ ] Uygulama **Firebase canlı** backend ile çalışıyor (`useFirebaseBackend = true`)
- [ ] `flutter analyze` → issues yok (geliştirici kontrolü)

### 0.2 Deploy / canlı servisler
- [ ] Admin paneli açılıyor: https://alljob1-admin.web.app
- [ ] Tanıtım / yasal sayfalar erişilebilir
- [ ] Firestore Indexes → `products` indeksleri **READY** (Console)
- [ ] Cloud Functions listesinde kritik olanlar var (özellikle: `deleteAccount`, `adminModerateProduct`, `adminBulkPlanUpdate`, `publishProduct` vb.)
- [ ] App Check: debug/canlıda login ve yazma **bloklanmıyor**

### 0.3 Cihaz hazırlığı
- [ ] Temiz kurulum veya son AAB/APK / `flutter run`
- [ ] İnternet stabil
- [ ] Bildirim izni (Android 13+) denenecekse açık
- [ ] Konum / depolama istekleri için hazır

**Bölüm 0 notu:** ________________________________

---

# BÖLÜM 1 — İlk açılış ve hesap

### 1.1 Splash / onboarding
- [ ] Uygulama splash sonrası takılmadan açılıyor
- [ ] Onboarding (varsa) okunabilir, atlanabiliyor veya tamamlanabiliyor
- [ ] Misafirken Keşfet / ana içerik **okunabiliyor**
- [ ] Yazma eylemi (ilan, mesaj…) → **giriş**e yönlendiriyor

### 1.2 Kayıt
- [ ] E-posta + şifre ile kayıt oluyor
- [ ] Zayıf şifre / hatalı e-posta için anlaşılır Türkçe hata
- [ ] Kayıt sonrası oturum açık, çökme yok
- [ ] E-posta doğrulama akışı (gönder / yenile) bozulmuyor

### 1.3 Giriş / çıkış
- [ ] Doğru bilgilerle giriş
- [ ] Yanlış şifrede anlaşılır hata
- [ ] Çıkış → misafir / login ekranı
- [ ] Tekrar giriş sorunsuz
- [ ] (Varsa) Google ile giriş dene; iptal edilince çökme yok

### 1.4 Şifre sıfırlama
- [ ] “Şifremi unuttum” e-posta kabul ediyor
- [ ] Spam kontrolü notu (kullanıcı tarafı)

**Bölüm 1 notu:** ________________________________

---

# BÖLÜM 2 — Profil ve roller

### 2.1 Müşteri profili
- [ ] Profil sekmesi açılıyor
- [ ] Ad / foto düzenleme kaydoluyor
- [ ] Ortak alanlar (hakkımda, sosyal) kaydoluyor; **silince geri gelmiyor**
- [ ] Yan menü: İlanlarım, yasal linkler, yardım erişilebilir

### 2.2 Usta olma
- [ ] “Hizmet vermeye başla” / usta profili akışı açılıyor
- [ ] Meslek seçimi (kategori + arama) çalışıyor
- [ ] İl / ilçe seçimi: klavye istemeden liste; arama ile filtre
- [ ] Kayıt sonrası usta vitrini oluşuyor
- [ ] **Meslek + bölge seçmeden geri basınca** usta modu zorla açık kalmıyor (kurulum yarımsa müşteriye dönmeli)
- [ ] Müşteri ⇄ Usta mod geçişi stabil

### 2.3 Usta profil düzenleme
- [ ] Hakkımda, foto, hizmet bölgesi güncelleniyor
- [ ] Kaydet sonrası profil ekranına dönülüyor
- [ ] Müsaitlik / takvim (varsa) kaydoluyor
- [ ] Telefon doğrulama: sonsuz bekleme yok; durum anlaşılır

**Bölüm 2 notu:** ________________________________

---

# BÖLÜM 3 — Keşfet ve arama

### 3.1 Keşfet sekmeleri
- [ ] Ustalar listesi yükleniyor
- [ ] Ürünler / Mağaza sekmesi (açıksa) yükleniyor
- [ ] Talepler / ilgili sekmeler boşken “boş durum” metni var
- [ ] Çekmece menü: geri tuşu önce menüyü kapatıyor (uygulamayı arka plana atmadan)

### 3.2 Filtre / detaylı arama
- [ ] İl, meslek, anahtar kelime süzüyor
- [ ] **Temizle** hem seçimi hem listeyi hemen sıfırlıyor
- [ ] Sonuç kartları tıklanınca detaya gidiyor

### 3.3 Usta kartı / detay
- [ ] Puan, meslek, bölge görünüyor
- [ ] Platform onayı / doğrulama rozeti (varsa) doğru
- [ ] Gizli vitrin (admin gizlediyse) listede çıkmıyor

**Bölüm 3 notu:** ________________________________

---

# BÖLÜM 4 — İlan (müşteri)

### 4.1 İlan oluşturma
- [ ] “İş ilanı ver” **tek net girişten** açılıyor
- [ ] Başlık, açıklama, kategori, il/ilçe zorunlulukları çalışıyor
- [ ] Foto ekleme / kaldırma
- [ ] Yayın sonrası ilan listede veya “İlanlarım”da görünüyor

### 4.2 İlanlarım
- [ ] **Müşteri modunda** da “İlanlarım” görünüyor
- [ ] Kendi ilanı açılıyor, düzenleme/iptal (desteklenen aksiyonlar) çalışıyor
- [ ] Başkasının ilanında yetkisiz aksiyon yok

### 4.3 İlan detayı (usta gözü)
- [ ] Usta yakındaki / ilgili ilanı görebiliyor
- [ ] “Mesaj at / sohbet” müsaitlik kapısına uyuyor (premium/beta kuralı)
- [ ] Kapı kapalıysa anlaşılır mesaj; profil yine görülebilir

**Bölüm 4 notu:** ________________________________

---

# BÖLÜM 5 — Sohbet

### 5.1 Sohbet açma
- [ ] Müşteri → usta (profil veya ilan üzerinden) tek sohbet kutusu
- [ ] Aynı çift için **ikinci kutu açılmıyor** (kimlik tutarlı)
- [ ] Mesajlar listesinde sohbet görünüyor

### 5.2 Mesajlaşma
- [ ] Metin gönder / al (iki hesap)
- [ ] Görsel mesaj (varsa)
- [ ] Okundu / sıralama bozulmuyor
- [ ] Askıdaki kullanıcı yazamıyor (mümkünse dene)

### 5.3 Bildirim (mümkünse)
- [ ] Arka planda mesaj bildirimi geliyor
- [ ] Tıklanınca doğru sohbete gidiyor

**Bölüm 5 notu:** ________________________________

---

# BÖLÜM 6 — Değerlendirme

### 6.1 Puanlama
- [ ] Profil üzerinden değerlendir açılıyor
- [ ] Yıldız + **hazır etiketler** (serbest uzun yorum yok / beklenen davranış)
- [ ] Gönderim sonrası puan özeti güncelleniyor (CF gecikmesi 1–2 sn normal)
- [ ] Aynı kişiye ikinci kez → güncelleme (yeni kayıt şişirmiyor)

**Bölüm 6 notu:** ________________________________

---

# BÖLÜM 7 — Mağaza (Ürünler + Talepler)

> Mağaza kapalıysa (`productsEnabled = false`) bu bölümü atla; admin Sistem’den kontrol et.

### 7.1 Ürün vitrini
- [ ] Keşfet → Ürünler listeleniyor
- [ ] Kategori süzme (ürün kategorileri; meslek listesi değil)
- [ ] Ürün detayı: foto, fiyat, satıcı

### 7.2 Ürün yayınlama (satıcı)
- [ ] Taslak oluştur
- [ ] Yayın / inceleme kuyruğu (force review açıksa `pending_review`)
- [ ] Onay sonrası vitrinde (admin onayladıysa)
- [ ] Sahip düzenleme / duraklat / kaldır

### 7.3 Ürün talebi (varsa)
- [ ] Talep oluşturma
- [ ] Usta tarafında görünürlük / mesaj

### 7.4 Admin ürün moderasyonu
- [ ] Admin → **Ürünler**: kuyruk yükleniyor (indeks READY)
- [ ] Onay / red / gizle çalışıyor
- [ ] Canlı vitrine yansıma

**Bölüm 7 notu:** ________________________________

---

# BÖLÜM 8 — Güvenlik, şikayet, askı

### 8.1 Şikayet
- [ ] Kullanıcı / mesaj / ilan / ürün şikayet formu
- [ ] Admin → **Şikayetler** kuyruğunda görünüyor
- [ ] Karar (çözüldü / reddedildi) kaydoluyor
- [ ] Şikayet edilen kişi dosyası açılıyor

### 8.2 Askı
- [ ] Admin kişiyi askıya alıyor
- [ ] Askıdaki hesap içerik üretemiyor (anlaşılır mesaj)
- [ ] Askı kaldırılınca normale dönüyor

### 8.3 Usta vitrin bayrakları
- [ ] Platform onayı rozeti
- [ ] Vitrini gizle → Keşfet’ten düşer
- [ ] Öne çıkar (görünür etki varsa)

**Bölüm 8 notu:** ________________________________

---

# BÖLÜM 9 — Admin paneli (canlı)

**Adres:** https://alljob1-admin.web.app  
**Yetkisiz e-posta** ile dene → erişim reddi beklenir.

### 9.1 Giriş ve kabuk
- [ ] Admin giriş
- [ ] Özet / menü / mobil çekmece
- [ ] Hesabım → şifre değiştir / sıfırlama e-postası (e-posta hesabı)

### 9.2 Özet
- [ ] KPI kartları dolu veya “yeniden kur” anlaşılır
- [ ] Superadmin: **Dağılım içgörüleri** yükleniyor (veya boş veri net)
- [ ] Hızlı erişim sekmeleri doğru yere gidiyor

### 9.3 Kullanıcılar
- [ ] Dizin listeleniyor
- [ ] E-posta / UID arama
- [ ] Dizinde ad süzme
- [ ] Kart → **kişi hub**: not, aktivite, askı
- [ ] Usta ise vitrin araçları hub’da

### 9.4 Usta vitrini / İlanlar / Şikayetler
- [ ] Usta listesinde **ad + e-posta** (meslek kodu yığını değil)
- [ ] Arama çalışıyor
- [ ] İlan arama + ID
- [ ] Şikayet dili anlaşılır

### 9.5 Superadmin
- [ ] Kadro, Denetim (okunabilir log), Sistem bayrakları
- [ ] Toplu Plan (dikkat: production’da önce dry-run)
- [ ] Yorumlar sekmesi **yok** (beklenen)

**Bölüm 9 notu:** ________________________________

---

# BÖLÜM 10 — Hesap silme ve yasal (Play zorunlu)

### 10.1 Uygulama içi
- [ ] Hesap sil yolu bulunuyor
- [ ] Onay uyarısı net (geri alınamaz)
- [ ] Silme sonrası giriş yapılamıyor
- [ ] Kişisel veri silinmiş / anonimleşmiş (spot kontrol: profil, ilan sahipliği)

### 10.2 Web
- [ ] Hesap silme bilgilendirme sayfası (mağaza URL’si)
- [ ] Gizlilik / KVKK / kullanım koşulları güncel marka: **İlanda Hizmet**
- [ ] Metinler “hâlâ X yapıyor” diye yalan söylemiyor

**Bölüm 10 notu:** ________________________________

---

# BÖLÜM 11 — Premium / müsaitlik (usta)

### 11.1 Beta ücretsiz açıksa
- [ ] Premium kapısı açıkken müsait usta ile sohbet / ilgili aksiyon çalışıyor

### 11.2 Kapı kapalı simülasyonu (mümkünse admin Sistem)
- [ ] Premium’suz usta `isAvailableAt` kapalı gibi davranıyor
- [ ] Anlaşılır “premium / müsait değil” mesajı
- [ ] Ödemeli abone (varsa) etkilenmiyor

**Bölüm 11 notu:** ________________________________

---

# BÖLÜM 12 — Regresyon ve kenar durumlar

- [ ] Usta olmayan hesap “İşler” / usta-only yerlerde bozulmuyor
- [ ] Derin link / geri yığını: menü → geri sırası doğru
- [ ] Uçak modu → hata ekranı / snackbar, sonsuz spinner yok
- [ ] Büyük foto yükleme / yavaş ağ (mümkünse)
- [ ] Çift hızlı tıklama: çift ilan / çift mesaj basmıyor (makul)

**Bölüm 12 notu:** ________________________________

---

# BÖLÜM 13 — Play Store paket kontrolü (yayın günü)

### 13.1 Teknik paket
- [ ] `applicationId` / paket: `com.sepettehizmet.app` (bilinçli eski ad)
- [ ] Sürüm kodu / adı artırıldı
- [ ] Release imzalı AAB üretildi
- [ ] ProGuard / minify çökme yok (smoke)

### 13.2 Play Console
- [ ] Mağaza listesi (TR): kısa/uzun açıklama, ekran görüntüleri
- [ ] İkon / özellik grafiği
- [ ] Data Safety formu
- [ ] Gizlilik politikası URL
- [ ] Hesap silme URL
- [ ] Hedef kitle / içerik derecelendirme
- [ ] Closed testing → en az 1 dış testçi veya internal

### 13.3 Son kapı
- [ ] Kritik `[!]` maddeler kapatıldı veya bilinen risk olarak imzalandı
- [ ] “Production’a bas” kararı verildi

**Bölüm 13 notu:** ________________________________

---

# Özet skor kartı (test bitince doldur)

| Bölüm | Geçti / Toplam | Bloke var mı? |
|---|---|---|
| 0 Ortam | / | |
| 1 Hesap | / | |
| 2 Profil / rol | / | |
| 3 Keşfet | / | |
| 4 İlan | / | |
| 5 Sohbet | / | |
| 6 Değerlendirme | / | |
| 7 Mağaza | / | |
| 8 Şikayet / askı | / | |
| 9 Admin | / | |
| 10 Yasal / silme | / | |
| 11 Premium | / | |
| 12 Kenar | / | |
| 13 Play paket | / | |

**Genel karar:**  
- [ ] Play’e hazır  
- [ ] Closed testing’e hazır, production değil  
- [ ] Kritik düzeltme şart — liste: _______________

---

# Hızlı yol haritası (zamanın azsa)

Sadece **1–2 saat** varsa şu sırayla minimum tur:

1. Kayıt + giriş + çıkış  
2. Usta profili aç + meslek/bölge  
3. İlan ver (müşteri) + İlanlarım  
4. İki hesap sohbet  
5. Değerlendirme  
6. Admin: kullanıcı + şikayet + ürün kuyruğu  
7. Hesap silme (test hesabı)  
8. Yasal URL’ler tarayıcıda  

Sonra Bölüm 13.

---

# İlgili dosyalar

| Dosya | Ne için |
|---|---|
| `Grok/GrokTest.md` | Eski analiz / boşluk raporu |
| `vault/06-Test/Yapılacaklar.md` | Cihaz bulguları geçmişi |
| `vault/05-Operasyon/Deploy-ve-Ortam.md` | Deploy komutları |
| `ILERLEME_NOTLARI.md` | Son oturum durumu |

---

**Sen:** Yukarıdan işaretle, `[!]` olanları numarasıyla yaz.  
**Ben:** O numaralardan düzeltme / doğrulama yaparım.

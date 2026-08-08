# 🚀 İlanda Hizmet — Proje Analizi, Test Haritası ve Token Tasarruf Rehberi

> **Oluşturulma Tarihi:** 2026-08-08  
> **Amaç:** Geliştirme sürecinde token kullanımını en aza indirmek, mevcut test kapsamını haritalandırmak ve eksik test senaryolarını birlikte analiz etmek.

---

## ⚡ 1. Token Kullanımını En Aza İndirme Stratejileri

AI ile geliştirme yaparken en çok token harcayan durumlar: geniş dosya aramaları (`grep`/`glob` turları), büyük dosyaların baştan sona okunması, lüzumsuz kod tekrarları ve bağlamın sürekli baştan kurulmasıdır.

### 🎯 A) Geliştirici & AI İçin Altın Kurallar
1. **Mimari Kasayı Kullanın (`vault/`):**
   * Kod turları atmak yerine önce `vault/00-BASLA-BURADAN.md` rehberindeki notlara bakın.
   * `vault/05-Operasyon/Bilinen-Tuzaklar.md` notu geçmişte yaşanmış 20+ gerçek hatayı içerir. Kod değiştirmeden önce burayı kontrol edin.

2. **Büyük Dosyalarda Satır Aralığı Belirtin:**
   * Projede `chat_screen.dart` (2077 satır), `job_detail_screen.dart` (1966 satır), `functions/index.js` (5127 satır) gibi dev dosyalar bulunmaktadır.
   * İlgili dosyaları okurken veya sorarken fonksiyon/sınıf adını verin (Örn: `job_detail_screen.dart dosyasındaki _JobCompletionChatBar widget'ını inceleyelim`).

3. **Doğrulama ve Komutları Tek Adımda İletin:**
   * Kod değişikliği sonrası `flutter analyze` ve ilgili test dosyasını doğrudan çalıştırın (Örn: `flutter test test/jobs_test.dart`).

4. **Kullanılabilecek Slash Komutları:**
   * `/plan` : Karmaşık özellik eklemeden önce adım adım plan çıkarmak için.
   * `/grill-me` : Tasarım ve mimari kararlarını soru-cevap ile netleştirmek için.
   * `/learn` : Tekrarlanan kalıpları veya proje kurallarını hafızaya kaydetmek için.

---

## 📊 2. Mevcut Test Yapısı ve Kapsam Analizi

Projede **33 test dosyasında 319 adet birim/entegrasyon testi** bulunmaktadır. Tüm testler `MockBackend` ve bellek içi repository'ler üzerinden ağ/Firebase bağımlılığı olmadan ~35 saniyede koşar.

### 📂 Modül Bazlı Mevcut Test Listesi

| Modül / Alan | Test Dosyası | Test Sayısı | Önemli Kapsanan Akışlar |
|---|---|---|---|
| **Yönetim & Moderasyon** | `test/admin_test.dart` | 54 | Yetenek sistemi, usta onay/ret, şikayet yönetimi, denetim kaydı |
| **İlan & İş Akışı** | `test/jobs_test.dart` | 48 | Durum makinesi geçişleri, usta seçimi, teklif kabul/ret, kilit mekanizması |
| **Takip Merkezi** | `test/tracking_test.dart` | 28 | Takip kaydı oluşturma, tekrarlı işler, yerel DB yedekleme |
| **Usta Arama & Filtre** | `test/artisan_search_test.dart` | 14 | Meslek/şehir filtresi, puan sıralaması, mesafe hesabı |
| **Sohbet & İletişim** | `test/chat_list_test.dart`<br>`test/chat_job_title_test.dart`<br>`test/contact_masker_test.dart` | 15 | Okunmamış mesaj sayacı, sohbet başlığında ilan adı gösterimi, maskeleme kuralları |
| **Çift Rol (Müşteri+Usta)** | `test/dual_role_test.dart` | 9 | Aynı kullanıcının hem ilan verip hem teklif sunabilmesi |
| **Profil & Yetkilendirme** | `test/my_profile_test.dart`<br>`test/profile_save_fields_test.dart`<br>`test/profile_simplify_test.dart` | 21 | Profil düzenleme, sunucuya ait alanların (sayaç/onay) korunması |
| **Değerlendirme & Yorum** | `test/chat_review_test.dart` | 9 | Karşılıklı değerlendirme akışı, puan hesaplama |
| **Müşteri & İstatistikler** | `test/customer_stats_test.dart` | 6 | Müşteri istatistikleri, aktif/tamamlanan ilan sayıları |
| **Üyelik & Abonelik** | `test/membership_access_test.dart` | 2 | Pro üyelik erişim yetkileri |
| **Güvenlik & Yardım** | `test/safety_test.dart`<br>`test/help_faq_test.dart`<br>`test/legal_test.dart` | 8 | SSS kategorileri, KVKK/sozlesme metinleri, güvenlik kuralları |
| **Bildirimler & Ayarlar** | `test/notifications_test.dart`<br>`test/notification_prefs_test.dart` | 3 | Bildirim tercihleri, FCM token kaydı |
| **Sistem & Ayarlar** | `test/version_compare_test.dart`<br>`test/theme_mode_test.dart` | 8 | Sürüm karşılaştırma, koyu/açık tema tercihi |

---

## 🔍 3. Tespit Edilen Test Boşlukları (Neleri Birlikte Analiz Etmeliyiz?)

Mevcut testler repository seviyesinde oldukça güçlüdür; ancak kritik mimari katmanlarda önemli test boşlukları tespit edilmiştir:

> [!WARNING] En Kritik 3 Test Boşluğu
> 1. **Firestore Güvenlik Kuralları (`firestore.rules` - 1.3K Satır):**
>    * Şu an kurallar için otomatik test bulunmamaktadır. Yanlış yazılan bir `match` veya `allow` ifadesi tüm uygulamayı `permission-denied` hatasına düşürebilir.
>    * **Çözüm/Öneri:** `@firebase/rules-unit-testing` kütüphanesi ile emülatör üzerinde kural testleri yazılabilir.
>
> 2. **Cloud Functions Backend (`functions/index.js` - 5.1K Satır):**
>    * 51 adet sunucusuz fonksiyonun hiç birim testi bulunmamaktadır. Puan ortalamaları, `offerCount` sayaçları ve hesap silme işlemleri doğrudan bu fonksiyonlara bağlıdır.
>    * **Çözüm/Öneri:** Firebase Functions test SDK (`firebase-functions-test`) ile kritik fonksiyonlar test edilebilir.
>
> 3. **Ekran Widget & UI Akış Testleri:**
>    * `job_detail_screen.dart`, `chat_screen.dart` ve `create_job_screen.dart` gibi büyük ekranların UI seviyesindeki buton tıklamaları ve durum değişimleri otomatize test edilmemektedir.

---

## 📋 4. Birlikte İncelenecek Test & Analiz Listesi

Geliştirme sürecinde sırayla üzerinden geçebileceğimiz yapılacaklar listesi:

- [ ] **Karşılıklı Değerlendirme Akışı Uçtan Uca Doğrulaması:**
  * Müşteri mesaj yazmadan "Bu Ustayı Seç" dediğinde ustanın sohbete yazabilmesi.
  * İki tarafın da sırayla değerlendirme yapıp ilan durumunun `completed` → `rated` geçişi.
- [ ] **Firestore Güvenlik Kuralları İçin Manuel/Otomatik Test Listesi:**
  * Müşteri kendi ilanına teklif verebiliyor mu? (Engellenmeli)
  * Usta seçilmeden önce mesaj gönderebiliyor mu? (Kontrol edilmeli)
  * `toMap()` kaydında istemci `averageRating` alanını göndermeye çalışırsa kural reddediyor mu?
- [ ] **Cloud Functions Sayaç Tutarlılığı:**
  * Yeni teklif geldiğinde `offerCount` doğru artıyor mu?
  * Değerlendirme yapıldığında usta ortalama puanı ve `totalReviews` güncelleniyor mu?
- [ ] **Çevrimdışı (Offline) & Ağ Hatası Dayanıklılığı:**
  * İnternet kesildiğinde `signOut` işlemi ANR'ye düşmeden zarifçe tamamlanıyor mu?
  * `snapshots()` dinleyicileri oturum kapandığında izin hatasını sessizce ele alıyor mu?

---
*Bu doküman proje kök dizininde `TEST_VE_TOKEN_REHBERI.md` olarak saklanabilir ve geliştirme ilerledikçe güncellenebilir.*

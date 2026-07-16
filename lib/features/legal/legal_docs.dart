/// Yasal metinler — TEK KAYNAK (KVKK/Store zorunluluğu, YOL_HARITASI P0-3).
///
/// Bu dosya BİLİNÇLİ olarak saf Dart'tır (Flutter import'u yok):
/// `tool/generate_legal_html.dart` bu içerikten hosting'deki statik HTML
/// sayfalarını üretir (store'lara verilecek URL'ler). Metin değişirse:
///   1) Burayı güncelle,  2) `dart run tool/generate_legal_html.dart` çalıştır,
///   3) `firebase deploy --only hosting`.
library;

/// KVKK başvuruları ve genel iletişim adresi (tüm metinlerde geçer).
const kLegalContactEmail = 'aboneai.plus@gmail.com';

/// Yasal metinler + hosting HTML marka adı (uygulama `AppConstants.appName` ile hizalı).
const kAppBrandName = 'Ustasından';

/// Metinlerin "Son güncelleme" etiketi — içerik değişince güncelle.
const kLegalUpdated = '15 Temmuz 2026';

/// Store girişlerine verilecek canlı URL'ler (Firebase Hosting).
const kLegalBaseUrl = 'https://alljob1.web.app';

class LegalSection {
  const LegalSection({this.heading, required this.body});

  /// Bölüm başlığı (giriş paragrafında null).
  final String? heading;

  /// Paragraflar `\n\n` ile, madde satırları `•` ile ayrılır.
  final String body;
}

class LegalDoc {
  const LegalDoc({
    required this.id,
    required this.title,
    required this.slug,
    required this.sections,
  });

  /// Uygulama içi rota kimliği (`/legal/{id}`).
  final String id;
  final String title;

  /// Hosting'deki dosya adı (`{slug}.html`).
  final String slug;
  final List<LegalSection> sections;

  String get hostedUrl => '$kLegalBaseUrl/$slug.html';
}

/// Uygulama içinde listelenen metinler (sıra: hub ekranındaki sıra).
const kLegalDocs = [legalTerms, legalPrivacy, legalKvkk];

LegalDoc? legalDocById(String id) {
  for (final d in kLegalDocs) {
    if (d.id == id) return d;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Kullanım Koşulları
// ---------------------------------------------------------------------------

const legalTerms = LegalDoc(
  id: 'kosullar',
  title: 'Kullanım Koşulları',
  slug: 'kullanim-kosullari',
  sections: [
    LegalSection(
      body:
          'Bu Kullanım Koşulları ("Koşullar"), Ustasından mobil ve web uygulamasının ("Uygulama") kullanımını düzenler. Uygulamaya kayıt olarak veya Uygulamayı kullanarak bu Koşulları kabul etmiş sayılırsınız. Koşulları kabul etmiyorsanız lütfen Uygulamayı kullanmayınız.',
    ),
    LegalSection(
      heading: '1. Hizmetin Tanımı',
      body:
          'Ustasından; tamirat, tadilat ve benzeri hizmetlere ihtiyaç duyan kullanıcılar ("Müşteri") ile bu hizmetleri sunan kullanıcıları ("Usta") buluşturan bir ARACI platformdur.\n\nUstasından, platform üzerinden ilan edilen veya anlaşılan işlerin TARAFI DEĞİLDİR. İşin yapılması, kalitesi, zamanlaması, bedeli ve ödemesi tamamen Müşteri ile Usta arasındadır. Uygulama üzerinden ödeme alınmaz ve ödemeye aracılık edilmez.',
    ),
    LegalSection(
      heading: '2. Hesap ve Güvenlik',
      body:
          '• Kayıt sırasında doğru ve güncel bilgi vermekle yükümlüsünüz.\n• Uygulamayı kullanmak için 18 yaşını doldurmuş olmanız gerekir.\n• Hesabınızın ve şifrenizin güvenliğinden siz sorumlusunuz; hesabınız üzerinden yapılan işlemler size aittir.\n• Tek hesap hem Müşteri hem Usta olarak kullanılabilir; usta profili açmak ek bilgi (meslek, bölge, tanıtım) gerektirir.',
    ),
    LegalSection(
      heading: '3. Kullanım Kuralları',
      body:
          'Uygulamada aşağıdakiler yasaktır:\n\n• Yanıltıcı, gerçek dışı ilan, profil, teklif veya değerlendirme oluşturmak,\n• Hakaret, taciz, tehdit, ayrımcılık içeren veya hukuka aykırı içerik paylaşmak,\n• Spam, dolandırıcılık ve benzeri kötü niyetli davranışlar,\n• Başkalarının kişisel verilerini izinsiz paylaşmak,\n• Uygulamanın sistemlerini kötüye kullanmak (otomatik erişim, güvenlik açıklarını istismar vb.).\n\nKurallara aykırılık hâlinde ilgili içeriği kaldırma ve hesabı askıya alma veya kapatma hakkımız saklıdır.',
    ),
    LegalSection(
      heading: '4. Kullanıcı İçerikleri, Şikayet ve Engelleme',
      body:
          'İlan, mesaj, fotoğraf ve değerlendirme gibi içerikler bunları oluşturan kullanıcının sorumluluğundadır. İçeriklerinizin hizmetin sunulması amacıyla barındırılmasına ve diğer kullanıcılara gösterilmesine izin vermiş sayılırsınız.\n\nUygunsuz içerik veya davranışları uygulama içindeki "Şikayet Et" seçenekleriyle bildirebilir, dilediğiniz kullanıcıyı engelleyebilirsiniz. Şikayetler ekibimizce incelenir; gerekli görülürse içerik kaldırılır ve ilgili hesaba yaptırım uygulanır.',
    ),
    LegalSection(
      heading: '5. Değerlendirmeler',
      body:
          'Değerlendirmeler yalnızca gerçekten alınan hizmete dayanmalıdır. Puanların anlaşmalı veya sahte işlemlerle manipüle edilmesi yasaktır; tespiti hâlinde ilgili kayıtlar silinebilir ve hesaplara yaptırım uygulanabilir.',
    ),
    LegalSection(
      heading: '6. Ücretlendirme',
      body:
          'Uygulama şu an ücretsizdir; premium özellikler beta süresince tüm kullanıcılara ücretsiz sunulmaktadır. İleride ücretli özellikler sunulması hâlinde kapsam ve fiyatlar satın alma öncesinde açıkça duyurulur.',
    ),
    LegalSection(
      heading: '7. Fikri Mülkiyet',
      body:
          'Uygulamanın yazılımı, tasarımı, logosu ve "Ustasından" markası Uygulama geliştiricisine aittir; izinsiz kopyalanamaz ve kullanılamaz. Kullanıcı içeriklerinin mülkiyeti kullanıcıya aittir.',
    ),
    LegalSection(
      heading: '8. Sorumluluğun Sınırlandırılması',
      body:
          'Uygulama "olduğu gibi" sunulur; kesintisiz veya hatasız çalışacağı garanti edilmez. Ustasından; kullanıcılar arasındaki iş, ödeme ve iletişimden doğan uyuşmazlıkların tarafı veya garantörü değildir. Mevzuatın izin verdiği azami ölçüde, dolaylı zararlardan sorumluluk kabul edilmez.',
    ),
    LegalSection(
      heading: '9. Hesabın Silinmesi',
      body:
          'Hesabınızı dilediğiniz an Profil → Hesabı Sil adımlarıyla kalıcı olarak silebilirsiniz. Nelerin silindiği ve nelerin anonimleştirildiği Gizlilik Politikasında açıklanmıştır.',
    ),
    LegalSection(
      heading: '10. Değişiklikler',
      body:
          'Koşullar güncellenebilir; güncel sürüm her zaman bu sayfada yayımlanır. Önemli değişiklikler uygulama içinde duyurulur. Değişiklik sonrasında Uygulamayı kullanmaya devam etmeniz güncel Koşulları kabul ettiğiniz anlamına gelir.',
    ),
    LegalSection(
      heading: '11. Uygulanacak Hukuk ve İletişim',
      body:
          'Bu Koşullar Türkiye Cumhuriyeti hukukuna tabidir.\n\nSoru ve talepleriniz için: $kLegalContactEmail',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Gizlilik Politikası
// ---------------------------------------------------------------------------

const legalPrivacy = LegalDoc(
  id: 'gizlilik',
  title: 'Gizlilik Politikası',
  slug: 'gizlilik-politikasi',
  sections: [
    LegalSection(
      body:
          'Bu Gizlilik Politikası, Ustasından uygulamasını kullandığınızda hangi kişisel verilerin toplandığını, nasıl kullanıldığını ve haklarınızı açıklar. Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgilendirme için KVKK Aydınlatma Metnine de bakabilirsiniz.',
    ),
    LegalSection(
      heading: '1. Topladığımız Veriler',
      body:
          "• Hesap bilgileri: ad soyad, e-posta adresi ve şifreniz. Şifreniz Google Firebase Authentication altyapısında güvenli biçimde saklanır; tarafımıza açık hâlde ulaşmaz.\n• Telefon numarası: yalnızca isteğe bağlı telefon doğrulama özelliğini kullanırsanız.\n• Profil bilgileri (usta profili açarsanız): profil fotoğrafı, meslek, hizmet bölgesi, tanıtım yazısı, iş fotoğrafları ve sertifikalar.\n• Konum: yalnızca sizin listeden seçtiğiniz il/ilçe bilgisi. GPS veya hassas konum verisi TOPLANMAZ.\n• Oluşturduğunuz içerikler: ilanlar, teklifler, mesajlar, değerlendirmeler ve şikayet kayıtları.\n• Teknik veriler: bildirim token'ı (Firebase Cloud Messaging), çökme ve hata kayıtları (Firebase Crashlytics), cihaz bütünlük doğrulaması (Firebase App Check / Play Integrity).",
    ),
    LegalSection(
      heading: '2. Verileri Nasıl Kullanıyoruz',
      body:
          '• Hizmetin sunulması: müşteri-usta eşleştirme, ilan ve tekliflerin gösterilmesi, mesajlaşma ve bildirimler,\n• Güvenlik: dolandırıcılık ve kötüye kullanımın önlenmesi, şikayetlerin incelenmesi,\n• İyileştirme: hataların tespiti ve giderilmesi,\n• Yasal yükümlülüklerin yerine getirilmesi.\n\nVerileriniz reklam amacıyla satılmaz ve üçüncü kişilerle paylaşılmaz.',
    ),
    LegalSection(
      heading: '3. Verilerin Görünürlüğü',
      body:
          '• Usta profilleri (ad, fotoğraf, meslek, bölge, değerlendirmeler) uygulamadaki herkese açıktır.\n• İlanlar, ilgili bölgedeki ustalara gösterilir.\n• Mesajlar yalnızca sohbetin iki tarafınca görülebilir.',
    ),
    LegalSection(
      heading: '4. Üçüncü Taraf Hizmetler',
      body:
          "Verileriniz Google Firebase altyapısında (Google LLC) işlenir ve saklanır: kimlik doğrulama, veritabanı, dosya depolama, bildirim ve çökme raporlama hizmetleri için. Google'ın gizlilik uygulamaları: https://policies.google.com/privacy",
    ),
    LegalSection(
      heading: '5. Saklama ve Silme',
      body:
          'Hesabınızı Profil → Hesabı Sil adımlarıyla kalıcı olarak silebilirsiniz. Silme işleminde:\n\n• Hesabınız, profiliniz, favorileriniz, teklifleriniz ve yüklediğiniz dosyalar SİLİNİR,\n• Ustaya bağlanmamış açık ilanlarınız silinir; aktif işleriniz iptal edilir,\n• Tamamlanmış işler, yaptığınız değerlendirmeler ve sohbetlerdeki adınız "Silinmiş Kullanıcı" olarak ANONİMLEŞTİRİLİR (diğer kullanıcıların kayıtlarının ve kazanılmış itibarının korunması için),\n• Uygulama içi bildirim kayıtları en geç 30 gün içinde kendiliğinden silinir.\n\nAyrıntılı talimat: $kLegalBaseUrl/hesap-silme.html',
    ),
    LegalSection(
      heading: '6. Güvenlik',
      body:
          'Verilere erişim, sunucu tarafında yetkilendirme kurallarıyla sınırlandırılmıştır; yalnızca yetkili olduğunuz verilere erişebilirsiniz. Buna ek olarak cihaz bütünlük doğrulaması kullanılır. Bununla birlikte hiçbir yöntem %100 güvenlik garantisi veremez.',
    ),
    LegalSection(
      heading: '7. Çocukların Gizliliği',
      body:
          'Uygulama 18 yaş altındaki kişilere yönelik değildir ve bu kişilerden bilerek veri toplanmaz.',
    ),
    LegalSection(
      heading: '8. Haklarınız',
      body:
          '6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamındaki haklarınız ve başvuru yolu KVKK Aydınlatma Metninde açıklanmıştır. Talepleriniz için: $kLegalContactEmail',
    ),
    LegalSection(
      heading: '9. Değişiklikler',
      body:
          'Bu politika güncellenebilir; güncel sürüm her zaman bu sayfada yayımlanır ve önemli değişiklikler uygulama içinde duyurulur.',
    ),
  ],
);

// ---------------------------------------------------------------------------
// KVKK Aydınlatma Metni
// ---------------------------------------------------------------------------

const legalKvkk = LegalDoc(
  id: 'kvkk',
  title: 'KVKK Aydınlatma Metni',
  slug: 'kvkk-aydinlatma',
  sections: [
    LegalSection(
      body:
          'Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, Ustasından uygulaması kullanıcılarının kişisel verilerinin işlenmesine ilişkin olarak hazırlanmıştır.',
    ),
    LegalSection(
      heading: '1. Veri Sorumlusu',
      body:
          'Kişisel verileriniz, veri sorumlusu sıfatıyla Ustasından uygulaması geliştiricisi tarafından işlenmektedir. İletişim: $kLegalContactEmail',
    ),
    LegalSection(
      heading: '2. İşlenen Kişisel Veri Kategorileri',
      body:
          "• Kimlik: ad soyad,\n• İletişim: e-posta adresi, telefon numarası (doğrulama özelliğini kullanırsanız),\n• Görsel kayıtlar: profil ve iş fotoğrafları, sertifikalar,\n• Konum: seçtiğiniz il/ilçe bilgisi (GPS verisi işlenmez),\n• Müşteri işlem: ilanlar, teklifler, mesajlar, değerlendirmeler, şikayetler,\n• İşlem güvenliği: bildirim token'ı, çökme/hata kayıtları, cihaz bütünlük doğrulaması.",
    ),
    LegalSection(
      heading: '3. İşleme Amaçları',
      body:
          '• Üyelik ve hesabın yönetimi,\n• Müşteri ile usta arasında eşleştirmenin, iletişimin ve bildirimlerin sağlanması,\n• Platform güvenliğinin sağlanması, kötüye kullanımın ve dolandırıcılığın önlenmesi,\n• Hataların tespiti ve hizmetin iyileştirilmesi,\n• Yasal yükümlülüklerin yerine getirilmesi.',
    ),
    LegalSection(
      heading: '4. Hukuki Sebepler',
      body:
          'Kişisel verileriniz KVKK m.5 uyarınca; üyelik sözleşmesinin kurulması ve ifası (m.5/2-c), hukuki yükümlülüklerin yerine getirilmesi (m.5/2-ç), temel hak ve özgürlüklerinize zarar vermemek kaydıyla meşru menfaatlerimiz (m.5/2-f — güvenlik ve hizmet iyileştirme) ve gerekli hâllerde açık rızanız (m.5/1) hukuki sebeplerine dayanılarak işlenir.',
    ),
    LegalSection(
      heading: '5. Aktarım',
      body:
          'Verileriniz, barındırma ve altyapı hizmeti alınan Google LLC (Firebase) sunucularında saklanır; sunucuların yurt dışında bulunması nedeniyle bu saklama KVKK m.9 kapsamında kayıt sırasında verdiğiniz açık rızaya dayanır. Ayrıca yasal zorunluluk hâlinde yetkili kurum ve kuruluşlara aktarım yapılabilir. Verileriniz bunlar dışında üçüncü kişilere aktarılmaz, reklam amacıyla paylaşılmaz.',
    ),
    LegalSection(
      heading: '6. Toplama Yöntemi',
      body:
          'Kişisel verileriniz, uygulama ve web sitesi üzerinden elektronik ortamda, otomatik veya kısmen otomatik yollarla toplanır.',
    ),
    LegalSection(
      heading: '7. Haklarınız (KVKK m.11)',
      body:
          '• Kişisel verilerinizin işlenip işlenmediğini öğrenme ve bilgi talep etme,\n• İşleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,\n• Yurt içinde/yurt dışında aktarıldığı üçüncü kişileri bilme,\n• Eksik veya yanlış işlenmişse düzeltilmesini isteme,\n• KVKK m.7 şartları çerçevesinde silinmesini veya yok edilmesini isteme,\n• Düzeltme/silme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme,\n• Münhasıran otomatik sistemlerle analiz sonucu aleyhinize bir sonucun ortaya çıkmasına itiraz etme,\n• Kanuna aykırı işleme nedeniyle zarara uğramanız hâlinde zararın giderilmesini talep etme.',
    ),
    LegalSection(
      heading: '8. Başvuru',
      body:
          'Haklarınıza ilişkin taleplerinizi $kLegalContactEmail adresine iletebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır.',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Hesap Silme Talimatı (yalnız web'de yayımlanır — Play "Veri güvenliği"
// formundaki hesap silme URL'si için; uygulama içi hub'da listelenmez,
// çünkü uygulamada silme akışının kendisi var.)
// ---------------------------------------------------------------------------

const legalDeletion = LegalDoc(
  id: 'hesap-silme',
  title: 'Hesap Silme Talimatı',
  slug: 'hesap-silme',
  sections: [
    LegalSection(
      body:
          'Ustasından hesabınızı ve verilerinizi dilediğiniz an kalıcı olarak silebilirsiniz.',
    ),
    LegalSection(
      heading: 'Uygulama içinden silme (önerilen)',
      body:
          '1. Uygulamada oturum açın,\n2. Alt bardan Profil sekmesine gidin,\n3. "Hesabı Sil" satırına dokunun,\n4. Onay ekranındaki "Kalıcı Olarak Sil" ile işlemi tamamlayın.\n\nİşlem birkaç saniye sürer; tamamlandığında oturumunuz kapanır.',
    ),
    LegalSection(
      heading: 'Neler silinir, neler anonimleştirilir?',
      body:
          '• SİLİNİR: hesabınız, profiliniz, favorileriniz, teklifleriniz, yüklediğiniz tüm fotoğraf ve dosyalar, ustaya bağlanmamış açık ilanlarınız,\n• İPTAL EDİLİR: devam eden aktif işleriniz (karşı taraf bilgilendirilir),\n• ANONİMLEŞTİRİLİR: tamamlanmış işler, yaptığınız değerlendirmeler ve sohbet geçmişindeki adınız "Silinmiş Kullanıcı" olarak görünür (diğer kullanıcıların kayıtlarının korunması için).',
    ),
    LegalSection(
      heading: 'Uygulamaya erişemiyorsanız',
      body:
          'Hesabınızı silmek istediğinizi kayıtlı e-posta adresinizden $kLegalContactEmail adresine yazarak da talep edebilirsiniz; talebiniz en geç 30 gün içinde sonuçlandırılır.',
    ),
  ],
);

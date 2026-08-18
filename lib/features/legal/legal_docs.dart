/// Yasal metinler — TEK KAYNAK (KVKK/Store zorunluluğu, YOL_HARITASI P0-3).
///
/// Bu dosya BİLİNÇLİ olarak saf Dart'tır (Flutter import'u yok):
/// `tool/generate_legal_html.dart` bu içerikten hosting'deki statik HTML
/// sayfalarını üretir (store'lara verilecek URL'ler). Metin değişirse:
///   1) Burayı güncelle,  2) `dart run tool/generate_legal_html.dart` çalıştır,
///   3) `firebase deploy --only hosting`.
library;

/// KVKK başvuruları ve genel iletişim adresi (tüm metinlerde geçer).
const kLegalContactEmail = 'ilandahizmet@gmail.com';

/// Yasal metinler + hosting HTML marka adı (uygulama `AppConstants.appName` ile hizalı).
const kAppBrandName = 'İlanda Hizmet';

/// Metinlerin "Son güncelleme" etiketi — içerik değişince güncelle.
const kLegalUpdated = '15 Ağustos 2026';

/// Store girişlerine verilecek canlı URL'ler (kanonik tanıtım domaini).
/// Eski `alljob1.web.app` hâlâ yönlendirebilir; store formunda bunu kullanın.
const kLegalBaseUrl = 'https://www.ilandahizmet.com';

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
          'Bu Kullanım Koşulları ("Koşullar"), İlanda Hizmet mobil ve web uygulamasının ("Uygulama") kullanımını düzenler. Uygulamaya kayıt olarak veya Uygulamayı kullanarak bu Koşulları kabul etmiş sayılırsınız. Koşulları kabul etmiyorsanız lütfen Uygulamayı kullanmayınız.',
    ),
    LegalSection(
      heading: '1. Hizmetin Tanımı',
      body:
          'İlanda Hizmet; tamirat, tadilat ve benzeri hizmetlere ihtiyaç duyan kullanıcılar ("Müşteri") ile bu hizmetleri sunan kullanıcıları ("Usta") buluşturan; ayrıca ürün satmak isteyen kullanıcıların ("Satıcı") ürünlerini vitrinde sergilemesine imkân veren bir ARACI platformdur.\n\nİlanda Hizmet; platform üzerinden ilan edilen, anlaşılan veya satışa sunulan hiçbir iş ya da ürünün TARAFI, satıcısı veya sağlayıcısı DEĞİLDİR. İşin yapılması, ürünün teslimi, kalitesi, zamanlaması, bedeli ve ödemesi tamamen kullanıcılar arasındadır. Uygulama üzerinden ödeme alınmaz, ödemeye aracılık edilmez ve kargo/teslimat hizmeti sunulmaz.',
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
      heading: '5. Mağaza, Ürün İlanları ve Satıcı Yükümlülükleri',
      body:
          'Mağaza açan kullanıcı ("Satıcı") ürünlerini vitrinde sergileyebilir; alıcılar Satıcıya mesajla ulaşır. Satış ilişkisi doğrudan Satıcı ile alıcı arasında kurulur.\n\nSATICININ YÜKÜMLÜLÜKLERİ:\n• Ürünü doğru, eksiksiz ve yanıltıcı olmayacak şekilde tanıtmak; gerçek fotoğrafını kullanmak,\n• Fiyat, durum (sıfır/ikinci el) ve teslim koşullarını açıkça belirtmek,\n• Ticari faaliyet yürütüyorsa vergi, fatura, tüketici hakları ve mesafeli satış mevzuatına UYMAK; gerekli izin ve kayıtları tamamlamak,\n• Satışı yasak veya izne tabi ürünleri (silah, ilaç, reçeteli ürünler, alkol/tütün, taklit/kaçak mal, canlı hayvan, çalıntı eşya vb.) yayınlamamak,\n• Ürünün ayıbından, tesliminden ve satış sonrası yükümlülüklerden doğrudan sorumlu olmak.\n\nİlanda Hizmet ürünleri satın almaz, satmaz, stoklamaz, kalitesini denetlemez ve garanti etmez. Satıcının mevzuata uygunluğu kendi sorumluluğundadır. Kurallara aykırı ürün ilanları kaldırılır; tekrarı hâlinde mağaza ve hesap kapatılabilir.\n\nALICININ DİKKATİNE: Ödeme ve teslimat platform dışında gerçekleşir. Peşin ödeme yapmadan önce satıcıyı ve ürünü doğrulamanız, mümkünse yüz yüze görüşmeniz önerilir.',
    ),
    LegalSection(
      heading: '6. Değerlendirmeler',
      body:
          'Değerlendirmeler yalnızca gerçekten alınan hizmete veya gerçekleşen alışverişe dayanmalıdır. Puanların anlaşmalı veya sahte işlemlerle manipüle edilmesi yasaktır; tespiti hâlinde ilgili kayıtlar silinebilir ve hesaplara yaptırım uygulanabilir.',
    ),
    LegalSection(
      heading: '7. Ücretlendirme, Abonelik ve Cayma Hakkı',
      body:
          'Uygulamanın temel kullanımı ücretsizdir. Ustalara yönelik "Pro" özellikleri, beta süresince tüm kullanıcılara ücretsiz sunulmaktadır.\n\nPro üyelik, uygulama içinden Google Play üzerinden satın alınabilen AYLIK YENİLENEN bir aboneliktir. Satın alma, ödeme, yenileme ve iade işlemleri Google Play tarafından yürütülür; İlanda Hizmet ödeme bilgilerinizi (kart vb.) görmez ve saklamaz.\n\n• Abonelik, iptal edilmediği sürece dönem sonunda otomatik yenilenir.\n• Aboneliğinizi dilediğiniz an Google Play > Abonelikler bölümünden iptal edebilirsiniz; iptal, ödenmiş dönemin sonunda geçerli olur.\n• İade talepleri Google Play iade politikasına tabidir ve Google üzerinden yapılır.\n• Dijital içerik/hizmetin ifasına anında başlandığından, mevzuatın öngördüğü hâller saklı kalmak kaydıyla cayma hakkı sınırlı olabilir.\n\nFiyat ve kapsam değişiklikleri satın alma öncesinde uygulama içinde açıkça gösterilir.',
    ),
    LegalSection(
      heading: '8. Fikri Mülkiyet',
      body:
          'Uygulamanın yazılımı, tasarımı, logosu ve "İlanda Hizmet" markası Uygulama geliştiricisine aittir; izinsiz kopyalanamaz ve kullanılamaz. Kullanıcı içeriklerinin mülkiyeti kullanıcıya aittir.',
    ),
    LegalSection(
      heading: '9. Sorumluluğun Sınırlandırılması',
      body:
          'Uygulama "olduğu gibi" sunulur; kesintisiz veya hatasız çalışacağı garanti edilmez. İlanda Hizmet; kullanıcılar arasındaki iş, ÜRÜN SATIŞI, ödeme, teslimat ve iletişimden doğan uyuşmazlıkların tarafı veya garantörü değildir. Kullanıcıların kimliği, yetkinliği, ruhsatı, ürünlerinin ayıpsızlığı ve mevzuata uygunluğu Uygulama tarafından garanti edilmez. Mevzuatın izin verdiği azami ölçüde, dolaylı zararlardan sorumluluk kabul edilmez.',
    ),
    LegalSection(
      heading: '10. Hesabın Silinmesi',
      body:
          'Hesabınızı dilediğiniz an yan menü → Hesap Ayarları → Hesabı Sil adımlarıyla kalıcı olarak silebilirsiniz. Nelerin silindiği ve nelerin anonimleştirildiği Gizlilik Politikasında ve Hesap Silme Talimatında açıklanmıştır.',
    ),
    LegalSection(
      heading: '11. Değişiklikler',
      body:
          'Koşullar güncellenebilir; güncel sürüm her zaman bu sayfada yayımlanır. Önemli değişiklikler uygulama içinde duyurulur. Değişiklik sonrasında Uygulamayı kullanmaya devam etmeniz güncel Koşulları kabul ettiğiniz anlamına gelir.',
    ),
    LegalSection(
      heading: '12. Uygulanacak Hukuk ve Uyuşmazlıkların Çözümü',
      body:
          'Bu Koşullar Türkiye Cumhuriyeti hukukuna tabidir.\n\nUygulamanın kullanımından doğan uyuşmazlıklarda Türkiye Cumhuriyeti mahkemeleri ve icra daireleri yetkilidir. Tüketici sıfatını haiz kullanıcılar, parasal sınırlar dâhilinde kendi yerleşim yerlerindeki Tüketici Hakem Heyetlerine ve Tüketici Mahkemelerine başvurabilir; bu Koşullardaki hiçbir hüküm tüketicinin kanundan doğan haklarını sınırlandırmaz.\n\nKullanıcılar arasındaki iş, ürün, ödeme ve teslimat uyuşmazlıklarının tarafı İlanda Hizmet DEĞİLDİR; bu uyuşmazlıklar ilgili kullanıcılar arasında çözülür.',
    ),
    LegalSection(
      heading: '13. İletişim',
      body:
          'Soru, talep ve bildirimleriniz için: $kLegalContactEmail',
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
          'Bu Gizlilik Politikası, İlanda Hizmet uygulamasını kullandığınızda hangi kişisel verilerin toplandığını, nasıl kullanıldığını ve haklarınızı açıklar. Kişisel verilerin işlenmesine ilişkin ayrıntılı bilgilendirme için KVKK Aydınlatma Metnine de bakabilirsiniz.',
    ),
    LegalSection(
      heading: '1. Topladığımız Veriler',
      body:
          "• Hesap bilgileri: ad soyad, e-posta adresi ve şifreniz. Şifreniz Google Firebase Authentication altyapısında güvenli biçimde saklanır; tarafımıza açık hâlde ulaşmaz.\n• Telefon numarası: isteğe bağlıdır. Uygulama SMS ile telefon doğrulaması YAPMAZ; numaranızı yalnızca profilinizde iletişim bilgisi olarak göstermeyi seçerseniz kaydederiz. Göstermeyi seçmediğiniz sürece numaranız diğer kullanıcılara açılmaz.\n• Profil bilgileri (usta profili açarsanız): profil fotoğrafı, meslek, hizmet bölgesi, tanıtım yazısı, iş fotoğrafları ve sertifikalar.\n• Mağaza bilgileri (mağaza açarsanız): satış kategorileri, hizmet bölgeleri ve ürün ilanlarınız (başlık, açıklama, fiyat, durum, fotoğraflar).\n• Konum: yalnızca sizin listeden seçtiğiniz il/ilçe bilgisi. GPS veya hassas konum verisi TOPLANMAZ.\n• Oluşturduğunuz içerikler: ilanlar, ürünler, ürün talepleri, teklifler, mesajlar, değerlendirmeler ve şikayet kayıtları.\n• Kullanım istatistikleri: hangi ekranların açıldığı, giriş/kayıt, ilan oluşturma gibi uygulama içi olaylar (Firebase Analytics). Bu veriler kimliğinizle ilişkilendirilmiş pazarlama profili oluşturmak için KULLANILMAZ; hizmetin nasıl kullanıldığını toplu olarak anlamaya yarar.\n• Teknik veriler: bildirim token'ı (Firebase Cloud Messaging), çökme ve hata kayıtları (Firebase Crashlytics), cihaz bütünlük doğrulaması (Firebase App Check / Play Integrity).\n• Abonelik bilgisi: Pro üyelik satın alırsanız Google Play'den dönen satın alma doğrulama kaydı. Kart ve ödeme bilgileriniz tarafımıza ULAŞMAZ; ödeme tamamen Google Play üzerinden yürür.",
    ),
    LegalSection(
      heading: '2. Verileri Nasıl Kullanıyoruz',
      body:
          '• Hizmetin sunulması: müşteri-usta eşleştirme, ilan ve tekliflerin gösterilmesi, mesajlaşma ve bildirimler,\n• Güvenlik: dolandırıcılık ve kötüye kullanımın önlenmesi, şikayetlerin incelenmesi,\n• İyileştirme: hataların tespiti ve giderilmesi, hangi bölümlerin kullanıldığının toplu olarak ölçülmesi,\n• Abonelik işlemlerinin doğrulanması,\n• Yasal yükümlülüklerin yerine getirilmesi.\n\nVerileriniz SATILMAZ ve pazarlama amacıyla üçüncü kişilere devredilmez. Uygulamada üçüncü taraf reklam ağı bulunmamaktadır. Yukarıda sayılan altyapı hizmetleri (Google Firebase / Google Play) dışında veri paylaşımı yapılmaz; ileride reklam veya benzeri bir kullanım söz konusu olursa bu politika önceden güncellenir ve uygulama içinde duyurulur.',
    ),
    LegalSection(
      heading: '3. Verilerin Görünürlüğü',
      body:
          '• Usta profilleri (ad, fotoğraf, meslek, bölge, değerlendirmeler) uygulamadaki herkese açıktır.\n• Mağaza vitrini ve ürün ilanları (başlık, fiyat, fotoğraf, il/ilçe) herkese açıktır.\n• İlanlar, ilgili bölgedeki ustalara gösterilir.\n• Ürün talepleri, mağaza sahibi satıcılara gösterilir.\n• Telefon numaranız VARSAYILAN OLARAK GİZLİDİR; yalnızca "profilimde görünsün" seçeneğini açarsanız yayınlanır ve dilediğiniz an kapatabilirsiniz.\n• Mesajlar yalnızca sohbetin iki tarafınca görülebilir.',
    ),
    LegalSection(
      heading: '4. Üçüncü Taraf Hizmetler',
      body:
          "Verileriniz Google Firebase altyapısında (Google LLC) işlenir ve saklanır: kimlik doğrulama, veritabanı, dosya depolama, bildirim, kullanım istatistiği (Analytics) ve çökme raporlama hizmetleri için. Pro üyelik satın alımları Google Play (Google LLC) üzerinden yürütülür.\n\nBunların dışında herhangi bir üçüncü tarafa (reklam ağı, veri simsarı, pazarlama sağlayıcısı vb.) veri aktarımı YAPILMAZ. Google'ın gizlilik uygulamaları: https://policies.google.com/privacy",
    ),
    LegalSection(
      heading: '5. Saklama ve Silme',
      body:
          'Hesabınızı yan menü → Hesap Ayarları → Hesabı Sil adımlarıyla kalıcı olarak silebilirsiniz. Silme işleminde:\n\n• Hesabınız, profiliniz, favorileriniz, takip kayıtlarınız, ürünleriniz, tüm ilanlarınız, hakkınızda yazılmış değerlendirmeler ve yüklediğiniz dosyalar SİLİNİR,\n• Başkaları hakkında yazdığınız değerlendirmeler ve sohbetlerdeki adınız / fotoğrafınız "Silinmiş Kullanıcı" olarak ANONİMLEŞTİRİLİR (karşı tarafın mesaj geçmişinin ve kazanılmış itibarın korunması için),\n• Destek yazışmalarında kimliğiniz düşer; gövde kalabilir,\n• Kötüye kullanım şikayet kayıtları meşru menfaat nedeniyle silinmez (şikayet eden kimliği anonimleşir).\n\nAyrıntılı talimat: $kLegalBaseUrl/hesap-silme.html',
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
          'Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, İlanda Hizmet uygulaması kullanıcılarının kişisel verilerinin işlenmesine ilişkin olarak hazırlanmıştır.',
    ),
    LegalSection(
      heading: '1. Veri Sorumlusu',
      body:
          'Kişisel verileriniz, veri sorumlusu sıfatıyla İlanda Hizmet uygulaması geliştiricisi tarafından işlenmektedir. İletişim: $kLegalContactEmail',
    ),
    LegalSection(
      heading: '2. İşlenen Kişisel Veri Kategorileri',
      body:
          "• Kimlik: ad soyad,\n• İletişim: e-posta adresi, telefon numarası (isteğe bağlı; SMS doğrulaması yapılmaz, numaranız profilinizde göstermeyi seçmediğiniz sürece gizli kalır),\n• Görsel kayıtlar: profil, iş ve ürün fotoğrafları, sertifikalar,\n• Konum: seçtiğiniz il/ilçe bilgisi (GPS verisi işlenmez),\n• Müşteri işlem: ilanlar, ürün ilanları ve talepleri, teklifler, mesajlar, değerlendirmeler, şikayetler, Pro üyelik satın alma doğrulama kaydı (ödeme/kart bilgisi işlenmez),\n• İşlem güvenliği: bildirim token'ı, çökme/hata kayıtları, cihaz bütünlük doğrulaması,\n• Pazarlama/analiz: uygulama içi kullanım olayları (hangi ekran açıldı, ilan oluşturuldu vb. — toplu istatistik amaçlı).",
    ),
    LegalSection(
      heading: '3. İşleme Amaçları',
      body:
          '• Üyelik ve hesabın yönetimi,\n• Müşteri ile usta, alıcı ile satıcı arasında eşleştirmenin, iletişimin ve bildirimlerin sağlanması,\n• Usta/mağaza profillerinde kimlik güvenilirliğinin artırılması (ekip tarafından yapılan platform onayı),\n• Platform güvenliğinin sağlanması, kötüye kullanımın ve dolandırıcılığın önlenmesi,\n• Pro üyelik satın alımlarının doğrulanması ve abonelik hakkının tanımlanması,\n• Hataların tespiti, kullanımın toplu olarak ölçülmesi ve hizmetin iyileştirilmesi,\n• Yasal yükümlülüklerin yerine getirilmesi.',
    ),
    LegalSection(
      heading: '4. Hukuki Sebepler',
      body:
          'Kişisel verileriniz KVKK m.5 uyarınca; üyelik sözleşmesinin kurulması ve ifası (m.5/2-c), hukuki yükümlülüklerin yerine getirilmesi (m.5/2-ç), temel hak ve özgürlüklerinize zarar vermemek kaydıyla meşru menfaatlerimiz (m.5/2-f — güvenlik ve hizmet iyileştirme) ve gerekli hâllerde açık rızanız (m.5/1) hukuki sebeplerine dayanılarak işlenir.',
    ),
    LegalSection(
      heading: '5. Aktarım',
      body:
          'Verileriniz, barındırma ve altyapı hizmeti alınan Google LLC (Firebase; kimlik doğrulama, veritabanı, depolama, bildirim, kullanım istatistiği ve çökme raporlama) sunucularında saklanır. Pro üyelik satın alımlarında ödeme ve doğrulama süreci Google Play (Google LLC) üzerinden yürür. Sunucuların yurt dışında bulunması nedeniyle bu saklama ve aktarım, KVKK m.9 kapsamında kayıt sırasında verdiğiniz açık rızaya dayanır.\n\nYasal zorunluluk hâlinde yetkili kurum ve kuruluşlara aktarım yapılabilir. Verileriniz bunlar dışında üçüncü kişilere aktarılmaz; satılmaz ve pazarlama amacıyla devredilmez. Uygulamada üçüncü taraf reklam ağı bulunmamaktadır.',
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
          'İlanda Hizmet hesabınızı ve verilerinizi dilediğiniz an kalıcı olarak silebilirsiniz. Google Play ve KVKK hesap silme yükümlülüğüne uygun olarak silme işlemi uygulama içinden yapılır.',
    ),
    LegalSection(
      heading: 'Uygulama içinden silme (önerilen)',
      body:
          '1. Uygulamada oturum açın,\n2. Sol üstteki menü düğmesini açın,\n3. "Hesap Ayarları" satırına dokunun,\n4. "Hesabı Sil" satırına dokunun,\n5. Onay ekranındaki "Kalıcı Olarak Sil" ile işlemi tamamlayın.\n\nİşlem birkaç saniye sürebilir; tamamlandığında oturumunuz kapanır.\n\nNot: Hesap silme, Profil sekmesinde değil; yan menüdeki Hesap Ayarları bölümündedir.',
    ),
    LegalSection(
      heading: 'Neler silinir, neler anonimleştirilir?',
      body:
          '• SİLİNİR: hesabınız, profiliniz, favorileriniz, takip kayıtlarınız, ürünleriniz, tüm ilanlarınız, hakkınızda yazılmış değerlendirmeler, yüklediğiniz fotoğraf ve dosyalar, üyelik satın alma kayıtlarınız,\n• ANONİMLEŞTİRİLİR: başkaları hakkında yazdığınız değerlendirmeler ve sohbetlerdeki adınız / profil fotoğrafınız "Silinmiş Kullanıcı" olarak görünür (karşı tarafın mesaj geçmişinin korunması için),\n• DESTEK YAZIŞMALARI: gövde kalabilir; kimlik bilgileriniz düşer,\n• ŞİKAYET KAYITLARI: kötüye kullanım denetimi için kalır; şikayet eden kimliği anonimleşir.',
    ),
    LegalSection(
      heading: 'Uygulamaya erişemiyorsanız',
      body:
          'Hesabınızı silmek istediğinizi kayıtlı e-posta adresinizden $kLegalContactEmail adresine yazarak da talep edebilirsiniz; talebiniz en geç 30 gün içinde sonuçlandırılır.',
    ),
  ],
);

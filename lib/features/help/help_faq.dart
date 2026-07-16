/// Sık sorulan sorular — uygulama içi Yardım (YOL_HARITASI P1).
///
/// Metinler ürün diliyle sade tutulur; yasal ayrıntı için /legal sayfaları.
class FaqItem {
  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });

  final String question;
  final String answer;

  /// Müşteri | Usta | Genel
  final String category;
}

const kFaqCategories = ['Genel', 'Müşteri', 'Usta'];

const kFaqItems = <FaqItem>[
  FaqItem(
    category: 'Eleman',
    question: 'Eleman bölümünde işveren ile eleman farkı nedir?',
    answer:
        'Keşfet → Eleman.\n'
        '• ELEMAN (iş arıyorum): Profil yayınlarsınız; “İşveren ilanları”na bakarsınız.\n'
        '• İŞVEREN (eleman arıyorum): “Eleman ara” listesinden kişi bulursunuz veya '
        'ilan açarsınız.\n'
        'Başvuru formu yok; sohbetle iletişim kurulur. Gündelik iş için profil/ilan '
        'üzerinde “Gündelik” işaretini kullanın.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Ustasından nedir?',
    answer:
        'Bölgenizdeki ustaları meslek ve konumla bulmanızı, iş ilanı vermenizi '
        've güvenli sohbetle anlaşmanızı sağlayan bir hizmet pazaryeridir. '
        'Tek hesapla hem müşteri hem usta modunda kullanabilirsiniz.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Üyelik ücretli mi?',
    answer:
        'Uygulamayı indirmek ve temel kullanım ücretsizdir. Beta döneminde '
        'Premium usta özellikleri de herkese açıktır. İleride ücretli Premium '
        'çıktığında mağaza ve uygulama içinde net duyurulur.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Bildirimleri nasıl kapatırım?',
    answer:
        'Profil → Bildirim tercihleri. Sohbet, iş durumu ve yeni ilan push’larını '
        'ayrı ayrı kapatabilirsiniz. Uygulama içi bildirim listesi çalışmaya '
        'devam eder; yalnız telefona gelen push kesilir.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Hesabımı nasıl silerim?',
    answer:
        'Profil → Hesabı Sil. Onayladığınızda hesabınız ve ilişkili verileriniz '
        'kalıcı olarak silinir. Ayrıntılı adımlar Yasal Metinler → Hesap Silme '
        'Talimatı sayfasında da vardır.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Nasıl ilan veririm?',
    answer:
        'Giriş yapın → menü veya Keşfet üzerinden İş İlanı Ver. Meslek, bölge, '
        'başlık ve açıklama doldurun. İlan yayınlanınca eşleşen ustalara '
        'bildirim gidebilir; teklifleri İlanlarım / sohbetten takip edersiniz.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'İlana teklif gelmezse ne olur?',
    answer:
        'İlan süresi dolana kadar açık kalır. Daha net başlık/açıklama, doğru '
        'meslek ve il/ilçe seçmek eşleşmeyi artırır. Süre bitince ilan kapanır; '
        'isterseniz yeni ilan açabilirsiniz.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Usta ile nasıl konuşurum?',
    answer:
        'Profil veya teklif üzerinden sohbet açılır. İletişim bilgileri sohbet '
        'kurallarına göre maskelenebilir; uygulama içinden yazışmak en güvenli '
        'yoldur. Şüpheli durumda sohbet menüsünden engelle / şikayet kullanın.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Değerlendirme ne zaman açılır?',
    answer:
        'İş tamamlandıktan ve sohbet belirli bir süre aktif olduktan sonra '
        'değerlendirme açılır. Böylece anlık spam puanlar engellenir; puanınız '
        'usta profilinde görünür.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Usta olarak nasıl başlarım?',
    answer:
        'Profil → Hizmet Vermeye Başla (veya Usta modu). Meslek, hizmet bölgeleri '
        've mümkünse fotoğraf ekleyin. Profil tamamlanınca aramada görünürsünüz; '
        'müsaitlik anahtarıyla görünürlüğü anlık kapatabilirsiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Neden ilan görmüyorum?',
    answer:
        'Yakınımdaki İşler, profilinizdeki meslek ve hizmet illeriyle eşleşen '
        'açık ilanları listeler. Meslek/bölge eksikse, müsait değilseniz veya '
        'o bölgede ilan yoksa liste boş kalır. Profili düzenleyip müsaitliği '
        'açmayı deneyin.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Hızlı Destek nedir?',
    answer:
        'Ayak işi ilanlarıdır: market, taşıma, kısa gidiş gibi. Meslek olarak '
        '"Hızlı Destek" seçerseniz bu ilanlar size gelir. Yalnız bunu seçerseniz '
        'boya/elektrik gibi klasik meslek ilanları gelmez; ikisini birlikte '
        'seçebilirsiniz.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Hızlı Destek ile ne ilan verebilirim?',
    answer:
        'İlan ver → kategori "Hızlı Destek". Market alışverişi, koli/odun '
        'taşıma, eczane gidişi gibi kısa yardımlar için. Örnek şablonlardan '
        'birine dokunarak başlık ve açıklamayı doldurabilirsiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Mavi tik nasıl alınır?',
    answer:
        'Telefon numaranızı doğruladığınızda hesap doğrulanır; usta profilinde '
        'mavi tik görünür. Profil → Telefonunu Doğrula / Mavi Tik Al adımını '
        'tamamlayın.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Premium ne kazandırır?',
    answer:
        'Premium; müsaitlik rozeti, iş ilanlarına öncelikli erişim gibi usta '
        'araçlarını kapsar. Beta’da bu özellikler ücretsizdir. Ücretli modele '
        'geçilince Premium sayfasından güncel haklar listelenir.',
  ),
];

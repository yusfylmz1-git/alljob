/// Sık sorulan sorular — uygulama içi Yardım (YOL_HARITASI P1).
///
/// Metinler ürün diliyle sade tutulur; yasal ayrıntı için /legal sayfaları.
///
/// > [!important] Bu dosya ÜRÜNLE BİRLİKTE değişir
/// > 2026-08-08'de baştan yazıldı: içerik kaldırılmış özellikleri anlatıyordu
/// > (Eleman modülü, teklif/iş akışı, iletişim maskeleme, "iş tamamlanınca
/// > değerlendirme"). Bir akışı değiştirirken buraya da bak — yanlış yardım
/// > metni, olmayan bir düğmeyi aratıp kullanıcıyı kaybettirir.
class FaqItem {
  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });

  final String question;
  final String answer;

  /// Genel | Müşteri | Usta
  ///
  /// DİKKAT: Buraya yazılan değer [kFaqCategories] içinde de OLMALIDIR —
  /// yardım ekranı sekmeleri o listeden üretilir ve listede olmayan bir
  /// kategorideki soru hiçbir sekmede görünmez (sessizce kaybolur).
  final String category;
}

/// Yardım ekranındaki sekmeler. Sıra = görünme sırası.
///
/// "Eleman" KALDIRILDI: modül projeden çıktı.
const kFaqCategories = [
  'Genel',
  'Müşteri',
  'Usta',
];

const kFaqItems = <FaqItem>[
  // ───────────────────────── Genel ─────────────────────────
  FaqItem(
    category: 'Genel',
    question: 'İlanda Hizmet nedir?',
    answer:
        'Bölgenizdeki ustaları meslek ve konumla bulmanızı, iş ilanı vermenizi '
        've sohbetle doğrudan anlaşmanızı sağlayan bir hizmet pazaryeridir. '
        'Tek hesapla hem müşteri hem usta olarak kullanabilirsiniz — '
        'profilinizdeki "Usta modu" anahtarıyla geçiş yaparsınız.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Uygulama nasıl çalışıyor? (özet)',
    answer:
        '1. İlan verirsiniz ya da usta ararsınız.\n'
        '2. İlgilenen usta size doğrudan mesaj atar; ya da siz bir ustaya '
        'yazarsınız.\n'
        '3. İşi, fiyatı ve zamanı kendi aranızda konuşup anlaşırsınız.\n'
        '4. İş bitince birbirinizi değerlendirirsiniz.\n\n'
        'Aracı bir "teklif toplama" ya da onay adımı yoktur; uygulama sizi '
        'buluşturur, gerisi sizin aranızdadır.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Ödeme uygulama üzerinden mi yapılıyor?',
    answer:
        'Hayır. İlanda Hizmet ödeme almaz, tutmaz ve aktarmaz. Ücreti ve '
        'ödeme şeklini karşı tarafla siz belirlersiniz. Bu yüzden peşin para '
        'isteyen, sizi uygulama dışına yönlendiren veya kapora talep eden '
        'kişilere karşı dikkatli olun.',
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
    question: 'Takip sistemi nasıl çalışıyor?',
    answer:
        'Herkes herkesi takip edebilir — usta, müşteri fark etmez. Bir profile '
        'girip Takip Et deyin; takip ettikleriniz ve takipçileriniz '
        'profilinizdeki sayaçlardan görünür. Takipten çıkmak için aynı '
        'düğmeye tekrar dokunun. Takip ettiğiniz kişiye bildirim gider.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Birini nasıl engellerim veya şikayet ederim?',
    answer:
        'Sohbet ekranındaki menüden Engelle / Şikayet Et. Engellediğiniz kişi '
        'size mesaj atamaz ve sohbetiniz listenizden gizlenir; karşı taraf '
        'engellendiğini görmez. Şikayetler yönetime düşer.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Bildirimleri nasıl kapatırım?',
    answer:
        'Profil → Hesap Ayarları → Bildirim tercihleri. Sohbet ve ilan '
        'bildirimlerini ayrı ayrı kapatabilirsiniz. Uygulama içi bildirim '
        'listesi çalışmaya devam eder; yalnız telefona gelen push kesilir.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Hesabımı nasıl silerim?',
    answer:
        'Profil → Hesap Ayarları → Hesabı Sil. Onayladığınızda hesabınız ve '
        'ilişkili verileriniz kalıcı olarak silinir. Ayrıntılı adımlar Yasal '
        'Metinler → Hesap Silme Talimatı sayfasında da vardır.',
  ),

  // ──────────────────────── Müşteri ────────────────────────
  FaqItem(
    category: 'Müşteri',
    question: 'Nasıl ilan veririm?',
    answer:
        'Ana sayfa → İş İlanı Ver. Meslek, il/ilçe, başlık ve açıklama '
        'doldurun; isterseniz fotoğraf ekleyin. İlan yayınlanınca eşleşen '
        'ustalara bildirim gider ve ilgilenenler size doğrudan mesaj atar.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Kolay İş ile İş İlanı arasındaki fark ne?',
    answer:
        'KOLAY İŞ: market alışverişi, koli/odun taşıma, eczane gidişi gibi '
        'uzmanlık gerektirmeyen kısa işler. İlan 1 gün yayında kalır ve '
        'ilinizdeki tüm Kolay İş ustalarına gider.\n\n'
        'İŞ İLANI: tesisat, elektrik, boya gibi meslek isteyen işler. '
        '3, 5 veya 7 gün seçersiniz; ilan seçtiğiniz meslekteki ustalara '
        'gider.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'İlanım ne kadar yayında kalır?',
    answer:
        'İş ilanında 3, 5 veya 7 gün seçersiniz (varsayılan 3 gün). '
        'Kolay İş ilanları her zaman 1 gündür. Süre dolunca ilan kapanır; '
        'dilediğinizde yenisini açabilirsiniz.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Aynı anda kaç ilan verebilirim?',
    answer:
        'Aynı anda en fazla 5 açık ilanınız olabilir. Bir ilanı iptal eder '
        'veya süresi dolarsa hakkınız geri gelir.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'İlanıma kimse yazmazsa ne olur?',
    answer:
        'İlan süresi dolana kadar açık kalır. Daha net bir başlık, doğru '
        'meslek ve il/ilçe seçimi eşleşmeyi artırır; fotoğraf eklemek de '
        'ilgiyi belirgin şekilde yükseltir. Süre bitince ilan kapanır.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'İlanımı düzenleyebilir veya silebilir miyim?',
    answer:
        'İlanı yayınladıktan sonraki 1 saat içinde düzenleyebilirsiniz — '
        'bu pencere, yazışmalar başladıktan sonra ilanın altınızdan '
        'değişmemesi içindir. İptal etme ve silme her zaman açıktır: '
        'İlan detayı → İlanı İptal Et / Sil.',
  ),
  FaqItem(
    category: 'Müşteri',
    question: 'Usta ile nasıl konuşurum?',
    answer:
        'İlanınızla ilgilenen ustalar size doğrudan mesaj atar; Mesajlar '
        'sekmesinden görürsünüz. Siz de bir usta profiline girip Mesaj Gönder '
        'diyebilirsiniz. Bir kişiyle tek sohbetiniz olur — kaç iş konuşursanız '
        'konuşun aynı yerden devam eder.',
  ),

  // ────────────────────────── Usta ──────────────────────────
  FaqItem(
    category: 'Usta',
    question: 'Usta olarak nasıl başlarım?',
    answer:
        'Profil → "Usta modu" anahtarını açın. Ardından meslek (en fazla 5), '
        'hizmet bölgeleri ve mümkünse fotoğraf ekleyin. Profil tamamlanınca '
        'aramada görünür ve ilanları görmeye başlarsınız.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'İlanları neden göremiyorum?',
    answer:
        'İlanları görmek için USTA MODU açık olmalı ve profilinizde en az bir '
        'meslek ile hizmet bölgesi bulunmalıdır. Ayrıca "müsait değilim" '
        'durumundaysanız ilan listesi kapanır. Keşfet → İlanlar sekmesinden '
        'bakabilirsiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: '"Müsait değilim" ne yapar?',
    answer:
        'Müsait olmadığınızda usta aramasında görünmezsiniz, yeni ilanlara '
        'mesaj atamazsınız ve size yeni sohbet açılamaz.\n\n'
        'MEVCUT SOHBETLERİNİZ ETKİLENMEZ: daha önce konuştuğunuz kişilerle '
        'yazışmaya devam edersiniz. Anahtarı profilinizden tek dokunuşla '
        'geri açabilirsiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'İlan sahibiyle nasıl iletişime geçerim?',
    answer:
        'İlan detayında Mesaj Gönder. Teklif verme veya seçilmeyi bekleme '
        'adımı yoktur — doğrudan yazışıp anlaşırsınız. Mesaj atabilmek için '
        'e-posta adresinizin doğrulanmış, mesleğinizin ve bölgenizin ilanla '
        'eşleşmiş olması gerekir.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Kolay İş nedir, nasıl alırım?',
    answer:
        'Market, taşıma, kısa gidiş gibi uzmanlık gerektirmeyen kısa işlerdir. '
        'Profilinizi düzenleyip meslek seçiminin üstündeki "Kolay İş işleri al" '
        'anahtarını açarsanız bu ilanlar size gelir. Meslek seçiminizden '
        'bağımsızdır ve 5 meslek sınırına dahil değildir: mesleğiniz varsa '
        'onun ilanlarını da almaya devam edersiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Kolay İş ilanları hangi bölgeden gelir?',
    answer:
        'Klasik meslek ilanlarından farklı olarak Kolay İş ilanları İLİN '
        'TAMAMINDAN gelir (yalnız kendi ilçenizden değil). Kısa işlerde usta '
        'sayısı az olduğundan ilan ilçeye kısılınca çoğu ilanın alıcısı '
        'olmuyordu. Kendi ilçenizdeki ilanlar listede "Yakınında" rozetiyle '
        'en üstte gösterilir; uzak bir ilanı almak zorunda değilsiniz.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Kaç meslek seçebilirim?',
    answer:
        'En fazla 5 meslek seçebilirsiniz. Kolay İş anahtarı bu sayıya dahil '
        'değildir — 5 mesleğiniz olsa bile açık kalabilir.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Mavi tik nasıl alınır?',
    answer:
        'Telefon numaranızı doğruladığınızda hesap doğrulanır ve profilinizde '
        'mavi tik görünür. Profil → Telefonunu Doğrula adımını tamamlayın.',
  ),
  FaqItem(
    category: 'Usta',
    question: 'Premium ne kazandırır?',
    answer:
        'Premium; vitrin, Kolay İş ve öne çıkma gibi usta araçlarını kapsar. '
        'Beta döneminde bu özellikler ücretsizdir. Ücretli modele geçilince '
        'Premium sayfasından güncel haklar listelenir.',
  ),

  // ───────────────────── Değerlendirme ─────────────────────
  FaqItem(
    category: 'Genel',
    question: 'Değerlendirme nasıl çalışıyor?',
    answer:
        'Her profilde bir Değerlendir düğmesi vardır — usta da müşteri de '
        'puan alır ve verir. 1–5 yıldız seçip hazır etiketlerden '
        'işaretlersiniz; serbest yorum yazılmaz.\n\n'
        'Bir kişiyi yalnızca BİR KEZ değerlendirebilirsiniz. Fikriniz '
        'değişirse aynı düğmeden puanınızı güncellersiniz; yeni bir '
        'değerlendirme eklenmez.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Değerlendirmemi sonradan değiştirebilir miyim?',
    answer:
        'Evet. Daha önce değerlendirdiğiniz bir profile girdiğinizde düğme '
        '"Değerlendirmeni Güncelle" olur ve form eski puanınızla açılır. '
        'Gönderdiğinizde önceki değerlendirmenizin üzerine yazılır.',
  ),
  FaqItem(
    category: 'Genel',
    question: 'Değerlendirmemi kim görür?',
    answer:
        'Puanlar herkese açıktır ve profilde ortalama olarak görünür. '
        'Yorumlarda adınız kısaltılmış gösterilir (örn. "A***").',
  ),
];

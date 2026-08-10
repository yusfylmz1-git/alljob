/// Ürün kategorileri — Mağaza vitrini için (2026-08-10).
///
/// **Neden mesleklerden ayrı:** `professions.json` bir HİZMET listesidir
/// ("Avukat", "Fizyoterapi", "Köpek Gezdirme", "DJ / Ses Sistemi"). Ürün
/// formu geri geldiğinde o listeyi kullanıyordu; kullanıcı "Boyacı"
/// kategorisinde boya mı satıldığını yoksa boyacı mı arandığını
/// anlayamıyordu ve 144 seçeneğin çoğunda ürün satmak anlamsızdı.
///
/// Bu liste ÜRÜNÜN KENDİSİNİ tarif eder; kim sattığını değil.
///
/// ⚠️ Kodlar Firestore'daki `products.categoryCode` alanına yazılır —
/// yeniden adlandırmak veri göçüdür (CLAUDE.md kural 6). Görünen ad
/// serbestçe değişebilir, kod değişemez.
class ProductCategory {
  ProductCategory._();

  static const String yapiMalzeme = 'yapi_malzeme';
  static const String hirdavat = 'hirdavat';
  static const String mobilya = 'mobilya';
  static const String beyazEsya = 'beyaz_esya';
  static const String elektronik = 'elektronik';
  static const String tesisatMalzeme = 'tesisat_malzeme';
  static const String aracParca = 'arac_parca';
  static const String bahce = 'bahce';
  static const String evTekstil = 'ev_tekstil';
  static const String mutfak = 'mutfak';
  static const String hobiSpor = 'hobi_spor';
  static const String bebekCocuk = 'bebek_cocuk';
  static const String isMakinesi = 'is_makinesi';
  static const String diger = 'diger';

  /// Gösterim sırası. Yapı/hırdavat en üstte — uygulamanın çekirdek
  /// kitlesi (usta + tadilat yapan müşteri) en çok bunları satıp arar.
  /// `diger` HER ZAMAN sonda.
  static const List<String> sirali = [
    yapiMalzeme,
    hirdavat,
    tesisatMalzeme,
    mobilya,
    beyazEsya,
    elektronik,
    aracParca,
    isMakinesi,
    bahce,
    evTekstil,
    mutfak,
    hobiSpor,
    bebekCocuk,
    diger,
  ];

  static const Map<String, String> _adlar = {
    yapiMalzeme: 'Yapı Malzemesi',
    hirdavat: 'Hırdavat & El Aleti',
    tesisatMalzeme: 'Tesisat & Elektrik Malzemesi',
    mobilya: 'Mobilya & Dekorasyon',
    beyazEsya: 'Beyaz Eşya',
    elektronik: 'Elektronik',
    aracParca: 'Araç & Yedek Parça',
    isMakinesi: 'İş Makinesi & Ekipman',
    bahce: 'Bahçe & Tarım',
    evTekstil: 'Ev Tekstili',
    mutfak: 'Mutfak & Züccaciye',
    hobiSpor: 'Hobi & Spor',
    bebekCocuk: 'Bebek & Çocuk',
    diger: 'Diğer',
  };

  /// Kategorinin Türkçe adı; bilinmeyen kod "Diğer" sayılır.
  ///
  /// Bilinmeyen kod normaldir: modül kaldırılmadan önce (PRD-006) ürünler
  /// MESLEK kodlarıyla kaydediliyordu. O kayıtlar okunmaya devam eder,
  /// yalnız "Diğer" olarak görünürler — veri göçü yapılmadı.
  static String label(String code) => _adlar[code] ?? _adlar[diger]!;

  /// Listedeki sıra numarası; bilinmeyen kod SONA düşer.
  static int order(String code) {
    final i = sirali.indexOf(code);
    return i < 0 ? sirali.length : i;
  }

  /// Bu kod tanıdık bir ürün kategorisi mi?
  static bool tanidik(String code) => _adlar.containsKey(code);
}

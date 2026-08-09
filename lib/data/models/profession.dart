/// Meslek kategorisi. Statik JSON'dan yüklenir (PRD §5).
class Profession {
  const Profession({
    required this.code,
    required this.nameTR,
    required this.icon,
    this.category = ProfessionCategory.diger,
  });

  final String code; // örn. "painter"
  final String nameTR; // örn. "Boyacı Ustası"
  final String icon; // Material ikon adı

  /// Gruplama anahtarı (2026-08-10). 144 meslek düz listede aranıyordu ve
  /// liste inşaat mesleklerine göre sıralı olduğundan beyaz yaka hizmetler
  /// (avukat, mimar, muhasebe) sona düşüp görünmez kalıyordu.
  final String category;

  factory Profession.fromMap(Map<String, dynamic> m) => Profession(
        code: m['code'] as String,
        nameTR: m['nameTR'] as String,
        icon: (m['icon'] as String?) ?? 'handyman',
        // Alan yoksa "diğer": eski/eksik kayıt listeden DÜŞMEZ, sona gelir.
        category: (m['category'] as String?) ?? ProfessionCategory.diger,
      );
}

/// Meslek kategorileri — kod ve gösterim adı.
///
/// Kodlar `professions.json`'daki `category` alanıyla birebir eşleşir.
/// Sıra ÖNEMLİDİR: seçim listesinde bu sırayla gruplanır. Sık aranan
/// gruplar üstte, `diger` her zaman sonda.
class ProfessionCategory {
  ProfessionCategory._();

  static const String yapi = 'yapi';
  static const String tesisat = 'tesisat';
  static const String ev = 'ev';
  static const String arac = 'arac';
  static const String teknoloji = 'teknoloji';
  static const String saglik = 'saglik';
  static const String egitim = 'egitim';
  static const String profesyonel = 'profesyonel';
  static const String etkinlik = 'etkinlik';
  static const String evcil = 'evcil';
  static const String ulasim = 'ulasim';
  static const String sanayi = 'sanayi';
  static const String diger = 'diger';

  /// Gösterim sırası.
  static const List<String> sirali = [
    yapi,
    tesisat,
    ev,
    arac,
    teknoloji,
    saglik,
    egitim,
    profesyonel,
    etkinlik,
    evcil,
    ulasim,
    sanayi,
    diger,
  ];

  static const Map<String, String> _adlar = {
    yapi: 'İnşaat & Tadilat',
    tesisat: 'Tesisat & Isıtma-Soğutma',
    ev: 'Ev Hizmetleri',
    arac: 'Araç',
    teknoloji: 'Teknoloji',
    saglik: 'Bakım & Sağlık',
    egitim: 'Eğitim',
    profesyonel: 'Profesyonel Hizmetler',
    etkinlik: 'Etkinlik & Medya',
    evcil: 'Evcil Hayvan',
    ulasim: 'Ulaşım',
    sanayi: 'Sanayi & Üretim',
    diger: 'Diğer',
  };

  /// Kategorinin Türkçe adı; bilinmeyen kod "Diğer" sayılır.
  static String label(String code) => _adlar[code] ?? _adlar[diger]!;

  /// Listedeki sıra numarası; bilinmeyen kod SONA düşer.
  static int order(String code) {
    final i = sirali.indexOf(code);
    return i < 0 ? sirali.length : i;
  }
}

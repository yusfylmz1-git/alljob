// Coğrafi referans modelleri. Statik JSON assetlerinden yüklenir (PRD §5).

class Province {
  const Province({required this.id, required this.name, required this.plateCode});

  final String id;
  final String name;
  final String plateCode;

  factory Province.fromMap(Map<String, dynamic> m) => Province(
        id: m['id'].toString(),
        name: m['name'] as String,
        plateCode: m['plateCode'].toString(),
      );
}

class District {
  const District({required this.id, required this.provinceId, required this.name});

  final String id;
  final String provinceId;
  final String name;

  factory District.fromMap(Map<String, dynamic> m) => District(
        id: m['id'].toString(),
        provinceId: m['provinceId'].toString(),
        name: m['name'] as String,
      );
}

class Neighborhood {
  const Neighborhood({required this.id, required this.districtId, required this.name});

  final String id;
  final String districtId;
  final String name;

  factory Neighborhood.fromMap(Map<String, dynamic> m) => Neighborhood(
        id: m['id'].toString(),
        districtId: m['districtId'].toString(),
        name: m['name'] as String,
      );
}

/// Bir ustanın hizmet verdiği tek bir bölge (il > ilçe).
/// `artisanProfiles.serviceAreas` dizisinin her elemanı budur.
/// Mahalle seçimi kaldırıldı; eski kayıtlarla uyum için alan opsiyonel durur.
class ServiceArea {
  const ServiceArea({
    required this.province,
    required this.district,
    this.neighborhood = '',
  });

  final String province;
  final String district;
  final String neighborhood; // eski kayıtlar için; yeni kayıtlar boş

  Map<String, dynamic> toMap() => {
        'province': province,
        'district': district,
        'neighborhood': neighborhood,
      };

  factory ServiceArea.fromMap(Map<String, dynamic> m) => ServiceArea(
        province: (m['province'] as String?) ?? '',
        district: (m['district'] as String?) ?? '',
        neighborhood: (m['neighborhood'] as String?) ?? '',
      );

  /// Ekranda gösterilecek etiket: "İl / İlçe".
  String get labelTR => '$province / $district';

  /// Firestore eşitlik sorgusu / mükerrer kontrolü için kompozit anahtar.
  /// Mahalle kalktığı için il+ilçe düzeyinde tekilleştirilir.
  String get key => '$province|$district';

  @override
  bool operator ==(Object other) =>
      other is ServiceArea &&
      other.province == province &&
      other.district == district;

  @override
  int get hashCode => key.hashCode;
}

/// TEK İL KURALI (2026-08-23).
///
/// Bir usta / mağaza **yalnız bir ilde** hizmet verebilir; o ilin istediği
/// kadar ilçesini seçebilir.
///
/// NEDEN:
///  * **Hizmet bölgesi belirsizleşiyordu.** Sınırsız il seçen usta "her yere
///    giderim" diyordu ama gerçekte gitmiyordu; müşteri cevapsız kalıyordu.
///  * **Şehir bazlı Pro geçişini delerdi.** Bir il ücretli döneme geçtiğinde
///    usta yanına komşu bir il ekleyip kapıdan kaçmayı öğrenirdi.
///    (Kural: illerden biri ücretliyse abonelik başlar — ama tek il varken
///    bu soru hiç doğmaz.)
///
/// ESKİ KAYITLAR: çok illi profiller veritabanında DURUYOR ve okunmaya
/// devam eder — göç yapılmaz, kimsenin verisi silinmez. Kullanıcı profilini
/// bir dahaki kaydedişinde tek ile iner ([singleProvinceOf] ile).
extension TekIlKurali on List<ServiceArea> {
  /// Listedeki bölgelerin ili (hepsi aynı olmalı). Liste boşsa `null`.
  ///
  /// Çok illi ESKİ kayıtta İLK ilin adı döner — keyfi değil: kullanıcının
  /// ilk seçtiği ildir ve kaydederken korunacak olan odur.
  String? get singleProvince {
    for (final a in this) {
      final p = a.province.trim();
      if (p.isNotEmpty) return p;
    }
    return null;
  }

  /// Yalnız [singleProvince]'e ait bölgeleri döndürür.
  ///
  /// Tek illi listede kimliktir (yeni liste bile üretmez). Çok illi eski
  /// kayıtta fazlalık illeri düşürür — kayıt anında normalleştirme.
  List<ServiceArea> get onlySingleProvince {
    final il = singleProvince;
    if (il == null) return this;
    if (every((a) => a.province.trim() == il)) return this;
    return where((a) => a.province.trim() == il).toList(growable: false);
  }

  /// Birden çok il taşıyor mu? (Eski kayıt uyarısı için.)
  bool get hasMultipleProvinces {
    final il = singleProvince;
    if (il == null) return false;
    return any((a) => a.province.trim() != il);
  }
}

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

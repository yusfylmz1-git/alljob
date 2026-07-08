/// Meslek kategorisi. Statik JSON'dan yüklenir (PRD §5).
class Profession {
  const Profession({required this.code, required this.nameTR, required this.icon});

  final String code; // örn. "painter"
  final String nameTR; // örn. "Boyacı Ustası"
  final String icon; // Material ikon adı

  factory Profession.fromMap(Map<String, dynamic> m) => Profession(
        code: m['code'] as String,
        nameTR: m['nameTR'] as String,
        icon: (m['icon'] as String?) ?? 'handyman',
      );
}

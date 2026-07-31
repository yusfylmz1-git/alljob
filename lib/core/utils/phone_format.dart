/// E.164 telefon numarasını Türk okuma biçimine çevirir.
///
/// `+905321234567` → `0532 123 45 67`. TR dışı / beklenmedik biçimdeki
/// numaralar olduğu gibi döner (bozuk gösterim yerine ham değer).
///
/// Aynı biçimlendirme profil, usta vitrini ve doğrulama akışında kullanılır;
/// tek yerde tutulur ki gösterimler birbirinden ayrışmasın.
String formatTrPhone(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  // 90 + 10 hane
  if (d.length == 12 && d.startsWith('90')) {
    final n = d.substring(2);
    return '0${n.substring(0, 3)} ${n.substring(3, 6)} '
        '${n.substring(6, 8)} ${n.substring(8)}';
  }
  return e164;
}

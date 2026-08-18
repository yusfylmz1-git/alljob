/// E.164 telefon numarasını Türk okuma biçimine çevirir.
///
/// `+905321234567` → `0532 123 45 67`. TR dışı / beklenmedik biçimdeki
/// numaralar olduğu gibi döner (bozuk gösterim yerine ham değer).
///
/// Aynı biçimlendirme profil, usta vitrini ve sohbet başlığında kullanılır;
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

/// Kullanıcının yazdığı TR cep numarasını E.164'e (`+905XXXXXXXXX`) çevirir.
///
/// SMS doğrulaması kaldırıldığından (2026-08-18) numara artık elle giriliyor;
/// tek savunma bu ayrıştırıcıdır. Kabul edilen yazımlar — hepsi aynı sonuca
/// iner:
///
///   `0532 123 45 67` · `532 123 45 67` · `+90 532 123 45 67`
///   `905321234567`   · `(0532) 123-45-67`
///
/// Kural: TR cep numarası `5` ile başlayan 10 hanedir. Sabit hat (212/312…)
/// ve kısa/uzun girdiler **reddedilir** — WhatsApp bağlantısı ancak cep
/// numarasında çalışır, sabit hat yayınlamak kullanıcıyı yanıltır.
///
/// Geçersizse `null` döner. Çağıran taraf [trPhoneError] ile kullanıcıya
/// sebebini gösterir.
String? normalizeTrMobile(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;

  // Ülke kodu / baştaki sıfır soyulur: 90XXXXXXXXXX, 0XXXXXXXXXX, XXXXXXXXXX.
  if (d.length == 12 && d.startsWith('90')) {
    d = d.substring(2);
  } else if (d.length == 11 && d.startsWith('0')) {
    d = d.substring(1);
  }

  // Kalan tam 10 hane ve cep önekiyle (5) başlamalı.
  if (d.length != 10 || !d.startsWith('5')) return null;
  return '+90$d';
}

/// Girdi geçerliyse `null`, değilse gösterilecek Türkçe hata metni.
///
/// Boş girdi HATA DEĞİLDİR: numara alanı isteğe bağlıdır (boş bırakmak
/// "numaram yayınlanmasın" demektir).
String? trPhoneError(String input) {
  if (input.trim().isEmpty) return null;
  if (normalizeTrMobile(input) != null) return null;

  final d = input.replaceAll(RegExp(r'\D'), '');
  if (d.length < 10) return 'Numara eksik — 10 haneli cep numarası girin.';
  if (d.length > 13) return 'Numara çok uzun. Örnek: 0532 123 45 67';
  return 'Geçerli bir TR cep numarası girin (5 ile başlar). '
      'Örnek: 0532 123 45 67';
}

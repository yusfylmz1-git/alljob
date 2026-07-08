/// Sohbet mesajlarındaki iletişim bilgilerini maskeler (PRD §5 Ekran E).
/// Telefon, e-posta, WhatsApp/Telegram/Instagram ve platform dışı bağlantılar
/// otomatik gizlenir; platform dışına yönlendirme engellenir.
class ContactMasker {
  ContactMasker._();

  static const String _mask = '•••';

  // E-posta adresleri.
  static final RegExp _email =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

  // http(s) veya www ile başlayan bağlantılar ve yaygın kısa alan adları.
  static final RegExp _url = RegExp(
    r'((https?:\/\/|www\.)[^\s]+|\b[\w\-]+\.(com|net|org|me|co|io|tr)\b(\/[^\s]*)?)',
    caseSensitive: false,
  );

  // Sosyal medya kullanıcı adları (@kullanici) ve platform anahtar kelimeleri
  // ardından gelen tanıtıcılar (whatsapp: 05.., instagram: ...).
  static final RegExp _social = RegExp(
    r'(@[A-Za-z0-9._]{3,})|((whatsapp|telegram|instagram|insta|snapchat|snap)\s*[:\-]?\s*\S+)',
    caseSensitive: false,
  );

  // Telefon numaraları: opsiyonel +90 / 0, ardından boşluk/tire/parantezli
  // en az 10 rakamlık diziler.
  static final RegExp _phone =
      RegExp(r'(\+?\d[\d\s\-()]{8,}\d)');

  // Rakamların Türkçe harflerle yazılmış hali (basit kaçış denemesi).
  static final RegExp _spacedDigits = RegExp(r'(\d[\s.\-]?){10,}');

  /// Metni maskeler. İletişim bilgisi bulunursa ilgili kısımlar [_mask] olur.
  static String mask(String input) {
    var out = input;
    out = out.replaceAll(_email, _mask);
    out = out.replaceAll(_url, _mask);
    out = out.replaceAll(_social, _mask);
    out = out.replaceAll(_spacedDigits, _mask);
    out = out.replaceAll(_phone, _mask);
    return out;
  }

  /// Metin herhangi bir iletişim bilgisi içeriyor mu? (Uyarı göstermek için.)
  static bool containsContact(String input) => mask(input) != input;
}

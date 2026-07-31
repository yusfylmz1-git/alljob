/// Ustanın vitrininde gösterebileceği sosyal medya / iletişim bağlantıları.
///
/// Tasarım kararları:
/// - Kullanıcı **kullanıcı adı** girer (`@ahmet_usta`), tam URL değil. Tam URL
///   yapıştırılsa da [normalizeHandle] kullanıcı adına indirger; böylece
///   depoda tek biçim durur ve kimlik avı linki gömülemez.
/// - WhatsApp ayrı bir E.164 numaradır (usta profil telefonundan farklı bir
///   iş hattı verebilir).
/// - Web sitesi tek serbest alandır; yalnız http(s) kabul edilir.
///
/// Boş/None alanlar `toMap`'te null yazılır (Firestore'da alan silinir).
class SocialLinks {
  const SocialLinks({
    this.instagram,
    this.youtube,
    this.tiktok,
    this.whatsapp,
    this.website,
  });

  /// Instagram kullanıcı adı (@'sız, ör. `ahmet_usta`).
  final String? instagram;

  /// YouTube kanal tanıtıcısı (@'sız handle ya da kanal adı).
  final String? youtube;

  /// TikTok kullanıcı adı (@'sız).
  final String? tiktok;

  /// WhatsApp iş hattı — E.164 (`+905321234567`).
  final String? whatsapp;

  /// Tam web sitesi adresi (`https://…`).
  final String? website;

  static const empty = SocialLinks();

  bool get hasAny =>
      _ok(instagram) ||
      _ok(youtube) ||
      _ok(tiktok) ||
      _ok(whatsapp) ||
      _ok(website);

  static bool _ok(String? s) => s != null && s.trim().isNotEmpty;

  /// Girilen metni kullanıcı adına indirger: baştaki `@`, tam URL, sondaki
  /// `/` ve sorgu parçaları atılır. Sonuç boşsa null döner.
  ///
  /// `https://instagram.com/ahmet_usta/?hl=tr` → `ahmet_usta`
  static String? normalizeHandle(String? raw) {
    var s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    // Tam URL ise son yol parçasını al.
    if (s.contains('/')) {
      final parts = s
          .split('?').first
          .split('#').first
          .split('/')
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      s = parts.last;
    }
    s = s.replaceFirst(RegExp(r'^@+'), '').trim();
    if (s.isEmpty) return null;
    // Nokta içeren girdi kullanıcı adı değil, alan adıdır ("instagram.com"):
    // kullanıcı yanlış alana site adresi yazmış demektir.
    if (s.contains('.')) return null;
    return s;
  }

  /// WhatsApp numarasını E.164'e indirger. TR kısayolları desteklenir:
  /// `0532…` ve `532…` → `+90532…`. Rakam sayısı makul değilse null.
  static String? normalizeWhatsapp(String? raw) {
    var s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final hadPlus = s.startsWith('+');
    var digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (!hadPlus) {
      // Yerel yazım: baştaki 0 atılır, 10 haneli TR numarasına +90 eklenir.
      if (digits.startsWith('0')) digits = digits.substring(1);
      if (digits.length == 10) digits = '90$digits';
    }
    if (digits.length < 8 || digits.length > 15) return null; // E.164 sınırı
    return '+$digits';
  }

  /// Web sitesi normalizasyonu: şema yoksa `https://` eklenir. Yalnız
  /// http/https kabul edilir (`javascript:` gibi şemalar reddedilir → null).
  static String? normalizeWebsite(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final withScheme =
        s.contains('://') ? s : 'https://$s';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    // Alan adında en az bir nokta olmalı ("localhost" vitrinde anlamsız).
    if (!uri.host.contains('.')) return null;
    return uri.toString();
  }

  /// Dokununca açılacak adresler (null = o bağlantı yok).
  String? get instagramUrl =>
      _ok(instagram) ? 'https://instagram.com/${instagram!.trim()}' : null;

  String? get youtubeUrl =>
      _ok(youtube) ? 'https://youtube.com/@${youtube!.trim()}' : null;

  String? get tiktokUrl =>
      _ok(tiktok) ? 'https://tiktok.com/@${tiktok!.trim()}' : null;

  /// wa.me `+` istemez, yalnız rakam.
  String? get whatsappUrl {
    if (!_ok(whatsapp)) return null;
    final digits = whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : 'https://wa.me/$digits';
  }

  String? get websiteUrl => _ok(website) ? website!.trim() : null;

  SocialLinks copyWith({
    String? instagram,
    String? youtube,
    String? tiktok,
    String? whatsapp,
    String? website,
    bool clearInstagram = false,
    bool clearYoutube = false,
    bool clearTiktok = false,
    bool clearWhatsapp = false,
    bool clearWebsite = false,
  }) =>
      SocialLinks(
        instagram: clearInstagram ? null : (instagram ?? this.instagram),
        youtube: clearYoutube ? null : (youtube ?? this.youtube),
        tiktok: clearTiktok ? null : (tiktok ?? this.tiktok),
        whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
        website: clearWebsite ? null : (website ?? this.website),
      );

  Map<String, dynamic> toMap() => {
        'instagram': _ok(instagram) ? instagram!.trim() : null,
        'youtube': _ok(youtube) ? youtube!.trim() : null,
        'tiktok': _ok(tiktok) ? tiktok!.trim() : null,
        'whatsapp': _ok(whatsapp) ? whatsapp!.trim() : null,
        'website': _ok(website) ? website!.trim() : null,
      };

  factory SocialLinks.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    String? read(String key) {
      final v = map[key];
      if (v is! String) return null;
      final s = v.trim();
      return s.isEmpty ? null : s;
    }

    return SocialLinks(
      instagram: read('instagram'),
      youtube: read('youtube'),
      tiktok: read('tiktok'),
      whatsapp: read('whatsapp'),
      website: read('website'),
    );
  }
}

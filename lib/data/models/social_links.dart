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

  /// Bilinen sosyal medya alan adları — kullanıcı adı sanılmasınlar.
  ///
  /// `ahmet.usta` GEÇERLİ bir Instagram adıdır; "nokta varsa alan adıdır"
  /// kuralı meşru adları da eliyordu. Onun yerine yalnız bu liste reddedilir.
  static const _domains = {
    'instagram.com', 'www.instagram.com', 'instagr.am',
    'youtube.com', 'www.youtube.com', 'youtu.be',
    'tiktok.com', 'www.tiktok.com', 'vm.tiktok.com',
    'facebook.com', 'www.facebook.com', 'fb.com',
    'x.com', 'twitter.com', 'www.twitter.com',
    'wa.me', 'api.whatsapp.com',
  };

  /// Kullanıcı adında izin verilen karakterler: harf, rakam, `.`, `_`, `-`.
  /// (Instagram/TikTok/YouTube'un ortak paydası.)
  static final _handleOk = RegExp(r'^[A-Za-z0-9._-]+$');

  /// Girilen metni kullanıcı adına indirger: baştaki `@`, tam URL, sondaki
  /// `/` ve sorgu parçaları atılır. Sonuç geçersizse null döner.
  ///
  /// `https://instagram.com/ahmet_usta/?hl=tr` → `ahmet_usta`
  ///
  /// Hata SEBEBİ gerekiyorsa [handleError] kullanın — bu metot yalnız
  /// "temiz değer ya da null" döndürür.
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
      // "instagram.com/" gibi yalnız alan adı kaldıysa kullanıcı adı yok.
      if (parts.length == 1 && _domains.contains(parts.first.toLowerCase())) {
        return null;
      }
      s = parts.last;
    }
    s = s.replaceFirst(RegExp(r'^@+'), '').trim();
    if (s.isEmpty) return null;
    // Şemasız alan adı ("instagram.com") — kullanıcı yanlış alana site
    // adresi yazmış demektir.
    if (_domains.contains(s.toLowerCase())) return null;
    // Boşluk/geçersiz karakter: hiçbir platformda böyle bir ad yok.
    if (!_handleOk.hasMatch(s)) return null;
    if (s.length > 40) return null;
    return s;
  }

  /// Kullanıcı adı için TÜRKÇE hata mesajı; sorun yoksa null.
  ///
  /// UI bunu `errorText` olarak gösterir — geçersiz girdiyi sessizce silmek
  /// yerine NEDENİNİ söyler. Boş girdi hata değildir (alan isteğe bağlı).
  static String? handleError(String? raw, {required String platform}) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    if (normalizeHandle(s) != null) return null;

    final temiz = s.replaceFirst(RegExp(r'^@+'), '').trim();
    if (_domains.contains(temiz.toLowerCase()) ||
        (temiz.contains('/') && normalizeHandle(temiz) == null)) {
      return '$platform adresini değil, kullanıcı adını yazın.';
    }
    if (temiz.contains(' ')) {
      return 'Kullanıcı adı boşluk içeremez.';
    }
    if (temiz.length > 40) {
      return 'Kullanıcı adı çok uzun.';
    }
    return 'Yalnız harf, rakam, nokta, alt çizgi ve tire kullanın.';
  }

  /// WhatsApp numarası için hata mesajı; sorun yoksa null.
  static String? whatsappError(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    if (normalizeWhatsapp(s) != null) return null;
    if (!RegExp(r'[0-9]').hasMatch(s)) {
      return 'Telefon numarası girin (ör. 0532 123 45 67).';
    }
    return 'Numara eksik ya da hatalı görünüyor.';
  }

  /// Web sitesi için hata mesajı; sorun yoksa null.
  static String? websiteError(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    if (normalizeWebsite(s) != null) return null;
    final lower = s.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:')) {
      return 'Yalnız http/https adresleri kabul edilir.';
    }
    if (!s.contains('.')) {
      return 'Geçerli bir adres girin (ör. ornek.com).';
    }
    return 'Adres anlaşılamadı (ör. ornek.com).';
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

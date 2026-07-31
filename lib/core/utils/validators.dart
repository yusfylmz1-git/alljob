import '../constants/app_constants.dart';

/// Form doğrulayıcıları. Kullanıcı hatalarını giriş anında yakalar.
/// Tüm mesajlar Türkçe ve kullanıcı dostudur.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  /// Mesaj içinde telefon numarası tespiti (yumuşak caydırma için).
  static final RegExp phoneInText = RegExp(
    r'(\+?\d[\d\s().-]{8,}\d)',
  );

  /// Kontrol / görünmez karakterler (null, bel, RTL override vb.).
  static final RegExp _controlChars = RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  /// Ad-soyad: harf (TR dahil), birleşik işaret, rakam, boşluk, . ' -
  static final RegExp _displayNamePattern = RegExp(
    r"^[\p{L}\p{M}\p{N}\s.'\-]+$",
    unicode: true,
  );

  static final RegExp _letterPattern = RegExp(r'\p{L}', unicode: true);

  /// 8+ ardışık harf/rakam dışı (sembol spam).
  static final RegExp _longSymbolRun = RegExp(
    r'[^\p{L}\p{N}\s]{8,}',
    unicode: true,
  );

  static final RegExp _multiSpace = RegExp(r'\s+');

  /// Görünen adı normalize et: trim, boşluk birleştir, kontrol karakteri sil.
  static String normalizeDisplayName(String? value) {
    var v = (value ?? '').trim();
    if (v.isEmpty) return '';
    v = v.replaceAll(_controlChars, '');
    v = v.replaceAll(_multiSpace, ' ').trim();
    return v;
  }

  /// Serbest metni temizle (kontrol karakteri + fazla boşluk).
  static String sanitizeFreeText(String? value) {
    var v = value ?? '';
    v = v.replaceAll(_controlChars, '');
    // Satır sonlarını koru, satır içi fazla boşluğu sadeleştir.
    v = v
        .split('\n')
        .map((line) => line.replaceAll(_multiSpace, ' ').trimRight())
        .join('\n')
        .trim();
    return v;
  }

  static String? required(String? value, {String field = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field boş bırakılamaz';
    }
    return null;
  }

  /// Ad-soyad: uzunluk + yalnızca güvenli karakterler + en az 2 harf.
  /// `***"""` veya `-/*-*/` gibi isimler reddedilir.
  static String? displayName(String? value) {
    final v = normalizeDisplayName(value);
    if (v.isEmpty) return 'Ad-soyad boş bırakılamaz';
    if (v.length < 3) return 'Ad-soyad en az 3 karakter olmalı';
    if (v.length > AppConstants.maxDisplayNameLength) {
      return 'Ad-soyad en fazla ${AppConstants.maxDisplayNameLength} karakter olabilir';
    }
    if (_controlChars.hasMatch(value ?? '') || !_displayNamePattern.hasMatch(v)) {
      return "Ad-soyad yalnızca harf, rakam, boşluk ve . ' - içerebilir";
    }
    final letters = _letterPattern.allMatches(v).length;
    if (letters < 2) {
      return 'Ad-soyad en az 2 harf içermeli';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta boş bırakılamaz';
    if (!_emailRegex.hasMatch(v)) return 'Geçerli bir e-posta adresi giriniz';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Şifre boş bırakılamaz';
    if (v.length < AppConstants.minPasswordLength) {
      return 'Şifre en az ${AppConstants.minPasswordLength} karakter olmalı';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Şifre tekrarı boş bırakılamaz';
    if (value != original) return 'Şifreler eşleşmiyor';
    return null;
  }

  /// TR yazımlı tutarı sayıya çevirir: "1.500" → 1500, "1.500,50" → 1500.5,
  /// "1500.50" → 1500.5, "₺ 2.000" → 2000. Ayrıştırılamazsa null.
  ///
  /// Kural: virgül ve nokta birlikteyse SONDAKİ ayraç ondalıktır; yalnız
  /// virgül varsa ondalıktır; yalnız nokta varsa ardından tam 3 hane
  /// geliyorsa (veya birden çok nokta varsa) binlik sayılır ("1.500" = 1500),
  /// aksi halde ondalıktır ("10.5" = 10.5).
  static double? parseTrAmount(String? value) {
    var v = (value ?? '').trim();
    if (v.isEmpty) return null;
    v = v.replaceAll(RegExp(r'[^\d.,]'), '');
    if (v.isEmpty) return null;
    final lastComma = v.lastIndexOf(',');
    final lastDot = v.lastIndexOf('.');
    String decimalSep = '';
    if (lastComma >= 0 && lastDot >= 0) {
      decimalSep = lastComma > lastDot ? ',' : '.';
    } else if (lastComma >= 0) {
      decimalSep = ',';
    } else if (lastDot >= 0) {
      final digitsAfter = v.length - lastDot - 1;
      final multipleDots = '.'.allMatches(v).length > 1;
      decimalSep = (digitsAfter == 3 || multipleDots) ? '' : '.';
    }
    String digitsOnly(String s) => s.replaceAll(RegExp(r'[.,]'), '');
    String normalized;
    if (decimalSep.isEmpty) {
      normalized = digitsOnly(v);
    } else {
      final sepIndex = decimalSep == ',' ? lastComma : lastDot;
      final intPart = digitsOnly(v.substring(0, sepIndex));
      final fracPart = digitsOnly(v.substring(sepIndex + 1));
      normalized = fracPart.isEmpty ? intPart : '$intPart.$fracPart';
    }
    if (normalized.isEmpty || normalized == '.') return null;
    return double.tryParse(normalized);
  }

  /// Pozitif tam sayı (örn. deneyim yılı).
  static String? positiveInt(String? value,
      {String field = 'Değer', int max = 80}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field boş bırakılamaz';
    final n = int.tryParse(v);
    if (n == null) return '$field sayı olmalı';
    if (n < 0) return '$field negatif olamaz';
    if (n > max) return '$field $max değerinden büyük olamaz';
    return null;
  }

  /// Deneyim yılı: boş = 0 kabul; aksi halde 0…[maxExperienceYears].
  static String? experienceYears(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null) return 'Deneyim yılı sayı olmalı';
    if (n < 0) return 'Deneyim yılı negatif olamaz';
    if (n > AppConstants.maxExperienceYears) {
      return 'Deneyim yılı en fazla ${AppConstants.maxExperienceYears} olabilir';
    }
    return null;
  }

  /// Deneyim yılını güvenli aralığa sıkıştır.
  static int clampExperienceYears(int years) =>
      years.clamp(0, AppConstants.maxExperienceYears);

  static String? maxLength(String? value, int max, {String field = 'Metin'}) {
    if (value != null && value.length > max) {
      return '$field en fazla $max karakter olabilir';
    }
    return null;
  }

  /// Serbest metin (ilan, sohbet, hakkımda):
  /// önce temizle (yapıştırma gizli karakterleri), sonra uzunluk/sembol kontrolü.
  static String? freeText(
    String? value, {
    required int max,
    String field = 'Metin',
    int min = 0,
    bool required = false,
  }) {
    // Gizli/kontrol karakterlerini REDDETMEK yerine temizle — WhatsApp/not
    // yapıştırması sık "geçersiz karakter" üretiyordu.
    final v = sanitizeFreeText(value);
    if (v.isEmpty) {
      return required || min > 0 ? '$field boş bırakılamaz' : null;
    }
    if (v.length < min) {
      return '$field en az $min karakter olmalı (şu an ${v.length})';
    }
    if (v.length > max) {
      return '$field en fazla $max karakter olabilir (şu an ${v.length})';
    }
    if (_longSymbolRun.hasMatch(v)) {
      return '$field içinde art arda çok fazla özel karakter var '
          '(…… / **** gibi). Metni sadeleştirin.';
    }
    // Sayı/ölçü ağırlıklı ilan metinleri (m², 3+1) harf oranını düşürür;
    // mutlak harf eşiği: en az 4 harf (spam/sadece rakam engeli).
    final letters = _letterPattern.allMatches(v).length;
    if (v.length >= 10 && letters < 4) {
      return '$field anlamlı bir cümle içermeli (sadece rakam/sembol olamaz)';
    }
    return null;
  }
}

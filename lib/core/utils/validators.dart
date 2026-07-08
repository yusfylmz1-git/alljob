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

  static String? required(String? value, {String field = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field boş bırakılamaz';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ad-soyad boş bırakılamaz';
    if (v.length < 3) return 'Ad-soyad en az 3 karakter olmalı';
    if (v.length > AppConstants.maxDisplayNameLength) {
      return 'Ad-soyad en fazla ${AppConstants.maxDisplayNameLength} karakter olabilir';
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

  /// Pozitif tam sayı (örn. deneyim yılı).
  static String? positiveInt(String? value, {String field = 'Değer', int max = 80}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field boş bırakılamaz';
    final n = int.tryParse(v);
    if (n == null) return '$field sayı olmalı';
    if (n < 0) return '$field negatif olamaz';
    if (n > max) return '$field $max değerinden büyük olamaz';
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'Metin'}) {
    if (value != null && value.length > max) {
      return '$field en fazla $max karakter olabilir';
    }
    return null;
  }
}

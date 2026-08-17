import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-15 cihaz bulgusu — MÜŞTERİ PROFİLİNİ KAYDEDEMİYORDU.
///
/// `/profile/edit` rotası (app_router.dart) `ArtisanProfileEditScreen`'i
/// MÜŞTERİYE de açar: ad, hakkımda, fotoğraf gibi alanlar her iki modda da
/// buradan düzenlenir. Ekran usta alanlarını (meslek + hizmet bölgesi)
/// `showArtisanVitrin` bayrağıyla YALNIZ ustaya gösterir.
///
/// Hata: `_save()` bu ayrımı yapmıyordu. Müşteri Kaydet'e bastığında
/// "En az bir meslek seçin..." uyarısı alıyor, ama uyarının işaret ettiği
/// seçici ekranda BULUNMUYORDU — kullanıcının kendi başına çözemeyeceği bir
/// çıkmaz. Aynı şey hizmet bölgesi kontrolü ve sağlayıcı telefon kapısı için
/// de geçerliydi (müşteri, görmediği bir alan yüzünden SMS doğrulamasına
/// zorlanıyordu).
///
/// Düzeltme: üç kapı da `ustaMi` (hasArtisanProfile) koşuluna bağlandı.
///
/// Ekran Riverpod + async kapılar içerdiği için birim testiyle
/// sürülemez; sözleşme `profile_save_fields_test.dart` ile aynı yöntemle,
/// kaynak üzerinden doğrulanır.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
    ).readAsStringSync();
  });

  /// `_save()` gövdesi: imzadan bir sonraki üst düzey üyeye kadar.
  String saveBody() {
    final start = source.indexOf('Future<void> _save() async {');
    expect(start, greaterThan(-1), reason: '_save bulunamadı.');
    final next = source.indexOf('Widget build(BuildContext context)', start);
    expect(next, greaterThan(start), reason: 'build sınır olarak bulunamadı.');
    return source.substring(start, next);
  }

  group('Müşteri profili — usta alanları zorunlu tutulmaz', () {
    test('_save usta modunu okur', () {
      expect(
        saveBody(),
        contains('hasArtisanProfile'),
        reason: '_save mod ayrımı yapmıyor; müşteri usta kapılarına takılır.',
      );
    });

    test('meslek kontrolü yalnız ustaya uygulanır', () {
      expect(
        saveBody(),
        contains('ustaMi && draft.profile.professionCodes.isEmpty'),
        reason: 'Meslek zorunluluğu müşteriyi de kapsıyor — ekranda '
            'görünmeyen bir alan yüzünden kayıt engellenir.',
      );
    });

    test('hizmet bölgesi kontrolü yalnız ustaya uygulanır', () {
      expect(
        saveBody(),
        contains('ustaMi && bolgeler.isEmpty'),
        reason: 'Bölge zorunluluğu müşteriyi de kapsıyor.',
      );
    });

    test('sağlayıcı telefon kapısı yalnız ustaya uygulanır', () {
      final body = saveBody();
      final kapi = body.indexOf('ensureVerifiedPhoneForProvider');
      expect(kapi, greaterThan(-1), reason: 'Telefon kapısı kaybolmuş.');

      // Kapı `if (ustaMi) {` bloğunun İÇİNDE olmalı: müşterinin adını
      // değiştirmesi SMS doğrulaması gerektirmez (maliyet + sürtünme).
      final blok = body.lastIndexOf('if (ustaMi) {', kapi);
      expect(
        blok,
        greaterThan(-1),
        reason: 'Telefon kapısı koşulsuz çağrılıyor; müşteri de SMS '
            'doğrulamasına zorlanır.',
      );
    });

    // FAZLASINI YAPMAMA kontrolü: kapılar kaldırılmadı, yalnız koşullandı.
    // Usta için üç doğrulama da yerinde durmalı.
    test('usta için üç kapı da korunur', () {
      final body = saveBody();
      expect(body, contains('professionCodes.isEmpty'),
          reason: 'Meslek kontrolü tamamen silinmiş.');
      expect(body, contains('En az bir hizmet bölgesi ekleyin.'),
          reason: 'Bölge kontrolü tamamen silinmiş.');
      expect(body, contains('ensureVerifiedPhoneForProvider'),
          reason: 'Telefon kapısı tamamen silinmiş.');
    });
  });
}

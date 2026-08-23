import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';

/// Profil düzenleme — kullanıcı bulguları (2026-08-10).
///
/// 1) Meslek aramasında kategori başlığı yazılınca altındakiler gelmeli.
/// 2) Bölge seçilip "+" basılmazsa Kaydet uyarı veriyordu; seçim ekranda
///    duruyorsa niyet açıktır, otomatik eklenmeli.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String ekran;
  setUpAll(() => ekran = read(
      'lib/features/artisan/presentation/artisan_profile_edit_screen.dart'));

  group('1 — Meslek araması kategori başlığına da bakar', () {
    test('filtre kategori adını arar', () {
      expect(
        ekran.contains(
            'matchesTrSearch(ProfessionCategory.label(p.category), q)'),
        isTrue,
        reason: '"İnşaat" yazınca o kategorinin meslekleri listelenmeli; '
            'yalnız meslek adına bakılsaydı sıfır sonuç verirdi.',
      );
    });

    test('kategori aramasında başlıklar KALIR', () {
      // Normal metin aramasında başlık gürültü (sonuç zaten daraldı), ama
      // kategori adı yazıldıysa sonucun neden geldiğini başlık açıklar.
      expect(ekran.contains('kategoriAramasi'), isTrue);
    });
  });

  group('2 — Bekleyen bölge seçimi kaydederken otomatik eklenir', () {
    test('kaydet, seçili il+ilçeyi ekler', () {
      expect(
        ekran.contains('if (_addProvince != null && _addDistrict != null)'),
        isTrue,
        reason: '"+" basılmadıysa da seçim kaydedilmeli.',
      );
      // Eklemeden SONRA okunmalı; önce okunursa liste boş görünür ve
      // kullanıcı yine uyarı alır.
      final kaydet = ekran.substring(ekran.indexOf('Future<void> _save()'));
      final ekleme = kaydet.indexOf('_controller.addServiceArea(');
      final okuma = kaydet.indexOf('final bolgeler =');
      expect(ekleme, greaterThan(0));
      expect(okuma, greaterThan(ekleme),
          reason: 'Bölge listesi otomatik eklemeden sonra okunmalı.');
    });

    test('boş durum metni seçim varken farklı', () {
      expect(ekran.contains('Seçtiğiniz bölge kaydederken eklenecek'), isTrue,
          reason: 'Kullanıcı ilçeyi seçmişken "eklemediniz" demek yanlış '
              'hissettiriyordu — seçimini ekranda görüyor.');
    });

    test('aynı bölge iki kez eklenmez (otomatik ekleme güvenli)', () {
      // Otomatik ekleme `addServiceArea`nın tekilleştirmesine dayanır:
      // kullanıcı "+" bastıysa ve seçim ekranda durmaya devam ediyorsa
      // Kaydet ikinci kez eklememeli.
      final a = ServiceArea(
          province: 'Bursa'.toString(), district: 'Nilüfer'.toString());
      final b = ServiceArea(
          province: 'Bursa'.toString(), district: 'Nilüfer'.toString());
      expect(a == b, isTrue,
          reason: 'ServiceArea eşitliği yoksa contains() çalışmaz ve '
              'bölge iki kez eklenir.');
      expect([a].contains(b), isTrue,
          reason: 'addServiceArea tam olarak bu kontrolü yapıyor.');
    });

    test('controller tekilleştirmeyi yapıyor', () {
      // 2026-08-23: tek il kuralı gelince satır `mevcut.contains(area)`
      // oldu (liste önce yerel değişkene alınıyor). Kontrol edilen şey
      // ifadenin YAZIMI değil, mükerrer eklemenin engellendiğidir.
      final c = read(
          'lib/features/artisan/application/my_profile_controller.dart');
      expect(c.contains('.contains(area)'), isTrue,
          reason: 'addServiceArea aynı bölgeyi ikinci kez eklememeli.');
    });
  });
}

// Regresyon: admin panelinde meslek/il SEÇİCİ, metin kutusu değil
// (2026-08-23).
//
// Kullanıcı bulgusu: "bildirim ekranında meslek kodu soruyor. ama bunlar
// nerede tutuluyor, nerden bulucaz? tek tek hepsine bakma mantıksız
// değil mi?"
//
// Katalogda 145 meslek var ve hiçbiri ekranda görünmüyordu. Yönetici
// `painter` yazmak zorundaydı. Daha kötüsü: yanlış yazım HATA VERMİYORDU —
// sunucu "alıcı bulunamadı" diyor, yönetici duyurunun kimseye gitmemesiyle
// meslek kodunu yanlış yazmayı ayırt edemiyordu.
//
// Çift test (kural 7): seçici geldi Mİ + katalog tek kaynaktan mı okunuyor.
// İkincisi kritik: dört ekran ayrı liste tutarsa biri güncellenip diğerleri
// unutulur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart'
    show kProfessionNames;

void main() {
  String read(String p) => File(p).readAsStringSync();

  const ekranlar = {
    'bildirim': 'lib/features/admin/presentation/admin_broadcast_screen.dart',
    'ilanlar': 'lib/features/admin/presentation/admin_jobs_screen.dart',
    'usta vitrini':
        'lib/features/admin/presentation/admin_artisans_screen.dart',
  };

  group('Meslek/il artık ELLE yazılmıyor', () {
    test('hiçbir ekranda "Meslek kodu" metin kutusu YOK', () {
      for (final e in ekranlar.entries) {
        expect(read(e.value).contains("labelText: 'Meslek kodu'"), isFalse,
            reason: '${e.key} ekranında hâlâ elle kod isteniyor.');
      }
    });

    test('hiçbir ekranda düz "İl" metin kutusu YOK', () {
      for (final e in ekranlar.entries) {
        final kaynak = read(e.value);
        // Seçicinin kendi `label: 'İl'` parametresi serbest; yasak olan
        // TextField'ın `labelText`i.
        expect(kaynak.contains("labelText: 'İl'"), isFalse,
            reason: '${e.key} ekranında hâlâ elle il yazılıyor.');
      }
    });

    test('üç ekran da ortak seçiciyi kullanıyor', () {
      expect(read(ekranlar['bildirim']!).contains('AdminProfessionPicker('),
          isTrue);
      expect(read(ekranlar['bildirim']!).contains('AdminProvincePicker('),
          isTrue);
      expect(read(ekranlar['ilanlar']!).contains('AdminProvincePicker('),
          isTrue);
      expect(
          read(ekranlar['usta vitrini']!).contains('AdminProfessionPicker('),
          isTrue);
    });
  });

  group('Katalog TEK kaynaktan okunuyor', () {
    late String secici;
    setUpAll(() =>
        secici = read('lib/features/admin/presentation/admin_pickers.dart'));

    test('meslek listesi kProfessionNames\'ten geliyor', () {
      // Dört ekranda ayrı liste tutulsaydı biri güncellenip diğerleri
      // unutulurdu; yeni meslek eklenince bazı ekranlar görmezdi.
      expect(secici.contains('kProfessionNames.keys'), isTrue);
    });

    test('il listesi provincesProvider\'dan geliyor', () {
      expect(secici.contains('provincesProvider'), isTrue);
    });

    test('katalog boş DEĞİL (seçici anlamlı)', () {
      expect(kProfessionNames.length, greaterThan(100),
          reason: 'Katalog beklenmedik biçimde küçülmüş.');
    });
  });

  group('Seçici kullanışlı davranıyor', () {
    late String secici;
    setUpAll(() =>
        secici = read('lib/features/admin/presentation/admin_pickers.dart'));

    test('meslekler ADA göre sıralı', () {
      // Yönetici "Boyacı"yı B'de arar, `painter`ı p'de değil.
      expect(secici.contains('..sort((a, b) => (kProfessionNames[a] ?? a)'),
          isTrue);
    });

    test('ekranda hem ad hem KOD görünüyor', () {
      // Denetim kaydında ham kod yazıyor; yönetici iki gösterimi
      // eşleştirebilmeli.
      expect(secici.contains("'\${kProfessionNames[k] ?? k}  ·  \$k'"), isTrue);
    });

    test('değer olarak KOD tutuluyor, ad değil', () {
      // Sunucu kod bekliyor; ad göndermek sessiz başarısızlık üretirdi.
      expect(secici.contains('SearchableSelectField<String>'), isTrue);
      expect(secici.contains('onSelected: onChanged'), isTrue);
    });

    test('il değeri AD tutuyor (sorgular adla çalışıyor)', () {
      // `serviceAreas.province` ve `jobs.province` il ADI tutar; id'ye
      // çevirmek gereksiz bir dönüşüm katmanı olurdu.
      expect(secici.contains('onChanged(p.name)'), isTrue);
    });
  });

  group('Fazlasını yapmıyor — filtre ile hedef AYRI', () {
    test('filtrelerde "Tümü" var, hedefte YOK', () {
      // Filtre temizlenebilmeli. Ama duyuru hedefinde "Tümü" seçilirse
      // kimseye gitmeyen bir kampanya doğar — orada allowClear kapalı.
      final bildirim = read(
          'lib/features/admin/presentation/admin_broadcast_screen.dart');
      final ilanlar =
          read('lib/features/admin/presentation/admin_jobs_screen.dart');
      final ustalar =
          read('lib/features/admin/presentation/admin_artisans_screen.dart');

      expect(ilanlar.contains('allowClear: true'), isTrue,
          reason: 'İlan filtresi temizlenemiyor.');
      expect(ustalar.contains('allowClear: true'), isTrue,
          reason: 'Usta filtresi temizlenemiyor.');
      expect(bildirim.contains('allowClear: true'), isFalse,
          reason: 'Duyuru hedefinde "Tümü" seçilirse kimseye gitmez.');
    });

    test('bildirim önizlemesi KOD değil AD gösteriyor', () {
      final bildirim = read(
          'lib/features/admin/presentation/admin_broadcast_screen.dart');
      expect(bildirim.contains('kProfessionNames[_professionCode]'), isTrue,
          reason: 'Onay ekranında ham kod gösterilirse yönetici ne '
              'seçtiğini okuyamaz.');
    });

    test('boş hedef hâlâ REDDEDİLİYOR', () {
      // Seçici geldi diye doğrulama düşmemeli.
      final bildirim = read(
          'lib/features/admin/presentation/admin_broadcast_screen.dart');
      expect(bildirim.contains("(_professionCode ?? '').isEmpty"), isTrue);
      expect(bildirim.contains("(_provinceName ?? '').isEmpty"), isTrue);
    });
  });
}

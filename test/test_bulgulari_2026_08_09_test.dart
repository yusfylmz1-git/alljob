import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cihaz testi bulguları (vault/06-Test/Yapılacaklar.md) — 2026-08-09.
///
/// Her test bir madde numarasına bağlıdır. Kaynak metnini okurlar çünkü
/// düzeltmelerin çoğu davranışsal kanca (PopScope, autofocus, yönlendirme)
/// ve bunları widget testiyle sürmek kurulum maliyetini kata çıkarırdı;
/// aranan şey "bu karar geri alınmış mı?" sorusunun cevabı.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Madde 3 — Temizle filtreyi HEMEN uygular', () {
    late String sheet;
    setUpAll(() => sheet = read(
        'lib/features/customer/presentation/widgets/detailed_search_sheet.dart'));

    test('Temizle hem seçimleri sıfırlar hem aramayı tetikler', () {
      final i = sheet.indexOf('clearSelections()');
      expect(i, greaterThan(-1), reason: 'Temizle düğmesi kaybolmuş.');

      // Aynı onPressed gövdesinde arama çağrısı da olmalı; yoksa liste
      // "Usta Bul"a basılana kadar ESKİ sonuçları göstermeye devam eder.
      final blok = sheet.substring(i, i + 220);
      expect(blok.contains('artisanSearchControllerProvider'), isTrue,
          reason: 'Temizle sonrası arama tetiklenmiyor — filtre kalkıyor '
              'ama liste değişmiyor.');
      expect(blok.contains('.search()'), isTrue);
    });
  });

  group('Madde 5 — İl/ilçe seçiminde klavye kendiliğinden açılmaz', () {
    test('SearchableSelectField arama kutusu autofocus KAPALI', () {
      final f = read('lib/core/widgets/searchable_select_field.dart');
      expect(f.contains('autofocus: true'), isFalse,
          reason: 'autofocus geri gelmiş — sheet açılınca klavye fırlar ve '
              'listenin yarısını kapatır.');
      expect(f.contains('autofocus: false'), isTrue);
    });
  });

  group('Madde 8 — "İş İlanı Ver" tek giriş', () {
    late String kesfet;
    setUpAll(() => kesfet = read(
        'lib/features/customer/presentation/customer_dashboard_screen.dart'));

    test('İlanlar sekmesi sağ üstte var (hero\'dan taşındı)', () {
      // 2026-08-10: hero barından İlanlar sekmesi altına taşındı.
      expect(kesfet.contains("Text('Yeni İlan')"), isTrue);
      expect(kesfet.contains('RoutePaths.newJob'), isTrue);
      expect(kesfet.contains('class _JobsTab'), isTrue);
    });

    test('arama satırının altındaki ikinci düğme YOK', () {
      // Filtreleri temizle'nin dibindeki OutlinedButton kalkmıştı: aramayla
      // ilgisi olmayan bir eylemi arama alanının içine sokuyordu.
      expect(kesfet.contains("label: const Text('İş İlanı Ver')"), isFalse,
          reason: 'İkinci ilan-ver düğmesi geri eklenmiş.');
    });

    test('yan menüde YOK', () {
      final drawer = read('lib/core/widgets/app_menu_drawer.dart');
      expect(drawer.contains("Text('İş İlanı Ver')"), isFalse);
    });
  });

  group('Madde 2 — Müşteri kendi ilanlarına ulaşabilir', () {
    test('İlanlarım menüde moddan bağımsız', () {
      final drawer = read('lib/core/widgets/app_menu_drawer.dart');
      final i = drawer.indexOf("title: const Text('İlanlarım')");
      expect(i, greaterThan(-1));

      // Satırın hemen ÖNÜNDE bir usta-modu koşulu olmamalı.
      final onceki = drawer.substring(i - 200, i);
      expect(onceki.contains('if (user.isArtisan)'), isFalse,
          reason: 'İlanlarım yeniden usta moduna bağlanmış — ilanı VEREN '
              'müşteri kendi ilanlarını göremez.');
    });

    test('profildeki ikinci düğme İlanlarım', () {
      final profil =
          read('lib/features/profile/presentation/profile_screen.dart');
      // 2026-08-14: `label: const Text('İlanlarım')` biçimi.
      expect(profil.contains('İlanlarım'), isTrue);
      expect(profil.contains('Profilime bak'), isFalse);
    });
  });

  group('Madde 4 — Menü açıkken geri tuşu menüyü kapatır', () {
    test('MainTabScope çekmece durumunu kontrol eder', () {
      final bar = read('lib/core/widgets/role_bottom_bar.dart');
      expect(bar.contains('isDrawerOpen'), isTrue,
          reason: 'Çekmece kontrolü kalkmış — menü açıkken geri tuşu '
              'uygulamayı küçültür.');
      expect(bar.contains('closeDrawer()'), isTrue);

      // Ana Sayfa'da bile çekmece varsa pop'u BİZ ele almalıyız; aksi hâlde
      // `canPop: true` geri tuşunu doğrudan sisteme yollardı.
      expect(bar.contains('canPop: isHome && scaffoldKey == null'), isTrue);
    });

    test('çekmeceli sekme ekranları scaffoldKey veriyor', () {
      // Anahtar verilmezse MainTabScope çekmeceyi göremez.
      for (final yol in [
        'lib/features/home/presentation/home_screen.dart',
        'lib/features/customer/presentation/customer_dashboard_screen.dart',
        'lib/features/profile/presentation/profile_screen.dart',
        'lib/features/jobs/presentation/nearby_jobs_screen.dart',
      ]) {
        final s = read(yol);
        expect(s.contains('scaffoldKey: _scaffoldKey'), isTrue,
            reason: '$yol MainTabScope\'a anahtar vermiyor.');
        expect(s.contains('key: _scaffoldKey'), isTrue,
            reason: '$yol Scaffold\'a anahtar vermiyor.');
      }
    });

    test('kendi PopScope\'u olan ekranlar da çekmeceyi kapatıyor', () {
      // Bu ikisi MainTabScope kullanmaz (seçim modu var), kancayı kendileri
      // uygular — sıra: çekmece → seçim → yığın → Ana Sayfa.
      for (final yol in [
        'lib/features/chat/presentation/chat_list_screen.dart',
        'lib/features/jobs/presentation/my_jobs_screen.dart',
      ]) {
        final s = read(yol);
        expect(s.contains('isDrawerOpen'), isTrue, reason: yol);
        expect(s.contains('closeDrawer()'), isTrue, reason: yol);
      }
    });
  });

  group('Madde 6 + 11 — Profil düzenleme çıkış davranışı', () {
    late String edit;
    setUpAll(() => edit = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart'));

    test('kayıt başarılıysa ekrandan çıkılır (madde 6)', () {
      final i = edit.indexOf("showSuccess('Profiliniz kaydedildi.')");
      expect(i, greaterThan(-1));
      final blok = edit.substring(i, i + 400);
      expect(blok.contains('context.go(RoutePaths.profile)'), isTrue,
          reason: 'Kaydettikten sonra formda kalınıyor — kullanıcı '
              '"kaydoldu mu?" diye tekrar basıyor. PopScope canPop:false '
              'pop() yutar; go ile profile dönülmeli.');
    });

    test('kurulum yapılmadan çıkılırsa usta modu geri alınır (madde 11)', () {
      expect(edit.contains('_cikistaModuGeriAl'), isTrue,
          reason: 'Geri alma kancası kalkmış — meslek/bölge seçmeden geri '
              'basan kullanıcı usta olarak kalır.');
      expect(edit.contains('UserRole.customer'), isTrue);

      // Yalnız HİÇ kurulum yoksa geri alınmalı: mevcut bir ustanın
      // profilini düzenlerken geri basması modunu KAPATMAMALI.
      final i = edit.indexOf('bool get _kurulumBos');
      expect(i, greaterThan(-1));
      final blok = edit.substring(i, i + 320);
      expect(blok.contains('professionCodes.isEmpty'), isTrue);
      expect(blok.contains('serviceAreas.isEmpty'), isTrue);
      expect(blok.contains('&&'), isTrue,
          reason: 'İki koşul VE ile bağlanmalı — yalnız biri boşken mod '
              'kapatılırsa mevcut usta cezalandırılır.');
    });
  });
}

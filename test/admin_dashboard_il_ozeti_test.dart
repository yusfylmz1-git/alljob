// Regresyon: kontrol panelinde Pro geçiş özeti (2026-08-23).
//
// Denetim bulgusu: "Dashboard ülke geneli KPI gösteriyor. Pro geçişi il il
// yürüyecekken ana ekranda hiç il bilgisi yok."
//
// Yöneticinin en sık soracağı soru "hangi il hazır" idi ve cevabı ancak
// toplu plan ekranına girerek görülebiliyordu.
//
// Çift test (kural 7): özet geldi Mİ + dashboard ikinci bir yönetim ekranına
// DÖNMEDİ Mİ. İkincisi tasarım kararı: dashboard bir vitrindir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  late String ekran;
  setUpAll(() => ekran =
      read('lib/features/admin/presentation/admin_dashboard_screen.dart'));

  group('Pro geçiş özeti ana ekranda', () {
    test('il istatistikleri okunuyor', () {
      expect(ekran.contains('provinceStatsProvider'), isTrue);
    });

    test('eşiğe ulaşan il AYIRT ediliyor', () {
      // Yöneticinin aradığı tek bilgi bu: hangi il hazır.
      expect(ekran.contains('il.reached'), isTrue);
      expect(ekran.contains('Icons.check_circle_outline'), isTrue);
    });

    test('ulaşmayan ilde KALAN sayı ve eşik yazıyor', () {
      // Özel eşikli ilde ("Siirt · eşik 300") yönetici neden orada
      // olduğunu anlayabilmeli.
      expect(ekran.contains('il.remaining'), isTrue);
      expect(ekran.contains('il.effectiveThreshold'), isTrue);
    });

    test('eşiğe ulaşan ilde AŞAMA gösteriliyor', () {
      // Geri sayım / teklif penceresi / ücretli — hangi ayda olduğu.
      expect(ekran.contains('phaseAt(DateTime.now())?.labelTR'), isTrue);
    });
  });

  group('Fazlasını yapmıyor — dashboard bir VİTRİN', () {
    test('yalnız ÜÇ il gösteriliyor', () {
      // Tam tablo toplu plan ekranında; dashboard ikinci bir yönetim
      // ekranına dönmemeli.
      expect(ekran.contains('iller.take(3)'), isTrue,
          reason: 'Dashboard tüm illeri listeliyor — vitrin olmaktan çıkmış.');
    });

    test('eşik DÜZENLEME dashboard\'da YOK', () {
      // Yıkıcı olmasa da karar gerektiren bir işlem; yeri toplu plan ekranı.
      expect(ekran.contains('setProvinceThresholdProvider'), isFalse);
      expect(ekran.contains('onLongPress'), isFalse);
    });

    test('veri yoksa bölüm HİÇ çizilmiyor', () {
      // İlk sayım yapılmadan boş bir başlık göstermek panelde gürültü.
      expect(ekran.contains('if (iller.isEmpty) return const SizedBox.shrink();'),
          isTrue);
      expect(ekran.contains('orElse: () => const SizedBox.shrink()'), isTrue,
          reason: 'Yükleme/hata durumunda boş başlık kalıyor.');
    });

    test('yetkisiz kullanıcıda dokunuş KAPALI', () {
      // Toplu plan sekmesi yalnız superadmin'de var; dokunuş sessizce
      // hiçbir şey yapmamalı.
      expect(ekran.contains('!ref.watch(isSuperAdminProvider)'), isTrue,
          reason: 'Moderatör dokununca hiçbir şey olmuyor ve sebebi '
              'anlaşılmıyor.');
    });
  });
}

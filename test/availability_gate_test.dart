import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Müsaitlik kapısı sözleşmesi (2026-08-08).
///
/// "Müsait değilim" = **yeni iş almıyorum**, "kimseyle konuşmuyorum" DEĞİL.
/// Bu ayrım kritik: süren bir işin sohbeti kesilirse teslim / sorun bildirme
/// / değerlendirme akışları ortada kalır.
///
/// | Durum | Müsait değilken |
/// |---|---|
/// | Usta aramasında görünme | ❌ |
/// | Profiline girme | ✅ ("şu an yeni iş almıyor") |
/// | **Mevcut sohbet** | ✅ **devam eder** |
/// | Yeni sohbet başlatma | ❌ |
/// | İlan listesini görme | ❌ |
/// | İlgi bildirme | ❌ |
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Aramada gizlenme', () {
    // 2026-08-09: kapı `musait()` yardımcısına taşındı — premium bayrağını
    // da hesaba katması gerekiyordu (madde 7). Eleme MANTIĞI aynı.
    test('müsait olmayan usta arama sonucunda ELENİR', () {
      for (final yol in [
        'lib/features/artisan/data/firebase_artisan_repository.dart',
        'lib/features/artisan/data/mock_artisan_repository.dart',
      ]) {
        final repo = read(yol);
        expect(repo.contains('if (!musait(r.profile)) return false;'), isTrue,
            reason: 'Müsait olmayan usta aramada görünmemeli ($yol).');
        expect(repo.contains('premiumFreeDuringBeta: premiumFreeDuringBeta'),
            isTrue,
            reason: 'Premium kapısı `musait()` içine bağlanmalı ($yol).');
      }
    });
  });

  group('İlan listesi kapısı', () {
    late String scr;
    setUpAll(() =>
        scr = read('lib/features/jobs/presentation/nearby_jobs_screen.dart'));

    // 2026-08-10 (kullanıcı kararı): müsaitlik artık listeyi KAPATMAZ.
    // Usta ilanları görür ve bildirim alır, yalnız MESAJ ATAMAZ. Eskiden
    // tam ekran duvar vardı ve usta piyasayı hiç göremiyordu.
    test('müsait değilken ilan listesi AÇILIR (duvar yok)', () {
      expect(scr.contains('_NotAvailableNotice'), isFalse,
          reason: 'Tam ekran müsaitlik duvarı geri gelmiş.');
      expect(scr.contains('_NotAvailableBanner'), isTrue,
          reason: 'Uyarı listenin üstünde şerit olarak durmalı.');
    });

    test('İlanlar sekmesi KEŞFET içinde, kapılı', () {
      // 2026-08-08: alt bardaki ayrı sekme kalktı, Keşfet'in 2. sekmesi oldu.
      // Kapı orada: giriş → usta modu → müsaitlik.
      final bar = read('lib/core/widgets/role_bottom_bar.dart');
      expect(bar.contains('showWork'), isFalse,
          reason: 'Alt bardaki İlanlar sekmesi geri gelmiş.');

      final exp = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      expect(exp.contains('class _JobsTab'), isTrue);
      expect(exp.contains('!user.isArtisan'), isTrue,
          reason: 'Usta modu kapısı olmalı.');
      // Müsaitlik kapısı BURADAN KALKTI (2026-08-10) — mesaj kapısı yerinde.
      expect(exp.contains('!draft.profile.isAvailable'), isFalse,
          reason: 'Keşfet İlanlar sekmesindeki müsaitlik duvarı geri gelmiş.');
    });
  });

  group('İlgi bildirme kapısı', () {
    test('müsait değilken ilgi bildirilemez', () {
      final s = read('lib/features/jobs/presentation/job_detail_screen.dart');
      expect(s.contains('if (!profile.isAvailable)'), isTrue,
          reason: 'Aramada görünmeyen usta ilan sahibine haber verememeli.');
    });
  });

  group('Sohbet: YENİ engellenir, MEVCUT sürer', () {
    late String s;
    setUpAll(() => s = read(
        'lib/features/customer/presentation/artisan_profile_screen.dart'));

    test('müsait olmayana yeni sohbet açılamaz', () {
      expect(s.contains('if (!detail.profile.isAvailable)'), isTrue);
      expect(s.contains('şu an yeni iş almıyor'), isTrue);
    });

    test('düğme pasif ve sebebi yazılı', () {
      // Kullanıcı tıklayıp hata almasın; durumu önceden görsün.
      expect(s.contains('Şu an yeni iş almıyor'), isTrue);
    });

    test('MEVCUT sohbet kısıtlanmıyor (kritik)', () {
      // Sohbet ekranı ve kural müsaitliğe BAKMAMALI — süren iş kesilmesin.
      final chat = read('lib/features/chat/presentation/chat_screen.dart');
      expect(chat.contains('isAvailable'), isFalse,
          reason: 'Sohbet ekranı müsaitliğe bakarsa süren iş kesilir.');

      final rules = read('firestore.rules');
      final fn = RegExp(r'function senderMayWrite\(\) \{.*?\n        \}',
              dotAll: true)
          .firstMatch(rules);
      expect(fn, isNotNull);
      expect(fn!.group(0)!.contains('isAvailable'), isFalse,
          reason: 'Kural müsaitliğe bakarsa mevcut sohbetler sunucuda '
              'reddedilir.');
    });

    test('canSend yalnız kilide bakar', () {
      final model = read('lib/data/models/chat.dart');
      expect(model.contains('bool canSend(String uid) => !isLocked;'), isTrue);
    });
  });
}

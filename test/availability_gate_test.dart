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
      // Kapı: giriş → usta PROFİLİ (mod switch değil).
      final bar = read('lib/core/widgets/role_bottom_bar.dart');
      expect(bar.contains('showWork'), isFalse,
          reason: 'Alt bardaki İlanlar sekmesi geri gelmiş.');

      final exp = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      expect(exp.contains('class _JobsTab'), isTrue);
      expect(exp.contains('!user.hasArtisanProfile'), isTrue,
          reason: 'Usta profili kapısı olmalı (aktif mod değil).');
      // Müsaitlik kapısı BURADAN KALKTI (2026-08-10) — mesaj kapısı yerinde.
      expect(exp.contains('!draft.profile.isAvailable'), isFalse,
          reason: 'Keşfet İlanlar sekmesindeki müsaitlik duvarı geri gelmiş.');
    });
  });

  group('İlgi bildirme kapısı', () {
    test('müsait değilken ilgi bildirilemez', () {
      final s = read('lib/features/jobs/presentation/job_detail_screen.dart');
      expect(s.contains('artisanAvailabilityAllowsNewChat'), isTrue,
          reason: 'Ortak müsaitlik kapısı çağrılmalı.');
      expect(s.contains('providerIsUnavailableForNewChat'), isTrue,
          reason: 'UI müsait değilken Mesaj Gönder gizlemeli.');
    });

    test('müsait değilken ekranda yönlendirme var (yanlış "başka müşteri" değil)',
        () {
      final s = read('lib/features/jobs/presentation/job_detail_screen.dart');
      expect(s.contains('hasArtisanProfile'), isTrue,
          reason: 'Teklif bölümü usta PROFİLİNE bakmalı, yalnız aktif moda değil.');
      expect(s.contains('Müsait değilsiniz'), isTrue,
          reason: 'Müsait değilken kullanıcıya açık mesaj gösterilmeli.');
      expect(s.contains('Profilde müsaitliği aç'), isTrue,
          reason: 'Profile yönlendirme düğmesi olmalı.');
      // Yanlış mesaj: müsait kapısı isArtisan'a düşüp "başka müşteri" göstermemeli.
      expect(s.contains('else if (isArtisan)'), isFalse,
          reason: 'isArtisan (aktif mod) ile teklif bölümü kilitlenmemeli.');
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

  group('Kapı TÜM sohbet girişlerine bağlı', () {
    // 2026-08-10: ürün detayı kapısız kaldı ve müsait olmayan usta
    // Mağaza'dan mesaj atabiliyordu. Sebep: kapı kurulduğunda ürün modülü
    // üründe yoktu, geri gelince kimse kapıyı hatırlamadı.
    //
    // Bu test SAYIYA dayanır: yeni bir `startChat` çağrısı eklenip kapısı
    // unutulursa kırılır. Kırıldığında yapılacak şey sayıyı büyütmek DEĞİL,
    // yeni girişe `artisanAvailabilityAllowsNewChat` eklemektir.

    test('startChat çağıran her ekran kapıyı çağırır', () {
      final dir = Directory('lib/features');
      final ekranlar = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('chat${Platform.pathSeparator}data'))
          .map((f) => (yol: f.path, kod: f.readAsStringSync()))
          .where((e) => e.kod.contains('.startChat('))
          .toList();

      expect(ekranlar, isNotEmpty, reason: 'Hiç giriş bulunamadı — test '
          'kendisi bozulmuş olabilir.');

      final kapisiz = ekranlar
          .where((e) =>
              // Ortak kapı VEYA kendi müsaitlik kontrolü. İlan detayı
              // ikincisini yapar: kontrolü meslek/bölge eşleşmesiyle iç
              // içe, o yüzden ortak fonksiyona taşınmadı.
              !e.kod.contains('artisanAvailabilityAllowsNewChat') &&
              !e.kod.contains('!profile.isAvailable') &&
              // Sohbet ekranının kendisi MEVCUT sohbeti sürdürür; kapı
              // yalnız YENİ sohbeti bağlar.
              !e.yol.contains('chat_screen'))
          .map((e) => e.yol)
          .toList();

      expect(kapisiz, isEmpty,
          reason: 'Bu ekranlar sohbet başlatıyor ama müsaitlik kapısını '
              'çağırmıyor — müsait olmayan usta buradan mesaj atabilir:\n'
              '${kapisiz.join('\n')}');
    });

    test('ürün detayı kapıyı çağırır (2026-08-10 bulgusu)', () {
      final s =
          read('lib/features/products/presentation/product_detail_screen.dart');
      expect(s.contains('artisanAvailabilityAllowsNewChat'), isTrue,
          reason: 'Mağaza beşinci giriştir; kapısız kalmıştı.');
    });
  });

  group('Sohbet kullanıcı adına söz söylemez', () {
    test('ürün detayı otomatik ilk mesaj GÖNDERMEZ', () {
      // Kullanıcı adına mesaj yazmak iki sorun doğuruyordu: sözü kullanıcı
      // kurmuyordu ve sohbet o hiçbir şey yazmadan başlayıp karşı tarafa
      // bildirim gidiyordu (yanlışlıkla dokunmak bile mesaj atıyordu).
      final s =
          read('lib/features/products/presentation/product_detail_screen.dart');
      expect(s.contains('ürününüz hakkında yazıyorum'), isFalse,
          reason: 'Otomatik ilk mesaj kaldırıldı.');
      expect(s.contains('chatRepo.sendMessage('), isFalse,
          reason: 'Sohbet boş açılmalı — diğer girişlerle parite.');
    });
  });
}

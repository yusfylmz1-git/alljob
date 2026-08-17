import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';

/// Yeni test aşaması bulguları (2026-08-10).
///
/// 1) İlanı veren kişinin profil resmi ilan kartında ve profiline gidebilsin.
/// 2) Mesaj rozeti anlık güncellenmiyordu.
/// 3) "Yeni İlan" İlanlar sekmesi sağ üstte (hero'dan taşındı).
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('1 — İlan veren kartta görünür ve profiline gidilir', () {
    late String kart;
    setUpAll(() =>
        kart = read('lib/features/jobs/presentation/widgets/job_widgets.dart'));

    test('kartta ilan verenin avatarı var', () {
      expect(kart.contains('AppAvatar'), isTrue,
          reason: 'İlan kartında ilanı verenin profil resmi görünmeli.');
      expect(kart.contains('job.customerPhotoUrl'), isTrue);
      expect(kart.contains('job.customerName'), isTrue);
    });

    test('avatara dokununca ilan verenin profiline gider', () {
      expect(kart.contains('RoutePaths.userProfile(job.customerId)'), isTrue,
          reason: 'Avatar profile götürmeli.');
    });

    test('kategori emojisi kaybolmadı (fazlasını yapma)', () {
      // Emoji avatarın köşesine rozet olarak indi; bilgi silinmedi.
      expect(kart.contains('jobCategoryEmoji(job.category)'), isTrue);
    });

    test('sohbet listesinde avatar profile götürür', () {
      final liste =
          read('lib/features/chat/presentation/chat_list_screen.dart');
      expect(liste.contains('RoutePaths.userProfile(thread.otherUid(myUid))'),
          isTrue);
      // Seçim modunda profile KAÇMAMALI: dokunma seçim demektir.
      expect(liste.contains('onTap: selectionMode'), isTrue,
          reason: 'Seçim modunda avatar seçimi değiştirmeli, profile değil.');
    });
  });

  group('2 — Mesaj rozeti', () {
    test('rozet sayacı SOHBET adedi sayar (mesaj adedi değil)', () async {
      // Karar: 1 sohbetteki 3 mesaj rozette "1" gösterir. CF tarafı
      // (bumpChatUnreadMeta) sohbet başına bir kez +1 yazdığı için mock da
      // 1'e sıkışmalı — yoksa mock "3", canlı "1" derdi.
      final repo = MockChatRepository();
      const ben = 'musteri1';
      const usta = 'usta1';

      final id = await repo.startChat(
        customerUid: ben,
        customerName: 'Müşteri',
        artisanUid: usta,
        artisanName: 'Usta',
      );
      for (var i = 0; i < 3; i++) {
        await repo.sendMessage(
          chatId: id,
          senderUid: usta,
          text: 'mesaj $i',
        );
      }

      expect(repo.unreadCount(chatId: id, uid: ben), 3,
          reason: 'Sohbet İÇİ sayaç mesaj adedini vermeye devam eder.');

      final meta = await repo.watchUnreadMeta(ben).first;
      expect(meta.total, 1,
          reason: 'ROZET sohbet adedi sayar: 3 mesaj tek sohbette → 1.');
      expect(meta.customer, 1);
    });

    test('iki ayrı sohbet rozette 2 gösterir', () async {
      final repo = MockChatRepository();
      const ben = 'musteri1';
      for (final usta in ['usta1', 'usta2']) {
        final id = await repo.startChat(
          customerUid: ben,
          customerName: 'Müşteri',
          artisanUid: usta,
          artisanName: 'Usta',
        );
        await repo.sendMessage(chatId: id, senderUid: usta, text: 'selam');
      }
      final meta = await repo.watchUnreadMeta(ben).first;
      expect(meta.total, 2);
    });

    test('okununca rozet düşer', () async {
      final repo = MockChatRepository();
      const ben = 'musteri1';
      const usta = 'usta1';
      final id = await repo.startChat(
        customerUid: ben,
        customerName: 'Müşteri',
        artisanUid: usta,
        artisanName: 'Usta',
      );
      await repo.sendMessage(chatId: id, senderUid: usta, text: 'selam');
      expect((await repo.watchUnreadMeta(ben).first).total, 1);

      repo.markRead(chatId: id, uid: ben);
      expect((await repo.watchUnreadMeta(ben).first).total, 0,
          reason: 'Sohbet okununca rozet sıfırlanmalı.');
    });

    test('markRead önbelleğe GÜVENMEZ (asıl bulgu)', () {
      // `_lastMsgMeta` yalnız watchThreads doldurur. Bildirimden doğrudan
      // sohbete girildiğinde önbellek boştur; eski kod `was == 0` görüp
      // düşürmeyi tamamen atlıyordu → CF'in +1'i takılı kalıyordu.
      final kod =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(kod.contains('_lastMsgMeta.containsKey(chatId)'), isTrue,
          reason: 'Önbelleğin SICAK olup olmadığı ayrılmalı.');
      expect(kod.contains('lastMessageSenderUid'), isTrue,
          reason: 'Önbellek soğuksa sohbet dökümanından okunmalı.');
    });

    test('rozet canlı sayaca bağlı (alt bar)', () {
      final bar = read('lib/core/widgets/role_bottom_bar.dart');
      expect(bar.contains('totalUnreadProvider'), isTrue);
      expect(bar.contains('badge: unread'), isTrue);
    });
  });

  group('4/6 — Aynı kişiyle TEK sohbet kutusu', () {
    test('Firebase kimliği sıralı (mock ile parite)', () {
      // Karar (kullanıcı): "ne olursa olsun karşıdaki aynı kişiyle tek
      // sohbet kutusu". Sıralı kimlik bunu matematiksel olarak garantiler.
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(repo.contains('compareTo(artisanUid)'), isTrue,
          reason: 'Firebase kimliği de sıralanmalı, yoksa mock ayrışır.');
    });

    test('roller kimlikten TÜRETİLMEZ', () {
      // Kimlik sıralı olduğu için ilk parça "müşteri" demek değil. Eskiden
      // markRead `_uidsFromChatId(...).$2`'yi usta sanıyordu; sıralamayla
      // bu çıkarım geçersizleşti (yanlış tarafın sayacı düşerdi).
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(repo.contains(r'_uidsFromChatId(chatId)?.$2'), isFalse,
          reason: 'Rol kimlikten türetilemez; doküman alanı okunmalı.');
    });

    test('mevcut sohbete ters yönden girmek rolleri bozmaz', () {
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(repo.contains('customerUid: prev?.customerUid ?? customerUid'),
          isTrue,
          reason: 'Önbellek çağıranın bakış açısını yazmamalı.');
    });

    test('KURAL da iki sırayı kabul ediyor (kritik)', () {
      // Kural yalnız `chat_{müşteri}__{usta}` sırasını kabul etseydi,
      // ustanın uid'i alfabetik olarak önce gelen HER çiftte sohbet
      // oluşturma permission-denied alırdı — istemci sıralı kimlik ürettiği
      // için sohbetlerin yarısı açılamazdı.
      final rules = read('firestore.rules');
      expect(
        rules.contains("chatId == 'chat_' + request.resource.data.artisanUid"),
        isTrue,
        reason: 'Kural ters sırayı da kabul etmeli (istemci sıralı üretiyor).',
      );
    });
  });

  group('3 — Yeni İlan İlanlar sekmesinde', () {
    test('"Yeni İlan" yazısı var', () {
      final kesfet = read(
          'lib/features/customer/presentation/customer_dashboard_screen.dart');
      expect(kesfet.contains("Text('Yeni İlan')"), isTrue);
      expect(kesfet.contains('RoutePaths.newJob'), isTrue);
      expect(kesfet.contains('class _JobsTab'), isTrue);
    });
  });

  group('5 — Normal ilanda İLÇE şartı kalktı', () {
    // Kolay İş zaten il düzeyindeydi; klasik ilanlar ilçeye kısıtlıydı ve
    // çoğu ilçede alıcısız kalıyordu. Sunucu (onJobCreated) zaten YALNIZ il
    // bakıyordu — bu değişiklik istemciyi sunucuyla aynı hizaya getirdi.
    const isvereninIli = 'Bursa';
    Job ilan(String kategori) => Job(
          jobId: 'j1',
          customerId: 'c1',
          customerName: 'Müşteri',
          title: 'Test',
          description: 'Test açıklama',
          category: kategori,
          province: isvereninIli,
          district: 'Osmangazi',
          photos: const [],
          priceType: JobPriceType.fixed,
          status: JobStatus.open,
          createdAt: DateTime(2026, 8, 10),
          expiresAt: DateTime(2026, 9, 10),
        );

    test('aynı il, FARKLI ilçe → eşleşir', () {
      expect(
        ilan('painter').matchesArtisan(
          professionCode: 'painter',
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
        ),
        isTrue,
      );
    });

    test('FARKLI il → eşleşmez (il sınırı duruyor)', () {
      expect(
        ilan('painter').matchesArtisan(
          professionCode: 'painter',
          serviceAreas: const [
            ServiceArea(province: 'İstanbul', district: 'Kadıköy'),
          ],
        ),
        isFalse,
      );
    });

    test('meslek şartı duruyor (fazlasını yapma)', () {
      expect(
        ilan('painter').matchesArtisan(
          professionCode: 'plumber',
          serviceAreas: const [
            ServiceArea(province: 'Bursa', district: 'Osmangazi'),
          ],
        ),
        isFalse,
      );
    });
  });

  group('7 — Bildirim ekranı sadeleşti + temizleme', () {
    late String scr;
    setUpAll(() => scr = read(
        'lib/features/notifications/presentation/notifications_screen.dart'));

    test('sistem duyurusu ve takipçi listesi kalktı', () {
      expect(scr.contains('_PinnedSystemAnnouncement'), isFalse,
          reason: 'Üstteki sabit admin duyurusu geri gelmiş.');
      expect(scr.contains('_FollowerTile'), isFalse,
          reason: '"Sizi Takip Edenler" listesi geri gelmiş.');
    });

    test('Temizle eylemi var ve onay istiyor', () {
      expect(scr.contains("Text('Temizle')"), isTrue);
      expect(scr.contains('_confirmClear'), isTrue,
          reason: 'Geri alınamaz işlem onaysız olmamalı.');
    });

    test('depo her iki uygulamada da clearAll taşıyor (kural 1)', () {
      final repo = read(
          'lib/features/notifications/data/notification_repository.dart');
      // Arayüz + Firebase + Mock = 3 kez geçmeli.
      expect('clearAll'.allMatches(repo).length >= 3, isTrue,
          reason: 'Mock paritesi eksik.');
    });

    test('kural: sahibi silebilir ama OLUŞTURAMAZ', () {
      final rules = read('firestore.rules');
      expect(rules.contains('allow delete: if isSelf(uid);'), isTrue);
      expect(rules.contains('allow create: if false;'), isTrue,
          reason: 'Sahte bildirim enjeksiyonu açılmış olur.');
    });
  });

  group('8 — Müsait değilken: görür + bildirim alır, mesaj ATAMAZ', () {
    test('ilan feed'
        'i müsaitliğe göre elenmiyor', () {
      final prov = read('lib/features/jobs/data/job_providers.dart');
      expect(prov.contains('!profile.isAvailable'), isFalse,
          reason: 'Feed müsaitliğe göre boşaltılmamalı.');
      // Meslek/bölge şartı duruyor.
      expect(prov.contains('profile.professionCodes.isEmpty'), isTrue);
    });

    test('MESAJ kapısı yerinde duruyor (asıl kısıt)', () {
      final s = read('lib/features/jobs/presentation/job_detail_screen.dart');
      expect(s.contains('artisanAvailabilityAllowsNewChat'), isTrue,
          reason: 'Müsait olmayan usta mesaj ATAMAMALI.');
    });

    // Kapı ATLANABİLİYORDU: ilan kartındaki avatar profile götürüyor,
    // profilden mesaj atılabiliyordu. Kapı gezinmede değil, sohbeti
    // BAŞLATAN her yolda olmalı.
    test('sohbet başlatan TÜM yollar müsaitlik kapısından geçiyor', () {
      // Kaynakta `startChat(` çağıran her ekran dosyası kapıyı da içermeli.
      const yollar = {
        'lib/features/customer/presentation/artisan_profile_screen.dart': 2,
        'lib/features/customer/presentation/public_user_screen.dart': 1,
      };
      yollar.forEach((yol, beklenenCagri) {
        final s = read(yol);
        final kapi =
            'artisanAvailabilityAllowsNewChat'.allMatches(s).length;
        final baslat = '.startChat('.allMatches(s).length;
        expect(baslat, beklenenCagri, reason: '$yol: startChat sayısı değişti '
            '— yeni bir giriş eklendiyse kapısı da eklenmeli.');
        expect(kapi >= baslat, isTrue,
            reason: '$yol: kapısız sohbet başlatma yolu var.');
      });
    });

    test('ilan detayındaki kapı da duruyor (4. yol)', () {
      final s = read('lib/features/jobs/presentation/job_detail_screen.dart');
      expect(s.contains('artisanAvailabilityAllowsNewChat'), isTrue);
    });

    test('kapı usta/mağaza profiline bakar', () {
      final g = read('lib/features/artisan/application/availability_gate.dart');
      expect(g.contains('hasArtisanProfile'), isTrue,
          reason: 'Aktif usta modu değil, profil şart.');
      expect(g.contains('!user.available'), isTrue,
          reason: 'users.available kapıda olmalı.');
      expect(g.contains('!user.isArtisan) return true'), isFalse,
          reason: 'isArtisan muafiyeti müsaitlik deliği açıyordu.');
    });

    test('MEVCUT sohbet kısıtlanmıyor (fazlasını yapma)', () {
      // Müsaitlik "yeni iş almıyorum" demek; süren işin sohbeti kesilmemeli.
      final g = read('lib/features/artisan/application/availability_gate.dart');
      expect(g.toLowerCase().contains('yeni'), isTrue);
      // canSend yalnız kilide bakar — müsaitlik oraya sızmamalı.
      final chat = read('lib/data/models/chat.dart');
      expect(chat.contains('bool canSend(String uid) => !isLocked;'), isTrue,
          reason: 'Müsaitlik mevcut sohbete sızmış.');
    });

    test('bildirim CF müsait olmayanı ELEMİYOR (bildirim gelmeli)', () {
      // Ürün kararı: müsait olmayan usta ilanı GÖRÜR ve bildirim ALIR;
      // yalnız yeni sohbet başlatamaz. Bildirimi de kesmek, ustayı
      // platformdan tamamen kopartırdı.
      final cf = read('functions/index.js');
      final idx = cf.indexOf('exports.onJobCreated');
      final son = cf.indexOf('\nexports.', idx + 1);
      final govde = cf.substring(idx, son == -1 ? cf.length : son);

      // Müsaitlik ELEME olarak kullanılmamalı: `return`/`continue` ile
      // alıcı listesinden çıkarmak bildirimi keser.
      final elemeDeseni = RegExp(
        r'(isAvailable|manualPause)[^\n]*\)\s*return|'
        r'if\s*\([^\n]*(isAvailable|manualPause)[^\n]*\)\s*(return|continue)',
      );
      expect(elemeDeseni.hasMatch(govde), isFalse,
          reason: 'Müsaitlik alıcı listesinden ELEME için kullanılmış — '
              'müsait olmayan usta ilanı hiç duymaz.');

      // 2026-08-14: `manualPause` SIRALAMA (score) için kullanılıyor —
      // aktif usta üste çıkar, müsait olmayan listede KALIR. Bu kabul
      // edilebilir; eleme değil önceliklendirmedir.
      if (govde.contains('manualPause')) {
        expect(govde.contains('score'), isTrue,
            reason: 'manualPause skorlama dışında kullanılmış — eleme riski.');
      }
    });
  });
}

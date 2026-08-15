import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/core/constants/app_constants.dart';

/// Yayın öncesi denetim (2026-08-14) sözleşme testleri.
///
/// Buradaki her test, canlıda KULLANICI TARAFINDAN görülen bir arızayı
/// karşılar. Sessizce geri alınırlarsa belirti tekrar ortaya çıkar ama
/// sebebi görünmez olur — bu yüzden kaynak üzerinden kilitleniyorlar.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Oturum kapatma · sahte çökme olmamalı', () {
    // BELİRTİ: "çıkış yapınca uygulama duruyor/çöküyor".
    // SEBEP: uid kapsamlı `snapshots()` dinleyicileri çıkış anında bir an
    // eski uid ile canlı kalır → permission-denied → Riverpod AsyncError →
    // ekran hata görünümüne düşer.
    test('ortak koruma yardımcısı var', () {
      final w = read('lib/core/utils/signout_safe_stream.dart');
      expect(w.contains('signOutSafe'), isTrue);
      expect(w.contains('isSignOutDenial'), isTrue);
      // YALNIZ permission-denied yutulmalı. Ağ/indeks hatası yutulursa
      // kullanıcı boş ekrana bakar ve sebebini asla öğrenemez.
      expect(w.contains("'permission-denied'"), isTrue);
      // Yalnız KOD satırlarına bak: "unavailable" açıklama metninde geçiyor
      // (neden yutulmadığını anlatıyor), kodda geçmemeli.
      final kodSatirlari = w
          .split('\n')
          .where((s) => !s.trimLeft().startsWith('///'))
          .join('\n');
      expect(kodSatirlari.contains("'unavailable'"), isFalse,
          reason: 'Ağ hatası da yutuluyor — gerçek arıza gizlenir.');
    });

    test('kullanıcı kapsamlı TÜM canlı akışlar korunuyor', () {
      // Kapsam listesi: uid/chatId'ye bağlı olan, yani çıkışta reddedilecek
      // akışlar. Biri atlanırsa o ekran çıkışta hata verir.
      const beklenen = {
        'lib/features/notifications/data/notification_repository.dart': 2,
        'lib/features/notifications/data/notification_prefs.dart': 1,
        'lib/features/favorites/data/firebase_favorite_repository.dart': 3,
        'lib/features/safety/data/firebase_block_repository.dart': 1,
        'lib/features/jobs/data/firebase_job_repository.dart': 1,
        'lib/features/products/data/firebase_product_repository.dart': 1,
        'lib/features/chat/data/firebase_chat_repository.dart': 2,
      };
      beklenen.forEach((yol, adet) {
        final kaynak = read(yol);
        final bulunan = 'signOutSafe('.allMatches(kaynak).length;
        expect(bulunan, greaterThanOrEqualTo(adet),
            reason: '$yol içinde korunan akış sayısı $adet olmalı, '
                '$bulunan bulundu — çıkışta bu ekran hata verir.');
      });
    });

    test('chat repo yerel kopya yerine ortak yardımcıyı kullanıyor', () {
      final chat = read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(chat.contains('isSignOutDenial'), isTrue);
      expect(chat.contains('_isPermissionDenied'), isFalse,
          reason: 'Yerel kopya geri gelmiş — iki doğruluk kaynağı.');
    });
  });

  group('Bildirim · sessiz arıza olmamalı', () {
    late String push;
    setUpAll(
      () => push = read('lib/features/notifications/data/push_service.dart'),
    );

    test('notDetermined durumunda token YAZILMAZ', () {
      // Eskiden yalnız `denied` bakılıyordu. `notDetermined` (kullanıcı sistem
      // iznini kapattı/kararsız) hâlinde token yazılıp "Bildirimler açık"
      // gösteriliyor ama sistem bildirimi hiç düşmüyordu.
      expect(push.contains('AuthorizationStatus.notDetermined'), isTrue);
    });

    test('çıkışta tanılama durumu ve token aboneliği sıfırlanır', () {
      // Sıfırlanmazsa: (a) Ayarlar ESKİ hesabın durumunu gösterir,
      // (b) `_tokenRefreshSub ??=` yüzünden ikinci hesapta abonelik yeniden
      // kurulmaz ve token yenilendiğinde hiçbir yere yazılmaz.
      final blok = push.substring(push.indexOf('Future<void> unregisterFor'));
      final govde = blok.substring(0, blok.indexOf('Future<void> _unregisterBody'));
      expect(govde.contains('_tokenRefreshSub'), isTrue,
          reason: 'Token yenileme aboneliği çıkışta iptal edilmiyor.');
      expect(govde.contains('_lastToken = null'), isTrue);
      expect(govde.contains('_lastStatus = null'), isTrue);
    });

    test('çıkış sırası: token temizliği uid kaybolmadan ÖNCE', () {
      final ctrl = read('lib/features/auth/application/auth_controller.dart');
      final blok = ctrl.substring(ctrl.indexOf('Future<void> signOut'));
      final unreg = blok.indexOf('unregisterFor');
      final cikis = blok.indexOf('_repo.signOut()');
      expect(unreg, lessThan(cikis),
          reason: 'Oturum kapandıktan sonra uid yok — token temizlenemez ve '
              'sonraki hesap bu cihazda eski hesabın bildirimini alır.');
    });
  });

  group('Telefon doğrulama · sunucu tarafı zorunlu', () {
    late String rules;
    setUpAll(() => rules = read('firestore.rules'));

    test('sağlayıcı bayrakları kuralda telefon claim ister', () {
      // İstemci kapısı (ensureVerifiedPhoneForProvider) ATLATILABİLİR:
      // doğrudan SDK çağrısıyla yazan biri doğrulanmamış numarayla usta
      // olabilirdi. Kural bunu sunucuda kapatır.
      expect(rules.contains('providerFlagOk'), isTrue);
      expect(rules.contains("providerFlagOk('hasArtisanProfile')"), isTrue);
      expect(rules.contains("providerFlagOk('hasShopProfile')"), isTrue);
      expect(rules.contains("request.auth.token.get('phone_number', null)"),
          isTrue);
    });

    test('mevcut sağlayıcılar kilitlenmiyor — yalnız AÇARKEN aranır', () {
      // Kapatma ve zaten açık profilin diğer alanlarını güncelleme serbest
      // olmalı; aksi hâlde telefonu doğrulanmamış mevcut ustalar profillerini
      // hiç düzenleyemez hâle gelirdi.
      final i = rules.indexOf('function providerFlagOk');
      final govde = rules.substring(i, i + 600);
      expect(govde.contains('!acilyor'), isTrue,
          reason: 'Kural her yazımda telefon istiyor — mevcut ustalar kilitlenir.');
    });

    test('mock, kural davranışını taklit ediyor (CLAUDE.md kural 1)', () {
      final mock = read('lib/features/auth/data/mock_auth_repository.dart');
      expect(mock.contains('hasShopProfile == true'), isTrue);
      expect(mock.contains('phoneVerified'), isTrue);
    });
  });

  group('Girdi güvenliği ve maliyet tavanları', () {
    test('fiyat üst sınırı tanımlı ve uygulanıyor', () {
      expect(AppConstants.maxPriceAmount, greaterThan(0));
      final ekran =
          read('lib/features/products/presentation/product_edit_screen.dart');
      expect(ekran.contains('AppConstants.maxPriceAmount'), isTrue,
          reason: 'Tavan yok — kullanıcı 999999999999 yazıp kartı bozabilir.');
    });

    test('canlı dinleyicilerin hepsinde limit var', () {
      // Limitsiz dinleyici: koleksiyon büyüdükçe her açılış ve her değişiklik
      // tüm dökümanları yeniden okur → Firestore faturası öngörülemez olur.
      const dosyalar = {
        'lib/features/favorites/data/firebase_favorite_repository.dart':
            'favoritesFetchCap',
        'lib/features/safety/data/firebase_block_repository.dart':
            'blockedFetchCap',
        'lib/features/chat/data/firebase_chat_repository.dart':
            'chatThreadsFetchCap',
      };
      dosyalar.forEach((yol, sabit) {
        expect(read(yol).contains(sabit), isTrue,
            reason: '$yol limitsiz dinliyor — maliyet riski.');
      });
    });

    test('çift gönderim koruması sağlayıcı kayıtlarında var', () {
      final usta = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(usta.contains('_phoneGateBusy'), isTrue,
          reason: 'Doğrulama sayfası açıkken Kaydet etkin kalıyor — '
              'ikinci basış ikinci sayfa açar.');
      final shop =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      final kapi = shop.indexOf('ensureVerifiedPhoneForProvider');
      final busy = shop.indexOf('_busy = true');
      expect(busy, lessThan(kapi),
          reason: '_busy kapıdan sonra açılıyor — düğme boşta kalıyor.');
    });
  });

  group('Play Store · yayın engelleyiciler', () {
    test('imza dosyaları depoya girmiyor', () {
      final ignore = read('.gitignore');
      expect(ignore.contains('android/key.properties'), isTrue);
      expect(ignore.contains('*.jks'), isTrue,
          reason: 'Keystore commit edilirse imza anahtarı herkese açılır — '
              'uygulama sahiplenilebilir.');
    });

    test('paket kimliği sabit (Play kalıcı kimliği)', () {
      // Değiştirmek yeni uygulama yayınlamak demektir: kullanıcılar,
      // yorumlar ve satın almalar sıfırlanır.
      expect(read('lib/firebase_options.dart').contains('com.sepettehizmet.app'),
          isTrue);
    });

    test('sürüm 1.0.0+1 değil (Play aynı versionCode\'u reddeder)', () {
      final pubspec = read('pubspec.yaml');
      final m = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(pubspec);
      expect(m, isNotNull, reason: 'pubspec.yaml içinde version yok.');
      final surum = m!.group(1)!;
      expect(surum, isNot('1.0.0+1'),
          reason: 'Şablon sürümü duruyor. Her Play yüklemesinde '
              'versionCode (+N) BENZERSİZ olmalı.');
      final code = int.tryParse(surum.split('+').last);
      expect(code, isNotNull, reason: 'versionCode sayı olmalı: $surum');
      expect(code, greaterThan(1));
    });

    test('R8 açık ve koruma kuralları var', () {
      final gradle = read('android/app/build.gradle.kts');
      expect(gradle.contains('isMinifyEnabled = true'), isTrue,
          reason: 'R8 kapalı — paket büyür, kod okunabilir kalır.');
      expect(gradle.contains('proguard-rules.pro'), isTrue);

      // Yansımayla çağrılan kritik paketler korunmalı. Biri düşerse hata
      // YALNIZ release derlemede ve çalışma anında görünür.
      final rules = read('android/app/proguard-rules.pro');
      for (final paket in [
        'com.google.firebase', // Firestore/Auth model sınıfları
        'com.android.billingclient', // PARA YOLU
        'com.yalantis.ucrop', // fotoğraf kırpma (manifest'ten açılır)
        'com.dexterous', // bildirim alıcıları
        'io.flutter',
      ]) {
        expect(rules.contains(paket), isTrue,
            reason: '$paket korunmuyor — R8 silerse release\'te çöker.');
      }
      // Crashlytics yığın izleri okunamaz olmasın.
      expect(rules.contains('SourceFile,LineNumberTable'), isTrue,
          reason: 'Satır bilgisi atılırsa çökme raporları anlamsızlaşır.');
    });
  });

  group('Cloud Functions · denetim kapıları', () {
    test('lint yapılandırması var ve deploy öncesi çalışıyor', () {
      // 2026-08-15 denetimi: functions/ HİÇ denetlenmiyordu (yapılandırma
      // dosyası yoktu). İlk koşuda 5 ölü tanım + 2 hatalı regex kaçışı buldu.
      expect(File('functions/eslint.config.js').existsSync(), isTrue,
          reason: 'ESLint yapılandırması yok — functions denetlenmiyor.');
      final pkg = read('functions/package.json');
      expect(pkg.contains('"lint"'), isTrue);
      final fb = read('firebase.json');
      expect(fb.contains('predeploy'), isTrue,
          reason: 'Lint deploy öncesi otomatik çalışmıyor — kapı unutulur.');
    });

    test('admin callable\'ları App Check zorluyor', () {
      final cf = read('functions/index.js');
      expect(cf.contains('ADMIN_CALL_OPTS'), isTrue);
      // Zorlamasız kalan admin fonksiyonu olmamalı.
      final bare = RegExp(r'onCall\(\s*\n?\s*\{region: REGION\}')
          .allMatches(cf)
          .length;
      expect(bare, 0,
          reason: 'App Check zorlamayan callable kalmış — çalınmış admin '
              'oturumu panel dışından kullanılabilir.');
    });

    test('eşzamanlı açık ilan limiti sunucuda atomik', () {
      // Kural motoru transaction yapamaz: sayaç tazelenmeden gelen istekler
      // aynı eski değeri okur ve hepsi limitten geçerdi (TOCTOU).
      final cf = read('functions/index.js');
      final i = cf.indexOf('exports.onJobCreated');
      final j = cf.indexOf('\nexports.', i + 1);
      final govde = cf.substring(i, j == -1 ? cf.length : j);
      expect(govde.contains('openReserved'), isTrue,
          reason: 'Rezervasyon sayacı yok — eşzamanlı ilanlar limiti aşar.');
      expect(govde.contains('MAX_OPEN_JOBS'), isTrue);
      expect(govde.contains('runTransaction'), isTrue);
      // Rezervasyonun tazelikle karşılaştırılabilmesi için sayısal damga şart.
      expect(cf.contains('updatedAtMs'), isTrue,
          reason: 'jobStats.updatedAtMs yazılmazsa rezervasyon hep "taze" '
              'sayılır ve limit yanlış tarafa kayar.');
    });

  });

  group('Android · harici bağlantılar', () {
    // BELİRTİ: "bağlantıya basıyorum hiçbir şey olmuyor" — hata da yok.
    // SEBEP: Android 11 (API 30) paket görünürlüğü. `<queries>` içinde VIEW
    // beyanı yoksa url_launcher tarayıcıyı göremez; `canLaunchUrl` false
    // döner, `launchUrl` sessizce başarısız olur. url_launcher eklentisi bu
    // bloğu kendi manifest'inde TAŞIMAZ — uygulama tanımlamak zorundadır.
    test('url_launcher için paket görünürlüğü beyan edilmiş', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android.intent.action.VIEW'), isTrue,
          reason: 'VIEW beyanı yok — tüm harici bağlantılar (menüdeki '
              'ilandahizmet.com, sosyal medya, WhatsApp) sessizce ölür.');
      expect(manifest.contains('android:scheme="https"'), isTrue,
          reason: 'https şeması beyan edilmemiş.');
    });
  });

  group('Gizlilik · release günlüğü', () {
    // `debugPrint` adına rağmen RELEASE derlemede de yazar (yalnız profile
    // modunda susar). Satırlar uid, chatId ve FCM token öneki taşıyordu;
    // cihaza erişimi olan biri `adb logcat` ile okuyabilirdi.
    test('doğrudan debugPrint kullanılmıyor (AppLog.d var)', () {
      expect(File('lib/core/utils/app_log.dart').existsSync(), isTrue);

      // İzinli istisnalar: main dosyaları (Firebase kurulum tanılaması,
      // zaten kDebugMode ile sarılı) ve AppLog'un kendisi.
      const izinli = {
        'lib\\main.dart',
        'lib\\main_admin.dart',
        'lib\\core\\utils\\app_log.dart',
        'lib\\core\\utils\\signout_safe_stream.dart',
      };

      final ihlaller = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final rel = f.path.replaceAll('/', '\\');
        if (izinli.any(rel.endsWith)) continue;
        if (RegExp(r'\bdebugPrint\(').hasMatch(f.readAsStringSync())) {
          ihlaller.add(rel);
        }
      }
      expect(ihlaller, isEmpty,
          reason: 'Bu dosyalar release\'te de günlük yazıyor — '
              'AppLog.d kullanın: ${ihlaller.join(", ")}');
    });
  });

  group('Üyelik · satın alma token\'ı tekrar kullanılamaz', () {
    // RİSK: Play token doğrulaması "abonelik aktif mi?" der, "çağıran kişi mi
    // aldı?" DEMEZ. Sahiplenme kilidi olmazsa tek ödeme sınırsız hesaba
    // premium verir — doğrudan gelir kaybı.
    test('grantArtisanPremium token sahibini kilitliyor', () {
      final cf = read('functions/index.js');
      expect(cf.contains('membershipTokens'), isTrue,
          reason: 'Token sahiplenme koleksiyonu yok — aynı satın alma '
              'birden çok hesaba premium verir.');
      // Yarış: iki istek aynı anda gelirse transaction biri için düşmeli.
      expect(cf.contains('runTransaction'), isTrue);
      expect(cf.contains('premium token reuse blocked'), isTrue,
          reason: 'Reddedilen tekrar kullanım loglanmıyor — kötüye kullanım '
              'görünmez olur.');
    });

    test('token sahiplenme kaydı istemciye tamamen kapalı', () {
      final rules = read('firestore.rules');
      final i = rules.indexOf('match /membershipTokens/');
      expect(i, greaterThan(-1),
          reason: 'membershipTokens kuralı yok — varsayılan reddetse bile '
              'niyet yazılı olmalı.');
      final blok = rules.substring(i, i + 200);
      expect(blok.contains('allow read, write: if false'), isTrue,
          reason: 'Token hash\'i istemciye açılmış.');
    });

    test('hesap silmede token kaydı da siliniyor (KVKK)', () {
      final cf = read('functions/index.js');
      final silme = cf.indexOf('exports.deleteAccount');
      final son = cf.indexOf('exports.', silme + 10);
      final govde = cf.substring(silme, son);
      expect(govde.contains('membershipTokens'), isTrue,
          reason: 'Token kaydı kalırsa hem uid saklanır (KVKK) hem de '
              'kullanıcı hesabını silip yeniden açtığında KENDİ aboneliği '
              '"başkasına ait" diye reddedilir.');
    });
  });
}

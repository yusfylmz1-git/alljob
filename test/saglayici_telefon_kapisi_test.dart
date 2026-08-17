import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/data/models/product_category.dart';

/// new.md (2026-08-14) dört maddesinin sözleşme testleri.
///
/// 1–2: usta/mağaza açan kişi telefonunu DOĞRULAMADAN kaydedemez.
/// 3: sohbette WhatsApp ikonu yalnız doğrulanmış + numarasını YAYINLAMIŞ
///    kişide çıkar.
/// 4: ürün kategorileri çeşitlendi; profilde çok çip taşmıyor.
///
/// Kapılar kaynak üzerinden doğrulanır: ekranlar Firebase/Riverpod'a bağlı
/// olduğu için widget testiyle tam kurulamıyor (profile_simplify_test deseni).
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Madde 1–2 · sağlayıcı telefon doğrulama kapısı', () {
    test('ortak kapı tek dosyada yaşıyor', () {
      final gate = read('lib/features/auth/application/provider_phone_gate.dart');
      expect(gate.contains('ensureVerifiedPhoneForProvider'), isTrue);
      // Zaten doğrulanmış kullanıcı SMS'e tekrar gönderilmez.
      expect(gate.contains('if (user.phoneVerified) return true;'), isTrue);
    });

    test('usta profili kaydı kapıdan geçiyor', () {
      final ekran = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(ekran.contains('ensureVerifiedPhoneForProvider'), isTrue);
      // Kapı KAYITTAN ÖNCE olmalı: doğrulanmazsa `save()` çağrılmamalı.
      final kapi = ekran.indexOf('ensureVerifiedPhoneForProvider');
      final kaydet = ekran.indexOf('await _controller.save()');
      expect(kapi, lessThan(kaydet),
          reason: 'Telefon kapısı kayıttan SONRA çalışıyor — doğrulanmamış '
              'usta profili kaydedilir.');
    });

    test('mağaza kurulumu kapıdan geçiyor', () {
      final ekran =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      expect(ekran.contains('ensureVerifiedPhoneForProvider'), isTrue);
      final kapi = ekran.indexOf('ensureVerifiedPhoneForProvider');
      final yaz = ekran.indexOf('updateUserProfile');
      expect(kapi, lessThan(yaz),
          reason: 'Telefon kapısı mağaza yazımından SONRA — doğrulanmamış '
              'mağaza açılır.');
    });

    test('mağazada en az bir kategori ve bölge zorunlu', () {
      final ekran =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      expect(ekran.contains('En az bir satış kategorisi seçin.'), isTrue);
      expect(ekran.contains('En az bir hizmet bölgesi ekleyin.'), isTrue);
    });

    test('ustada en az bir meslek ve bölge zorunlu', () {
      final ekran = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(ekran.contains('En az bir hizmet bölgesi ekleyin.'), isTrue);
      expect(ekran.contains('professionCodes.isEmpty'), isTrue);
    });
  });

  group('Telefon doğrulama · hata eşlemesi', () {
    late String repo;
    setUpAll(() => repo = read(
        'lib/features/auth/data/firebase_phone_verification_repository.dart'));

    // 2026-08-14 cihaz bulgusu: ekranda "Doğrulama başarısız (unknown)".
    // `unknown`, Android'de SMS ÖNCESİ cihaz doğrulaması (Play Integrity /
    // SafetyNet) düştüğünde gelir — en sık sebep Google Cloud'da
    // `androidcheck.googleapis.com` API'sinin KAPALI olması.
    // Kullanıcıya "unknown" göstermek hiçbir şey anlatmıyordu.
    test('code=unknown anlamlı mesaja eşleniyor', () {
      expect(repo.contains("case 'unknown':"), isTrue,
          reason: 'unknown default dalına düşüyor — kullanıcı "(unknown)" '
              'görüyor ve ne yapacağını bilmiyor.');
      expect(repo.contains('deviceCheckFailed'), isTrue);
    });

    test('cihaz doğrulama hatası kullanıcıya eylem öneriyor', () {
      final ex = read('lib/features/auth/data/phone_verification_repository.dart');
      final i = ex.indexOf('deviceCheckFailed');
      expect(i, greaterThan(-1));
      final blok = ex.substring(i, i + 400);
      // Mesaj teknik kod değil, yapılabilir bir şey söylemeli.
      expect(blok.contains('unknown'), isFalse,
          reason: 'Ham hata kodu kullanıcıya sızıyor.');
      expect(blok.toLowerCase().contains('bağlantı'), isTrue);
    });

    test('tanı logu kök nedeni işaret ediyor', () {
      // Bir daha baştan araştırma yapılmasın.
      expect(repo.contains('androidcheck'), isTrue,
          reason: 'Tanı logu kök nedeni göstermiyor.');
    });
  });

  group('Madde 3 · sohbette WhatsApp ikonu', () {
    late String chat;
    setUpAll(
      () => chat = read('lib/features/chat/presentation/chat_screen.dart'),
    );

    test('ikon var ve wa.me bağlantısı açıyor', () {
      expect(chat.contains('_WhatsappAction'), isTrue);
      expect(chat.contains('https://wa.me/'), isTrue);
    });

    test('yalnız DOĞRULANMIŞ kişide çıkar', () {
      expect(chat.contains('!other.phoneVerified'), isTrue);
    });

    test('GİZLİ numara sızdırılmıyor — yalnız publicPhone okunur', () {
      // `phoneNumber` hassas alandır (users/{uid}/private/contact).
      // WhatsApp ikonu ona bağlanırsa gizli numara sohbetten sızar.
      final blok = chat.substring(chat.indexOf('class _WhatsappAction'));
      final govde = blok.substring(0, blok.indexOf('class _PartyAvatar'));
      expect(govde.contains('publicPhone'), isTrue);
      expect(govde.contains('other.phoneNumber'), isFalse,
          reason: 'Gizli numara (phoneNumber) WhatsApp ikonuna bağlanmış — '
              'kullanıcının yayınlamadığı numara sızıyor.');
    });
  });

  group('Kaydet sonrası doğru sayfaya dönüş (cihaz bulgusu 2026-08-14)', () {
    // BELİRTİ: mağaza düzenlemede "Kaydet"e basınca aynı formda kalıyordu.
    //
    // SEBEP: `context.pop()` gezinme YIĞININA bağlıdır. Ekran derin
    // bağlantıyla veya bir yönlendirme sonrası açıldığında geri gidilecek
    // sayfa olmayabilir; `pop()` sessizce hiçbir şey yapmaz ve kullanıcı
    // kaydın çalışıp çalışmadığını anlayamaz.
    //
    // `go()` yığını sıfırlar → her durumda hedefe düşer.
    test('mağaza kaydı profile dönüyor (pop DEĞİL)', () {
      final s =
          read('lib/features/products/presentation/shop_setup_screen.dart');
      expect(s.contains('context.go(RoutePaths.profile)'), isTrue,
          reason: 'Kaydet sonrası profile dönülmüyor.');
      // Kod satırlarında `pop()` kalmamalı (yorumda geçebilir).
      final kod = s
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(kod.contains('context.pop()'), isFalse,
          reason: 'pop() yığına bağlı — kullanıcı formda kalabilir.');
    });

    test('usta profili kaydı profile dönüyor', () {
      final s = read(
        'lib/features/artisan/presentation/artisan_profile_edit_screen.dart',
      );
      expect(s.contains('context.go(RoutePaths.profile)'), isTrue);
    });

    test('ürün ve ilan kaydı da go() kullanıyor', () {
      // Aynı desen: kaydet → listeye dön.
      expect(
        read('lib/features/products/presentation/product_edit_screen.dart')
            .contains('context.go(RoutePaths.myProducts)'),
        isTrue,
      );
      expect(
        read('lib/features/jobs/presentation/create_job_screen.dart')
            .contains('context.go(RoutePaths.myJobs)'),
        isTrue,
      );
    });
  });

  group('Profilde telefon görünürlüğü (cihaz bulgusu 2026-08-14)', () {
    // BELİRTİ: "telefon numaram profilde görünsün" işaretlendiği hâlde
    // numara profilde ÇIKMIYOR.
    //
    // SEBEP: `setPhoneVisibility` yalnız `artisanProfiles/{uid}` dokümanına
    // yazıyordu; profil başlığı ise numarayı `users/{uid}.publicPhone`
    // alanından okuyor. İki alan aynı adı taşıyor ama AYRI dokümanlarda —
    // yazılan yer okunan yer değildi.
    test('numara users dokümanına da yazılıyor', () {
      final repo = read(
        'lib/features/artisan/data/firebase_my_profile_repository.dart',
      );
      final i = repo.indexOf('setPhoneVisibility');
      // Dosya sonuna kadar oku: sabit pencere dosya büyüyünce taşıyordu.
      final govde = repo.substring(i);
      expect(govde.contains("collection('users')"), isTrue,
          reason: 'users/{uid}.publicPhone yazılmıyor — profil başlığı '
              'numarayı okuyamaz, "göster" işaretlense de görünmez.');
    });

    test('users yazımı profil dokümanı KONTROLÜNDEN önce', () {
      // Mağaza sahibinin `artisanProfiles` dokümanı olmayabilir. Eski kod
      // `if (!snap.exists) return` ile çıkıyordu ve mağazacının numarası
      // HİÇ yazılmıyordu.
      final repo = read(
        'lib/features/artisan/data/firebase_my_profile_repository.dart',
      );
      // YALNIZ setPhoneVisibility gövdesi VE yalnız KOD satırları.
      // Açıklama yorumları da `if (!snap.exists) return` metnini içeriyor
      // (neden taşındığını anlatıyor); yorum atılmazsa test onu kod sanıp
      // yanlış sıra ölçüyordu.
      final i = repo.indexOf('setPhoneVisibility');
      final son = repo.indexOf('\n  Future<', i + 1);
      final govde = repo
          .substring(i, son == -1 ? repo.length : son)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      final usersYazimi = govde.indexOf("collection('users')");
      final varlikKontrolu = govde.indexOf('if (!snap.exists) return');
      expect(usersYazimi, greaterThan(-1));
      expect(varlikKontrolu, greaterThan(-1));
      expect(usersYazimi, lessThan(varlikKontrolu),
          reason: 'users yazımı erken çıkıştan SONRA — usta profili olmayan '
              'mağaza sahibinin numarası hiç kaydedilmez.');
    });

    // BELİRTİ: "profilde göster" onayı verilince "Telefon numarası
    // bulunamadı" hatası.
    //
    // SEBEP: `AppUser.phoneNumber` hassas alandır ve KURAL GEREĞİ `users`
    // dokümanında tutulamaz (`private/contact` altında). `fromMap` onu hep
    // boş bırakıyordu; yalnız doğrulama ANINDA bellekte doluyordu. Uygulama
    // yeniden açılınca değer kaybolup anahtar gösterecek numara bulamıyordu.
    //
    // ÇÖZÜM: Firebase Auth doğrulanmış numarayı zaten taşıyor → oradan
    // alınır (ek Firestore okuması yok).
    test('doğrulanmış numara Auth\'tan okunuyor', () {
      final repo = read('lib/features/auth/data/firebase_auth_repository.dart');
      expect(repo.contains('phoneNumber: fbUser.phoneNumber'), isTrue,
          reason: 'Numara Auth\'tan alınmıyor — uygulama yeniden açılınca '
              '"Telefon numarası bulunamadı" hatası döner.');
      // Hem canlı dinleyicide hem yedek (minimal) yolda olmalı.
      expect('phoneNumber: fbUser.phoneNumber'.allMatches(repo).length,
          greaterThanOrEqualTo(2),
          reason: 'Yedek kullanıcı yolunda numara eksik.');
    });

    test('hassas numara users dokümanına YAZILMIYOR (kural)', () {
      // Düzeltme, hassas veriyi herkese açık dokümana taşımamalı.
      final rules = read('firestore.rules');
      expect(rules.contains("'phoneNumber'"), isTrue,
          reason: 'phoneNumber yasak listesinden çıkarılmış — hassas numara '
              'herkese açık dokümana sızabilir.');
      final repo = read('lib/features/auth/data/firebase_auth_repository.dart');
      expect(repo.contains("collection('private').doc('contact')"), isTrue,
          reason: 'Numara private/contact yerine başka yere yazılıyor.');
    });

    test('profil başlığı numarayı users alanından okuyor', () {
      final header = read('lib/core/widgets/profile_header.dart');
      expect(header.contains('user.publicPhone'), isTrue);
    });

    test('mock, iki yere yazma davranışını taklit ediyor (kural 1)', () {
      final mock = read('lib/features/artisan/data/my_profile_repository.dart');
      final i = mock.indexOf('setPhoneVisibility');
      final govde = mock.substring(i);
      expect(govde.contains('authRepositoryProvider'), isTrue,
          reason: 'Mock yalnız artisanProfiles yazıyor — canlıdaki hata '
              'mock testlerinde görünmez.');
    });
  });

  group('WhatsApp ikonu gerçek marka logosu (cihaz bulgusu)', () {
    // BELİRTİ: "whatsapp iconu gerçek icon değil".
    // Material'da WhatsApp ikonu YOK; `Icons.chat` düz konuşma balonudur ve
    // marka tanınmıyordu.
    test('özel çizim widget var', () {
      final w = read('lib/core/widgets/whatsapp_icon.dart');
      expect(w.contains('class WhatsappIcon'), isTrue);
      expect(w.contains('CustomPaint'), isTrue);
      // Marka yeşili korunmalı.
      expect(w.contains('0xFF25D366'), isTrue);
    });

    test('sohbet ve profil ikisi de gerçek logoyu kullanıyor', () {
      final chat = read('lib/features/chat/presentation/chat_screen.dart');
      expect(chat.contains('WhatsappIcon('), isTrue);
      expect(chat.contains('Icons.chat,'), isFalse,
          reason: 'Sohbette hâlâ düz balon ikonu kullanılıyor.');
      final header = read('lib/core/widgets/profile_header.dart');
      expect(header.contains('WhatsappIcon('), isTrue);
    });
  });

  group('Madde 4 · kategori çeşitliliği ve profil görünümü', () {
    test('mağaza senaryoları çeşitlendi', () {
      // Vitrin yalnız tadilat/hırdavat ekseninde kuruluydu; yaygın esnaf
      // "Diğer"e düşüyordu.
      expect(ProductCategory.sirali.length, greaterThanOrEqualTo(25));
      for (final kod in [
        ProductCategory.giyimAksesuar,
        ProductCategory.kozmetikKisisel,
        ProductCategory.gidaMarket,
        ProductCategory.petHayvan,
        ProductCategory.aydinlatma,
        ProductCategory.banyoSeramik,
      ]) {
        expect(ProductCategory.sirali.contains(kod), isTrue,
            reason: '$kod sıralı listede yok — seçicide görünmez.');
        expect(ProductCategory.label(kod), isNot('Diğer'),
            reason: '$kod için Türkçe ad tanımlanmamış.');
      }
    });

    test('ESKİ kodlar korundu (kural 6: kod = Firestore verisi)', () {
      // Yeniden adlandırma veri göçüdür: mevcut ürünlerin kategorisi kopar.
      for (final kod in [
        'yapi_malzeme',
        'hirdavat',
        'tesisat_malzeme',
        'mobilya',
        'beyaz_esya',
        'elektronik',
        'arac_parca',
        'bahce',
        'ev_tekstil',
        'mutfak',
        'hobi_spor',
        'bebek_cocuk',
        'is_makinesi',
        'diger',
      ]) {
        expect(ProductCategory.sirali.contains(kod), isTrue,
            reason: '$kod kaybolmuş — bu kodu taşıyan ürünler kategorisiz '
                'kalır (veri göçü).');
      }
    });

    test('kodlar tekil ve geçerli biçimde', () {
      final set = ProductCategory.sirali.toSet();
      expect(set.length, ProductCategory.sirali.length,
          reason: 'Yinelenen kategori kodu var.');
      for (final kod in ProductCategory.sirali) {
        expect(ProductCategory.isValidCode(kod), isTrue, reason: '$kod geçersiz.');
      }
    });

    test('"diger" HER ZAMAN sonda', () {
      expect(ProductCategory.sirali.last, ProductCategory.diger);
    });

    test('profilde çipler daraltılıyor (taşma düzeltmesi)', () {
      final profil =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(profil.contains('CollapsibleChips'), isTrue,
          reason: 'Kategori çipleri ham Wrap ile çiziliyor — çok kategori '
              'seçen mağazada profil şişer.');
      final w = read('lib/core/widgets/collapsible_chips.dart');
      expect(w.contains('daha'), isTrue); // "+N daha" rozeti
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/features/legal/legal_docs.dart';

/// Yasal kapsam denetimi (2026-08-14).
///
/// BULGU: Mağaza / ürün satışı modülü canlıydı ama yasal metinlerde HİÇ
/// geçmiyordu — satıcı yükümlülüğü, yasak ürünler, ödeme/teslimat sorumluluğu
/// tanımsızdı. Ayrıca ekranlarda akışa özgü sorumluluk reddi yoktu.
void main() {
  String read(String p) => File(p).readAsStringSync();

  String govde(LegalDoc d) =>
      d.sections.map((s) => '${s.heading ?? ''}\n${s.body}').join('\n');

  group('Kullanım Koşulları mağazayı kapsıyor', () {
    late String terms;
    setUpAll(() => terms = govde(legalTerms));

    test('satıcı ve ürün satışı tanımlı', () {
      for (final k in ['Satıcı', 'ürün', 'Mağaza']) {
        expect(terms.contains(k), isTrue, reason: '"$k" koşullarda geçmiyor.');
      }
    });

    test('satıcı yükümlülükleri sayılmış', () {
      // Ticari satıcı için mevzuat uyarısı olmadan platform risk alır.
      for (final k in ['vergi', 'fatura', 'tüketici']) {
        expect(terms.toLowerCase().contains(k), isTrue,
            reason: '"$k" yükümlülüğü yazılmamış.');
      }
    });

    test('yasak ürünler listelenmiş', () {
      expect(terms.contains('silah'), isTrue);
      expect(terms.toLowerCase().contains('taklit'), isTrue);
    });

    test('ödeme ve teslimatın platform dışı olduğu açık', () {
      expect(terms.contains('ödeme alınmaz'), isTrue);
      expect(terms.toLowerCase().contains('teslimat'), isTrue);
    });

    test('madde numaraları benzersiz ve sıralı', () {
      // Araya madde eklerken numaraların kayması sık yapılan hata.
      final numaralar = <int>[];
      for (final s in legalTerms.sections) {
        final h = s.heading;
        if (h == null) continue;
        final m = RegExp(r'^(\d+)\.').firstMatch(h);
        if (m != null) numaralar.add(int.parse(m.group(1)!));
      }
      expect(numaralar, isNotEmpty);
      expect(numaralar.toSet().length, numaralar.length,
          reason: 'Yinelenen madde numarası var.');
      final sirali = [...numaralar]..sort();
      expect(numaralar, sirali, reason: 'Madde numaraları sırasız.');
    });
  });

  group('Gizlilik ve KVKK ürün verisini içeriyor', () {
    test('gizlilik: mağaza/ürün verisi ve telefon görünürlüğü', () {
      final p = govde(legalPrivacy);
      expect(p.contains('Mağaza bilgileri'), isTrue);
      expect(p.toLowerCase().contains('ürün ilanları'), isTrue);
      // Telefon varsayılan gizli — kullanıcıya net söylenmeli.
      expect(p.contains('GİZLİDİR'), isTrue,
          reason: 'Telefon görünürlüğü politikası yazılmamış.');
    });

    test('kvkk: ürün ve doğrulama zorunluluğu', () {
      final k = govde(legalKvkk);
      expect(k.toLowerCase().contains('ürün'), isTrue);
      expect(k.contains('SMS doğrulaması'), isTrue,
          reason: 'Telefon doğrulama zorunluluğu aydınlatma metninde yok.');
    });
  });

  group('Metinler KODLA uyumlu (2026-08-15 denetimi)', () {
    // Yasal metnin en tehlikeli hatası eksiklik değil, YANLIŞLIKTIR:
    // yapmadığını söylemek Play'de beyan çelişkisi, KVKK'da ise
    // aydınlatma yükümlülüğü ihlalidir.

    test('Analytics kullanılıyorsa metinde AÇIKLANMALI', () {
      // firebase_analytics pubspec'te ve AppAnalytics olay gönderiyor;
      // metin bunu hiç anmıyordu.
      final analyticsVar =
          read('pubspec.yaml').contains('firebase_analytics');
      if (!analyticsVar) return; // paket kaldırılmışsa kural düşer
      final p = govde(legalPrivacy);
      expect(p.contains('Analytics'), isTrue,
          reason: 'Analytics kullanılıyor ama gizlilik metninde yok — '
              'Play veri güvenliği formuyla çelişir.');
      final k = govde(legalKvkk);
      expect(k.toLowerCase().contains('kullanım olay') ||
              k.toLowerCase().contains('analiz'),
          isTrue,
          reason: 'KVKK veri kategorilerinde analiz verisi yok.');
    });

    test('"reklam amacıyla paylaşılmaz" mutlak cümlesi KALMAMALI', () {
      // Reklam ağı eklendiği gün bu cümle YALAN olur ve metinleri
      // güncellemeyi unutmak en kolay hatadır. Yerine "şu an reklam ağı
      // yok, eklenirse politika güncellenir" ifadesi kullanılır.
      for (final d in [legalPrivacy, legalKvkk]) {
        final g = govde(d);
        expect(g.contains('reklam amacıyla paylaşılmaz'), isFalse,
            reason: '${d.title}: mutlak reklam taahhüdü — reklam '
                'eklendiğinde beyan çelişkisi doğurur.');
        expect(g.contains('reklam ağı bulunmamakta'), isTrue,
            reason: '${d.title}: mevcut durum ("şu an reklam yok") '
                'yazılmamış.');
      }
    });

    test('IAP açıksa abonelik koşulları yazılmalı', () {
      final iapAcik =
          read('lib/features/membership/billing_config.dart')
              .contains('kBillingEnabled = true');
      if (!iapAcik) return;
      final t = govde(legalTerms);
      expect(t.contains('Google Play'), isTrue,
          reason: 'Abonelik satılıyor ama ödemenin Google Play üzerinden '
              'yürüdüğü yazılmamış.');
      expect(t.toLowerCase().contains('otomatik yenilen'), isTrue,
          reason: 'Otomatik yenileme bildirilmemiş — tüketici mevzuatı '
              'açısından zorunludur.');
      expect(t.toLowerCase().contains('cayma'), isTrue,
          reason: 'Cayma hakkı bilgisi yok.');
      expect(t.toLowerCase().contains('iptal'), isTrue,
          reason: 'Aboneliğin nasıl iptal edileceği yazılmamış.');
    });

    test('uyuşmazlık çözümü ve tüketici hakları yazılı', () {
      final t = govde(legalTerms);
      expect(t.contains('Tüketici Hakem'), isTrue,
          reason: 'Tüketici hakem heyeti hakkı belirtilmemiş; sınırlayıcı '
              'sayılıp geçersiz kılınabilir.');
      expect(t.toLowerCase().contains('mahkeme'), isTrue,
          reason: 'Yetkili mahkeme maddesi yok.');
    });

    test('ödeme bilgisinin İŞLENMEDİĞİ açıkça yazılı', () {
      // Kullanıcı "kart bilgim nerede?" diye sorduğunda cevap metinde
      // olmalı; Play veri güvenliği formunda da "ödeme bilgisi toplanmıyor"
      // diyeceğiz, ikisi tutarlı olmalı.
      final p = govde(legalPrivacy);
      expect(p.contains('ULAŞMAZ') || p.contains('işlenmez'), isTrue,
          reason: 'Kart/ödeme bilgisinin tarafımıza ulaşmadığı yazılmamış.');
    });
  });

  group('Akışa özgü sorumluluk reddi', () {
    test('her akışın KENDİ metni var', () {
      // Genel tek cümle uyarı körlüğü yaratır; her akış kendi riskini
      // anlatmalı. `text` getter'ındaki dalların GÖVDELERİ farklı olmalı.
      final src =
          read('lib/core/widgets/disclaimer_note.dart');
      final basla = src.indexOf('String get text =>');
      final bit = src.indexOf('IconData get icon =>');
      final blok = src.substring(basla, bit);
      // Her dalın metni tırnak içindedir; tümünü topla.
      final metinler = RegExp(r"'([^']{20,})'")
          .allMatches(blok)
          .map((m) => m.group(1)!)
          .toSet();
      expect(metinler.length, greaterThanOrEqualTo(4),
          reason: 'Akışlar aynı metni paylaşıyor — akışa özgü değil.');
    });

    test('riskli ekranlara bağlanmış', () {
      const ekranlar = {
        'lib/features/products/presentation/product_detail_screen.dart':
            'urunSatinAlma',
        'lib/features/products/presentation/product_edit_screen.dart':
            'urunYayinlama',
        'lib/features/jobs/presentation/create_job_screen.dart':
            'DisclaimerFlow',
      };
      ekranlar.forEach((yol, beklenen) {
        final s = read(yol);
        expect(s.contains('DisclaimerNote'), isTrue,
            reason: '$yol içinde sorumluluk reddi yok.');
        expect(s.contains(beklenen), isTrue,
            reason: '$yol yanlış akış metnini kullanıyor.');
      });
    });
  });

  group('Girişte yasal onay (KVKK)', () {
    test('onay verilmeden Google girişi başlamıyor', () {
      final l = read('lib/features/auth/presentation/login_screen.dart');
      final i = l.indexOf('Future<void> _google');
      final govdeMetin = l.substring(i, i + 400);
      expect(govdeMetin.contains('if (!_consent)'), isTrue,
          reason: 'Onay kapısı yok — KVKK onayı alınmadan giriş yapılabilir.');
      // Kapı, giriş çağrısından ÖNCE olmalı.
      final kapi = govdeMetin.indexOf('_consent');
      final giris = govdeMetin.indexOf('signInWithGoogle');
      expect(kapi, lessThan(giris));
    });

    test('üç metne de bağlantı var', () {
      final l = read('lib/features/auth/presentation/login_screen.dart');
      expect(l.contains('legalTerms'), isTrue);
      expect(l.contains('legalPrivacy'), isTrue);
      expect(l.contains('legalKvkk'), isTrue);
    });
  });

  group('HTML sayfaları uygulama metinleriyle senkron', () {
    // Play Console gizlilik URL'i hosting'e işaret eder. Uygulama metni
    // güncellenip HTML unutulursa mağazada ESKİ politika yayında kalır —
    // reddedilme ve uyum riski.
    test('kullanım koşulları: mağaza maddesi HTML\'de de var', () {
      final h = read('hosting/kullanim-kosullari.html');
      expect(h.contains('Satıcı Yükümlülükleri'), isTrue,
          reason: 'HTML güncellenmemiş — yayındaki politika eski.');
      expect(h.contains('silah'), isTrue);
      expect(h.toLowerCase().contains('vergi'), isTrue);
    });

    test('gizlilik: mağaza verisi ve telefon görünürlüğü HTML\'de', () {
      final h = read('hosting/gizlilik-politikasi.html');
      expect(h.contains('Mağaza bilgileri'), isTrue);
      expect(h.contains('GİZLİDİR'), isTrue);
    });

    test('kvkk: ürün ve SMS doğrulaması HTML\'de', () {
      final h = read('hosting/kvkk-aydinlatma.html');
      expect(h.contains('SMS doğrulaması'), isTrue);
      expect(h.toLowerCase().contains('ürün'), isTrue);
    });

    test('tüm sayfalarda güncelleme tarihi AYNI', () {
      // Farklı tarihler "hangisi geçerli?" sorusu yaratır.
      final tarihler = <String>{};
      for (final f in [
        'hosting/kullanim-kosullari.html',
        'hosting/gizlilik-politikasi.html',
        'hosting/kvkk-aydinlatma.html',
        'hosting/hesap-silme.html',
      ]) {
        final m =
            RegExp(r'Son güncelleme: ([^<]+)<').firstMatch(read(f));
        if (m != null) tarihler.add(m.group(1)!.trim());
      }
      expect(tarihler.length, 1,
          reason: 'HTML sayfalarında farklı tarihler var: $tarihler');
      // Uygulama içindeki tarihle de eşleşmeli.
      expect(tarihler.first, kLegalUpdated,
          reason: 'HTML tarihi uygulama metniyle ayrışmış.');
    });
  });

  group('Site: sorumluluk reddi (uyuşmazlıkta dayanılacak metin)', () {
    late String site;
    setUpAll(() => site = read('hosting/index.html'));

    test('görünür bir sorumluluk reddi bölümü var', () {
      expect(site.contains('class="disclaimer"'), isTrue,
          reason: 'Sitede yalnız pazarlama dili var — sorumluluk sınırları '
              'hiçbir yerde yazmıyor.');
      expect(site.contains('Sorumluluk Reddi'), isTrue);
    });

    test('kritik reddiyeler tek tek yazılmış', () {
      for (final k in [
        'ARACI platformdur', // aracı konumu
        'garantörü değildir', // taraf/garantör reddi
        'platform dışındadır', // ödeme/teslimat
        'garanti edilmez', // yetkinlik/ürün
        'vergi, fatura', // satıcı mevzuatı
        'olduğu gibi', // hizmet garantisi
      ]) {
        expect(site.contains(k), isTrue, reason: '"$k" reddiyesi eksik.');
      }
    });

    test('koşulların yerine geçmediği belirtilmiş', () {
      // Özet metin bağlayıcı sanılmamalı.
      expect(site.contains('yerine'), isTrue);
      expect(site.contains('kullanim-kosullari.html'), isTrue);
    });

    test('"Aracı yok" ifadesi KULLANILMIYOR', () {
      // Platform hukuken ARACIDIR; sadece işin tarafı değildir. "Aracı yok"
      // demek aracılık sıfatının reddi olarak okunup aleyhe yorumlanabilir.
      final kod = site
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('<!--'))
          .join('\n');
      expect(kod.contains('Aracı yok'), isFalse,
          reason: 'Yanıltıcı ifade geri gelmiş.');
    });
  });

  group('Yardım: mağaza kapsamı', () {
    late String faq;
    setUpAll(() => faq = read('lib/features/help/help_faq.dart'));

    test('Mağaza kategorisi sekmelerde tanımlı', () {
      // Kategori listede yoksa sorular HİÇBİR sekmede görünmez (sessiz kayıp).
      final i = faq.indexOf('const kFaqCategories');
      final blok = faq.substring(i, i + 260);
      expect(blok.contains("'Mağaza'"), isTrue,
          reason: 'Mağaza sekmesi yok — sorular görünmez.');
    });

    test('satıcının en çok sorduğu konular var', () {
      for (final k in [
        'Mağaza nasıl açarım',
        'görünmüyor', // ürünüm neden çıkmıyor
        'komisyon',
        'sorumluyum', // yasal yükümlülük
      ]) {
        expect(faq.contains(k), isTrue, reason: '"$k" sorusu eksik.');
      }
    });

    test('her Mağaza sorusunun kategorisi doğru', () {
      final adet = "category: 'Mağaza'".allMatches(faq).length;
      expect(adet, greaterThanOrEqualTo(5),
          reason: 'Mağaza bölümü yetersiz.');
    });
  });

  group('Onboarding modülleri tanıtıyor', () {
    late String ob;
    setUpAll(() => ob = read(
        'lib/features/onboarding/presentation/onboarding_screen.dart'));

    test('Kolay İş sayfası var', () {
      expect(ob.contains('kQuickSupportName'), isTrue,
          reason: 'Kolay İş tanıtılmıyor — kullanıcı modülden habersiz.');
    });

    test('Mağaza sayfası var', () {
      expect(ob.contains('Mağazanı aç'), isTrue);
    });
  });
}

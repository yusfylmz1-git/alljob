// Regresyon: argo / müstehcen içerik denetimi (2026-08-23).
//
// Kapalı test geri bildirimi: "mesajlarda argo kelime filtreleme yapmıyoruz.
// müstehcen yazıların denetlemesini nasıl yaparız?"
//
// Tasarım — ENGELLEME DEĞİL, MASKELEME (2026-08-23 revizyonu):
//   * Gönderirken bir kez sorulur; ısrar eden kullanıcı gönderir.
//   * ALICI metni `***` maskeli görür; gönderen kendi yazdığını görür.
//   * Moderasyon YALNIZ kullanıcı şikâyetiyle başlar.
//
// İlk sürümde ağır içerik otomatik olarak `reports` kuyruğuna düşüyordu.
// Kullanıcı kararıyla kaldırıldı: kimsenin şikâyet etmediği mesajı
// incelemeye almak kuyruğu doldurur, gerçek şikâyetleri kaybettirir ve
// özel yazışmaya istenmeden girer. Sunucudaki sözlük de kalktı — tek
// kaynak `content_filter.dart`.
//
// Çift test (kural 7): küfür yakalanıyor MU + masum mesaj ELENMİYOR MU.
// İkincisi burada BİRİNCİDEN ÖNEMLİ: yanlış pozitif, kullanıcının meşru
// mesajını bozar ve filtreye olan güveni bitirir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/utils/content_filter.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  ContentSeverity sev(String s) => ContentFilter.inspect(s).severity;

  group('Küfür yakalanıyor', () {
    test('düz yazım', () {
      expect(sev('siktir git buradan'), ContentSeverity.severe);
      expect(sev('amk'), ContentSeverity.severe);
    });

    test('kaba dil UYARI eşiğinde', () {
      expect(sev('salak herif'), ContentSeverity.mild);
      expect(sev('serefsiz adam'), ContentSeverity.mild);
    });

    test('ağır içerik kaba dili EZER (öncelik)', () {
      // Aynı mesajda ikisi de varsa sonuç severe olmalı — uyarı metni
      // buna göre sertleşir.
      expect(sev('salak herif siktir'), ContentSeverity.severe);
    });
  });

  group('Kaçış denemeleri normalize ediliyor', () {
    test('boşlukla ayırma: "S İ K T İ R"', () {
      expect(normalizeForFilter('S İ K T İ R'), 'siktir');
      expect(sev('S İ K T İ R'), ContentSeverity.severe);
    });

    test('noktalama: "a.m.k"', () {
      expect(sev('a.m.k'), ContentSeverity.severe);
    });

    test('leetspeak: "s1kt1r"', () {
      expect(sev('s1kt1r'), ContentSeverity.severe);
    });

    test('harf tekrarı: "siktirrrr"', () {
      expect(sev('siktirrrr'), ContentSeverity.severe);
    });

    test('büyük/küçük harf ve Türkçe karakter', () {
      expect(sev('OROSPU'), ContentSeverity.severe);
    });
  });

  group('Fazlasını yapmıyor — masum mesajlar TEMİZ', () {
    test('normal usta mesajları', () {
      const mesajlar = [
        'Merhaba, kombi tamiri için yarın gelebilirim.',
        'Fiyat 2500 TL, malzeme dahil.',
        'Adresinizi paylaşır mısınız?',
        'İşi bitirdim, kolay gelsin.',
        'Boya işi için Salı günü uygunum.',
      ];
      for (final m in mesajlar) {
        expect(ContentFilter.inspect(m).isClean, isTrue,
            reason: 'Masum mesaj yakalandı: "$m"');
      }
    });

    test('yasak kelimeyi İÇEREN masum kelimeler', () {
      // Kelime sınırı + kalkan listesi olmasa hepsi yanlışlıkla yakalanırdı.
      const masum = [
        'malzeme listesi hazır',
        'maliyet hesabı çıkardım',
        'analiz raporu ektedir',
        'anahtar teslim iş',
        'sikke koleksiyonu için vitrin',
        'Malatya\'dan geliyorum',
        'bokser marka ürün',
      ];
      for (final m in masum) {
        expect(ContentFilter.inspect(m).isClean, isTrue,
            reason: 'Yanlış pozitif: "$m"');
      }
    });

    test('günlük dolgu sözcükleri uyarı ÜRETMİYOR', () {
      // "lan"/"bok" bilinçli olarak listede DEĞİL: her mesajda uyarı çıkarsa
      // kullanıcı öğrenip geçer ve uyarı gerçek hakarette de anlamsızlaşır.
      expect(ContentFilter.inspect('lan unuttum').isClean, isTrue);
      expect(ContentFilter.inspect('hava bok gibi').isClean, isTrue);
    });

    test('boş / null metin çökmüyor', () {
      expect(ContentFilter.inspect(null).isClean, isTrue);
      expect(ContentFilter.inspect('').isClean, isTrue);
      expect(ContentFilter.inspect('   ').isClean, isTrue);
      expect(ContentFilter.inspect('!!! ??? ...').isClean, isTrue);
    });
  });

  group('Sözlükler normalize biçimde TUTULUYOR', () {
    // Bu testin varlık sebebi gerçek bir hata: liste ilk yazıldığında
    // 'yarrak' ve 'namussuz' ham hâldeydi. Normalize edilmiş metinde çift
    // harf teke indiği için ('yarak', 'namusuz') bu maddeler HİÇ eşleşmiyor,
    // filtre sessizce delik veriyordu.
    test('her sözlük maddesi kendi normalizasyonuna eşit', () {
      final kaynak = read('lib/core/utils/content_filter.dart');
      final listeler = RegExp(
        r'static const List<String> _\w+ = \[(.*?)\];',
        dotAll: true,
      ).allMatches(kaynak);

      expect(listeler.length, 3,
          reason: 'Üç liste bekleniyor: _severe, _mild, _allowList.');

      for (final l in listeler) {
        final govde = l
            .group(1)!
            .split('\n')
            .where((x) => !x.trimLeft().startsWith('//'))
            .join('\n');
        final kelimeler =
            RegExp(r"'([^']+)'").allMatches(govde).map((m) => m.group(1)!);
        for (final k in kelimeler) {
          expect(normalizeForFilter(k), k,
              reason: '"$k" normalize edilince "${normalizeForFilter(k)}" '
                  'oluyor — bu maddeyi HİÇBİR mesaj tetikleyemez.');
        }
      }
    });
  });

  group('Küfür ALICI tarafında maskeleniyor', () {
    test('düz küfür *** olur', () {
      expect(ContentFilter.mask('siktir git buradan'), '*** git buradan');
    });

    test('noktalı kaçış da maskelenir', () {
      expect(ContentFilter.mask('a.m.k ya'), '*** ya');
    });

    test('boşluklu kaçış da maskelenir', () {
      expect(ContentFilter.mask('s i k t i r'), '***');
    });

    test('leetspeak ve harf tekrarı maskelenir', () {
      expect(ContentFilter.mask('s1kt1r'), '***');
      expect(ContentFilter.mask('siktirrrr'), '***');
    });

    test('ünlem küfrü KAÇIRTMIYOR', () {
      // `!` bir ara leetspeak'te `i` sayılıyordu: "SIKTIR!!!" → "siktirii"
      // olup sözlükte eşleşmiyordu. Ünlem artık ayraç.
      expect(ContentFilter.mask('SIKTIR!!!'), '***!!!');
    });

    test('boşluklu bileşik küfür TEK maske olur', () {
      // Sözlükte "orospucocugu" bitişik duruyor.
      expect(ContentFilter.mask('bir orospu cocugu daha'), 'bir *** daha');
    });

    test('kaba dil de maskelenir', () {
      expect(ContentFilter.mask('seni salak herif'), 'seni *** herif');
    });
  });

  group('Maskeleme fazlasını yapmıyor', () {
    test('temiz mesaja DOKUNMUYOR', () {
      const mesajlar = [
        'Merhaba, kombi tamiri için yarın gelebilirim.',
        'Fiyat 2500 TL, malzeme dahil.',
        'İşi bitirdim, kolay gelsin.',
      ];
      for (final m in mesajlar) {
        expect(ContentFilter.mask(m), m, reason: 'Metin değişti: "$m"');
      }
    });

    test('yanlış pozitif kalkanı maskede de geçerli', () {
      expect(ContentFilter.mask('malzeme listesi'), 'malzeme listesi');
      expect(ContentFilter.mask('sikke koleksiyonu'), 'sikke koleksiyonu');
      expect(ContentFilter.mask('analiz raporu'), 'analiz raporu');
    });

    test('boşluk ve noktalama YERİNDE kalıyor', () {
      // Maske biçimi bozarsa mesaj okunamaz hale gelir.
      expect(ContentFilter.mask('ne bu amk'), 'ne bu ***');
      expect(ContentFilter.mask('Merhaba, nasılsın?'), 'Merhaba, nasılsın?');
    });

    test('boş / null çökmüyor', () {
      expect(ContentFilter.mask(null), '');
      expect(ContentFilter.mask(''), '');
    });
  });

  group('Maskeleme yalnız ALICI ekranında', () {
    late String chat;
    late String liste;
    setUpAll(() {
      chat = read('lib/features/chat/presentation/chat_screen.dart');
      liste = read('lib/features/chat/presentation/chat_list_screen.dart');
    });

    test('gönderen kendi metnini olduğu gibi görüyor', () {
      // Maskelenirse kullanıcı ne yazdığını göremez ve düzeltemez.
      expect(
          chat.contains(
              'isMine ? message.text! : ContentFilter.mask(message.text)'),
          isTrue);
    });

    test('sohbet listesi önizlemesi de maskeleniyor', () {
      // Sohbeti açmadan listede küfür okumak maskelemeyi anlamsız kılardı.
      expect(liste.contains('ContentFilter.mask(thread.lastMessage)'), isTrue);
    });

    test('VERİ değişmiyor — yalnız görüntü maskeli', () {
      // Şikâyet gelirse moderatör gerçek metni görebilmeli.
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(repo.contains('ContentFilter'), isFalse,
          reason: 'Maskeleme yazma yoluna girmiş — moderatör gerçek metni '
              'göremez ve karar veremez.');
    });
  });

  group('Sunucuda otomatik şikâyet YOK', () {
    late String js;
    setUpAll(() => js = read('functions/index.js'));

    test('flagMessageForReview kaldırıldı', () {
      // Kimsenin şikâyet etmediği mesaj moderasyona düşmemeli: kuyruk
      // dolar, gerçek şikâyetler kaybolur, özel yazışma istenmeden
      // incelemeye alınır.
      expect(js.contains('async function flagMessageForReview'), isFalse);
      expect(js.contains('reporterUid: "system"'), isFalse);
    });

    test('sunucuda küfür sözlüğü tutulmuyor', () {
      // Sözlük tek kaynakta (Dart) — iki liste ayrışma riski kalktı.
      expect(js.contains('const SEVERE_WORDS'), isFalse);
      expect(js.contains('const FILTER_ALLOW'), isFalse);
    });

    test('onMessageCreated hâlâ bildirim gönderiyor', () {
      // Filtre kaldırılırken push akışı bozulmamalı.
      expect(js.contains('exports.onMessageCreated'), isTrue);
      expect(js.contains('sendPushToUid('), isTrue);
    });
  });

  group('İstemci: gönderim öncesi uyarı', () {
    late String chat;
    setUpAll(() =>
        chat = read('lib/features/chat/presentation/chat_screen.dart'));

    test('gönderim denetimden geçiyor', () {
      expect(chat.contains('if (!await _icerikOnayi(text)) return;'), isTrue);
    });

    test('temiz mesajda diyalog AÇILMIYOR', () {
      expect(chat.contains('if (verdict.isClean) return true;'), isTrue,
          reason: 'Sıcak yolda gereksiz diyalog kullanıcıyı yorar.');
    });

    test('kullanıcı ısrar edebiliyor (kapı değil)', () {
      expect(chat.contains('Yine de gönder'), isTrue,
          reason: 'Yanlış pozitif meşru mesajı engellememeli.');
    });

    test('yakalanan KELİME kullanıcıya gösterilmiyor', () {
      // Söylemek filtreyi atlatmayı öğretir.
      expect(chat.contains('verdict.matches'), isFalse,
          reason: 'Eşleşen kelimeyi göstermek kaçış öğretir.');
    });
  });

  group('Uyarı metni DÜRÜST', () {
    test('"kaydedilir" vaadi kaldırıldı', () {
      // Otomatik şikâyet varken "mesaj incelenmek üzere kaydedilir"
      // yazıyordu. Kaldırılınca bu cümle yalan oldu — kullanıcıya olmayan
      // bir sonucu söylemek güveni bitirir.
      // Yorum satırları elenir: değişikliğin GEREKÇESİ kodda anlatılıyor
      // ve o metin "incelenmek üzere" ifadesini içeriyor. Sınanan şey
      // kullanıcıya GÖRÜNEN metindir.
      final chat = read('lib/features/chat/presentation/chat_screen.dart')
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('///'))
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(chat.contains('incelenmek üzere'), isFalse,
          reason: 'Artık kaydedilmiyor; metin gerçekle uyuşmalı.');
      expect(chat.contains('*** şeklinde'), isTrue,
          reason: 'Gerçekten olan şey söylenmeli: karşı taraf maskeli görür.');
    });

    test('eski "system" kayıtları admin ekranında okunabilir', () {
      // Otomatik filtre kısa süre canlıdaydı; birkaç kayıt kuyrukta
      // kalmış olabilir. Ham uid gösterilirse moderatör olmayan bir
      // kullanıcıyı arar.
      final ekran =
          read('lib/features/admin/presentation/admin_reports_screen.dart');
      expect(ekran.contains("r.reporterUid == 'system'"), isTrue);
    });
  });
}

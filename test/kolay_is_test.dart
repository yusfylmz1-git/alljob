import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/features/help/help_faq.dart';

/// "Kolay İş" + ilan süreleri + Yardım sözleşmesi (2026-08-08).
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Marka: Hemen Lazım → Kolay İş', () {
    test('görünen ad değişti', () {
      expect(kQuickSupportName, 'Kolay İş');
    });

    test('DEPOLAMA kodu değişmedi (kural 6 — veri göçü)', () {
      // Kategori kodu Firestore'da yazılı ve CF/rules ile paylaşılıyor.
      expect(kQuickSupportCategory, 'quick_support');
      expect(kOtherProfession, 'other');
    });

    test('kullanıcıya görünen metinlerde eski ad kalmadı', () {
      final kalan = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final satir in f.readAsLinesSync()) {
          final t = satir.trim();
          if (t.startsWith('//')) continue; // yorumlar serbest (tarihçe)
          if (t.contains('Hemen Lazım')) kalan.add('${f.path}: $t');
        }
      }
      expect(kalan, isEmpty, reason: 'eski ad görünür metinde kaldı: $kalan');
    });
  });

  group('İlan süreleri: 3 / 5 / 7', () {
    test('seçilebilir süreler', () {
      expect(JobDuration.selectable, [
        JobDuration.day3,
        JobDuration.day5,
        JobDuration.day7,
      ]);
    });

    test('day5 eklendi ve doğru süreyi veriyor', () {
      expect(JobDuration.day5.duration, const Duration(days: 5));
      expect(JobDuration.day5.labelTR, '5 gün');
      expect(JobDuration.day5.apiValue, 'day5');
    });

    test('day1 SİLİNMEDİ — Kolay İş kullanıyor + eski kayıtlar var', () {
      // apiValue = enum adı = Firestore değeri (kural 6).
      expect(JobDuration.values.contains(JobDuration.day1), isTrue);
      expect(JobDuration.day1.duration, const Duration(days: 1));
      expect(JobDuration.day1.labelTR, '1 gün');
    });

    test('day1 normal ilan formunda SEÇİLEMEZ', () {
      expect(JobDuration.selectable.contains(JobDuration.day1), isFalse);
    });

    test('eski Firestore değerleri hâlâ çözülüyor', () {
      expect(JobDuration.fromString('day1'), JobDuration.day1);
      expect(JobDuration.fromString('day3'), JobDuration.day3);
      expect(JobDuration.fromString('day7'), JobDuration.day7);
      // Bilinmeyen → varsayılan.
      expect(JobDuration.fromString('day99'), JobDuration.day3);
    });
  });

  group('Kolay İş 1 günlük — form', () {
    late String form;
    setUpAll(() =>
        form = read('lib/features/jobs/presentation/create_job_screen.dart'));

    test('süre seçici Kolay İş\'te GİZLİ', () {
      expect(form.contains('if (_category == kQuickSupportCategory)'), isTrue);
    });

    test('seçenekler enum\'dan türüyor (elle liste yok)', () {
      expect(form.contains('for (final d in JobDuration.selectable)'), isTrue);
      expect(form.contains("label: Text('24 saat')"), isFalse);
    });

    test('süre gönderimde de ZORLANIYOR (UI gizlemek yetmez)', () {
      // Kullanıcı 7 gün seçip kategoriyi Kolay İş'e çevirirse eski değer
      // kalırdı; expiresAt hesabı kategoriye bakmalı.
      expect(
        form.contains('_category == kQuickSupportCategory') &&
            form.contains('JobDuration.day1'),
        isTrue,
      );
    });
  });

  group('Kolay İş ana sayfada öne çıktı', () {
    late String qa;
    setUpAll(() => qa = read(
        'lib/features/home/presentation/widgets/home_quick_access.dart'));

    test('tam genişlikli kendi kartı var', () {
      expect(qa.contains('_WideAction('), isTrue);
      expect(qa.contains('title: kQuickSupportName'), isTrue);
    });

    test('İş İlanı Ver\'in ÜSTÜNDE', () {
      expect(qa.indexOf('title: kQuickSupportName'),
          lessThan(qa.indexOf("title: 'İş İlanı Ver'")));
    });

    test('süre farkı kartta yazıyor', () {
      expect(qa.contains('1 günlük ilan'), isTrue);
      expect(qa.contains('3, 5 veya 7 gün'), isTrue);
    });

    test('eski yarım kutu düzeni kalktı', () {
      expect(qa.contains('_QuickCard'), isFalse);
      expect(qa.contains('_QuickItem'), isFalse);
    });
  });

  group('Yardım güncel', () {
    test('"Eleman" sekmesi kalktı (modül projede yok)', () {
      // Testin ASIL iddiası: silinen modülün sekmesi geri gelmemeli.
      // Tam liste sabitlenmiyor — yeni modül (2026-08-14: Mağaza) eklenince
      // bu test yanlış yere düşüyordu.
      expect(kFaqCategories.contains('Eleman'), isFalse);
      // Çekirdek sekmeler ve sıraları korunmalı.
      expect(kFaqCategories.take(3).toList(), ['Genel', 'Müşteri', 'Usta']);
    });

    test('her sorunun kategorisi sekmelerde VAR (sessiz kayıp yok)', () {
      for (final item in kFaqItems) {
        expect(kFaqCategories.contains(item.category), isTrue,
            reason: '"${item.question}" hiçbir sekmede görünmez');
      }
    });

    test('kaldırılan özellikleri anlatmıyor', () {
      final hepsi = kFaqItems.map((e) => '${e.question} ${e.answer}').join(' ');
      // İş akışı, teklif toplama ve maskeleme kaldırıldı.
      expect(hepsi.contains('teklif al'), isFalse);
      expect(hepsi.contains('maskelen'), isFalse);
      expect(hepsi.contains('İş tamamlandıktan'), isFalse);
      expect(hepsi.contains('Eleman'), isFalse);
    });

    test('YENİ davranışları anlatıyor', () {
      final hepsi = kFaqItems.map((e) => '${e.question} ${e.answer}').join(' ');
      expect(hepsi.contains('doğrudan mesaj'), isTrue);
      expect(hepsi.contains('BİR KEZ'), isTrue, reason: 'tek değerlendirme');
      expect(hepsi.contains('Kolay İş'), isTrue);
      expect(hepsi.contains('3, 5 veya 7'), isTrue);
      expect(hepsi.contains('ödeme almaz'), isTrue);
    });

    test('her sorunun cevabı dolu', () {
      for (final item in kFaqItems) {
        expect(item.question.trim(), isNotEmpty);
        expect(item.answer.trim().length, greaterThan(20),
            reason: item.question);
      }
    });
  });
}

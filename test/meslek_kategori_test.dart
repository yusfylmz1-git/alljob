import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart'
    show kProfessionNames;
import 'package:sepette_hizmet/data/models/profession.dart';

/// Madde 10 — meslek listesi çeşitlendirme + bulunabilirlik.
///
/// 132 meslek DÜZ listedeydi ve sıra inşaat mesleklerine göreydi; avukat,
/// mimar, muhasebe gibi hizmetler sona düşüp görünmez kalıyordu. Kullanıcı
/// "avukat yok" sanmıştı — aslında `lawyer_consult` vardı, bulunamıyordu.
void main() {
  late List<Map<String, dynamic>> json;

  setUpAll(() {
    final raw = File('assets/data/professions.json').readAsStringSync();
    json = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  });

  group('Veri bütünlüğü', () {
    test('her mesleğin kategorisi var', () {
      final eksik = json.where((p) => p['category'] == null).toList();
      expect(eksik, isEmpty,
          reason: 'Kategorisiz meslek gruplu listede kaybolur: '
              '${eksik.map((e) => e['code']).join(', ')}');
    });

    test('kategori kodları tanımlı listede', () {
      for (final p in json) {
        expect(ProfessionCategory.sirali, contains(p['category']),
            reason: '${p['code']}: bilinmeyen kategori ${p['category']}');
      }
    });

    test('meslek kodu tekil', () {
      final kodlar = json.map((p) => p['code'] as String).toList();
      expect(kodlar.toSet().length, kodlar.length,
          reason: 'Aynı kod iki kez tanımlı.');
    });

    test('kProfessionNames JSON ile SENKRON (kural: dosya başı notu)', () {
      // Ad JSON'da değişip Dart haritasında kalırsa kartlarda eski ad
      // görünür — iki kaynak birbirinden ayrışır.
      for (final p in json) {
        final code = p['code'] as String;
        expect(kProfessionNames[code], p['nameTR'],
            reason: '$code: JSON ve kProfessionNames farklı.');
      }
    });
  });

  group('Bulunabilirlik — asıl bulgu', () {
    String? adOf(String code) => json
        .cast<Map<String, dynamic>?>()
        .firstWhere((p) => p!['code'] == code, orElse: () => null)?['nameTR']
        as String?;

    test('"avukat" araması karşılık buluyor', () {
      final ad = adOf('lawyer_consult');
      expect(ad, isNotNull);
      expect(ad!.toLowerCase(), contains('avukat'),
          reason: 'Kullanıcı "avukat" yazıyor; ad bunu içermeli.');
    });

    test('"muhasebeci" araması karşılık buluyor', () {
      expect(adOf('accountant')!.toLowerCase(), contains('muhasebeci'));
    });

    test('profesyonel hizmetler genişledi', () {
      final kodlar = json.map((p) => p['code']).toSet();
      for (final c in ['architect', 'interior_arch', 'web_dev', 'graphic']) {
        expect(kodlar, contains(c), reason: '$c eksik.');
      }
    });

    test('sağlık/eğitim genişledi', () {
      final kodlar = json.map((p) => p['code']).toSet();
      for (final c in ['psychologist', 'dietitian', 'exam_prep']) {
        expect(kodlar, contains(c), reason: '$c eksik.');
      }
    });
  });

  group('Gruplama', () {
    test('kategori sırasına göre dizilince gruplar ARDIŞIK', () {
      // Başlık satırı grup değişiminde basılır; aynı kategori iki kez
      // görünürse liste iki ayrı başlık çizerdi.
      final sirali = [...json]..sort((a, b) => ProfessionCategory.order(
              a['category'] as String)
          .compareTo(ProfessionCategory.order(b['category'] as String)));
      final gorulen = <String>{};
      String? son;
      for (final p in sirali) {
        final c = p['category'] as String;
        if (c != son) {
          expect(gorulen.contains(c), isFalse,
              reason: '$c grubu bölünmüş.');
          gorulen.add(c);
          son = c;
        }
      }
    });

    test('"diger" her zaman SONDA', () {
      expect(ProfessionCategory.sirali.last, ProfessionCategory.diger);
      // Bilinmeyen kategori de sona düşer (listeden düşmez).
      expect(ProfessionCategory.order('bilinmeyen'),
          greaterThanOrEqualTo(ProfessionCategory.order(ProfessionCategory.diger)));
    });

    test('her kategorinin Türkçe adı var', () {
      for (final c in ProfessionCategory.sirali) {
        expect(ProfessionCategory.label(c), isNotEmpty);
      }
      // Bilinmeyen kod "Diğer" döner, boş değil.
      expect(ProfessionCategory.label('yok'), 'Diğer');
    });

    test('Kolay İş meslek gruplarına karışmıyor', () {
      final other = json.firstWhere((p) => p['code'] == 'other');
      expect(other['category'], ProfessionCategory.diger);
    });
  });
}

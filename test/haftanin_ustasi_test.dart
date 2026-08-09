import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_repository.dart'
    show ArtisanSummary;
import 'package:sepette_hizmet/features/home/presentation/widgets/home_discover.dart';

/// Yeni liste madde 1 — "Haftanın Ustası".
///
/// Kullanıcı bulgusu: "puanı yüksek olan usta sürekli gözükecek, her hafta
/// aynı ustayı görmek can sıkıcı". Doğruydu — eski kod puana göre sıralayıp
/// `.first` alıyordu, yani "Haftanın" sözü hiç tutulmuyordu.
void main() {
  ArtisanSummary usta(String uid, {double puan = 4.5, int yorum = 3}) =>
      ArtisanSummary(
        uid: uid,
        displayName: 'Usta $uid',
        professionCode: 'painter',
        professionNameTR: 'Boyacı',
        experienceYears: 5,
        averageRating: puan,
        totalReviews: yorum,
        isVerified: true,
        isPremium: true,
        isAvailable: true,
        isNewArtisan: false,
      );

  group('Rotasyon — asıl bulgu', () {
    test('hafta değişince usta DEĞİŞİR', () {
      final havuz = [usta('a'), usta('b'), usta('c')];
      final secimler = <String>{};
      // Ardışık 6 hafta.
      for (var i = 0; i < 6; i++) {
        final t = DateTime(2026, 1, 5).add(Duration(days: 7 * i));
        secimler.add(haftaninUstasiSec(havuz, t)!.uid);
      }
      expect(secimler.length, greaterThan(1),
          reason: 'Her hafta aynı usta çıkıyor — rotasyon yok.');
    });

    test('AYNI hafta içinde seçim SABİT', () {
      // Pazartesi ve cuma aynı ustayı vermeli; yoksa kullanıcı gün içinde
      // değişen bir "hafta"nın ustasını görürdü.
      final havuz = [usta('a'), usta('b'), usta('c')];
      final pzt = haftaninUstasiSec(havuz, DateTime(2026, 1, 5))!.uid;
      final cum = haftaninUstasiSec(havuz, DateTime(2026, 1, 9))!.uid;
      expect(cum, pzt);
    });

    test('havuz sırası karışsa da seçim AYNI (kararlı sıralama)', () {
      // Sunucu listeyi farklı sırada döndürebilir; iki kullanıcı aynı hafta
      // farklı usta görmemeli.
      final t = DateTime(2026, 3, 10);
      final a = [usta('x'), usta('y'), usta('z')];
      final b = [usta('z'), usta('x'), usta('y')];
      expect(haftaninUstasiSec(b, t)!.uid, haftaninUstasiSec(a, t)!.uid);
    });

    test('puan eşitliğinde bile belirsizlik yok', () {
      final havuz = [usta('m', puan: 5), usta('n', puan: 5)];
      final t = DateTime(2026, 5, 4);
      expect(haftaninUstasiSec(havuz, t)!.uid,
          haftaninUstasiSec(havuz.reversed.toList(), t)!.uid);
    });
  });

  group('Aday havuzu', () {
    test('yorumu OLMAYAN usta seçilmez', () {
      final havuz = [usta('a', yorum: 0), usta('b', yorum: 0)];
      expect(haftaninUstasiSec(havuz, DateTime(2026, 2, 2)), isNull,
          reason: 'Puan almamış usta "haftanın ustası" olamaz.');
    });

    test('havuz boşsa null (bölüm gizlenir)', () {
      expect(haftaninUstasiSec(const [], DateTime(2026, 2, 2)), isNull);
    });

    test('tek aday varsa hep o seçilir (çökme yok)', () {
      final havuz = [usta('tek')];
      for (var i = 0; i < 3; i++) {
        final t = DateTime(2026, 1, 5).add(Duration(days: 7 * i));
        expect(haftaninUstasiSec(havuz, t)!.uid, 'tek');
      }
    });
  });

  group('ISO hafta numarası', () {
    test('aynı haftanın günleri aynı numarayı verir', () {
      expect(isoHaftaNo(DateTime(2026, 1, 8)), isoHaftaNo(DateTime(2026, 1, 5)));
    });

    test('sonraki hafta numara artar', () {
      expect(isoHaftaNo(DateTime(2026, 1, 12)),
          isoHaftaNo(DateTime(2026, 1, 5)) + 1);
    });

    test('yıl sonu/başı çökmez', () {
      for (final d in [
        DateTime(2025, 12, 29),
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      ]) {
        expect(isoHaftaNo(d), inInclusiveRange(1, 53));
      }
    });
  });

  group('Ana sayfa sadeleşti', () {
    late String src;
    setUpAll(() => src = File(
            'lib/features/home/presentation/widgets/home_discover.dart')
        .readAsStringSync());

    test('sistem duyurusu kartı KALKTI', () {
      expect(src.contains('Son Duyuru'), isFalse,
          reason: 'Duyuru bildirimdir, ana sayfa vitrini değil.');
      expect(src.contains('hasAnnouncement'), isFalse);
    });

    test('büyük yatay kart yerine tek satır', () {
      expect(src.contains('height: 150'), isFalse,
          reason: '150px yatay kart şeridi geri gelmiş.');
      expect(src.contains('scrollDirection: Axis.horizontal'), isFalse);
    });
  });
}

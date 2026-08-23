// Regresyon: bölge/meslek uyumsuzluğu SEBEBİYLE BİRLİKTE söylenir (2026-08-23).
//
// Kullanıcı bulgusu (iki turda): "boyacı olmadığım halde boyacı ilanını
// gösterdi. ilana basıp msj yazmaya çalıştım, bana ilgili kategoridekiler
// yazabilir mesajı verdi." Sonra: "kendi hizmet bölgesinde olmadığı için
// mesaj yazmak isterse aynı hizmet bölgesinde değilsiniz mesajı verilmeli."
//
// Amaç: "usta tüm ilanları görsün ama yalnızca kendi bölgesinde ve
// kategorilerinde olanlara hizmet verebilsin."
//
// Eskiden tek satır yazıyordu: "meslek veya hizmet bölgenizle eşleşmiyor."
// Kullanıcı hangi alanı düzelteceğini bilmiyordu — iki sorun TAMAMEN farklı
// çözüm ister (biri il değiştirmek, diğeri meslek eklemek).
//
// Çift test (kural 7): kapı çalışıyor MU + TALEPLER muaf MI.
// İkincisi kritik: ürün kargoyla gider, satıcının pazarı kendi iline
// hapsedilmemeli.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/data/models/job.dart';

Job _job({
  String category = 'painter',
  String province = 'Bursa',
}) {
  final now = DateTime(2026, 8, 23);
  return Job(
    jobId: 'j1',
    customerId: 'musteri',
    customerName: 'Müşteri',
    title: 'Başlık',
    description: 'Açıklama',
    category: category,
    province: province,
    district: 'Osmangazi',
    photos: const [],
    priceType: JobPriceType.fixed,
    status: JobStatus.open,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 7)),
  );
}

void main() {
  String read(String p) => File(p).readAsStringSync();

  const bursa = [ServiceArea(province: 'Bursa', district: 'Osmangazi')];
  const balikesir = [ServiceArea(province: 'Balıkesir', district: 'Edremit')];

  group('İki yarı AYRI ayrı sorulabiliyor', () {
    test('bölge tutuyor, meslek tutmuyor', () {
      final j = _job(category: 'painter', province: 'Bursa');
      expect(j.matchesArtisanArea(bursa), isTrue);
      expect(j.matchesArtisanProfession(const ['plumber']), isFalse,
          reason: 'Boyacı olmayan boyacı ilanına yazamamalı.');
    });

    test('meslek tutuyor, bölge tutmuyor', () {
      final j = _job(category: 'painter', province: 'Bursa');
      expect(j.matchesArtisanProfession(const ['painter']), isTrue);
      expect(j.matchesArtisanArea(balikesir), isFalse,
          reason: 'Balıkesirli usta Bursa ilanına yazamamalı.');
    });

    test('ikisi de tutuyor', () {
      final j = _job(category: 'painter', province: 'Bursa');
      expect(j.matchesArtisanArea(bursa), isTrue);
      expect(j.matchesArtisanProfession(const ['painter']), isTrue);
    });
  });

  group('matchesArtisan iki yarıdan TÜRETİLİYOR', () {
    // Mantık kopyalanırsa üç yer ayrışır: usta feed'de yeşil çerçeve görüp
    // mesaj yazamayabilir ya da tersi.
    test('yarılar ile bütün aynı sonucu veriyor', () {
      final durumlar = [
        (_job(category: 'painter', province: 'Bursa'), ['painter'], bursa),
        (_job(category: 'painter', province: 'Bursa'), ['plumber'], bursa),
        (_job(category: 'painter', province: 'Bursa'), ['painter'], balikesir),
        (_job(category: 'painter', province: 'Bursa'), ['plumber'], balikesir),
      ];
      for (final (j, kodlar, alanlar) in durumlar) {
        final butun =
            j.matchesArtisan(professionCodes: kodlar, serviceAreas: alanlar);
        final yarilar = j.matchesArtisanProfession(kodlar) &&
            j.matchesArtisanArea(alanlar);
        expect(butun, yarilar,
            reason: 'Bütün ve yarılar ayrışmış: $kodlar / $alanlar');
      }
    });

    test('kaynak gerçekten türetiyor (kopya mantık yok)', () {
      final model = read('lib/data/models/job.dart');
      expect(
          model.contains('return matchesArtisanProfession(codes) && '
              'matchesArtisanArea(serviceAreas);'),
          isTrue,
          reason: 'matchesArtisan mantığı yarılardan bağımsız yazılmış — '
              'ayrışma riski geri gelmiş.');
    });
  });

  group('Hemen Lazım ilanında meslek kuralı farklı', () {
    test('Hemen Lazım sağlayıcısı yeterli, belirli meslek şart değil', () {
      final j = _job(category: kQuickSupportCategory, province: 'Bursa');
      expect(j.matchesArtisanProfession(const [kQuickSupportCategory]), isTrue);
      expect(j.matchesArtisanProfession(const [kOtherProfession]), isTrue);
    });

    test('Hemen Lazım da BÖLGE şartına tabi', () {
      final j = _job(category: kQuickSupportCategory, province: 'Bursa');
      expect(j.matchesArtisanArea(balikesir), isFalse);
    });
  });

  group('Fazlasını yapmıyor — TALEPLER muaf', () {
    test('ürün talebi meslek eşleşmesi ARAMIYOR', () {
      final t = _job(category: kProductRequestCategory, province: 'Bursa');
      expect(t.matchesArtisanProfession(const ['painter']), isFalse,
          reason: 'Talep usta feed’ine düşmemeli — kapı burada değil, '
              'mağaza sahipliğinde.');
    });

    test('mesaj kapısında talep BÖLGEYE bakmıyor', () {
      // Ürün kargoyla gider: satıcı istediği ile gönderebilir. Bölge
      // kapısını talebe koymak satıcının pazarını kendi iline hapsederdi.
      final ekran =
          read('lib/features/jobs/presentation/job_detail_screen.dart');
      final talepDali = RegExp(
        r'if \(job\.isProductRequest\) \{(.*?)\} else \{',
        dotAll: true,
      ).firstMatch(ekran);
      expect(talepDali, isNotNull);
      expect(talepDali!.group(1)!.contains('matchesArtisanArea'), isFalse,
          reason: 'Talep dalına bölge kapısı girmiş — satıcı başka ile '
              'ürün gönderemez hale gelir.');
      expect(talepDali.group(1)!.contains('hasShopProfile'), isTrue,
          reason: 'Talepte tek şart mağaza sahipliği olmalı.');
    });
  });

  group('Kullanıcı hangi alanı düzelteceğini biliyor', () {
    late String ekran;
    setUpAll(() => ekran =
        read('lib/features/jobs/presentation/job_detail_screen.dart'));

    test('bölge ve meslek AYRI mesaj veriyor', () {
      expect(ekran.contains('final bolgeTutuyor'), isTrue);
      expect(ekran.contains('final meslekTutuyor'), isTrue);
      expect(ekran.contains('ilinde hizmet '), isTrue,
          reason: 'Bölge uyuşmazlığı kendi metnini almalı.');
      expect(ekran.contains('mesleği profilinizde yok'), isTrue,
          reason: 'Meslek uyuşmazlığı kendi metnini almalı.');
    });

    test('İKİ ili de yazıyor (karşılaştırılabilsin)', () {
      // Kullanıcı kendi ilini bilir, ilanınkini bilmez.
      expect(ekran.contains(r'${job.province} ilinde; siz $benimIl'), isTrue);
    });

    test('uyarı TIKLAMADAN ÖNCE de görünüyor', () {
      // Eskiden düğmeye basmadan uyumsuzluk anlaşılmıyordu.
      expect(ekran.contains('Icons.location_off_outlined'), isTrue,
          reason: 'Bölge uyarı kartı yok — kullanıcı tıklayana kadar '
              'yazamayacağını bilmiyor.');
      expect(ekran.contains('Hizmet bölgemi değiştir'), isTrue,
          reason: 'Uyarı çözüme götürmeli, sadece engellememelidir.');
      expect(ekran.contains('Mesleklerimi düzenle'), isTrue);
    });
  });
}

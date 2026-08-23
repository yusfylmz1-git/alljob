import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/artisan_profile.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/features/admin/data/admin_artisan_repository.dart';

/// Madde 7 — ücretsiz dönem bitince müsaitlik KENDİLİĞİNDEN kapanmalı.
///
/// Kullanıcının bildirdiği sorun: "ücretsiz moda geçtiğimizde müsaitlik
/// durumu otomatik kapanmıyor, eğer açıksa açık kalmaya devam ediyor."
///
/// Çözüm toplu yazma DEĞİL, hesaplanan bir kapı: `isAvailableAt` premium
/// erişimi yoksa false döner. Hiçbir usta verisi değişmez → ücretsiz döneme
/// dönülünce herkes eski hâline kendiliğinden döner.
void main() {
  ArtisanProfile usta({
    bool alwaysAvailable = true,
    bool manualPause = false,
    bool isPremium = false,
    DateTime? premiumExpiresAt,
  }) {
    return ArtisanProfile.initial('u1').copyWith(
      alwaysAvailable: alwaysAvailable,
      manualPause: manualPause,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
    );
  }

  final an = DateTime(2026, 7, 1, 12);

  group('Premium kapısı — isAvailableAt', () {
    test('ücretsiz dönem AÇIKKEN premium olmayan usta müsait', () {
      final p = usta();
      expect(
        p.isAvailableAt(an, premiumFreeDuringBeta: true),
        isTrue,
        reason: 'Beta boyunca herkes müsait olabilmeli.',
      );
    });

    test('ücretsiz dönem KAPANINCA premium olmayan usta müsait DEĞİL', () {
      final p = usta();
      expect(
        p.isAvailableAt(an, premiumFreeDuringBeta: false),
        isFalse,
        reason: 'Kullanıcının bildirdiği hata: ücretsiz mod bitince '
            'müsaitlik açık kalıyordu.',
      );
    });

    test('ücretsiz dönem kapalıyken AKTİF premium usta müsait kalır', () {
      final p = usta(
        isPremium: true,
        premiumExpiresAt: an.add(const Duration(days: 30)),
      );
      expect(
        p.isAvailableAt(an, premiumFreeDuringBeta: false),
        isTrue,
        reason: 'Parasını ödeyen usta kapıdan geçmeli.',
      );
    });

    test('süresi DOLMUŞ premium müsait sayılmaz', () {
      final p = usta(
        isPremium: true,
        premiumExpiresAt: an.subtract(const Duration(days: 1)),
      );
      expect(p.isAvailableAt(an, premiumFreeDuringBeta: false), isFalse);
    });

    test('premium olsa bile manuel duraklatma her şeyi geçersiz kılar', () {
      final p = usta(
        manualPause: true,
        isPremium: true,
        premiumExpiresAt: an.add(const Duration(days: 30)),
      );
      expect(p.isAvailableAt(an, premiumFreeDuringBeta: false), isFalse);
      expect(p.isAvailableAt(an, premiumFreeDuringBeta: true), isFalse);
    });

    test('kapı VERİYİ değiştirmez — geri dönüş bedava', () {
      final p = usta();
      // Aynı nesne, yalnız bayrak değişiyor: ücretsiz döneme dönülünce
      // usta hiçbir işlem yapmadan tekrar müsait olur.
      expect(p.isAvailableAt(an, premiumFreeDuringBeta: false), isFalse);
      expect(p.isAvailableAt(an, premiumFreeDuringBeta: true), isTrue);
      expect(p.manualPause, isFalse, reason: 'Kapı manualPause yazmamalı.');
      expect(p.isPremium, isFalse, reason: 'Kapı isPremium yazmamalı.');
    });
  });

  group('Toplu plan yönetimi (admin) — mock CF paritesi', () {
    MockAdminArtisanRepository repoWith(List<ArtisanProfile> ustalar) {
      final r = MockAdminArtisanRepository();
      for (final u in ustalar) {
        r.put(u);
      }
      return r;
    }

    ArtisanProfile u(
      String uid, {
      bool isPremium = false,
      DateTime? expires,
      bool manualPause = false,
      String il = 'Bursa',
    }) =>
        ArtisanProfile.initial(uid).copyWith(
          isPremium: isPremium,
          premiumExpiresAt: expires,
          manualPause: manualPause,
          alwaysAvailable: true,
          // İL FİLTRESİ (2026-08-23): toplu işlem artık tek il için
          // çalışır; bölgesiz usta hiçbir işlemin kapsamına girmez.
          serviceAreas: [
            ServiceArea(province: il, district: 'Merkez'),
          ],
        );

    test('gerekçe zorunlu (sunucu doğrulamasının aynısı)', () {
      final repo = repoWith([u('a')]);
      expect(
        () => repo.bulkPlanUpdate(
            province: 'Bursa',
            mode: 'pauseAvailability',
            reason: 'kısa'),
        throwsArgumentError,
      );
    });

    test('geçersiz mode reddedilir', () {
      final repo = repoWith([u('a')]);
      expect(
        () => repo.bulkPlanUpdate(
            province: 'Bursa',
            mode: 'hepsiniSil',
            reason: 'geçerli sebep'),
        throwsArgumentError,
      );
    });

    test('dryRun hiçbir şey YAZMAZ ama sayar', () async {
      final repo = repoWith([u('a'), u('b')]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'pauseAvailability',
        reason: 'beta bitti',
        dryRun: true,
      );
      expect(res.etkilenen, 2);
      expect(res.dryRun, isTrue);
      // Veri DEĞİŞMEMELİ.
      final liste = await repo.fetchPage();
      expect(liste.every((p) => !p.profile.manualPause), isTrue,
          reason: 'dryRun veri yazmamalı.');
    });

    test('ödeme yapan aktif abone ATLANIR (varsayılan)', () async {
      final gelecek = DateTime.now().add(const Duration(days: 30));
      final repo = repoWith([
        u('odeyen', isPremium: true, expires: gelecek),
        u('bedava'),
      ]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'both',
        reason: 'beta bitti',
      );
      expect(res.etkilenen, 1);
      expect(res.atlanan, 1);

      final liste = await repo.fetchPage();
      final odeyen = liste.firstWhere((p) => p.uid == 'odeyen');
      expect(odeyen.profile.manualPause, isFalse,
          reason: 'Parasını ödeyen ustaya dokunulmamalı.');
      expect(odeyen.profile.isPremium, isTrue);
    });

    test('onlyWithoutActivePremium=false ödeyenlere de dokunur', () async {
      final gelecek = DateTime.now().add(const Duration(days: 30));
      final repo = repoWith([u('odeyen', isPremium: true, expires: gelecek)]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'both',
        reason: 'toplu düzeltme',
        onlyWithoutActivePremium: false,
      );
      expect(res.etkilenen, 1);
    });

    test('zaten hedef durumdaki usta ATLANIR (boşuna yazma yok)', () async {
      final repo = repoWith([u('duraklamis', manualPause: true)]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'pauseAvailability',
        reason: 'beta bitti',
      );
      expect(res.etkilenen, 0);
      expect(res.atlanan, 1);
    });

    test('pauseAvailability premium bayrağına DOKUNMAZ', () async {
      final gecmis = DateTime.now().subtract(const Duration(days: 1));
      final repo = repoWith([u('a', isPremium: true, expires: gecmis)]);
      await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'pauseAvailability',
        reason: 'yalnız duraklat',
      );
      final p = (await repo.fetchPage()).single;
      expect(p.profile.manualPause, isTrue);
      expect(p.profile.isPremium, isTrue,
          reason: 'Bu mod premium\'a dokunmamalı.');
    });

    // ── İL FİLTRESİ (2026-08-23) ──────────────────────────────────────
    //
    // Önce yoktu: işlem TÜM koleksiyonu tarıyordu ve Bursa'yı geçirmek
    // isteyen yönetici Türkiye'deki her ustanın müsaitliğini
    // kapatabiliyordu. İşlem GERİ ALINAMAZ.

    test('BAŞKA ildeki ustaya DOKUNULMUYOR', () async {
      final repo = repoWith([
        u('bursali', il: 'Bursa'),
        u('ankarali', il: 'Ankara'),
      ]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'pauseAvailability',
        reason: 'Bursa geçişi',
      );

      expect(res.etkilenen, 1);
      final liste = await repo.fetchPage();
      final ankarali = liste.firstWhere((p) => p.uid == 'ankarali');
      expect(ankarali.profile.manualPause, isFalse,
          reason: 'Kapsam dışı il etkilenmemeli — geri alınamaz işlem.');
    });

    test('kapsam dışı il "atlanan" SAYILMIYOR', () async {
      // "N ustadan M tanesi" ifadesi yalnız seçilen ili anlatmalı;
      // Ankara'yı atlanan saymak yöneticiyi yanıltır.
      final repo = repoWith([
        u('bursali', il: 'Bursa'),
        u('ankarali1', il: 'Ankara'),
        u('ankarali2', il: 'Ankara'),
      ]);
      final res = await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'pauseAvailability',
        reason: 'Bursa geçişi',
      );

      expect(res.etkilenen, 1);
      expect(res.atlanan, 0, reason: 'Kapsam dışı kayıt atlanan değildir.');
      expect(res.toplam, 1, reason: 'toplam = İLDEKİ usta sayısı.');
    });

    test('boş il REDDEDİLİYOR ("tümü" kazası olmasın)', () {
      final repo = repoWith([u('a')]);
      expect(
        () => repo.bulkPlanUpdate(
            province: '', mode: 'pauseAvailability', reason: 'geçerli sebep'),
        throwsArgumentError,
      );
      expect(
        () => repo.bulkPlanUpdate(
            province: '   ',
            mode: 'pauseAvailability',
            reason: 'geçerli sebep'),
        throwsArgumentError,
      );
    });

    test('bölgesiz usta hiçbir işlemin kapsamında DEĞİL', () {
      // Hizmet bölgesi olmayan profil hangi ile ait bilinemez; toplu
      // işlem onu süpürmemeli.
      final repo = MockAdminArtisanRepository();
      repo.put(ArtisanProfile.initial('bolgesiz'));
      expect(
        repo
            .bulkPlanUpdate(
              province: 'Bursa',
              mode: 'pauseAvailability',
              reason: 'Bursa geçişi',
            )
            .then((r) => r.etkilenen),
        completion(0),
      );
    });

    test('il denetim kaydına yazılıyor', () async {
      final repo = repoWith([u('a', il: 'Bursa')]);
      await repo.bulkPlanUpdate(
        province: 'Bursa',
        mode: 'both',
        reason: 'Bursa geçişi 2026-09',
      );
      expect(repo.bulkOps.single.province, 'Bursa',
          reason: 'Hangi ilde çalıştırıldığı denetimde görünmeli.');
    });

    test('işlem denetim için kaydedilir', () async {
      final repo = repoWith([u('a')]);
      await repo.bulkPlanUpdate(
          province: 'Bursa', mode: 'both', reason: 'beta bitti 2026-09');
      expect(repo.bulkOps, hasLength(1));
      expect(repo.bulkOps.single.reason, 'beta bitti 2026-09');
      expect(repo.bulkOps.single.dryRun, isFalse);
    });
  });

  group('Sunucu tarafı da aynı kapıyı kuruyor', () {
    late String js;
    setUpAll(() {
      js = File('functions/index.js').readAsStringSync();
    });

    test('CF boş ili REDDEDİYOR', () {
      // Mock kapıyı kurar ama asıl savunma sunucudadır: eski istemci ya da
      // doğrudan çağrı `province` göndermeyebilir.
      expect(js.contains('province zorunlu'), isTrue,
          reason: 'CF ilsiz çağrıyı kabul ederse tüm koleksiyon taranır.');
    });

    test('CF sorgusu SAYFALI', () {
      // Eskiden `.get()` ile tek çağrıda tüm koleksiyon okunuyordu:
      // 10.000 ustada 10.000 okuma + zaman aşımı riski.
      expect(js.contains('db.collection("artisanProfiles").get()'), isFalse,
          reason: 'Limitsiz tarama geri gelmiş.');
      expect(js.contains('.orderBy(FieldPath.documentId())'), isTrue);
      expect(js.contains('startAfter(sonDoc.id)'), isTrue);
    });

    test('CF il eşleşmesini bellekte yapıyor', () {
      // `serviceAreas` bir dizi; içindeki `province` alanına Firestore
      // `where` ile bakılamaz.
      expect(js.contains('String(a.province || "").trim() === il'), isTrue);
    });

    test('kapsam dışı kayıt CF tarafında da atlanan SAYILMIYOR', () {
      expect(js.contains('if (!ildeMi) continue;'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/artisan_profile.dart';
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
    }) =>
        ArtisanProfile.initial(uid).copyWith(
          isPremium: isPremium,
          premiumExpiresAt: expires,
          manualPause: manualPause,
          alwaysAvailable: true,
        );

    test('gerekçe zorunlu (sunucu doğrulamasının aynısı)', () {
      final repo = repoWith([u('a')]);
      expect(
        () => repo.bulkPlanUpdate(mode: 'pauseAvailability', reason: 'kısa'),
        throwsArgumentError,
      );
    });

    test('geçersiz mode reddedilir', () {
      final repo = repoWith([u('a')]);
      expect(
        () => repo.bulkPlanUpdate(mode: 'hepsiniSil', reason: 'geçerli sebep'),
        throwsArgumentError,
      );
    });

    test('dryRun hiçbir şey YAZMAZ ama sayar', () async {
      final repo = repoWith([u('a'), u('b')]);
      final res = await repo.bulkPlanUpdate(
        mode: 'pauseAvailability',
        reason: 'beta bitti',
        dryRun: true,
      );
      expect(res.etkilenen, 2);
      expect(res.dryRun, isTrue);
      // Veri DEĞİŞMEMELİ.
      final liste = await repo.fetchPage();
      expect(liste.every((p) => !p.manualPause), isTrue,
          reason: 'dryRun veri yazmamalı.');
    });

    test('ödeme yapan aktif abone ATLANIR (varsayılan)', () async {
      final gelecek = DateTime.now().add(const Duration(days: 30));
      final repo = repoWith([
        u('odeyen', isPremium: true, expires: gelecek),
        u('bedava'),
      ]);
      final res = await repo.bulkPlanUpdate(
        mode: 'both',
        reason: 'beta bitti',
      );
      expect(res.etkilenen, 1);
      expect(res.atlanan, 1);

      final liste = await repo.fetchPage();
      final odeyen = liste.firstWhere((p) => p.uid == 'odeyen');
      expect(odeyen.manualPause, isFalse,
          reason: 'Parasını ödeyen ustaya dokunulmamalı.');
      expect(odeyen.isPremium, isTrue);
    });

    test('onlyWithoutActivePremium=false ödeyenlere de dokunur', () async {
      final gelecek = DateTime.now().add(const Duration(days: 30));
      final repo = repoWith([u('odeyen', isPremium: true, expires: gelecek)]);
      final res = await repo.bulkPlanUpdate(
        mode: 'both',
        reason: 'toplu düzeltme',
        onlyWithoutActivePremium: false,
      );
      expect(res.etkilenen, 1);
    });

    test('zaten hedef durumdaki usta ATLANIR (boşuna yazma yok)', () async {
      final repo = repoWith([u('duraklamis', manualPause: true)]);
      final res = await repo.bulkPlanUpdate(
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
        mode: 'pauseAvailability',
        reason: 'yalnız duraklat',
      );
      final p = (await repo.fetchPage()).single;
      expect(p.manualPause, isTrue);
      expect(p.isPremium, isTrue, reason: 'Bu mod premium\'a dokunmamalı.');
    });

    test('işlem denetim için kaydedilir', () async {
      final repo = repoWith([u('a')]);
      await repo.bulkPlanUpdate(mode: 'both', reason: 'beta bitti 2026-09');
      expect(repo.bulkOps, hasLength(1));
      expect(repo.bulkOps.single.reason, 'beta bitti 2026-09');
      expect(repo.bulkOps.single.dryRun, isFalse);
    });
  });
}

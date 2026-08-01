import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/data/models/artisan_profile.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/data/models/user_role.dart';
import 'package:sepette_hizmet/features/artisan/application/my_profile_controller.dart';
import 'package:sepette_hizmet/features/artisan/data/my_profile_repository.dart';
import 'package:sepette_hizmet/features/auth/application/auth_controller.dart';

import 'helpers/mock_backend.dart';

void main() {
  final testUser = AppUser(
    uid: 'artisan_test',
    displayName: 'Test Usta',
    email: 'usta@test.com',
    hasArtisanProfile: true,
    activeMode: UserRole.artisan,
    createdAt: DateTime(2026, 1, 1),
  );

  const area1 = ServiceArea(
      province: 'Bursa', district: 'Osmangazi', neighborhood: 'Dikkaldırım');
  const area2 = ServiceArea(
      province: 'Bursa', district: 'Nilüfer', neighborhood: 'Beşevler');

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      ...mockBackendOverrides(),
      currentUserProvider.overrideWithValue(testUser),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('boş başlangıç profili yüklenir', () async {
    final c = makeContainer();
    final draft = await c.read(myProfileControllerProvider.future);
    expect(draft.displayName, 'Test Usta');
    expect(draft.profile.serviceAreas, isEmpty);
  });

  test('hizmet bölgesi eklenir ve mükerrer engellenir', () async {
    final c = makeContainer();
    await c.read(myProfileControllerProvider.future);
    final n = c.read(myProfileControllerProvider.notifier);

    expect(n.addServiceArea(area1), isTrue);
    expect(n.addServiceArea(area1), isFalse); // aynısı tekrar
    expect(n.addServiceArea(area2), isTrue);

    final areas =
        c.read(myProfileControllerProvider).value!.profile.serviceAreas;
    expect(areas.length, 2);
  });

  test('hizmet bölgesi kaldırılır', () async {
    final c = makeContainer();
    await c.read(myProfileControllerProvider.future);
    final n = c.read(myProfileControllerProvider.notifier);

    n.addServiceArea(area1);
    n.addServiceArea(area2);
    n.removeServiceArea(area1);

    final areas =
        c.read(myProfileControllerProvider).value!.profile.serviceAreas;
    expect(areas, [area2]);
  });

  test('sertifika eklenir ve kaldırılır', () async {
    final c = makeContainer();
    await c.read(myProfileControllerProvider.future);
    final n = c.read(myProfileControllerProvider.notifier);

    n.addCertificate('local://cert1');
    n.addCertificate('local://cert2');
    expect(
        c.read(myProfileControllerProvider).value!.profile.certificates.length,
        2);

    n.removeCertificate('local://cert1');
    expect(c.read(myProfileControllerProvider).value!.profile.certificates,
        ['local://cert2']);
  });

  test('isPremium istemci kaydıyla yazılamaz; beta erişimi yine açık',
      () async {
    final c = makeContainer();
    final repo = c.read(myProfileRepositoryProvider);

    // Kurcalama girişimi: istemci kendine premium yazmaya çalışıyor.
    final tampered = ArtisanProfile.initial('artisan_test').copyWith(
      profession: 'painter',
      isPremium: true,
      premiumExpiresAt: DateTime.now().add(const Duration(days: 3650)),
    );
    await repo.saveMyProfile(
      uid: 'artisan_test',
      displayName: 'Test Usta',
      profile: tampered,
    );

    final saved = await repo.getMyProfile('artisan_test');
    expect(saved.profession, 'painter'); // normal alanlar kaydedildi
    expect(saved.isPremium, isFalse); // premium yazılamadı (kural paritesi)
    expect(saved.hasActivePremium, isFalse);
    // Beta süresince premium ÖZELLİKLERİ yine herkese açık.
    expect(saved.hasPremiumAccess(), isTrue);
  });

  test('profil alanları güncellenir ve kaydedilir', () async {
    final c = makeContainer();
    await c.read(myProfileControllerProvider.future);
    final n = c.read(myProfileControllerProvider.notifier);

    n.setProfession('painter');
    n.setExperience(12);
    n.setAbout('Deneyimli boyacı.');
    n.addServiceArea(area1);

    final ok = await n.save();
    expect(ok, isTrue);

    final draft = c.read(myProfileControllerProvider).value!;
    expect(draft.profile.profession, 'painter');
    expect(draft.profile.experienceYears, 12);
  });

  group('Hemen Lazım anahtarı (meslekten ayrı)', () {
    test('açılır/kapanır ve meslekleri BOZMAZ', () async {
      final c = makeContainer();
      await c.read(myProfileControllerProvider.future);
      final n = c.read(myProfileControllerProvider.notifier);

      n.setProfessions(['painter', 'plumber']);
      expect(n.quickSupportEnabled, isFalse);

      n.setQuickSupportEnabled(true);
      expect(n.quickSupportEnabled, isTrue);
      // Meslekler korunmalı — anahtar bir meslek DEĞİL.
      final codes = c.read(myProfileControllerProvider).value!
          .profile.professionCodes;
      expect(codes, containsAll(['painter', 'plumber']));

      n.setQuickSupportEnabled(false);
      expect(n.quickSupportEnabled, isFalse);
      expect(
        c.read(myProfileControllerProvider).value!.profile.professionCodes,
        containsAll(['painter', 'plumber']),
      );
    });

    test('5 meslek doluyken bile açılabilir (sınır anahtarı engellemez)',
        () async {
      final c = makeContainer();
      await c.read(myProfileControllerProvider.future);
      final n = c.read(myProfileControllerProvider.notifier);

      n.setProfessions(
          ['painter', 'plumber', 'electrician', 'mover', 'gardener']);
      n.setQuickSupportEnabled(true);

      expect(n.quickSupportEnabled, isTrue);
      final codes = c.read(myProfileControllerProvider).value!
          .profile.professionCodes;
      expect(codes.length, 6); // 5 meslek + Hemen Lazım
      expect(codes, contains('painter'));
    });

    test('kapatma legacy quick_support kodunu da temizler', () async {
      final c = makeContainer();
      await c.read(myProfileControllerProvider.future);
      final n = c.read(myProfileControllerProvider.notifier);

      // Eski profillerde meslek olarak 'quick_support' yazılmış olabilir.
      n.setProfessions(['painter', 'quick_support']);
      expect(n.quickSupportEnabled, isTrue);

      n.setQuickSupportEnabled(false);
      // Yalnız 'other' silinseydi anahtar kapalı görünür, ilanlar gelmeye
      // devam ederdi.
      expect(n.quickSupportEnabled, isFalse);
      expect(
        c.read(myProfileControllerProvider).value!.profile.professionCodes,
        ['painter'],
      );
    });

    test('serviceProvinces serviceAreas ile senkron yazılır (rules paritesi)',
        () async {
      final c = makeContainer();
      await c.read(myProfileControllerProvider.future);
      final n = c.read(myProfileControllerProvider.notifier);

      n.setProfessions(['painter']);
      n.addServiceArea(area1); // Bursa/Osmangazi
      n.addServiceArea(area2); // Bursa/Nilüfer

      final map = c.read(myProfileControllerProvider).value!.profile.toMap();
      // İki ilçe, tek il → tekilleştirilmiş olmalı (rules il eşleşmesi).
      expect(map['serviceProvinces'], ['Bursa']);
      expect((map['serviceAreaKeys'] as List).length, 2);
    });
  });
}

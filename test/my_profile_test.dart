import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/data/models/artisan_profile.dart';
import 'package:usta_cepte/data/models/geo_models.dart';
import 'package:usta_cepte/data/models/user_role.dart';
import 'package:usta_cepte/features/artisan/application/my_profile_controller.dart';
import 'package:usta_cepte/features/artisan/data/my_profile_repository.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';

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
    expect(saved.hasPremiumAccess, isTrue);
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
}

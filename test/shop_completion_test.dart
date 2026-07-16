import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/data/models/artisan_profile.dart';
import 'package:usta_cepte/data/models/availability.dart';
import 'package:usta_cepte/data/models/geo_models.dart';
import 'package:usta_cepte/features/artisan/application/my_profile_controller.dart';
import 'package:usta_cepte/features/artisan/data/shop_completion.dart';

void main() {
  final user = AppUser(
    uid: 'u1',
    displayName: 'Test',
    email: 't@t.com',
    createdAt: DateTime(2026, 1, 1),
  );

  ArtisanProfile baseProfile({
    List<String> professions = const [],
    List<ServiceArea> areas = const [],
    String about = '',
    List<String> photos = const [],
    bool alwaysAvailable = false,
  }) {
    return ArtisanProfile(
      uid: 'u1',
      profession: professions.isEmpty ? '' : professions.first,
      professions: professions,
      experienceYears: 0,
      aboutText: about,
      serviceAreas: areas,
      certificates: const [],
      workPhotos: photos,
      isVerified: false,
      averageRating: 0,
      totalReviews: 0,
      totalRatingSum: 0,
      isPremium: false,
      alwaysAvailable: alwaysAvailable,
      manualPause: false,
      weeklySchedule: WeeklySchedule.empty(),
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('eksik profil: canMatchJobs false', () {
    final c = ShopCompletion.from(
      user: user,
      draft: MyProfileDraft(
        displayName: 'Test',
        profile: baseProfile(),
      ),
    );
    expect(c.canMatchJobs, isFalse);
    expect(c.isComplete, isFalse);
    expect(c.nextMissing?.id, isNotNull);
  });

  test('meslek + bölge: canMatchJobs true', () {
    final c = ShopCompletion.from(
      user: user.copyWith(profilePhotoUrl: 'http://x/p.jpg'),
      draft: MyProfileDraft(
        displayName: 'Test',
        profilePhotoUrl: 'http://x/p.jpg',
        profile: baseProfile(
          professions: ['painter'],
          areas: const [
            ServiceArea(province: 'Bursa', district: 'Nilüfer'),
          ],
          about: 'Boyacıyım',
          photos: ['http://x/w.jpg'],
          alwaysAvailable: true,
        ),
      ),
    );
    expect(c.canMatchJobs, isTrue);
    expect(c.isComplete, isTrue);
    expect(c.percent, 100);
  });
}

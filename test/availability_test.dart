import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/artisan_profile.dart';
import 'package:usta_cepte/data/models/availability.dart';

void main() {
  ArtisanProfile base({
    bool alwaysAvailable = false,
    bool manualPause = false,
    WeeklySchedule? schedule,
    DateTime? createdAt,
  }) {
    return ArtisanProfile.initial('u1').copyWith(
      alwaysAvailable: alwaysAvailable,
      manualPause: manualPause,
      weeklySchedule: schedule,
    );
  }

  group('Canlı müsaitlik (PRD §3)', () {
    test('manuel duraklatma her şeyi geçersiz kılar', () {
      final p = base(alwaysAvailable: true, manualPause: true);
      expect(p.isAvailableAt(DateTime(2026, 7, 1, 12)), isFalse);
    });

    test('her zaman müsait daima açık', () {
      final p = base(alwaysAvailable: true);
      expect(p.isAvailableAt(DateTime(2026, 7, 1, 3)), isTrue);
    });

    test('haftalık plan saat penceresine göre çalışır', () {
      // Çarşamba (weekday=3) 09:00-18:00 açık.
      final schedule = WeeklySchedule.empty().withDay(
        DateTime.wednesday,
        (d) => d.copyWith(enabled: true, startMinute: 9 * 60, endMinute: 18 * 60),
      );
      final p = base(schedule: schedule);
      // 2026-07-01 bir Çarşamba.
      final wed = DateTime(2026, 7, 1);
      expect(wed.weekday, DateTime.wednesday);
      expect(p.isAvailableAt(DateTime(2026, 7, 1, 10)), isTrue); // pencere içi
      expect(p.isAvailableAt(DateTime(2026, 7, 1, 20)), isFalse); // pencere dışı
      expect(p.isAvailableAt(DateTime(2026, 7, 2, 10)), isFalse); // Perşembe kapalı
    });
  });

  group('Çalışma takvimi serileştirme (PRD §4 Firestore şekli)', () {
    test('gün-adlı map + HH:mm; kapalı günde yalnızca enabled', () {
      final schedule = WeeklySchedule.empty()
          .withDay(DateTime.monday,
              (d) => d.copyWith(enabled: true, startMinute: 8 * 60, endMinute: 17 * 60))
          .withDay(DateTime.wednesday, (d) => d.copyWith(enabled: false));

      final map = schedule.toMap();
      expect(map['monday'], {'enabled': true, 'start': '08:00', 'end': '17:00'});
      expect(map['wednesday'], {'enabled': false});
    });

    test('toMap → fromMap roundtrip korunur', () {
      final schedule = WeeklySchedule.empty().withDay(
        DateTime.thursday,
        (d) => d.copyWith(enabled: true, startMinute: 10 * 60, endMinute: 18 * 60),
      );
      final restored = WeeklySchedule.fromMap(schedule.toMap());
      final thu = restored.dayFor(DateTime.thursday);
      expect(thu.enabled, isTrue);
      expect(thu.startLabel, '10:00');
      expect(thu.endLabel, '18:00');
    });
  });

  group('Yeni Usta rozeti (PRD §3)', () {
    test('ilk 15 gün rozetli, sonrası değil', () {
      final fresh = ArtisanProfile.initial('u1');
      // 15 gün eşik: içinde rozetli, sonrasında değil.
      expect(fresh.isNewArtisanAt(fresh.createdAt.add(const Duration(days: 5))),
          isTrue);
      expect(fresh.isNewArtisanAt(fresh.createdAt.add(const Duration(days: 20))),
          isFalse);
    });
  });
}

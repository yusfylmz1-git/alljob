import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/features/notifications/data/notification_prefs.dart';

void main() {
  group('NotificationPrefs.fromMap', () {
    test('null / boş → hepsi açık', () {
      expect(NotificationPrefs.fromMap(null), NotificationPrefs.defaults);
      expect(NotificationPrefs.fromMap({}), NotificationPrefs.defaults);
    });

    test('yalnız false olanlar kapalı; eksik alan açık kalır', () {
      final p = NotificationPrefs.fromMap({
        'chat': false,
        'nearbyJobs': false,
      });
      expect(p.chat, isFalse);
      expect(p.jobUpdates, isTrue);
      expect(p.nearbyJobs, isFalse);
    });

    test('toMap round-trip', () {
      const original = NotificationPrefs(
        chat: false,
        jobUpdates: true,
        nearbyJobs: false,
      );
      final back = NotificationPrefs.fromMap(original.toMap());
      expect(back, original);
    });
  });

  group('MockNotificationPrefsRepository', () {
    test('save + watch varsayılan ve güncelleme', () async {
      final repo = MockNotificationPrefsRepository();
      final first = await repo.watch('u1').first;
      expect(first.chat, isTrue);

      await repo.save(
        'u1',
        const NotificationPrefs(chat: false, nearbyJobs: false),
      );
      final second = await repo.watch('u1').first;
      expect(second.chat, isFalse);
      expect(second.jobUpdates, isTrue);
      expect(second.nearbyJobs, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_notification.dart';
import 'package:usta_cepte/features/notifications/data/notification_repository.dart';

void main() {
  group('MockNotificationRepository (bildirim merkezi)', () {
    test('akış bildirim döner ve markRead okundu yapar (rozet paritesi)',
        () async {
      final repo = MockNotificationRepository();

      final first = await repo.watchMyNotifications('u1').first;
      expect(first, isNotEmpty);
      final unreadIds =
          first.where((n) => !n.read).map((n) => n.id).toList();
      expect(unreadIds, isNotEmpty);

      await repo.markRead('u1', unreadIds);
      final after = await repo.watchMyNotifications('u1').first;
      expect(after.where((n) => !n.read), isEmpty);
    });

    test('fromMap eksik alanlara dayanıklı', () {
      final n = AppNotification.fromMap('x', const {});
      expect(n.type, 'system');
      expect(n.read, isFalse);
      expect(n.title, '');
    });
  });
}

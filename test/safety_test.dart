import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/blocked_user.dart';
import 'package:usta_cepte/data/models/report.dart';
import 'package:usta_cepte/features/safety/data/block_repository.dart';
import 'package:usta_cepte/features/safety/data/report_repository.dart';

void main() {
  group('MockBlockRepository (engelleme)', () {
    test('engelle → listede görünür; kaldır → düşer', () async {
      final repo = MockBlockRepository();
      addTearDown(repo.dispose);

      await repo.block(
        uid: 'me',
        other: BlockedUser(
            uid: 'spammer', name: 'Spam Usta', blockedAt: DateTime.now()),
      );
      var list = await repo.watchBlocked('me').first;
      expect(list.map((b) => b.uid), ['spammer']);

      // Engel yalnız engelleyenin listesindedir (tek yönlü).
      expect(await repo.watchBlocked('spammer').first, isEmpty);

      await repo.unblock(uid: 'me', otherUid: 'spammer');
      list = await repo.watchBlocked('me').first;
      expect(list, isEmpty);
    });

    test('aynı kişiyi tekrar engellemek kaydı çoğaltmaz', () async {
      final repo = MockBlockRepository();
      addTearDown(repo.dispose);

      final other = BlockedUser(
          uid: 'x', name: 'Tekrar', blockedAt: DateTime.now());
      await repo.block(uid: 'me', other: other);
      await repo.block(uid: 'me', other: other);
      expect((await repo.watchBlocked('me').first).length, 1);
    });
  });

  group('MockReportRepository (şikayet)', () {
    test('şikayet kaydedilir; aynı hedefe tekrar şikayet TEK kayıt kalır',
        () async {
      final repo = MockReportRepository();

      await repo.submitReport(
        reporterUid: 'me',
        reportedUid: 'bad',
        target: ReportTarget.message,
        targetId: 'chat_me__bad_m1',
        chatId: 'chat_me__bad',
        reason: ReportReason.harassment,
        note: 'hakaret etti',
      );
      // Aynı hedef, farklı neden → mevcut kayıt güncellenir (kuyruk şişmez).
      await repo.submitReport(
        reporterUid: 'me',
        reportedUid: 'bad',
        target: ReportTarget.message,
        targetId: 'chat_me__bad_m1',
        chatId: 'chat_me__bad',
        reason: ReportReason.spam,
      );

      expect(repo.reports.length, 1);
      final r = repo.reports.values.single;
      expect(r['reason'], 'spam');
      expect(r['reportedUid'], 'bad');
      expect(r['status'], 'open');

      // Farklı hedef → yeni kayıt.
      await repo.submitReport(
        reporterUid: 'me',
        reportedUid: 'bad',
        target: ReportTarget.user,
        targetId: 'bad',
        reason: ReportReason.scam,
      );
      expect(repo.reports.length, 2);
    });

    test('deterministik döküman ID formatı kuralla birebir', () {
      expect(
        reportDocId(
            target: ReportTarget.job, targetId: 'job42', reporterUid: 'u1'),
        'job_job42__u1',
      );
    });
  });
}

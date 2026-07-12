import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/report.dart';
import 'package:usta_cepte/features/admin/data/admin_config.dart';
import 'package:usta_cepte/features/admin/data/admin_report.dart';
import 'package:usta_cepte/features/admin/data/admin_report_repository.dart';
import 'package:usta_cepte/features/auth/data/mock_auth_repository.dart';

Report _r(String id, ReportStatus status, DateTime created) => Report(
      id: id,
      reporterUid: 'reporter_$id',
      reportedUid: 'reported_$id',
      target: ReportTarget.user,
      targetId: 'target_$id',
      reason: ReportReason.spam,
      note: 'not $id',
      status: status,
      createdAt: created,
    );

void main() {
  group('Report modeli', () {
    test('fromMap tüm alanları çözer + bozuk enum güvenli varsayılana düşer',
        () {
      final r = Report.fromMap('message_x__u1', {
        'reporterUid': 'u1',
        'reportedUid': 'u2',
        'targetType': 'message',
        'targetId': 'x',
        'chatId': 'c1',
        'reason': 'harassment',
        'note': 'kötü',
        'status': 'reviewing',
        'createdAt': '2026-07-12T10:00:00.000',
        'adminNote': 'bakılıyor',
        'resolvedBy': 'admin1',
        'resolvedAt': '2026-07-12T11:00:00.000',
      });
      expect(r.target, ReportTarget.message);
      expect(r.reason, ReportReason.harassment);
      expect(r.status, ReportStatus.reviewing);
      expect(r.chatId, 'c1');
      expect(r.resolvedBy, 'admin1');
      expect(r.resolvedAt, isNotNull);

      final bad = Report.fromMap('id', {
        'targetType': 'uçan-halı',
        'reason': 'yok',
        'status': 'neon',
        'createdAt': 123,
      });
      expect(bad.target, ReportTarget.user);
      expect(bad.reason, ReportReason.other);
      expect(bad.status, ReportStatus.open);
    });

    test('ReportStatus.isClosed yalnız resolved/dismissed için', () {
      expect(ReportStatus.open.isClosed, isFalse);
      expect(ReportStatus.reviewing.isClosed, isFalse);
      expect(ReportStatus.resolved.isClosed, isTrue);
      expect(ReportStatus.dismissed.isClosed, isTrue);
    });
  });

  group('MockAdminReportRepository', () {
    test('watchReports en yeni üstte sıralar; openOnly kapalıları eler',
        () async {
      final repo = MockAdminReportRepository([
        _r('a', ReportStatus.open, DateTime(2026, 1, 1)),
        _r('b', ReportStatus.resolved, DateTime(2026, 1, 3)),
        _r('c', ReportStatus.open, DateTime(2026, 1, 2)),
      ]);
      addTearDown(repo.dispose);

      final all = await repo.watchReports().first;
      expect(all.map((e) => e.id), ['b', 'c', 'a']); // createdAt desc

      final open = await repo.watchReports(openOnly: true).first;
      expect(open.map((e) => e.id), ['c', 'a']); // resolved 'b' düştü
    });

    test('updateStatus durumu + çözüm alanlarını yazar; açık kuyruktan düşer',
        () async {
      final repo = MockAdminReportRepository([
        _r('a', ReportStatus.open, DateTime(2026, 1, 1)),
      ]);
      addTearDown(repo.dispose);

      await repo.updateStatus('a',
          status: ReportStatus.resolved,
          resolvedBy: 'admin1',
          adminNote: 'halledildi');

      final all = await repo.watchReports().first;
      expect(all.single.status, ReportStatus.resolved);
      expect(all.single.resolvedBy, 'admin1');
      expect(all.single.adminNote, 'halledildi');
      expect(all.single.resolvedAt, isNotNull);

      final open = await repo.watchReports(openOnly: true).first;
      expect(open, isEmpty);
    });
  });

  group('Yönetici erişimi (claimAdminAccess)', () {
    test('izinli e-posta yönetici olur; akışa yansır', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);
      // Bootstrap listesindeki e-posta ile kayıt.
      final email = kBootstrapAdminEmails.first;
      final user = await repo.register(
          displayName: 'Admin', email: email, password: 'sifre123');
      expect(user.isAdmin, isFalse);

      final ok = await repo.claimAdminAccess();
      expect(ok, isTrue);
      expect(repo.currentUser?.isAdmin, isTrue);
    });

    test('izinsiz e-posta reddedilir; yönetici olmaz', () async {
      final repo = MockAuthRepository();
      addTearDown(repo.dispose);
      await repo.register(
          displayName: 'N', email: 'siradan@ornek.com', password: 'sifre123');

      expect(() => repo.claimAdminAccess(), throwsA(isA<Exception>()));
      expect(repo.currentUser?.isAdmin, isFalse);
    });
  });
}

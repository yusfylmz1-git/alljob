import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/data/models/job.dart';
import 'package:usta_cepte/data/models/report.dart';
import 'package:usta_cepte/features/admin/data/admin_audit_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_config.dart';
import 'package:usta_cepte/features/admin/data/admin_dispute_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_report.dart';
import 'package:usta_cepte/features/admin/data/admin_report_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_user_repository.dart';
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

/// `disputed` durumunda bir iş (hakemlik kuyruğu testleri için).
Job _dispute(
  String id, {
  required JobStatus before,
  required DateTime disputedAt,
}) =>
    Job(
      jobId: id,
      customerId: 'cust_$id',
      customerName: 'Müşteri $id',
      title: 'İş $id',
      description: 'açıklama',
      category: 'plumber',
      province: 'İstanbul',
      district: 'Kadıköy',
      photos: const [],
      isUrgent: false,
      priceType: JobPriceType.inspection,
      status: JobStatus.disputed,
      offerCount: 1,
      customerConfirmedDone: false,
      artisanConfirmedDone: false,
      createdAt: disputedAt.subtract(const Duration(days: 1)),
      expiresAt: disputedAt.add(const Duration(days: 3)),
      selectedArtisanId: 'art_$id',
      disputedBy: JobDisputeParty.customer,
      disputeReason: JobDisputeReason.qualityIssue,
      disputeNote: 'not $id',
      disputedAt: disputedAt,
      statusBeforeDispute: before,
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

    test('assignReport üstlenir/bırakır; kapanınca atama düşer', () async {
      final repo = MockAdminReportRepository([
        _r('a', ReportStatus.open, DateTime(2026, 1, 1)),
      ]);
      addTearDown(repo.dispose);

      await repo.assignReport('a', assign: true, adminUid: 'admin1');
      expect((await repo.watchReports().first).single.assignedTo, 'admin1');

      await repo.assignReport('a', assign: false, adminUid: 'admin1');
      expect((await repo.watchReports().first).single.assignedTo, isNull);

      // Karara bağlanınca (kapanınca) atama temizlenir (CF paritesi).
      await repo.assignReport('a', assign: true, adminUid: 'admin1');
      await repo.updateStatus('a',
          status: ReportStatus.resolved, resolvedBy: 'admin1');
      expect((await repo.watchReports().first).single.assignedTo, isNull);
    });
  });

  group('MockAdminDisputeRepository (hakemlik)', () {
    test('watchDisputes yalnız disputed işleri en yeni bildirilen üstte verir',
        () async {
      final repo = MockAdminDisputeRepository([
        _dispute('a',
            before: JobStatus.inProgress, disputedAt: DateTime(2026, 1, 1)),
        _dispute('b',
            before: JobStatus.completed, disputedAt: DateTime(2026, 1, 3)),
        _dispute('c',
            before: JobStatus.workerSelected,
            disputedAt: DateTime(2026, 1, 2)),
      ]);
      addTearDown(repo.dispose);

      final list = await repo.watchDisputes().first;
      expect(list.map((e) => e.jobId), ['b', 'c', 'a']); // disputedAt desc
      expect(list.every((e) => e.status == JobStatus.disputed), isTrue);
    });

    test('cancel kararı işi iptal eder + anlaşmazlığı temizler; kuyruktan düşer',
        () async {
      final repo = MockAdminDisputeRepository([
        _dispute('a',
            before: JobStatus.inProgress, disputedAt: DateTime(2026, 1, 1)),
      ]);
      addTearDown(repo.dispose);

      await repo.resolveDispute('a',
          decision: DisputeDecision.cancelJob, note: 'haklı');

      final list = await repo.watchDisputes().first;
      expect(list, isEmpty); // artık disputed değil → kuyruktan düşer
    });

    test('restore kararı işi sorun öncesi durumuna döndürür + temizler',
        () async {
      final repo = MockAdminDisputeRepository([
        _dispute('a',
            before: JobStatus.completed, disputedAt: DateTime(2026, 1, 1)),
      ]);
      addTearDown(repo.dispose);

      await repo.resolveDispute('a', decision: DisputeDecision.restoreJob);

      // Kuyruktan düştü; iç durum completed'a döndü, dispute alanları temizlendi.
      final list = await repo.watchDisputes().first;
      expect(list, isEmpty);
    });
  });

  group('MockAdminUserRepository (kullanıcı yönetimi)', () {
    AppUser u(String uid, String email, {bool suspended = false}) => AppUser(
          uid: uid,
          displayName: 'Kullanıcı $uid',
          email: email,
          createdAt: DateTime(2026, 1, 1),
          suspended: suspended,
        );

    test('findByUid / findByEmail bulur (email küçük harfe duyarsız)',
        () async {
      final repo = MockAdminUserRepository([
        u('u1', 'Ali@Ornek.com'),
        u('u2', 'veli@ornek.com'),
      ]);
      expect((await repo.findByUid('u1'))?.email, 'Ali@Ornek.com');
      expect((await repo.findByEmail('ali@ornek.com'))?.uid, 'u1');
      expect(await repo.findByUid('yok'), isNull);
      expect(await repo.findByEmail('yok@ornek.com'), isNull);
    });

    test('setSuspended askıya alır ve geri açar', () async {
      final repo = MockAdminUserRepository([u('u1', 'a@ornek.com')]);

      expect((await repo.findByUid('u1'))?.suspended, isFalse);

      await repo.setSuspended('u1', suspended: true, reason: 'spam');
      expect((await repo.findByUid('u1'))?.suspended, isTrue);

      await repo.setSuspended('u1', suspended: false);
      expect((await repo.findByUid('u1'))?.suspended, isFalse);
    });

    test('setRole rol atar/değiştirir/kaldırır (findRole yansıtır)', () async {
      final repo = MockAdminUserRepository([u('u1', 'a@ornek.com')]);
      addTearDown(repo.dispose);
      expect(await repo.findRole('u1'), isNull);

      await repo.setRole('u1', role: 'moderator');
      expect(await repo.findRole('u1'), 'moderator');

      await repo.setRole('u1', role: 'superadmin');
      expect(await repo.findRole('u1'), 'superadmin');

      await repo.setRole('u1', role: null);
      expect(await repo.findRole('u1'), isNull);
    });

    test('watchRoster süper yöneticileri üstte sıralar; setRole yansır',
        () async {
      final repo = MockAdminUserRepository([
        u('u1', 'a@ornek.com'),
        u('u2', 'b@ornek.com'),
      ]);
      addTearDown(repo.dispose);

      expect(await repo.watchRoster().first, isEmpty);

      await repo.setRole('u1', role: 'moderator');
      await repo.setRole('u2', role: 'superadmin');

      final roster = await repo.watchRoster().first;
      expect(roster.map((e) => e.uid), ['u2', 'u1']); // superadmin üstte
      expect(roster.first.isSuperAdmin, isTrue);

      await repo.setRole('u2', role: null);
      final after = await repo.watchRoster().first;
      expect(after.map((e) => e.uid), ['u1']); // kaldırılan düştü
    });
  });

  group('AppUser.suspended', () {
    test('fromMap suspended alanını okur; yoksa false', () {
      final s = AppUser.fromMap('u1', {
        'displayName': 'S',
        'email': 's@ornek.com',
        'suspended': true,
      });
      expect(s.suspended, isTrue);

      final n = AppUser.fromMap('u2', {'email': 'n@ornek.com'});
      expect(n.suspended, isFalse);
    });
  });

  group('Denetim kaydı (AuditEntry)', () {
    test('fromMap alanları + before/after haritalarını çözer; label TR', () {
      final e = AuditEntry.fromMap('log1', {
        'actorUid': 'admin1',
        'action': 'set_role',
        'targetType': 'user',
        'targetId': 'u9',
        'before': {'role': null},
        'after': {'role': 'moderator'},
        'createdAt': '2026-07-13T10:00:00.000',
      });
      expect(e.actorUid, 'admin1');
      expect(e.action, 'set_role');
      expect(e.actionLabelTR, 'Rol atandı');
      expect(e.targetId, 'u9');
      expect(e.after?['role'], 'moderator');

      // Bilinmeyen eylem kodu olduğu gibi gösterilir.
      final unknown = AuditEntry.fromMap('l2', {'action': 'foo_bar'});
      expect(unknown.actionLabelTR, 'foo_bar');
    });

    test('MockAdminAuditRepository en yeni üstte sıralar', () async {
      AuditEntry a(String id, DateTime t) =>
          AuditEntry(id: id, actorUid: 'x', action: 'grant_admin', createdAt: t);
      final repo = MockAdminAuditRepository([
        a('a', DateTime(2026, 1, 1)),
        a('b', DateTime(2026, 1, 3)),
        a('c', DateTime(2026, 1, 2)),
      ]);
      final list = await repo.watchAuditLog().first;
      expect(list.map((e) => e.id), ['b', 'c', 'a']);
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
      // RBAC: bootstrap her zaman superadmin rolü verir.
      expect(repo.currentUser?.adminRole, 'superadmin');
      expect(repo.currentUser?.isSuperAdmin, isTrue);
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

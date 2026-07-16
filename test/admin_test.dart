import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/data/models/job.dart';
import 'package:usta_cepte/data/models/report.dart';
import 'package:usta_cepte/features/admin/data/admin_audit_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_config.dart';
import 'package:usta_cepte/features/admin/data/admin_dispute_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_report.dart';
import 'package:usta_cepte/features/admin/data/admin_report_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_artisan_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_capabilities.dart';
import 'package:usta_cepte/features/admin/data/admin_invite_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_job_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_export_util.dart';
import 'package:usta_cepte/features/admin/data/admin_runtime_config_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_stats_repository.dart';
import 'package:usta_cepte/features/admin/data/admin_user_repository.dart';
import 'package:usta_cepte/features/auth/data/mock_auth_repository.dart';
import 'package:usta_cepte/data/models/artisan_profile.dart';
import 'package:usta_cepte/data/models/availability.dart';

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

    test('fetchPage createdAt cursor ile sayfalar (en yeni üstte)', () async {
      final repo = MockAdminReportRepository([
        _r('a', ReportStatus.open, DateTime(2026, 1, 1)),
        _r('b', ReportStatus.resolved, DateTime(2026, 1, 4)),
        _r('c', ReportStatus.open, DateTime(2026, 1, 3)),
        _r('d', ReportStatus.open, DateTime(2026, 1, 2)),
      ]);
      addTearDown(repo.dispose);

      final p1 = await repo.fetchPage(limit: 2);
      expect(p1.map((e) => e.id), ['b', 'c']);
      final p2 = await repo.fetchPage(
          beforeCursor: p1.last.createdAt.toIso8601String(), limit: 2);
      expect(p2.map((e) => e.id), ['d', 'a']);
      final p3 = await repo.fetchPage(
          beforeCursor: p2.last.createdAt.toIso8601String(), limit: 2);
      expect(p3, isEmpty);
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

    test('fetchPage disputed işleri createdAt cursor ile sayfalar', () async {
      // createdAt = disputedAt - 1 gün (helper böyle kuruyor) → createdAt sırası.
      final repo = MockAdminDisputeRepository([
        _dispute('a',
            before: JobStatus.inProgress, disputedAt: DateTime(2026, 1, 2)),
        _dispute('b',
            before: JobStatus.completed, disputedAt: DateTime(2026, 1, 5)),
        _dispute('c',
            before: JobStatus.workerSelected,
            disputedAt: DateTime(2026, 1, 4)),
      ]);
      addTearDown(repo.dispose);

      final p1 = await repo.fetchPage(limit: 2);
      expect(p1.map((e) => e.jobId), ['b', 'c']); // createdAt desc
      final p2 = await repo.fetchPage(
          beforeCursor: p1.last.createdAt.toIso8601String(), limit: 2);
      expect(p2.map((e) => e.jobId), ['a']);
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

    test('fetchPage en yeni üstte + cursor ile sonraki sayfa', () async {
      AuditEntry a(String id, DateTime t) =>
          AuditEntry(id: id, actorUid: 'x', action: 'grant_admin', createdAt: t);
      final repo = MockAdminAuditRepository([
        a('a', DateTime(2026, 1, 1)),
        a('b', DateTime(2026, 1, 4)),
        a('c', DateTime(2026, 1, 3)),
        a('d', DateTime(2026, 1, 2)),
      ]);

      // İlk sayfa (limit 2): en yeni ikisi.
      final page1 = await repo.fetchPage(limit: 2);
      expect(page1.map((e) => e.id), ['b', 'c']);

      // Sonraki sayfa: son kaydın cursor'ından eskiler.
      final page2 =
          await repo.fetchPage(beforeCursor: page1.last.cursor, limit: 2);
      expect(page2.map((e) => e.id), ['d', 'a']);

      // Sondan sonrası boş.
      final page3 =
          await repo.fetchPage(beforeCursor: page2.last.cursor, limit: 2);
      expect(page3, isEmpty);
    });

    test('filterAudit kategori + aktör/hedef uid araması', () {
      AuditEntry e(String id, String action, String actor, String target) =>
          AuditEntry(
            id: id,
            actorUid: actor,
            action: action,
            targetId: target,
            createdAt: DateTime(2026, 1, 1),
          );
      final all = [
        e('1', 'set_role', 'admin1', 'u9'),
        e('2', 'suspend_user', 'admin2', 'u9'),
        e('3', 'resolve_report', 'admin1', 'r5'),
        e('4', 'resolve_dispute', 'admin2', 'j7'),
      ];

      // Kategori süzme.
      expect(
          filterAudit(all, category: AuditCategory.roles).map((x) => x.id),
          ['1']);
      expect(
          filterAudit(all, category: AuditCategory.reports).map((x) => x.id),
          ['3']);
      expect(filterAudit(all).length, 4); // all → hepsi

      // Serbest metin (aktör veya hedef).
      expect(filterAudit(all, query: 'u9').map((x) => x.id), ['1', '2']);
      expect(filterAudit(all, query: 'ADMIN1').map((x) => x.id), ['1', '3']);

      // Kategori + arama birlikte.
      expect(
          filterAudit(all, category: AuditCategory.suspension, query: 'u9')
              .map((x) => x.id),
          ['2']);
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

  group('Admin dizin sayfalama (Wave 1)', () {
    AppUser _u(String id, DateTime t,
            {bool suspended = false, bool artisan = false}) =>
        AppUser(
          uid: id,
          displayName: id,
          email: '$id@t.com',
          createdAt: t,
          suspended: suspended,
          hasArtisanProfile: artisan,
        );

    test('kullanıcı fetchPage createdAt desc + filtre + cursor', () async {
      final base = DateTime.utc(2026, 7, 1);
      final repo = MockAdminUserRepository([
        _u('a', base),
        _u('b', base.add(const Duration(days: 1)), suspended: true),
        _u('c', base.add(const Duration(days: 2)), artisan: true),
        _u('d', base.add(const Duration(days: 3))),
      ]);
      final all = await repo.fetchPage(limit: 2);
      expect(all.map((u) => u.uid), ['d', 'c']);
      final next = await repo.fetchPage(
        beforeCursor: all.last.createdAt.toUtc().toIso8601String(),
        limit: 2,
      );
      expect(next.map((u) => u.uid), ['b', 'a']);
      final sus = await repo.fetchPage(filter: AdminUserListFilter.suspended);
      expect(sus.map((u) => u.uid), ['b']);
      final arts = await repo.fetchPage(filter: AdminUserListFilter.artisans);
      expect(arts.map((u) => u.uid), ['c']);
    });

    test('ilan fetchPage status filtre + cursor', () async {
      Job job(String id, JobStatus s, DateTime t) => Job(
            jobId: id,
            customerId: 'c',
            customerName: 'C',
            title: id,
            description: 'd',
            category: 'plumber',
            province: 'İstanbul',
            district: 'Kadıköy',
            photos: const [],
            isUrgent: false,
            priceType: JobPriceType.inspection,
            status: s,
            offerCount: 0,
            customerConfirmedDone: false,
            artisanConfirmedDone: false,
            createdAt: t,
            expiresAt: t.add(const Duration(days: 3)),
          );
      final base = DateTime.utc(2026, 7, 1);
      final repo = MockAdminJobRepository([
        job('1', JobStatus.open, base),
        job('2', JobStatus.open, base.add(const Duration(hours: 1))),
        job('3', JobStatus.completed, base.add(const Duration(hours: 2))),
      ]);
      final open = await repo.fetchPage(status: JobStatus.open, limit: 1);
      expect(open.map((j) => j.jobId), ['2']);
      final more = await repo.fetchPage(
        status: JobStatus.open,
        beforeCursor: open.last.createdAt.toUtc().toIso8601String(),
        limit: 5,
      );
      expect(more.map((j) => j.jobId), ['1']);
    });

    test('usta fetchPage verified filtre', () async {
      ArtisanProfile p(String id, bool v, DateTime t) => ArtisanProfile(
            uid: id,
            profession: 'plumber',
            experienceYears: 1,
            aboutText: '',
            serviceAreas: const [],
            certificates: const [],
            workPhotos: const [],
            isVerified: v,
            averageRating: 0,
            totalReviews: 0,
            totalRatingSum: 0,
            isPremium: false,
            alwaysAvailable: true,
            manualPause: false,
            weeklySchedule: WeeklySchedule.empty(),
            createdAt: t,
          );
      final base = DateTime.utc(2026, 7, 1);
      final repo = MockAdminArtisanRepository([
        p('x', false, base),
        p('y', true, base.add(const Duration(days: 1))),
      ]);
      final verified = await repo.fetchPage(isVerified: true);
      expect(verified.map((a) => a.uid), ['y']);
    });
  });

  group('AdminCapabilities (Wave 2)', () {
    test('superadmin her şeyi geçer', () {
      final c = AdminCapabilities.superAdmin();
      expect(c.allows('chats.read'), isTrue);
      expect(c.allows('staff.manage'), isTrue);
    });

    test('missing field enforce → default set (chats yok)', () {
      final c = AdminCapabilities.fromRoster(
        isSuperAdmin: false,
        capabilities: null,
        enforceMode: true,
      );
      expect(c.allows('reports.manage'), isTrue);
      expect(c.allows('chats.read'), isFalse);
      expect(c.allows('export.run'), isFalse);
    });

    test('missing field log-only → full', () {
      final c = AdminCapabilities.fromRoster(
        isSuperAdmin: false,
        capabilities: null,
        enforceMode: false,
      );
      expect(c.allows('chats.read'), isTrue);
    });

    test('explicit empty → hiçbir şey', () {
      final c = AdminCapabilities.fromRoster(
        isSuperAdmin: false,
        capabilities: const [],
      );
      expect(c.allows('reports.manage'), isFalse);
    });

    test('explicit chats.read', () {
      final c = AdminCapabilities.fromRoster(
        isSuperAdmin: false,
        capabilities: const ['chats.read', 'reports.manage'],
      );
      expect(c.allows('chats.read'), isTrue);
      expect(c.allows('users.suspend'), isFalse);
    });
  });

  group('Admin invite mock', () {
    test('create pending + aynı email önceki pending revoke', () async {
      final repo = MockAdminInviteRepository();
      addTearDown(repo.dispose);
      final id1 = await repo.create(email: 'A@B.com');
      final id2 = await repo.create(email: 'a@b.com');
      final pending = await repo.watchPending().first;
      expect(pending.map((i) => i.id), [id2]);
      expect(id1, isNot(id2));
    });
  });

  group('adminStats deltas (Wave 3 / PR6)', () {
    test('jobStatsDelta create/open→disputed/delete', () {
      expect(
        jobStatsDelta(null, {'status': 'open'}),
        {'jobsOpen': 1},
      );
      expect(
        jobStatsDelta({'status': 'open'}, {'status': 'disputed'}),
        {'jobsOpen': -1, 'jobsDisputed': 1, 'openDisputes': 1},
      );
      expect(
        jobStatsDelta({'status': 'disputed'}, {'status': 'cancelled'}),
        {'jobsDisputed': -1, 'jobsCancelled': 1, 'openDisputes': -1},
      );
      expect(
        jobStatsDelta({'status': 'open'}, null),
        {'jobsOpen': -1},
      );
    });

    test('reportStatsDelta open/closed', () {
      expect(
        reportStatsDelta(null, {'status': 'open'}),
        {'openReports': 1},
      );
      expect(
        reportStatsDelta({'status': 'open'}, {'status': 'resolved'}),
        {'openReports': -1},
      );
      expect(
        reportStatsDelta({'status': 'resolved'}, {'status': 'reviewing'}),
        {'openReports': 1},
      );
    });

    test('AdminStatsSnapshot fromMap + stale', () {
      final s = AdminStatsSnapshot.fromMap({
        'usersTotal': 10,
        'openReports': 2,
        'updatedAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      });
      expect(s.usersTotal, 10);
      expect(s.openReports, 2);
      expect(s.isStale, isTrue);
      final fresh = AdminStatsSnapshot.fromMap({
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      expect(fresh.isStale, isFalse);
    });
  });

  group('Wave 5 ops (config / export / bulk)', () {
    test('AdminRuntimeConfig fromMap varsayılanlar', () {
      final c = AdminRuntimeConfig.fromMap({});
      expect(c.premiumFreeDuringBeta, isTrue);
      expect(c.maintenanceMode, isFalse);
      final c2 = AdminRuntimeConfig.fromMap({
        'premiumFreeDuringBeta': false,
        'maintenanceMode': true,
        'minAppVersion': '1.0.0',
      });
      expect(c2.premiumFreeDuringBeta, isFalse);
      expect(c2.maintenanceMode, isTrue);
      expect(c2.minAppVersion, '1.0.0');
    });

    test('mock runtime config update + watch', () async {
      final repo = MockAdminRuntimeConfigRepository();
      addTearDown(repo.dispose);
      expect((await repo.watchRuntime().first).maintenanceMode, isFalse);
      await repo.update({
        'maintenanceMode': true,
        'premiumFreeDuringBeta': false,
      });
      final next = await repo.watchRuntime().first;
      expect(next.maintenanceMode, isTrue);
      expect(next.premiumFreeDuringBeta, isFalse);
    });

    test('buildUsersCsv phone içermez + escape', () {
      final csv = buildUsersCsv([
        AppUser(
          uid: 'u1',
          displayName: 'Ali, "Veli"',
          email: 'a@b.com',
          createdAt: DateTime.utc(2026, 1, 2),
          phoneNumber: '+905551112233',
          suspended: true,
        ),
      ]);
      expect(csv, contains('uid,email,displayName'));
      expect(csv, isNot(contains('+90555')));
      expect(csv, isNot(contains('phone')));
      expect(csv, contains('"Ali, ""Veli"""'));
      expect(csv, contains('true')); // suspended
    });

    test('bulkSuspend max 25 + admin atlanır', () async {
      final base = DateTime.utc(2026, 7, 1);
      final repo = MockAdminUserRepository([
        for (var i = 0; i < 3; i++)
          AppUser(
            uid: 'u$i',
            displayName: 'U$i',
            email: 'u$i@t.com',
            createdAt: base.add(Duration(hours: i)),
          ),
      ]);
      await repo.setRole('u0', role: 'moderator');
      final results = await repo.bulkSuspend(
        ['u0', 'u1', 'u2'],
        suspended: true,
        reason: 'spam',
      );
      expect(results.length, 3);
      expect(results[0].ok, isFalse);
      expect(results[0].error, 'is-admin');
      expect(results[1].ok, isTrue);
      expect((await repo.findByUid('u1'))!.suspended, isTrue);
      expect((await repo.findByUid('u0'))!.suspended, isFalse);

      expect(
        () => repo.bulkSuspend(
          List.generate(26, (i) => 'x$i'),
          suspended: true,
        ),
        throwsStateError,
      );
    });

    test('logExport mock kaydeder', () async {
      final repo = MockAdminUserRepository();
      await repo.logExport(kind: 'users', rowCount: 12);
      expect(repo.exportLogs.single.kind, 'users');
      expect(repo.exportLogs.single.rowCount, 12);
    });
  });
}

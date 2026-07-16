import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/data/models/staffing.dart';
import 'package:usta_cepte/features/staffing/data/staffing_repository.dart';
import 'package:usta_cepte/features/staffing/presentation/need_search_filter.dart';
import 'package:usta_cepte/features/staffing/presentation/worker_search_filter.dart';

void main() {
  group('StaffWorkerListing', () {
    test('idFor, isDaily, toMap/fromMap', () {
      final now = DateTime(2026, 7, 16);
      final w = StaffWorkerListing(
        id: StaffWorkerListing.idFor('u1'),
        uid: 'u1',
        displayName: 'Ali',
        title: 'Boya yardımcısı',
        about: '5 yıl tecrübe, düzenli çalışırım.',
        professionLabel: 'Boyacı',
        province: 'Bursa',
        district: 'Nilüfer',
        rateType: StaffRateType.daily,
        rate: 1500,
        openToWork: true,
        isDaily: true,
        updatedAt: now,
        createdAt: now,
      );
      expect(w.id, 'worker_u1');
      final restored = StaffWorkerListing.fromMap(w.id, w.toMap());
      expect(restored.isDaily, isTrue);
      expect(restored.rateLabel, '1500 ₺/gün');
    });

    test('legacy kind=dayLabor → isDaily', () {
      final w = StaffWorkerListing.fromMap('worker_x', {
        'uid': 'x',
        'displayName': 'V',
        'kind': 'dayLabor',
        'title': 't',
        'about': 'about text enough',
        'professionLabel': 'p',
        'province': 'İstanbul',
        'district': 'Kadıköy',
        'rateType': 'negotiable',
        'openToWork': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(w.isDaily, isTrue);
    });
  });

  group('WorkerSearchFilter', () {
    StaffWorkerListing sample({bool isDaily = false, String district = 'Nilüfer'}) {
      final now = DateTime.now();
      return StaffWorkerListing(
        id: 'worker_x',
        uid: 'x',
        displayName: 'Ali',
        title: 'Boya kalfası',
        about: 'Tecrübeli yardımcı.',
        professionLabel: 'Boyacı',
        province: 'Bursa',
        district: district,
        rateType: StaffRateType.daily,
        rate: 1200,
        openToWork: true,
        isDaily: isDaily,
        updatedAt: now,
      );
    }

    test('gündelik filtresi ve metin arama', () {
      final list = [
        sample(isDaily: true),
        sample(isDaily: false, district: 'Osmangazi'),
      ];
      final daily = const WorkerSearchFilter(dailyOnly: true);
      expect(daily.applyClientFilters(list).length, 1);
      expect(WorkerSearchFilter.matchesQuery(list.first, 'boya nilüfer'), isTrue);
    });
  });

  group('NeedSearchFilter', () {
    test('gündelik + metin', () {
      final n = StaffNeed(
        id: 'n1',
        employerUid: 'e1',
        employerName: 'Firma',
        title: 'Yarın boyacı lazım',
        detail: 'Daire boyası.',
        province: 'Ankara',
        district: 'Çankaya',
        neededCount: 2,
        isDaily: true,
        status: 'open',
        createdAt: DateTime.now(),
      );
      expect(NeedSearchFilter.matchesQuery(n, 'boya ankara'), isTrue);
      expect(
        const NeedSearchFilter(dailyOnly: true).applyClientFilters([n]).length,
        1,
      );
    });
  });

  group('MockStaffingRepository', () {
    test('eleman kaydet → listede → gündelik süz', () async {
      final repo = MockStaffingRepository();
      final now = DateTime.now();
      await repo.saveWorkerListing(StaffWorkerListing(
        id: StaffWorkerListing.idFor('w1'),
        uid: 'w1',
        displayName: 'Veli',
        title: 'İş arıyorum',
        about: 'Şantiye deneyimli, sabah müsaitim.',
        professionLabel: 'Genel işçi',
        province: 'İstanbul',
        district: 'Kartal',
        rateType: StaffRateType.negotiable,
        openToWork: true,
        isDaily: true,
        updatedAt: now,
      ));
      final open = await repo.watchOpenWorkers(dailyOnly: true).first;
      expect(open.length, 1);
    });

    test('eleman ilanı aç → kapat', () async {
      final repo = MockStaffingRepository();
      final id = await repo.createNeed(StaffNeed(
        id: '',
        employerUid: 'e1',
        employerName: 'Firma',
        title: 'Yarın 3 boyacı',
        detail: 'Daire boyası, sabah 08:00.',
        province: 'Ankara',
        district: 'Çankaya',
        neededCount: 3,
        isDaily: true,
        status: 'open',
        createdAt: DateTime.now(),
      ));
      await repo.closeNeed(id);
      final mine = await repo.watchMyNeeds('e1').first;
      expect(mine.first.isOpen, isFalse);
    });
  });
}

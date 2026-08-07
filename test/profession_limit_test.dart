import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/job.dart'
    show JobCancelReason, kOtherProfession, kQuickSupportCategory;
import 'package:sepette_hizmet/features/artisan/application/my_profile_controller.dart';

/// B-03 + B-11 regresyonları.
void main() {
  group('B-03 · Hemen Lazım meslek limitine dahil DEĞİL', () {
    test('isRealProfession Hemen Lazım kodlarını eler', () {
      expect(MyProfileController.isRealProfession('elektrikci'), isTrue);
      expect(MyProfileController.isRealProfession(kOtherProfession), isFalse);
      expect(
          MyProfileController.isRealProfession(kQuickSupportCategory), isFalse);
    });

    test('4 meslek + Hemen Lazım varken sayım 4 döner (5 değil)', () {
      // Cihazda görülen hata tam buydu: sayaç "4/5 seçili" yazarken 5.
      // meslek reddediliyordu, çünkü limit kontrolü Hemen Lazım'ı sayıyordu.
      final codes = [
        'elektrikci',
        'tesisatci',
        'boyaci',
        'marangoz',
        kOtherProfession, // Hemen Lazım — meslek değil
      ];

      expect(MyProfileController.realProfessionCount(codes), 4,
          reason: 'Hemen Lazım meslek sayısına karışmamalı.');
      expect(
        MyProfileController.realProfessionCount(codes) <
            MyProfileController.maxProfessions,
        isTrue,
        reason: '5. meslek hâlâ seçilebilmeli.',
      );
    });

    test('5 gerçek meslek varsa limit dolmuştur', () {
      final codes = [
        'elektrikci',
        'tesisatci',
        'boyaci',
        'marangoz',
        'kaportaci',
        kOtherProfession,
      ];

      expect(MyProfileController.realProfessionCount(codes), 5);
      expect(
        MyProfileController.realProfessionCount(codes) >=
            MyProfileController.maxProfessions,
        isTrue,
        reason: '6. meslek reddedilmeli — Hemen Lazım bunu değiştirmez.',
      );
    });

    test('yalnız Hemen Lazım açıksa meslek sayısı 0', () {
      expect(MyProfileController.realProfessionCount([kOtherProfession]), 0);
    });
  });

  group('B-11 · iptal nedenlerinde rateLimited kullanıcıya sunulmaz', () {
    test('rateLimited yalnız CF tarafından yazılır', () {
      // Kullanıcıya gösterilen liste `rateLimited` HARİÇ olmalı: günlük ilan
      // hakkı dolmuşsa zaten ilan açamıyor, "nedeni bu" demek anlamsız.
      final userFacing = JobCancelReason.values
          .where((r) => r != JobCancelReason.rateLimited)
          .toList();

      expect(userFacing, hasLength(3));
      expect(userFacing, contains(JobCancelReason.changedMind));
      expect(userFacing, contains(JobCancelReason.solved));
      expect(userFacing, contains(JobCancelReason.wrongPost));
      expect(userFacing, isNot(contains(JobCancelReason.rateLimited)));
    });

    test('rateLimited enum içinde KALIR (veri göçü riski)', () {
      // Sunucu bu değeri yazmaya devam ediyor; enum'dan silmek eski
      // kayıtları okunamaz yapar (CLAUDE.md kural 6: apiValue = Firestore
      // değeri).
      expect(JobCancelReason.fromString('rateLimited'),
          JobCancelReason.rateLimited);
      expect(JobCancelReason.rateLimited.labelTR, 'Günlük ilan hakkı doldu');
    });
  });
}

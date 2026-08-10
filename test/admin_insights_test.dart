import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/admin/data/admin_insights_repository.dart';

void main() {
  group('rankCounts', () {
    test('çoktan aza sıralar ve top keser', () {
      final r = rankCounts(
        {'a': 1, 'b': 5, 'c': 3},
        labelOf: (k) => 'L$k',
        top: 2,
      );
      expect(r.map((e) => e.key).toList(), ['b', 'c']);
      expect(r.first.label, 'Lb');
      expect(r.first.count, 5);
    });

    test('boş anahtar emptyLabel alır', () {
      final r = rankCounts(
        {'': 2, 'x': 1},
        labelOf: (k) => k,
        emptyLabel: 'Belirtilmemiş',
      );
      expect(r.first.label, 'Belirtilmemiş');
    });
  });

  group('buildInsightsFromSamples', () {
    test('il / meslek / ürün kategorisi ve 7 günlük sayaç', () {
      final now = DateTime.utc(2026, 8, 10, 12);
      final ins = buildInsightsFromSamples(
        now: now,
        jobs: [
          {
            'province': 'İstanbul',
            'category': 'plumber',
            'status': 'open',
            'createdAt': '2026-08-09T10:00:00.000Z',
          },
          {
            'province': 'İstanbul',
            'category': 'painter',
            'status': 'open',
            'createdAt': '2026-08-08T10:00:00.000Z',
          },
          {
            'province': 'Bursa',
            'category': 'plumber',
            'status': 'cancelled',
            'createdAt': '2026-07-01T10:00:00.000Z',
          },
        ],
        artisans: [
          {
            'profession': 'plumber',
            'professions': ['plumber', 'electrician'],
            'isVerified': true,
            'adminVerified': true,
            'isPremium': true,
            'certificateStatus': 'pending',
          },
          {
            'profession': 'painter',
            'isVerified': false,
          },
        ],
        products: [
          {
            'categoryCode': 'hirdavat',
            'status': 'active',
          },
          {
            'categoryCode': 'hirdavat',
            'status': 'pending_review',
          },
          {
            'categoryCode': 'mobilya',
            'status': 'active',
            'moderationHidden': true,
          },
        ],
        users: [
          {
            'hasArtisanProfile': true,
            'phoneVerified': true,
            'createdAt': '2026-08-09T00:00:00.000Z',
          },
          {
            'hasArtisanProfile': false,
            'phoneVerified': false,
            'suspended': true,
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        professionLabel: (c) => c == 'plumber' ? 'Tesisatçı' : c,
        productCategoryLabel: (c) => c,
        jobStatusLabel: (s) => s,
        productStatusLabel: (s) => s,
      );

      expect(ins.jobsSampled, 3);
      expect(ins.jobsLast7d, 2); // 9 ve 8 Ağustos
      expect(ins.jobsOpenInSample, 2);
      expect(ins.jobProvinces.first.label, 'İstanbul');
      expect(ins.jobProvinces.first.count, 2);
      expect(ins.jobCategories.first.key, 'plumber');
      expect(ins.jobCategories.first.label, 'Tesisatçı');
      expect(ins.jobCategories.first.count, 2);

      // plumber+electrician + painter → plumber 1, electrician 1, painter 1
      expect(ins.artisanProfessions.length, 3);
      expect(ins.artisansVerified, 1);
      expect(ins.artisansAdminVerified, 1);
      expect(ins.artisansPremium, 1);
      expect(ins.artisansCertPending, 1);

      expect(ins.productCategories.first.key, 'hirdavat');
      expect(ins.productCategories.first.count, 2);
      expect(ins.productsPendingReview, 1);
      expect(ins.productsActive, 2);
      expect(ins.productsHidden, 1);

      expect(ins.usersWithArtisan, 1);
      expect(ins.usersPhoneVerified, 1);
      expect(ins.usersSuspended, 1);
      expect(ins.usersLast7d, 1);
    });

    test('MockAdminInsightsRepository seed döner', () async {
      final seed = AdminInsights(
        generatedAt: DateTime.utc(2026, 1, 1),
        jobsSampled: 0,
        artisansSampled: 0,
        productsSampled: 0,
        usersSampled: 0,
      );
      final repo = MockAdminInsightsRepository(seed: seed);
      final got = await repo.fetchInsights();
      expect(got.generatedAt, seed.generatedAt);
    });
  });
}

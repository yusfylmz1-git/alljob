import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/features/membership/membership_access.dart';
import 'package:usta_cepte/features/membership/membership_package.dart';

void main() {
  group('artisanProUnlocked', () {
    test('ödenmiş premium her zaman açık', () {
      expect(
        artisanProUnlocked(
          package: MembershipPackage.free,
          hasPaidPremium: true,
          freeDuringBetaGlobal: false,
        ),
        isTrue,
      );
    });

    test('ücretsiz plan kilitli', () {
      expect(
        artisanProUnlocked(
          package: MembershipPackage.free,
          hasPaidPremium: false,
          freeDuringBetaGlobal: true,
        ),
        isFalse,
      );
    });

    test('beta ve pro açık', () {
      expect(
        artisanProUnlocked(
          package: MembershipPackage.beta,
          hasPaidPremium: false,
          freeDuringBetaGlobal: false,
        ),
        isTrue,
      );
      expect(
        artisanProUnlocked(
          package: MembershipPackage.pro,
          hasPaidPremium: false,
          freeDuringBetaGlobal: false,
        ),
        isTrue,
      );
    });

    test('plan yoksa global beta bayrağı', () {
      expect(
        artisanProUnlocked(
          package: null,
          hasPaidPremium: false,
          freeDuringBetaGlobal: true,
        ),
        isTrue,
      );
      expect(
        artisanProUnlocked(
          package: null,
          hasPaidPremium: false,
          freeDuringBetaGlobal: false,
        ),
        isFalse,
      );
    });
  });
}

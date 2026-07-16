import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/core/config/app_version.dart';

void main() {
  group('compareVersions', () {
    test('eşit ve farklı majör/minör/yama', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('eksik parça 0 sayılır', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
    });

    test('build / pre soneki yok sayılır', () {
      expect(compareVersions('1.0.0+12', '1.0.0'), 0);
      expect(compareVersions('1.0.1-beta', '1.0.0'), greaterThan(0));
    });
  });

  group('isClientBelowMinVersion', () {
    test('min yoksa asla zorlama yok', () {
      expect(
        isClientBelowMinVersion(clientVersion: '1.0.0', minAppVersion: null),
        isFalse,
      );
      expect(
        isClientBelowMinVersion(clientVersion: '1.0.0', minAppVersion: '  '),
        isFalse,
      );
    });

    test('istemci düşükse true', () {
      expect(
        isClientBelowMinVersion(
          clientVersion: '1.0.0',
          minAppVersion: '1.0.1',
        ),
        isTrue,
      );
      expect(
        isClientBelowMinVersion(
          clientVersion: '1.0.1',
          minAppVersion: '1.0.1',
        ),
        isFalse,
      );
      expect(
        isClientBelowMinVersion(
          clientVersion: '1.1.0',
          minAppVersion: '1.0.1',
        ),
        isFalse,
      );
    });

    test('kClientVersion tutarlı semver', () {
      expect(compareVersions(kClientVersion, kClientVersion), 0);
      expect(
        isClientBelowMinVersion(
          clientVersion: kClientVersion,
          minAppVersion: null,
        ),
        isFalse,
      );
    });
  });
}

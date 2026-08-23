import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/config/app_version.dart';
import 'package:sepette_hizmet/core/constants/app_constants.dart';

void main() {
  group('compareVersions', () {
    test('eşit ve farklı majör/minör/yama', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
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

  group('Sürüm TEK kaynaktan gelir (2026-08-23)', () {
    // Bu grubun varlık sebebi gerçek bir tuzak: `kClientVersion` elle
    // yazılmış ayrı bir sabitti ve `1.0.0`'da unutulmuştu — gerçek sürüm
    // `1.2.0` iken. Zorunlu güncelleme kapısı bu değeri okuduğu için
    // `minAppVersion: 1.1.0` yazan bir yönetici GÜNCEL sürümdekiler dâhil
    // HERKESİ kilitlerdi.

    test('kClientVersion == AppConstants.appVersion', () {
      expect(kClientVersion, AppConstants.appVersion,
          reason: 'İkinci bir sürüm sabiti doğmuş — biri eskiyecek ve '
              'zorunlu güncelleme kapısı yanlış hesaplayacak.');
    });

    test('güncel sürüm kendi sürümüyle KİLİTLENMİYOR', () {
      // minAppVersion = çalışan sürüm → kapı açılmamalı.
      expect(
        isClientBelowMinVersion(
          clientVersion: kClientVersion,
          minAppVersion: AppConstants.appVersion,
        ),
        isFalse,
      );
    });

    test('compareVersions İKİ kez tanımlanmıyor', () {
      // İki kopya = iki farklı davranış: güncelleme rozeti bir şey,
      // zorunlu güncelleme kapısı başka şey söyleyebilirdi.
      final kaynak = File('lib/core/config/app_version.dart').readAsStringSync();
      expect(kaynak.contains('int compareVersions('), isFalse,
          reason: 'Kopya uygulama geri gelmiş; tek kaynak '
              'app_version_info.dart olmalı.');
      expect(kaynak.contains("show compareVersions"), isTrue);
    });
  });
}

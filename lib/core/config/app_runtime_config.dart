import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'backend_config.dart';

/// Sunucu `adminConfig/runtime` (bayraklar + platform içeriği).
/// Admin paneli yazar; tüketici salt okur (rules: public read).
class AppRuntimeConfig {
  const AppRuntimeConfig({
    this.premiumFreeDuringBeta = AppConstants.premiumFreeDuringBeta,
    this.maintenanceMode = false,
    this.minAppVersion,
    this.appDisplayName,
    this.tagline,
    this.supportEmail,
    this.supportPhone,
    this.playStoreUrl,
    this.appStoreUrl,
    this.websiteUrl,
    this.logoUrl,
    this.aboutShort,
    this.announcementEnabled = false,
    this.announcementTitle,
    this.announcementBody,
    this.announcementCtaLabel,
    this.announcementCtaUrl,
  });

  final bool premiumFreeDuringBeta;
  final bool maintenanceMode;
  final String? minAppVersion;

  final String? appDisplayName;
  final String? tagline;
  final String? supportEmail;
  final String? supportPhone;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? websiteUrl;
  final String? logoUrl;
  final String? aboutShort;

  final bool announcementEnabled;
  final String? announcementTitle;
  final String? announcementBody;
  final String? announcementCtaLabel;
  final String? announcementCtaUrl;

  bool get hasAnnouncement =>
      announcementEnabled &&
      ((announcementTitle ?? '').trim().isNotEmpty ||
          (announcementBody ?? '').trim().isNotEmpty);

  factory AppRuntimeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppRuntimeConfig();
    String? s(String k) {
      final v = map[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return AppRuntimeConfig(
      premiumFreeDuringBeta: map['premiumFreeDuringBeta'] != false,
      maintenanceMode: map['maintenanceMode'] == true,
      minAppVersion: s('minAppVersion'),
      appDisplayName: s('appDisplayName'),
      tagline: s('tagline'),
      supportEmail: s('supportEmail'),
      supportPhone: s('supportPhone'),
      playStoreUrl: s('playStoreUrl'),
      appStoreUrl: s('appStoreUrl'),
      websiteUrl: s('websiteUrl'),
      logoUrl: s('logoUrl'),
      aboutShort: s('aboutShort'),
      announcementEnabled: map['announcementEnabled'] == true,
      announcementTitle: s('announcementTitle'),
      announcementBody: s('announcementBody'),
      announcementCtaLabel: s('announcementCtaLabel'),
      announcementCtaUrl: s('announcementCtaUrl'),
    );
  }
}

/// Canlı runtime config. Firebase kapalıysa sabit varsayılan.
final appRuntimeConfigProvider = StreamProvider<AppRuntimeConfig>((ref) {
  if (!useFirebaseBackend) {
    return Stream.value(const AppRuntimeConfig());
  }
  return FirebaseFirestore.instance
      .collection('adminConfig')
      .doc('runtime')
      .snapshots()
      .map((s) => AppRuntimeConfig.fromMap(s.data()));
});

/// Premium erişim: remote beta bayrağı + gerçek abonelik.
bool premiumAccessFrom({
  required bool hasActivePremium,
  bool? premiumFreeDuringBeta,
}) {
  final free =
      premiumFreeDuringBeta ?? AppConstants.premiumFreeDuringBeta;
  return free || hasActivePremium;
}

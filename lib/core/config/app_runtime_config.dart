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
    this.productsEnabled = true,
    this.productsForceReview = false,
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

  /// Mağaza ürün vitrini açık mı? (deploy'suz kill-switch).
  /// Alan yoksa `true` — Mağaza varsayılan açık; admin kapatır.
  /// Yerel `AppConstants.kProductsEnabled == false` bunu ezer (hard off).
  final bool productsEnabled;

  /// true ise her yayın denemesi `pending_review`'a düşer (publishProduct CF).
  final bool productsForceReview;

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

  /// Ürün vitrini fiilen kullanılabilir mi?
  /// Yerel hard-off VEYA remote kapalı → false.
  bool get isProductsLive =>
      AppConstants.kProductsEnabled && productsEnabled;

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
      // Yoksa açık (Mağaza varsayılan). Yalnız açık `false` yazar kapatır.
      productsEnabled: map['productsEnabled'] != false,
      productsForceReview: map['productsForceReview'] == true,
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

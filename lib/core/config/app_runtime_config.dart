import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'backend_config.dart';

/// Sunucu `adminConfig/runtime` (bayraklar + platform içeriği).
/// Admin paneli yazar; tüketici salt okur (rules: public read).
class AppRuntimeConfig {
  const AppRuntimeConfig({
    this.premiumFreeDuringBeta = AppConstants.premiumFreeDuringBeta,
    this.paidProvinces = const [],
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

  /// ÜCRETLİ döneme geçmiş iller (2026-08-23).
  ///
  /// Şehir bazlı geçişin anahtarı. Boşken davranış bugünküyle BİREBİR
  /// aynıdır — [premiumFreeDuringBeta] tek başına karar verir.
  ///
  /// Bir il bu listeye eklendiği an, o ilde çalışan ve aktif aboneliği
  /// olmayan kullanıcının müsaitliği düşer. Liste dışındaki iller beta'da
  /// kalmaya devam eder.
  ///
  /// GERİ ALINABİLİR: il listeden çıkarılınca herkes eski hâline
  /// kendiliğinden döner — kapı hiçbir veri yazmaz, yalnız okur.
  final List<String> paidProvinces;

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
      // Bozuk/eksik değer BOŞ listeye düşer: yanlış bir il adı yüzünden
      // kimsenin müsaitliği kapanmamalı (güvenli varsayılan).
      // `as List?` DEĞİL: yanlış tipte bir değer (ör. düz String) cast
      // hatası atar ve TÜM yapılandırma okunamaz hâle gelirdi — tek bir
      // hatalı alan yüzünden bakım modu, sürüm kapısı, duyuru da düşerdi.
      paidProvinces: _ilListesi(map['paidProvinces']),
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

/// Bir KULLANICI için premium ücretsiz mi? — il farkındalıklı (2026-08-23).
///
/// Şehir bazlı geçişin tek karar noktası. `bool premiumFreeDuringBeta`
/// yerine bunu kullanan taraf, kullanıcının ilini de hesaba katar.
///
/// ── KARAR SIRASI ──
///
/// 1. Beta bayrağı KAPALIYSA → hiç kimse ücretsiz değil (eski davranış).
/// 2. Kullanıcının ili ÜCRETLİ listesindeyse → ücretsiz değil.
/// 3. Aksi hâlde ücretsiz.
///
/// [userProvinces] boşsa (bölgesiz profil, misafir) kullanıcı hiçbir ilin
/// kapsamına girmez ve beta bayrağı ne diyorsa o geçerlidir. Bölgesiz
/// kullanıcıyı ücretliye almak yanlış olurdu: hangi ile ait olduğu bilinmiyor.
///
/// GERİ ALINABİLİR: il listeden çıkınca fonksiyon eski cevabı vermeye başlar
/// ve herkes kendiliğinden eski hâline döner — hiçbir veri yazılmaz.
bool premiumFreeForUser({
  required List<String> userProvinces,
  bool? premiumFreeDuringBeta,
  List<String> paidProvinces = const [],
}) {
  final free = premiumFreeDuringBeta ?? AppConstants.premiumFreeDuringBeta;
  if (!free) return false;
  if (paidProvinces.isEmpty || userProvinces.isEmpty) return free;

  // Karşılaştırma kırpılmış ve büyük/küçük harfe duyarsız: admin panelinden
  // " bursa" yazılması yüzünden geçiş sessizce çalışmamamalı.
  final ucretli = paidProvinces
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  for (final il in userProvinces) {
    if (ucretli.contains(il.trim().toLowerCase())) return false;
  }
  return true;
}

/// `paidProvinces` alanını GÜVENLİ okur.
///
/// Liste değilse (ör. elle düz String yazılmışsa) BOŞ liste döner: yanlış
/// bir değer yüzünden ne kimsenin müsaitliği kapanmalı ne de tüm
/// yapılandırma okunamaz hâle gelmeli.
List<String> _ilListesi(Object? v) {
  if (v is! List) return const [];
  return v
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

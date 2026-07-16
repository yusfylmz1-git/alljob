import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../config/backend_config.dart';

/// İnce Analytics sarmalayıcı (YOL_HARITASI P1).
///
/// Mock backend / hata → sessiz no-op. Olay adları snake_case (GA4).
class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? get _fa {
    if (!useFirebaseBackend) return null;
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> log(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics log ($name): $e');
    }
  }

  static Future<void> login({required String method}) =>
      log('login', {'method': method});

  static Future<void> signUp({required String method}) =>
      log('sign_up', {'method': method});

  static Future<void> createJob({String? category}) => log(
        'create_job',
        {if (category != null && category.isNotEmpty) 'category': category},
      );

  static Future<void> becomeArtisan() => log('become_artisan');

  static Future<void> sendOffer() => log('send_offer');

  static Future<void> packageSelected({required String package}) =>
      log('package_selected', {'package': package});

  /// Vitrin funnel CTA (Hizmetlerim / Profil banner).
  static Future<void> shopCompletionCta({
    String? step,
    int? percent,
  }) =>
      log('shop_completion_cta', {
        if (step != null && step.isNotEmpty) 'step': step,
        'percent': ?percent,
      });
}


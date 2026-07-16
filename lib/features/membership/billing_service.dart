import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../artisan/application/my_profile_controller.dart';
import 'billing_config.dart';
import 'membership_package.dart';

/// Play Billing sarmalayıcı. [kBillingEnabled] false iken no-op / bilgilendirme.
///
/// Akış: buy → purchaseStream → CF `verifyMembershipPurchase` →
/// `artisanProfiles.isPremium` (sunucu) + yerel plan = Pro.
class BillingService {
  BillingService(this._ref);

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _ready = false;
  List<ProductDetails> _products = const [];

  List<ProductDetails> get products => _products;
  bool get isReady => _ready && kBillingEnabled;

  Future<void> init() async {
    if (!kBillingEnabled || kIsWeb) return;
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('BillingService: mağaza kullanılamıyor');
      return;
    }
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Billing purchaseStream: $e'),
    );
    final resp = await _iap.queryProductDetails(kKnownSubscriptionIds);
    if (resp.error != null) {
      debugPrint('Billing query error: ${resp.error}');
    }
    if (resp.notFoundIDs.isNotEmpty) {
      debugPrint('Billing not found: ${resp.notFoundIDs}');
    }
    _products = resp.productDetails;
    _ready = true;
  }

  ProductDetails? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Pro aylık abonelik başlat. false = başlatılamadı.
  Future<bool> buyProMonthly() async {
    if (!kBillingEnabled || kIsWeb) return false;
    if (!_ready) await init();
    final product = productById(kProMonthlyProductId);
    if (product == null) {
      debugPrint('Billing: ürün yok ($kProMonthlyProductId)');
      return false;
    }
    // Abonelik ürünleri de plugin tarafında buyNonConsumable ile alınır.
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) continue;
      if (p.status == PurchaseStatus.error) {
        debugPrint('Billing error: ${p.error}');
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
        continue;
      }
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final ok = await _verifyOnServer(p);
        if (ok) {
          _ref.read(selectedMembershipPackageProvider.notifier).state =
              MembershipPackage.pro;
          await saveMembershipPackage(MembershipPackage.pro);
          // Sunucunun yazdığı isPremium/premiumExpiresAt'i yeniden yükle.
          _ref.invalidate(myProfileControllerProvider);
        }
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }
    }
  }

  Future<bool> _verifyOnServer(PurchaseDetails p) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('verifyMembershipPurchase');
      final res = await callable.call<Map<String, dynamic>>({
        'productId': p.productID,
        'purchaseToken': p.verificationData.serverVerificationData,
        'source': p.verificationData.source,
      });
      final data = res.data;
      return data['ok'] == true;
    } catch (e) {
      debugPrint('verifyMembershipPurchase: $e');
      // Üretimde sunucu doğrulaması zorunlu — istemci premium VERMEZ.
      // (Eski kDebugMode bypass kaldırıldı: sahte Pro riski.)
      return false;
    }
  }

  Future<void> restore() async {
    if (!kBillingEnabled || kIsWeb) return;
    await _iap.restorePurchases();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

final billingServiceProvider = Provider<BillingService>((ref) {
  final s = BillingService(ref);
  ref.onDispose(s.dispose);
  // Arka planda ısıt (web/no-op).
  unawaited(s.init());
  return s;
});

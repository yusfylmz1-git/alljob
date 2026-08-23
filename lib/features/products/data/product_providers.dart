import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/product.dart';
import '../../artisan/data/artisan_providers.dart' show mockDatabaseProvider;
import '../../auth/application/auth_controller.dart'
    show currentUserProvider, publicUserProvider;
import 'firebase_product_repository.dart';
import 'mock_product_repository.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  if (useFirebaseBackend) return FirebaseProductRepository();
  return MockProductRepository(ref.watch(mockDatabaseProvider));
});

/// Mağaza ürün vitrini açık mı? Yerel hard-off + remote `productsEnabled`.
///
/// Config henüz yüklenmediyse yerel sabite düşer (varsayılan: açık).
final productsLiveProvider = Provider<bool>((ref) {
  final remote = ref.watch(appRuntimeConfigProvider).valueOrNull;
  if (remote != null) return remote.isProductsLive;
  return AppConstants.kProductsEnabled;
});

final discoverProductsProvider = StreamProvider<List<Product>>((ref) {
  if (!ref.watch(productsLiveProvider)) {
    return Stream.value(const <Product>[]);
  }
  return ref.watch(productRepositoryProvider).watchDiscoverProducts(
        limit: AppConstants.productDiscoverFetchCap,
      );
});

/// Keşfet ürünleri, **müsait olmayan satıcılar elenmiş** hâli
/// (2026-08-14 ürün kararı).
///
/// Neden gerekli: müsait olmayan satıcı ürün taleplerine mesaj atamıyor
/// (`availability_gate.dart`) ve mağaza vitrini de profilinde gizleniyor
/// (`dukkan_bolumu.dart`). Ürünleri Keşfet'te durmaya devam ederse müşteri
/// ilgilenip yazamayan bir satıcıya düşer — ölü ilan etkisi.
///
/// **Maliyet:** ürün başına değil, **benzersiz satıcı** başına bir okuma.
/// 48 ürün tipik olarak ~10 satıcıya aittir ve `publicUserProvider`
/// önbelleklidir; aynı satıcı ikinci kez okunmaz.
///
/// Satıcı bilgisi henüz yüklenmediyse ürün **gösterilir** — yükleme
/// sırasında vitrinin boşalıp dolması titreme yaratırdı. Gelen veri
/// "müsait değil" derse ürün o an listeden düşer.
final availableDiscoverProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(discoverProductsProvider).valueOrNull;
  if (products == null || products.isEmpty) return const [];

  final me = ref.watch(currentUserProvider)?.uid;
  final sonuc = <Product>[];
  for (final p in products) {
    // Sahibi kendi ürününü her zaman görür (kaybolduğunu sanmasın).
    if (p.ownerUid == me) {
      sonuc.add(p);
      continue;
    }
    final satici = ref.watch(publicUserProvider(p.ownerUid)).valueOrNull;
    // Henüz yüklenmedi → göster (titreme olmasın).
    //
    // NOT (2026-08-23): burada `users.available` bayrağı okunuyor, premium
    // kapısı DEĞİL. Bu bayrağı satıcının kendi cihazı yazar ve o cihazdaki
    // kapı (`artisanIsAvailableProvider`) artık il farkında. Yani şehir
    // geçişinde satıcı uygulamayı açtığında bayrak düşer ve ürünler bir
    // sonraki okumada gizlenir — ama satıcı hiç açmazsa bayrak açık kalır.
    //
    // Kalıcı çözüm ürün sorgusunun sahibin ilini de okuması; şimdilik
    // toplu plan ekranı (`pauseAvailability`) bu boşluğu kapatabiliyor.
    if (satici == null || satici.available) sonuc.add(p);
  }
  return sonuc;
});

/// Sahibin KENDİ ürünleri — taslak, duraklatılmış, satılmış dâhil.
/// Yalnızca "Ürünlerim" ekranında kullanılır.
final myProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, ownerUid) {
  return ref.watch(productRepositoryProvider).watchMyProducts(ownerUid);
});

/// Bir kullanıcının BAŞKASINA görünen vitrini — yalnız yayındakiler.
///
/// `myProductsProvider` durum filtresi uygulamaz; başkasının profilinde
/// onu kullanmak taslak ve satılmış ürünleri sızdırırdı. Moderasyonla
/// gizlenmişler de elenir.
/// Ölçüt `Product.isLiveInDiscover` — Keşfet feed'iyle AYNI kural
/// (`active` && `!moderationHidden`). İkisi ayrışırsa profilde görünüp
/// Keşfet'te görünmeyen (veya tersi) ürünler doğar.
final publicProductsProvider =
    StreamProvider.family<List<Product>, String>((ref, ownerUid) {
  return ref
      .watch(productRepositoryProvider)
      .watchMyProducts(ownerUid)
      .map((list) => list.where((p) => p.isLiveInDiscover).toList());
});

final productProvider =
    StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});

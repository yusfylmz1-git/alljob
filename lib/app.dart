import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/globals.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_accent.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_state.dart';
import 'data/models/app_user.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/notifications/data/push_service.dart';
import 'features/tracking/data/track_notification_service.dart';

class UstaCepteApp extends ConsumerWidget {
  const UstaCepteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Oturum durumu değiştikçe FCM token'ını kaydet: kullanıcı giriş yapınca
    // bu cihazın token'ı `users/{uid}.fcmTokens` dizisine eklenir. (Çıkışta
    // çıkarma işlemi AuthController.signOut içinde, uid kaybolmadan yapılır.)
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
      final uid = next.valueOrNull?.uid;
      if (uid != null && prev?.valueOrNull?.uid != uid) {
        ref.read(pushServiceProvider).registerFor(uid);
      }
    });
    // Uygulama açılırken zaten oturum açıksa (listener henüz tetiklenmez) ilk
    // token kaydını burada yap.
    final initialUid = ref.read(authStateProvider).valueOrNull?.uid;
    if (initialUid != null) {
      ref.read(pushServiceProvider).registerFor(initialUid);
    }

    // Takip Merkezi hatırlatma servisini hazırla (idempotent; web/test no-op) —
    // böylece bildirime dokununca ilgili takibe gitme işleyicisi hazır olur.
    ref.read(trackNotificationServiceProvider).init();

    // Aktif moda göre vurgu rengi: müşteri/misafir → tatlı mavi, usta → zümrüt
    // yeşili. Mod değişince tema yeniden kurulur ve renkler yumuşakça geçer.
    final artisanMode =
        ref.watch(currentUserProvider.select((u) => u?.isArtisan ?? false));

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(
          AppAccent.resolve(artisan: artisanMode, isDark: false)),
      darkTheme: AppTheme.dark(
          AppAccent.resolve(artisan: artisanMode, isDark: true)),
      // Kullanıcı tercihi (Sistem/Açık/Koyu) — menüden değiştirilir, cihazda
      // saklanır (theme_mode_state.dart).
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}

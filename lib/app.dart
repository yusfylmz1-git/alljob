import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_version.dart';
import 'core/constants/app_constants.dart';
import 'core/globals.dart';
import 'core/router/app_router.dart';
import 'core/router/route_paths.dart';
import 'core/theme/accent_options.dart';
import 'core/theme/accent_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_state.dart';
import 'core/widgets/offline_banner.dart';
import 'core/widgets/status_views.dart';
import 'data/models/app_user.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/notifications/data/push_service.dart';

/// ErrorView "Sorunu bildir": Yardım ekranındaki destek formunu, hatanın
/// bağlamı önceden yazılmış olarak açar (form yönetim paneline düşer, yanıt
/// bildirim olarak gelir). Girişsiz kullanıcıyı Yardım ekranı zaten girişe
/// yönlendirir.
void _openErrorReport(BuildContext context, String summary) {
  final konu = Uri.encodeComponent('Uygulama hata bildirimi');
  final detay = Uri.encodeComponent(
    'Karşılaşılan durum: $summary\n'
    'Uygulama sürümü: $kClientVersion\n\n'
    'Sorunu yaşadığınız anı kısaca anlatır mısınız? '
    '(Hangi ekrandaydınız, ne yapmak istediniz?)',
  );
  GoRouter.of(context).push('${RoutePaths.help}?konu=$konu&detay=$detay');
}

class SepetteHizmetApp extends ConsumerWidget {
  const SepetteHizmetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Oturum durumu değiştikçe FCM token'ını kaydet: kullanıcı giriş yapınca
    // bu cihazın token'ı `users/{uid}/private/push.fcmTokens` dizisine eklenir.
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

    // Tek vurgu rengi (Görünüm → Renk); açık/koyu temadan bağımsız.
    final accentId = ref.watch(accentIdProvider);
    final accent = accentById(accentId, fallbackId: kDefaultAccentId);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(accent.light),
      darkTheme: AppTheme.dark(accent.dark),
      // Kullanıcı tercihi (Sistem/Açık/Koyu) — menüden değiştirilir, cihazda
      // saklanır (theme_mode_state.dart).
      themeMode: ref.watch(themeModeProvider),
      // Takvim / saat seçici / Material metinleri Türkçe.
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Global kabuk: boş alana dokununca klavye kapansın + çevrimdışı şerit
      // + ErrorView "Sorunu bildir".
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // Boş alana basınca da yakala (klavye kapansın).
        behavior: HitTestBehavior.translucent,
        child: ErrorReportScope(
          onReport: _openErrorReport,
          child: OfflineBannerHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

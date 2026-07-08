import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../features/artisan/presentation/artisan_home_screen.dart';
import '../../features/artisan/presentation/artisan_notifications_screen.dart';
import '../../features/artisan/presentation/artisan_profile_edit_screen.dart';
import '../../features/artisan/presentation/premium_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/customer/presentation/artisan_profile_screen.dart';
import '../../features/customer/presentation/customer_dashboard_screen.dart';
import '../../features/customer/presentation/customer_profile_screen.dart';
import '../../features/jobs/presentation/create_job_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/jobs/presentation/my_jobs_screen.dart';
import '../../features/jobs/presentation/my_offers_screen.dart';
import '../../features/jobs/presentation/nearby_jobs_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import 'route_paths.dart';

/// Uygulama yönlendiricisi. "Misafir-önce" akış + tek hesap, çift rol:
/// - Herkes (giriş yapmadan) keşif ekranını ve usta profillerini görebilir.
/// - Ustayla iletişim / değerlendirme için giriş gerekir.
/// - Usta paneli yalnızca usta profili açmış (hasArtisanProfile) hesaplara
///   açıktır; arayüz aktif moda (Müşteri/Usta) göre şekillenir.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // Oturum durumu çözülene kadar splash'te bekle.
      if (authState.isLoading) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final AppUser? user = authState.valueOrNull;
      final inArtisanMode = user?.isArtisan ?? false; // aktif arayüz modu
      final onAuthFlow =
          loc == RoutePaths.login || loc == RoutePaths.register;

      // Splash çözüldü → aktif moda uygun ana ekrana geç.
      if (loc == RoutePaths.splash) {
        if (user == null) return RoutePaths.home;
        return inArtisanMode ? RoutePaths.panel : RoutePaths.home;
      }

      // Oturum gerektiren bölgeler.
      final needsLogin = loc.startsWith(RoutePaths.panel) ||
          loc.startsWith(RoutePaths.chats) ||
          loc.startsWith(RoutePaths.reviewBase) ||
          loc.startsWith(RoutePaths.jobsBase) ||
          loc.startsWith(RoutePaths.favorites) ||
          loc.startsWith(RoutePaths.profile);

      // Misafir: keşif + profilleri gezebilir; korunan bölgeler girişe yönlenir.
      if (user == null) {
        if (needsLogin) return RoutePaths.login;
        return null;
      }

      // Oturum açmışken auth ekranları → aktif modun ana ekranına.
      if (onAuthFlow) {
        return inArtisanMode ? RoutePaths.panel : RoutePaths.home;
      }

      // Usta paneli yalnızca usta profili açmış hesaplara açıktır. Diğer tüm
      // gezinme serbesttir — UI zaten aktif moda göre menüleri gösterir.
      if (loc.startsWith(RoutePaths.panel) && !user.hasArtisanProfile) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (_, _) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: '/artisan/:uid',
        builder: (_, state) =>
            ArtisanProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.panel,
        builder: (_, _) => const ArtisanHomeScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, _) => const ArtisanProfileEditScreen(),
          ),
          GoRoute(
            path: 'jobs',
            builder: (_, _) => const NearbyJobsScreen(),
          ),
          GoRoute(
            path: 'offers',
            builder: (_, _) => const MyOffersScreen(),
          ),
          GoRoute(
            path: 'premium',
            builder: (_, _) => const PremiumScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const ArtisanNotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.chats,
        builder: (_, _) => const ChatListScreen(),
        routes: [
          GoRoute(
            path: ':chatId',
            builder: (_, state) =>
                ChatScreen(chatId: state.pathParameters['chatId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/review/:uid',
        builder: (_, state) => ReviewScreen(
          artisanUid: state.pathParameters['uid']!,
          jobId: state.uri.queryParameters['jobId'],
        ),
      ),
      // İş ilanları — sıralama önemli: /jobs/new ve /jobs/mine, /jobs/:jobId'den
      // ÖNCE tanımlanmalıdır (aksi halde :jobId onları da yakalar).
      GoRoute(
        path: RoutePaths.newJob,
        builder: (_, _) => const CreateJobScreen(),
      ),
      GoRoute(
        path: RoutePaths.myJobs,
        builder: (_, _) => const MyJobsScreen(),
      ),
      GoRoute(
        path: '/jobs/:jobId',
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['jobId']!),
      ),
      GoRoute(
        path: RoutePaths.favorites,
        builder: (_, _) => const FavoritesScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, _) => const CustomerProfileScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
    ),
  );
});

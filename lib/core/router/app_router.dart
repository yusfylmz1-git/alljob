import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
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
import '../../features/jobs/presentation/create_job_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/jobs/presentation/my_jobs_screen.dart';
import '../../features/jobs/presentation/my_offers_screen.dart';
import '../../features/jobs/presentation/nearby_jobs_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/onboarding/onboarding_state.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/review/presentation/review_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/safety/presentation/blocked_users_screen.dart';
import '../../features/tracking/presentation/track_detail_screen.dart';
import '../../features/tracking/presentation/track_edit_screen.dart';
import '../../features/tracking/presentation/tracking_center_screen.dart';
import '../../features/tracking/presentation/track_backup_screen.dart';
import '../../features/tracking/presentation/tracking_trash_screen.dart';
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
      final onAuthFlow =
          loc == RoutePaths.login || loc == RoutePaths.register;

      // İlk açılış: onboarding görülmemişse tanıtım akışı.
      // (Varsayılan "görüldü"; gerçek değer main.dart override'ı ile gelir.)
      final seenOnboarding = ref.read(onboardingSeenProvider);

      // Splash çözüldü → herkes Keşfet'te başlar (tek tutarlı giriş noktası;
      // usta kendi alanına alt bardaki Profil sekmesinden ulaşır). Onboarding
      // gerekiyorsa aşağıdaki genel kural home'dan tanıtıma yönlendirir.
      if (loc == RoutePaths.splash) return RoutePaths.home;

      // Onboarding cihazda BİR KEZ, oturumdan bağımsız gösterilir: yalnız
      // "oturum yok + splash" koşulu, oturumu açık kalan cihazlarda ve
      // kayıt-sonrası akışta tanıtımı HİÇ göstermiyordu (kullanıcı bildirimi).
      if (!seenOnboarding) {
        return loc == RoutePaths.onboarding ? null : RoutePaths.onboarding;
      }
      if (loc == RoutePaths.onboarding) return RoutePaths.home;

      // Eski usta paneli ana sayfası → birleşik profil sayfası.
      if (loc == RoutePaths.panel) return RoutePaths.profile;

      // Oturum gerektiren bölgeler.
      final needsLogin = loc.startsWith(RoutePaths.panel) ||
          loc.startsWith(RoutePaths.chats) ||
          loc.startsWith(RoutePaths.reviewBase) ||
          loc.startsWith(RoutePaths.jobsBase) ||
          loc.startsWith(RoutePaths.favorites) ||
          loc.startsWith(RoutePaths.notifications) ||
          loc.startsWith(RoutePaths.tracking) ||
          loc.startsWith('/admin') ||
          loc.startsWith(RoutePaths.profile);

      // Misafir: keşif + profilleri gezebilir; korunan bölgeler girişe yönlenir.
      if (user == null) {
        if (needsLogin) return RoutePaths.login;
        return null;
      }

      // Oturum açmışken auth ekranları → ana ekrana.
      if (onAuthFlow) return RoutePaths.home;

      // Usta paneli yalnızca usta profili açmış hesaplara açıktır. Diğer tüm
      // gezinme serbesttir — UI zaten aktif moda göre menüleri gösterir.
      if (loc.startsWith(RoutePaths.panel) && !user.hasArtisanProfile) {
        return RoutePaths.home;
      }
      // Yönetici paneli yalnızca admin claim'i olan hesaplara. (Asıl koruma
      // Firestore kuralında; bu, yetkisizin ekranı hiç görmemesi içindir.)
      if (loc.startsWith('/admin') && !user.isAdmin) {
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
        path: RoutePaths.onboarding,
        builder: (_, _) => const OnboardingScreen(),
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
        // Eski panel ana sayfası birleşik profile taşındı (global redirect
        // /panel'i /profile'a çevirir); builder yalnızca alt rotalar için
        // ebeveyn olarak durur.
        builder: (_, _) => const ProfileScreen(),
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
            // Eski bağlantılar için: birleşik bildirim merkezine gider.
            builder: (_, _) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (_, _) => const NotificationsScreen(),
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
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'blocked',
            builder: (_, _) => const BlockedUsersScreen(),
          ),
        ],
      ),
      // Takip Merkezi — sıralama önemli: /tracking/new ve /tracking/trash,
      // /tracking/:id'den ÖNCE tanımlanmalı (aksi halde :id onları yakalar).
      GoRoute(
        path: RoutePaths.trackingNew,
        builder: (_, _) => const TrackEditScreen(),
      ),
      GoRoute(
        path: RoutePaths.trackingTrash,
        builder: (_, _) => const TrackingTrashScreen(),
      ),
      GoRoute(
        path: RoutePaths.trackingBackup,
        builder: (_, _) => const TrackBackupScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminReports,
        builder: (_, _) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: RoutePaths.tracking,
        builder: (_, _) => const TrackingCenterScreen(),
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (_, state) =>
            TrackDetailScreen(trackId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                TrackEditScreen(trackId: state.pathParameters['id']),
          ),
        ],
      ),
      // Yasal metinler — misafir dâhil herkese açık (kayıt onayındaki
      // linkler ve Profil → Yasal Metinler buraya gelir).
      GoRoute(
        path: RoutePaths.legal,
        builder: (_, _) => const LegalHubScreen(),
        routes: [
          GoRoute(
            path: ':doc',
            builder: (_, state) =>
                LegalDocScreen(docId: state.pathParameters['doc']!),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
    ),
  );
});

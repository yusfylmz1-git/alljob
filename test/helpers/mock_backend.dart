import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_providers.dart';
import 'package:sepette_hizmet/features/artisan/data/mock_artisan_repository.dart';
import 'package:sepette_hizmet/features/artisan/data/my_profile_repository.dart';
import 'package:sepette_hizmet/features/auth/application/auth_controller.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';
import 'package:sepette_hizmet/features/chat/data/chat_providers.dart';
import 'package:sepette_hizmet/features/chat/data/chat_repository.dart';
import 'package:sepette_hizmet/features/favorites/data/favorite_providers.dart';
import 'package:sepette_hizmet/features/favorites/data/mock_favorite_repository.dart';
import 'package:sepette_hizmet/features/jobs/data/job_providers.dart';
import 'package:sepette_hizmet/features/jobs/data/mock_job_repository.dart';
import 'package:sepette_hizmet/features/products/data/mock_product_repository.dart';
import 'package:sepette_hizmet/features/products/data/product_providers.dart';
import 'package:sepette_hizmet/features/safety/data/block_repository.dart';
import 'package:sepette_hizmet/features/safety/data/report_repository.dart';
import 'package:sepette_hizmet/features/safety/data/safety_providers.dart';
import 'package:sepette_hizmet/features/storage/storage_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_artisan_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_audit_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_invite_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_job_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_providers.dart';
import 'package:sepette_hizmet/features/admin/data/admin_report_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_review_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_stats_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_user_repository.dart';

/// Tüm backend repo sağlayıcılarını bellek-içi mock uygulamalara yönlendirir.
///
/// Uygulama `useFirebaseBackend = true` ile derlenir; testler Firebase'e
/// erişemeyeceğinden (başlatılmamış) bu override'lar olmadan gerçek Firebase
/// repo'ları çağrılıp çöker. Bu liste ile testler tamamen mock üzerinde koşar.
List<Override> mockBackendOverrides() => [
      authRepositoryProvider.overrideWith((ref) {
        final repo = MockAuthRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      artisanRepositoryProvider.overrideWith(
        (ref) => MockArtisanRepository(ref.watch(mockDatabaseProvider)),
      ),
      chatRepositoryProvider.overrideWith((ref) {
        final repo = MockChatRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      favoriteRepositoryProvider.overrideWith(
        (ref) => MockFavoriteRepository(ref.watch(mockDatabaseProvider)),
      ),
      jobRepositoryProvider.overrideWith(
        (ref) => MockJobRepository(ref.watch(mockDatabaseProvider)),
      ),
      productRepositoryProvider.overrideWith(
        (ref) => MockProductRepository(ref.watch(mockDatabaseProvider)),
      ),
      myProfileRepositoryProvider.overrideWith(
        (ref) => MockMyProfileRepository(ref),
      ),
      storageRepositoryProvider.overrideWith(
        (ref) => MockStorageRepository(),
      ),
      blockRepositoryProvider.overrideWith((ref) {
        final repo = MockBlockRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      reportRepositoryProvider.overrideWith(
        (ref) => MockReportRepository(),
      ),
      adminReportRepositoryProvider.overrideWith((ref) {
        final repo = MockAdminReportRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      adminUserRepositoryProvider.overrideWith((ref) {
        final repo = MockAdminUserRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      adminJobRepositoryProvider.overrideWith(
        (ref) => MockAdminJobRepository(),
      ),
      adminArtisanRepositoryProvider.overrideWith(
        (ref) => MockAdminArtisanRepository(),
      ),
      adminInviteRepositoryProvider.overrideWith((ref) {
        final repo = MockAdminInviteRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      adminStatsRepositoryProvider.overrideWith(
        (ref) => MockAdminStatsRepository(),
      ),
      adminReviewRepositoryProvider.overrideWith(
        (ref) => MockAdminReviewRepository(),
      ),
      adminAuditRepositoryProvider.overrideWith(
        (ref) => MockAdminAuditRepository(),
      ),
    ];

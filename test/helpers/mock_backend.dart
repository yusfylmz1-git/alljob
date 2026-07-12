import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usta_cepte/features/artisan/data/artisan_providers.dart';
import 'package:usta_cepte/features/artisan/data/mock_artisan_repository.dart';
import 'package:usta_cepte/features/artisan/data/my_profile_repository.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/auth/data/mock_auth_repository.dart';
import 'package:usta_cepte/features/chat/data/chat_providers.dart';
import 'package:usta_cepte/features/chat/data/chat_repository.dart';
import 'package:usta_cepte/features/favorites/data/favorite_providers.dart';
import 'package:usta_cepte/features/favorites/data/mock_favorite_repository.dart';
import 'package:usta_cepte/features/jobs/data/job_providers.dart';
import 'package:usta_cepte/features/jobs/data/mock_job_repository.dart';
import 'package:usta_cepte/features/jobs/data/mock_offer_repository.dart';
import 'package:usta_cepte/features/safety/data/block_repository.dart';
import 'package:usta_cepte/features/safety/data/report_repository.dart';
import 'package:usta_cepte/features/safety/data/safety_providers.dart';
import 'package:usta_cepte/features/storage/storage_repository.dart';
import 'package:usta_cepte/features/tracking/data/mock_tracking_repository.dart';
import 'package:usta_cepte/features/tracking/data/track_notification_service.dart';
import 'package:usta_cepte/features/tracking/data/tracking_providers.dart';

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
      offerRepositoryProvider.overrideWith(
        (ref) => MockOfferRepository(ref.watch(mockDatabaseProvider)),
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
      trackingRepositoryProvider.overrideWith((ref) {
        final repo = MockTrackingRepository();
        ref.onDispose(repo.dispose);
        return repo;
      }),
      // Bildirimler native eklenti gerektirir → testlerde no-op.
      trackNotificationServiceProvider
          .overrideWithValue(const NoopTrackNotificationService()),
    ];

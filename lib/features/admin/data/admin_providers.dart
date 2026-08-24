import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/job.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_category.dart';
import '../../auth/application/auth_controller.dart';
import 'admin_artisan_repository.dart';
import 'admin_audit_repository.dart';
import 'admin_capabilities.dart';
import 'admin_invite_repository.dart';
import 'admin_job_repository.dart';
import 'admin_product_repository.dart';
import 'admin_report.dart';
import 'admin_report_repository.dart';
import 'admin_review_repository.dart';
import 'admin_runtime_config_repository.dart';
import 'admin_daily_stats_repository.dart';
import 'admin_insights_repository.dart';
import 'admin_stats_repository.dart';
import 'admin_support_repository.dart';
import 'admin_user_repository.dart';
import 'paged_queue.dart';

/// Oturumdaki kullanıcı yönetici mi? (Auth custom claim'inden.)
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider.select((u) => u?.isAdmin ?? false));
});

/// Oturumdaki kullanıcı SÜPER yönetici mi? (RBAC: yalnız superadmin başka
/// kullanıcılara rol atayabilir.)
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider.select((u) => u?.isSuperAdmin ?? false));
});

final adminReportRepositoryProvider = Provider<AdminReportRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminReportRepository();
  final repo = MockAdminReportRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Şikayet kuyruğu (tüm kayıtlar, en yeni üstte). Yalnız yönetici için akar;
/// yönetici değilse boş (kural zaten okumayı reddeder — istemci de guard eder).
final adminReportsProvider = StreamProvider<List<Report>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const <Report>[]);
  return ref.watch(adminReportRepositoryProvider).watchReports();
});

/// Açık (çözülmemiş) şikayet sayısı — menü rozeti için (canlı stream).
final openReportCountProvider = Provider<int>((ref) {
  final list = ref.watch(adminReportsProvider).valueOrNull ?? const [];
  return list.where((r) => !r.status.isClosed).length;
});

/// Şikayet kuyruğu liste controller'ı (cursor sayfalama). Rozet için canlı
/// stream ayrı ([openReportCountProvider]); bu yalnız listenin sayfalanmasıdır.
final reportQueueControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<Report>,
      AsyncValue<PagedData<Report>>
    >((ref) {
      final repo = ref.watch(adminReportRepositoryProvider);
      return PagedController<Report>(
        fetch: ({beforeCursor, limit = 30}) =>
            repo.fetchPage(beforeCursor: beforeCursor, limit: limit),
        cursorOf: (r) => r.createdAt.toIso8601String(),
      );
    });

// Hakemlik (anlaşmazlık) kuyruğu KALDIRILDI — `JobStatus.disputed` diye bir
// durum artık yok. Kullanıcı şikayeti `reports` koleksiyonundan akıyor
// (AdminReportsScreen), ilan üstünden değil.

final adminUserRepositoryProvider = Provider<AdminUserRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminUserRepository();
  final repo = MockAdminUserRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Kullanıcı dizini filtresi (shell ekranı).
final userDirectoryFilterProvider =
    StateProvider.autoDispose<AdminUserListFilter>(
      (ref) => AdminUserListFilter.all,
    );

/// Kullanıcı dizini İL filtresi (2026-08-23).
///
/// Ayrı bir provider: diğer filtrelerle BİRLEŞMEZ. Her kombinasyon ayrı
/// bileşik indeks isterdi; il seçiliyken rol/askı filtresi yok sayılır.
final userDirectoryProvinceProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Sayfalı kullanıcı dizini.
final userDirectoryControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<AppUser>,
      AsyncValue<PagedData<AppUser>>
    >((ref) {
      final repo = ref.watch(adminUserRepositoryProvider);
      final filter = ref.watch(userDirectoryFilterProvider);
      final province = ref.watch(userDirectoryProvinceProvider);
      return PagedController<AppUser>(
        fetch: ({beforeCursor, limit = 30}) => repo.fetchPage(
          beforeCursor: beforeCursor,
          limit: limit,
          filter: filter,
          province: province,
        ),
        cursorOf: (u) => u.createdAt.toUtc().toIso8601String(),
      );
    });

final adminJobRepositoryProvider = Provider<AdminJobRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminJobRepository();
  return MockAdminJobRepository();
});

/// İlan listesi: durum filtresi (null = hepsi). Province ayrı provider.
final jobDirectoryStatusFilterProvider = StateProvider.autoDispose<JobStatus?>(
  (ref) => null,
);

final jobDirectoryProvinceFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final jobDirectoryControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<Job>,
      AsyncValue<PagedData<Job>>
    >((ref) {
      final repo = ref.watch(adminJobRepositoryProvider);
      final status = ref.watch(jobDirectoryStatusFilterProvider);
      final province = ref.watch(jobDirectoryProvinceFilterProvider);
      return PagedController<Job>(
        fetch: ({beforeCursor, limit = 30}) => repo.fetchPage(
          beforeCursor: beforeCursor,
          limit: limit,
          // Tek equality: status seçiliyse province yok sayılır (repo kuralı).
          status: status,
          province: status == null ? province : null,
        ),
        cursorOf: (j) => j.createdAt.toUtc().toIso8601String(),
      );
    });

// ── Mağaza ürün kuyruğu ──
final adminProductRepositoryProvider = Provider<AdminProductRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminProductRepository();
  return MockAdminProductRepository();
});

/// Varsayılan: inceleme kuyruğu (pending_review).
final productDirectoryFilterProvider =
    StateProvider.autoDispose<AdminProductListFilter>(
  (ref) => AdminProductListFilter.pendingReview,
);

final productDirectoryControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<Product>,
      AsyncValue<PagedData<Product>>
    >((ref) {
      final repo = ref.watch(adminProductRepositoryProvider);
      final filter = ref.watch(productDirectoryFilterProvider);
      return PagedController<Product>(
        fetch: ({beforeCursor, limit = 30}) => repo.fetchPage(
          beforeCursor: beforeCursor,
          limit: limit,
          filter: filter,
        ),
        cursorOf: (p) => p.createdAt.toUtc().toIso8601String(),
      );
    });

final adminArtisanRepositoryProvider = Provider<AdminArtisanRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminArtisanRepository();
  return MockAdminArtisanRepository();
});

final artisanDirectoryProfessionFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final artisanDirectoryVerifiedFilterProvider = StateProvider.autoDispose<bool?>(
  (ref) => null,
);

final artisanDirectoryControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<AdminArtisanListItem>,
      AsyncValue<PagedData<AdminArtisanListItem>>
    >((ref) {
      final repo = ref.watch(adminArtisanRepositoryProvider);
      final profession = ref.watch(artisanDirectoryProfessionFilterProvider);
      final verified = ref.watch(artisanDirectoryVerifiedFilterProvider);
      return PagedController<AdminArtisanListItem>(
        fetch: ({beforeCursor, limit = 30}) => repo.fetchPage(
          beforeCursor: beforeCursor,
          limit: limit,
          profession: profession,
          isVerified: (profession == null || profession.isEmpty)
              ? verified
              : null,
        ),
        cursorOf: (a) => a.profile.createdAt.toUtc().toIso8601String(),
      );
    });

final adminReviewRepositoryProvider = Provider<AdminReviewRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminReviewRepository();
  return MockAdminReviewRepository();
});

final reviewDirectoryControllerProvider =
    StateNotifierProvider.autoDispose<
      PagedController<AdminReview>,
      AsyncValue<PagedData<AdminReview>>
    >((ref) {
      final repo = ref.watch(adminReviewRepositoryProvider);
      return PagedController<AdminReview>(
        fetch: ({beforeCursor, limit = 30}) =>
            repo.fetchPage(beforeCursor: beforeCursor, limit: limit),
        cursorOf: (r) => r.review.createdAt.toUtc().toIso8601String(),
      );
    });

/// Yönetici kadrosu (rol sahipleri). Yalnız yönetici için akar.
final adminRosterProvider = StreamProvider<List<AdminRosterEntry>>((ref) {
  if (!ref.watch(isAdminProvider)) {
    return Stream.value(const <AdminRosterEntry>[]);
  }
  return ref.watch(adminUserRepositoryProvider).watchRoster();
});

/// Oturumdaki kullanıcının yetki matrisi (roster stream + claim rol).
final adminCapabilitiesProvider = Provider<AdminCapabilities>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) {
    return const AdminCapabilities(
      isSuperAdmin: false,
      capsFieldMissing: false,
      caps: {},
    );
  }
  if (user.isSuperAdmin) return AdminCapabilities.superAdmin();
  final roster = ref.watch(adminRosterProvider).valueOrNull;
  final mine = roster?.where((e) => e.uid == user.uid).firstOrNull;
  if (mine == null) {
    return AdminCapabilities.fromRoster(
      isSuperAdmin: false,
      capabilities: null,
    );
  }
  return AdminCapabilities.fromRoster(
    isSuperAdmin: mine.isSuperAdmin,
    capabilities: mine.capabilitiesFieldPresent
        ? (mine.capabilities ?? const [])
        : null,
  );
});

final adminInviteRepositoryProvider = Provider<AdminInviteRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminInviteRepository();
  final repo = MockAdminInviteRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Bekleyen davetler (superadmin okur).
final adminPendingInvitesProvider = StreamProvider<List<AdminInvite>>((ref) {
  if (!ref.watch(isSuperAdminProvider)) {
    return Stream.value(const <AdminInvite>[]);
  }
  return ref.watch(adminInviteRepositoryProvider).watchPending();
});

final adminStatsRepositoryProvider = Provider<AdminStatsRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminStatsRepository();
  return MockAdminStatsRepository();
});

/// Platform KPI (adminStats/global). Yönetici değilse boş.
final adminStatsProvider = StreamProvider<AdminStatsSnapshot>((ref) {
  if (!ref.watch(isAdminProvider)) {
    return Stream.value(const AdminStatsSnapshot());
  }
  return ref.watch(adminStatsRepositoryProvider).watchGlobal();
});

final adminInsightsRepositoryProvider = Provider<AdminInsightsRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminInsightsRepository();
  return MockAdminInsightsRepository();
});

/// Superadmin özet paneli: örneklem dağılımları (bölge / meslek / ürün…).
/// Yalnız superadmin yükler — ~4×400 okuma; moderatörde boş.
final adminInsightsProvider = FutureProvider.autoDispose<AdminInsights?>((ref) async {
  if (!ref.watch(isSuperAdminProvider)) return null;
  return ref.watch(adminInsightsRepositoryProvider).fetchInsights();
});

final adminDailyStatsRepositoryProvider =
    Provider<AdminDailyStatsRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminDailyStatsRepository();
  return MockAdminDailyStatsRepository();
});

/// Günlük eğilim (son 30 gün) — `adminStats/daily/days`.
///
/// `stats.read` yeteneği olan her yönetici görür (içgörülerin aksine
/// superadmin'e kapalı değil): 30 doküman okur, ucuzdur ve moderatörün
/// "bugün yoğunluk nasıl?" sorusunu yanıtlar.
final adminDailyStatsProvider =
    FutureProvider.autoDispose<List<AdminDailyStat>>((ref) async {
  if (!ref.watch(adminCapabilitiesProvider).allows('stats.read')) {
    return const <AdminDailyStat>[];
  }
  return ref.watch(adminDailyStatsRepositoryProvider).fetchRecent(dayCount: 30);
});

final adminAuditRepositoryProvider = Provider<AdminAuditRepository>((ref) {
  if (useFirebaseBackend) return FirebaseAdminAuditRepository();
  return MockAdminAuditRepository();
});

final adminRuntimeConfigRepositoryProvider =
    Provider<AdminRuntimeConfigRepository>((ref) {
      if (useFirebaseBackend) return FirebaseAdminRuntimeConfigRepository();
      final repo = MockAdminRuntimeConfigRepository();
      ref.onDispose(repo.dispose);
      return repo;
    });

/// Runtime config stream (adminConfig/runtime).
final adminRuntimeConfigProvider = StreamProvider<AdminRuntimeConfig>((ref) {
  if (!ref.watch(isAdminProvider)) {
    return Stream.value(const AdminRuntimeConfig());
  }
  return ref.watch(adminRuntimeConfigRepositoryProvider).watchRuntime();
});

/// Mağaza ürün kategorileri (adminConfig/productCategories).
final adminProductCategoriesProvider =
    StreamProvider<ProductCategoryCatalog>((ref) {
  if (!ref.watch(isAdminProvider)) {
    return Stream.value(ProductCategoryCatalog.defaults);
  }
  return ref
      .watch(adminRuntimeConfigRepositoryProvider)
      .watchProductCategories();
});

final adminBroadcastRepositoryProvider = Provider<AdminBroadcastRepository>((
  ref,
) {
  return AdminBroadcastRepository();
});

/// Zamanlanmış kampanyalar (en yeni plan üstte).
final scheduledCampaignsProvider =
    StreamProvider.autoDispose<List<ScheduledCampaign>>((ref) {
      if (!ref.watch(isAdminProvider)) {
        return Stream.value(const []);
      }
      return ref.watch(adminBroadcastRepositoryProvider).watchCampaigns();
    });

final adminSupportRepositoryProvider = Provider<AdminSupportRepository>((ref) {
  return AdminSupportRepository();
});

/// [openOnly] true → yalnız open/in_progress.
final adminSupportTicketsProvider = StreamProvider.autoDispose
    .family<List<SupportTicket>, bool>((ref, openOnly) {
      if (!ref.watch(isAdminProvider)) {
        return Stream.value(const []);
      }
      return ref
          .watch(adminSupportRepositoryProvider)
          .watchTickets(openOnly: openOnly);
    });

/// Sayfalanmış denetim kaydı durumu: birikmiş kayıtlar + daha eski var mı +
/// "daha fazla yükleniyor" bayrağı.
class AuditPage {
  const AuditPage({
    required this.entries,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<AuditEntry> entries;
  final bool hasMore;
  final bool loadingMore;

  AuditPage copyWith({
    List<AuditEntry>? entries,
    bool? hasMore,
    bool? loadingMore,
  }) => AuditPage(
    entries: entries ?? this.entries,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Denetim kaydını cursor ile sayfalar: ilk sayfa + "daha eski" ekler +
/// yenile. Sonsuz büyüyen append-only koleksiyon için sabit tavan yerine
/// aşamalı yükleme (ölçek).
class AuditLogController extends StateNotifier<AsyncValue<AuditPage>> {
  AuditLogController(this._repo) : super(const AsyncLoading()) {
    load();
  }

  final AdminAuditRepository _repo;
  static const int _pageSize = 50;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final first = await _repo.fetchPage(limit: _pageSize);
      state = AsyncData(
        AuditPage(entries: first, hasMore: first.length == _pageSize),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore || cur.entries.isEmpty) {
      return;
    }
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final next = await _repo.fetchPage(
        beforeCursor: cur.entries.last.cursor,
        limit: _pageSize,
      );
      state = AsyncData(
        AuditPage(
          entries: [...cur.entries, ...next],
          hasMore: next.length == _pageSize,
        ),
      );
    } catch (_) {
      // Hata: yalnız "yükleniyor"u kapat, mevcut kayıtlar korunur.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }
}

/// Denetim kaydı sayfalama controller'ı. Yalnız yönetici için yükler; değilse
/// boş kalır (sekme zaten süper yöneticiye görünür). Sekmeden çıkınca sıfırlanır.
final auditLogControllerProvider =
    StateNotifierProvider.autoDispose<
      AuditLogController,
      AsyncValue<AuditPage>
    >((ref) {
      final repo = ref.watch(adminAuditRepositoryProvider);
      return AuditLogController(repo);
    });

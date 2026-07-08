import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/geo_models.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../artisan/data/artisan_repository.dart';

/// Müşterinin seçtiği filtre kriterleri (metin sorgusu + kademeli dropdown).
/// İl/İlçe/Meslek opsiyoneldir; null = "Tümü".
class CustomerFilter {
  const CustomerFilter({
    this.province,
    this.district,
    this.profession,
    this.query = '',
  });

  final Province? province;
  final District? district;
  final String? profession; // meslek kodu
  final String query; // arama kutusundaki serbest metin

  /// Filtre alanları bağımsız ve opsiyoneldir (PRD §3). Repository'ye
  /// gönderilecek opsiyonel filtreye dönüştürür.
  ArtisanFilter toArtisanFilter() => ArtisanFilter(
        province: province?.name,
        district: district?.name,
        professionCode: profession,
        query: query.trim().isEmpty ? null : query.trim(),
      );

  /// Detaylı arama panelinde kaç filtre aktif? (rozet için)
  int get activeCount =>
      (province == null ? 0 : 1) +
      (district == null ? 0 : 1) +
      (profession == null ? 0 : 1);
}

/// Filtre seçimlerini yöneten notifier. İl değişince ilçe sıfırlanır —
/// tutarsız seçim önlenir. null değer "Tümü" anlamına gelir.
class CustomerFilterNotifier extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() => const CustomerFilter();

  void setProvince(Province? p) {
    state = CustomerFilter(
      province: p,
      profession: state.profession,
      query: state.query,
    );
  }

  void setDistrict(District? d) {
    state = CustomerFilter(
      province: state.province,
      district: d,
      profession: state.profession,
      query: state.query,
    );
  }

  void setProfession(String? code) {
    state = CustomerFilter(
      province: state.province,
      district: state.district,
      profession: code,
      query: state.query,
    );
  }

  void setQuery(String q) {
    state = CustomerFilter(
      province: state.province,
      district: state.district,
      profession: state.profession,
      query: q,
    );
  }

  /// Detaylı arama panelindeki tüm seçimleri temizler (metin kalır).
  void clearSelections() {
    state = CustomerFilter(query: state.query);
  }
}

final customerFilterProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilter>(
        CustomerFilterNotifier.new);

/// Arama sonucu durumu — liste + sayfalama bayrakları.
class ArtisanSearchState {
  const ArtisanSearchState({
    this.items = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.hasSearched = false,
  });

  final List<ArtisanSummary> items;
  final bool hasMore;
  final bool isLoadingMore;
  final bool hasSearched;

  ArtisanSearchState copyWith({
    List<ArtisanSummary>? items,
    bool? hasMore,
    bool? isLoadingMore,
    bool? hasSearched,
  }) {
    return ArtisanSearchState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

/// Usta aramasını ve "daha fazla yükle" sayfalamasını yürüten controller.
class ArtisanSearchController extends AsyncNotifier<ArtisanSearchState> {
  // Aktif aramanın filtresi (sayfalama için saklanır).
  ArtisanFilter _filter = const ArtisanFilter();

  @override
  Future<ArtisanSearchState> build() async => const ArtisanSearchState();

  ArtisanRepository get _repo => ref.read(artisanRepositoryProvider);

  /// Seçili (opsiyonel) filtreyle ilk sayfayı getirir. Filtre boş olabilir.
  Future<void> search() async {
    _filter = ref.read(customerFilterProvider).toArtisanFilter();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await _repo.searchArtisans(
        filter: _filter,
        offset: 0,
        limit: AppConstants.artisanPageSize,
      );
      return ArtisanSearchState(
        items: page.items,
        hasMore: page.hasMore,
        hasSearched: true,
      );
    });
  }

  /// Sonraki sayfayı mevcut listeye ekler.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        !current.hasSearched) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.searchArtisans(
        filter: _filter,
        offset: current.items.length,
        limit: AppConstants.artisanPageSize,
      );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...page.items],
        hasMore: page.hasMore,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final artisanSearchControllerProvider =
    AsyncNotifierProvider<ArtisanSearchController, ArtisanSearchState>(
        ArtisanSearchController.new);

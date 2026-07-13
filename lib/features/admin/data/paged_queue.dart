import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cursor sayfalı bir kuyruğun durumu: birikmiş öğeler + daha var mı +
/// "daha fazla yükleniyor" bayrağı. (Şikayet/anlaşmazlık/denetim kuyrukları
/// aynı kalıbı paylaşır — sabit tavan yerine aşamalı yükleme, ölçek.)
class PagedData<T> {
  const PagedData({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;

  PagedData<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      PagedData<T>(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Bir sayfayı (en yeni üstte) çeken fonksiyon. [beforeCursor] verilirse yalnız
/// ondan eski öğeler döner. Dönen liste [limit]'e eşitse muhtemelen daha var.
typedef PageFetcher<T> = Future<List<T>> Function({
  String? beforeCursor,
  int limit,
});

/// Bir öğeden sayfalama imlecini (genelde ham `createdAt` metni) üretir.
typedef CursorOf<T> = String Function(T item);

/// Cursor sayfalama controller'ı: ilk sayfa + "daha eski" ekleme + yenile.
/// Her kuyruk için tek örnek; UI `AsyncValue<PagedData<T>>` dinler.
class PagedController<T> extends StateNotifier<AsyncValue<PagedData<T>>> {
  PagedController({
    required PageFetcher<T> fetch,
    required CursorOf<T> cursorOf,
    this.pageSize = 30,
  })  : _fetch = fetch,
        _cursorOf = cursorOf,
        super(const AsyncLoading()) {
    load();
  }

  final PageFetcher<T> _fetch;
  final CursorOf<T> _cursorOf;
  final int pageSize;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final first = await _fetch(limit: pageSize);
      state = AsyncData(
          PagedData<T>(items: first, hasMore: first.length == pageSize));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore || cur.items.isEmpty) {
      return;
    }
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final next = await _fetch(
        beforeCursor: _cursorOf(cur.items.last),
        limit: pageSize,
      );
      state = AsyncData(PagedData<T>(
        items: [...cur.items, ...next],
        hasMore: next.length == pageSize,
      ));
    } catch (_) {
      // Hata: yalnız "yükleniyor"u kapat, mevcut öğeler korunur.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }
}

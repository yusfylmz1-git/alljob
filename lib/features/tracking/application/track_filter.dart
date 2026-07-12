import '../../../data/models/track_item.dart';

/// Durum filtresi (hızlı erişim çipleri).
enum TrackStatusFilter {
  all,
  active,
  done;

  String get labelTR => switch (this) {
        TrackStatusFilter.all => 'Tümü',
        TrackStatusFilter.active => 'Aktif',
        TrackStatusFilter.done => 'Tamamlanan',
      };
}

/// Sıralama seçenekleri.
enum TrackSort {
  updatedDesc,
  createdDesc,
  reminderAsc,
  priorityDesc,
  titleAsc;

  String get labelTR => switch (this) {
        TrackSort.updatedDesc => 'Son güncellenen',
        TrackSort.createdDesc => 'Son eklenen',
        TrackSort.reminderAsc => 'Hatırlatmaya göre',
        TrackSort.priorityDesc => 'Önceliğe göre',
        TrackSort.titleAsc => 'Başlık (A-Z)',
      };
}

/// Takip listesi filtresi. Değişmez (immutable); [copyWith] ile türetilir.
/// Filtreleme/sıralama saf [apply] fonksiyonundadır (birim testi kolay).
class TrackFilter {
  const TrackFilter({
    this.status = TrackStatusFilter.all,
    this.priorities = const {},
    this.tags = const {},
    this.onlyReminders = false,
    this.sort = TrackSort.updatedDesc,
  });

  final TrackStatusFilter status;
  final Set<TrackPriority> priorities; // boş = hepsi
  final Set<String> tags; // boş = hepsi (herhangi biri eşleşirse geçer)
  final bool onlyReminders;
  final TrackSort sort;

  /// Durum ve sıralama HARİÇ, "gelişmiş" aktif filtre sayısı (rozet için):
  /// öncelik + etiket + yalnız-hatırlatmalı.
  int get advancedCount =>
      (priorities.isEmpty ? 0 : 1) +
      (tags.isEmpty ? 0 : 1) +
      (onlyReminders ? 1 : 0);

  bool get isDefault =>
      status == TrackStatusFilter.all &&
      advancedCount == 0 &&
      sort == TrackSort.updatedDesc;

  TrackFilter copyWith({
    TrackStatusFilter? status,
    Set<TrackPriority>? priorities,
    Set<String>? tags,
    bool? onlyReminders,
    TrackSort? sort,
  }) {
    return TrackFilter(
      status: status ?? this.status,
      priorities: priorities ?? this.priorities,
      tags: tags ?? this.tags,
      onlyReminders: onlyReminders ?? this.onlyReminders,
      sort: sort ?? this.sort,
    );
  }

  /// [items] üzerine filtreyi + serbest metin [query]'sini uygular, sıralar.
  List<TrackItem> apply(List<TrackItem> items, {String query = ''}) {
    final q = query.trim().toLowerCase();
    final out = items.where((t) {
      switch (status) {
        case TrackStatusFilter.active:
          if (t.isDone) return false;
        case TrackStatusFilter.done:
          if (!t.isDone) return false;
        case TrackStatusFilter.all:
          break;
      }
      if (priorities.isNotEmpty && !priorities.contains(t.priority)) {
        return false;
      }
      if (tags.isNotEmpty && !t.tags.any(tags.contains)) return false;
      if (onlyReminders && !t.hasReminder) return false;
      if (q.isNotEmpty) {
        final match = t.title.toLowerCase().contains(q) ||
            (t.note?.toLowerCase().contains(q) ?? false) ||
            t.tags.any((tag) => tag.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();

    out.sort(_comparator);
    return out;
  }

  static int _priorityRank(TrackPriority p) => switch (p) {
        TrackPriority.high => 0,
        TrackPriority.normal => 1,
        TrackPriority.low => 2,
      };

  int _comparator(TrackItem a, TrackItem b) {
    switch (sort) {
      case TrackSort.updatedDesc:
        return b.updatedAt.compareTo(a.updatedAt);
      case TrackSort.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case TrackSort.reminderAsc:
        // Hatırlatması olanlar önce (en yakın en üstte); olmayanlar sona.
        final ar = a.reminderAt;
        final br = b.reminderAt;
        if (ar == null && br == null) return b.updatedAt.compareTo(a.updatedAt);
        if (ar == null) return 1;
        if (br == null) return -1;
        return ar.compareTo(br);
      case TrackSort.priorityDesc:
        final byP = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
        return byP != 0 ? byP : b.updatedAt.compareTo(a.updatedAt);
      case TrackSort.titleAsc:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
  }
}

/// Kayıtlarda geçen tüm etiketler (filtre panelinde göstermek için), sıralı.
List<String> collectTags(List<TrackItem> items) {
  final set = <String>{};
  for (final t in items) {
    set.addAll(t.tags);
  }
  final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

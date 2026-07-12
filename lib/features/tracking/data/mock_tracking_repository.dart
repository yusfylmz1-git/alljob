import 'dart:async';

import '../../../data/models/track_item.dart';
import 'tracking_repository.dart';

/// Bellek-içi Takip Merkezi deposu (testler ve mock backend).
/// [SqfliteTrackingRepository] ile davranış paritesi tutar.
class MockTrackingRepository implements TrackingRepository {
  final Map<String, _Entry> _items = {};
  final _changes = StreamController<void>.broadcast();

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<TrackItem> _query(String ownerUid, {required bool trashed}) {
    final list = _items.values
        .where((e) => e.ownerUid == ownerUid && (e.item.isTrashed == trashed))
        .map((e) => e.item)
        .toList();
    list.sort((a, b) => trashed
        ? b.deletedAt!.compareTo(a.deletedAt!)
        : b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<TrackItem>> watchActive(String ownerUid) async* {
    yield _query(ownerUid, trashed: false);
    await for (final _ in _changes.stream) {
      yield _query(ownerUid, trashed: false);
    }
  }

  @override
  Stream<List<TrackItem>> watchTrashed(String ownerUid) async* {
    yield _query(ownerUid, trashed: true);
    await for (final _ in _changes.stream) {
      yield _query(ownerUid, trashed: true);
    }
  }

  @override
  Future<TrackItem?> getById(String id) async => _items[id]?.item;

  @override
  Future<void> upsert(String ownerUid, TrackItem item) async {
    _items[item.id] = _Entry(ownerUid, item);
    _ping();
  }

  @override
  Future<void> moveToTrash(String id) async {
    final e = _items[id];
    if (e == null) return;
    _items[id] = _Entry(e.ownerUid, e.item.copyWith(deletedAt: DateTime.now()));
    _ping();
  }

  @override
  Future<void> restore(String id) async {
    final e = _items[id];
    if (e == null) return;
    // copyWith null'ı temizleyemez → map üstünden deletedAt'i kaldır.
    final map = e.item.toMap()..remove('deletedAt');
    _items[id] = _Entry(e.ownerUid, TrackItem.fromMap(map));
    _ping();
  }

  @override
  Future<void> deletePermanently(String id) async {
    _items.remove(id);
    _ping();
  }

  @override
  Future<void> emptyTrash(String ownerUid) async {
    _items.removeWhere((_, e) => e.ownerUid == ownerUid && e.item.isTrashed);
    _ping();
  }

  void dispose() => _changes.close();
}

class _Entry {
  _Entry(this.ownerUid, this.item);
  final String ownerUid;
  final TrackItem item;
}

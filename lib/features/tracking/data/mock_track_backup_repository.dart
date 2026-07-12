import '../../../data/models/track_item.dart';
import 'track_backup_repository.dart';

/// Bellek-içi [TrackBackupRepository] (testler ve mock backend).
/// Firebase impl'i ile davranış paritesi tutar: yedekleme tam ayna
/// (eksikleri siler), restore özet dokümanını içermez.
class MockTrackBackupRepository implements TrackBackupRepository {
  final Map<String, Map<String, TrackItem>> _byUid = {};
  final Map<String, TrackBackupInfo> _info = {};

  @override
  Future<TrackBackupInfo?> fetchInfo(String uid) async => _info[uid];

  @override
  Future<void> backup(String uid, List<TrackItem> items, DateTime at) async {
    _byUid[uid] = {for (final i in items) i.id: i};
    _info[uid] = TrackBackupInfo(updatedAt: at, count: items.length);
  }

  @override
  Future<List<TrackItem>> restore(String uid) async =>
      _byUid[uid]?.values.toList() ?? const [];
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/track_item.dart';
import 'track_backup_repository.dart';

/// Firestore `users/{uid}/trackBackup/{id}` ile çalışan [TrackBackupRepository].
/// Kural: yalnızca sahibi okur/yazar (kişisel takip verisi gizlidir).
///
/// Özet, aynı koleksiyonda ayrılmış [_metaId] dokümanında tutulur (TrackItem
/// kimlikleri `t_...` ile başladığından çakışmaz). Yedekleme tek bir toplu
/// yazımla (batch) yapılır — kişisel kullanımda kayıt sayısı Firestore'un 500
/// işlem/batch sınırının çok altındadır.
class FirebaseTrackBackupRepository implements TrackBackupRepository {
  FirebaseTrackBackupRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _metaId = '__meta';

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('trackBackup');

  @override
  Future<TrackBackupInfo?> fetchInfo(String uid) async {
    final doc = await _col(uid).doc(_metaId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    final ms = (data['updatedAt'] as num?)?.toInt();
    return TrackBackupInfo(
      updatedAt: ms == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(ms),
      count: (data['count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> backup(String uid, List<TrackItem> items, DateTime at) async {
    final col = _col(uid);
    final existing = await col.get();
    final keepIds = {for (final i in items) i.id};

    final batch = _db.batch();
    // Artık yerelde olmayan (silinen) kayıtları buluttan da temizle.
    for (final doc in existing.docs) {
      if (doc.id != _metaId && !keepIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final item in items) {
      batch.set(col.doc(item.id), item.toMap());
    }
    batch.set(col.doc(_metaId), {
      'updatedAt': at.millisecondsSinceEpoch,
      'count': items.length,
    });
    await batch.commit();
  }

  @override
  Future<List<TrackItem>> restore(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs
        .where((d) => d.id != _metaId)
        .map((d) => TrackItem.fromMap(d.data()))
        .toList();
  }
}

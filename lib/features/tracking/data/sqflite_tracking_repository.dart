import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../data/models/track_item.dart';
import 'tracking_repository.dart';

/// Yerel (cihaz içi) Takip Merkezi deposu. Offline tam çalışır; ağ gerekmez.
///
/// Tek tablo `track_items`: kaydın tamamı `data` sütununda JSON olarak durur;
/// ayrıca sık sorgulanan alanlar (`owner_uid`, `deleted_at`, `updated_at`)
/// indeks/filtre için ayrı sütunlarda tutulur. Kişisel ölçekte veri küçük
/// olduğundan arama/filtre bellek katmanında yapılır — SQL sade kalır.
///
/// Reaktiflik: Firestore snapshot yok; her değişiklikten sonra tek bir
/// "değişti" tetikçisi ([_changes]) yayınlanır, izleyen akışlar yeniden
/// sorgular. (Job repo'sundaki canlı liste hissi, yerelde bu kalıpla.)
class SqfliteTrackingRepository implements TrackingRepository {
  SqfliteTrackingRepository();

  static const _dbName = 'usta_cepte_tracking.db';
  static const _table = 'track_items';

  Database? _db;
  final _changes = StreamController<void>.broadcast();

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table(
            id TEXT PRIMARY KEY,
            owner_uid TEXT NOT NULL,
            data TEXT NOT NULL,
            deleted_at INTEGER,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_owner_deleted ON $_table(owner_uid, deleted_at)');
      },
    );
    _db = db;
    return db;
  }

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<List<TrackItem>> _query(String ownerUid, {required bool trashed}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where:
          'owner_uid = ? AND deleted_at IS ${trashed ? 'NOT NULL' : 'NULL'}',
      whereArgs: [ownerUid],
      orderBy: trashed ? 'deleted_at DESC' : 'updated_at DESC',
    );
    return rows
        .map((r) => TrackItem.fromMap(
            (jsonDecode(r['data'] as String) as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Stream<List<TrackItem>> watchActive(String ownerUid) async* {
    yield await _query(ownerUid, trashed: false);
    await for (final _ in _changes.stream) {
      yield await _query(ownerUid, trashed: false);
    }
  }

  @override
  Stream<List<TrackItem>> watchTrashed(String ownerUid) async* {
    yield await _query(ownerUid, trashed: true);
    await for (final _ in _changes.stream) {
      yield await _query(ownerUid, trashed: true);
    }
  }

  @override
  Future<TrackItem?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return TrackItem.fromMap(
        (jsonDecode(rows.first['data'] as String) as Map)
            .cast<String, dynamic>());
  }

  @override
  Future<void> upsert(String ownerUid, TrackItem item) async {
    final db = await _database;
    await db.insert(
      _table,
      {
        'id': item.id,
        'owner_uid': ownerUid,
        'data': jsonEncode(item.toMap()),
        'deleted_at': item.deletedAt?.millisecondsSinceEpoch,
        'updated_at': item.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _ping();
  }

  /// Var olan kaydın JSON'ını okuyup [deletedAt]'i güncelleyerek geri yazar
  /// (copyWith null'ı temizleyemediği için map üstünden).
  Future<void> _setDeletedAt(String id, DateTime? value) async {
    final db = await _database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final map = (jsonDecode(rows.first['data'] as String) as Map)
        .cast<String, dynamic>();
    if (value == null) {
      map.remove('deletedAt');
    } else {
      map['deletedAt'] = value.millisecondsSinceEpoch;
    }
    await db.update(
      _table,
      {'data': jsonEncode(map), 'deleted_at': value?.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    _ping();
  }

  @override
  Future<void> moveToTrash(String id) => _setDeletedAt(id, DateTime.now());

  @override
  Future<void> restore(String id) => _setDeletedAt(id, null);

  @override
  Future<void> deletePermanently(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _ping();
  }

  @override
  Future<void> emptyTrash(String ownerUid) async {
    final db = await _database;
    await db.delete(_table,
        where: 'owner_uid = ? AND deleted_at IS NOT NULL',
        whereArgs: [ownerUid]);
    _ping();
  }

  Future<void> dispose() async {
    await _changes.close();
    await _db?.close();
  }
}

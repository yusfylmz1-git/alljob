import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/artisan_profile.dart';

/// Yönetici usta tarayıcısı + bayraklar.
abstract interface class AdminArtisanRepository {
  Future<List<ArtisanProfile>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    String? profession,
    bool? isVerified,
  });

  Future<void> setFlags(
    String uid, {
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  });
}

class FirebaseAdminArtisanRepository implements AdminArtisanRepository {
  FirebaseAdminArtisanRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<List<ArtisanProfile>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    String? profession,
    bool? isVerified,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('artisanProfiles');
    if (profession != null && profession.trim().isNotEmpty) {
      q = q.where('profession', isEqualTo: profession.trim());
    } else if (isVerified != null) {
      q = q.where('isVerified', isEqualTo: isVerified);
    }
    q = q.orderBy('createdAt', descending: true);
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      q = q.where('createdAt', isLessThan: beforeCursor);
    }
    final snap = await q.limit(limit).get();
    return snap.docs
        .map((d) => ArtisanProfile.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<void> setFlags(
    String uid, {
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) async {
    final payload = <String, dynamic>{'uid': uid};
    if (adminVerified != null) payload['adminVerified'] = adminVerified;
    if (featured != null) payload['featured'] = featured;
    if (moderationHidden != null) {
      payload['moderationHidden'] = moderationHidden;
    }
    await _functions
        .httpsCallable('adminSetArtisanFlags')
        .call<Object?>(payload);
  }
}

class MockAdminArtisanRepository implements AdminArtisanRepository {
  MockAdminArtisanRepository([List<ArtisanProfile>? seed]) {
    if (seed != null) {
      for (final a in seed) {
        _items[a.uid] = a;
      }
    }
  }

  final Map<String, ArtisanProfile> _items = {};

  void put(ArtisanProfile p) => _items[p.uid] = p;

  @override
  Future<List<ArtisanProfile>> fetchPage({
    String? beforeCursor,
    int limit = 30,
    String? profession,
    bool? isVerified,
  }) async {
    var list = _items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (profession != null && profession.trim().isNotEmpty) {
      final p = profession.trim();
      list = list.where((a) => a.profession == p).toList();
    } else if (isVerified != null) {
      list = list.where((a) => a.isVerified == isVerified).toList();
    }
    if (beforeCursor != null && beforeCursor.isNotEmpty) {
      final cut = DateTime.tryParse(beforeCursor);
      if (cut != null) {
        list = list.where((a) => a.createdAt.isBefore(cut)).toList();
      }
    }
    if (list.length > limit) list = list.sublist(0, limit);
    return list;
  }

  @override
  Future<void> setFlags(
    String uid, {
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) async {
    // Mock: no-op (UI tests use real flags via CF in prod).
  }
}

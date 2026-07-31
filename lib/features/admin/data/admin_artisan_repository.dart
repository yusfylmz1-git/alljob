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

  /// Manuel Premium tanımlar/uzatır ([days]) veya iptal eder ([revoke]).
  ///
  /// Play satın alma kaydını BOZMAZ; manuel müdahale ayrı tutulur. [reason]
  /// zorunludur (para etkili işlem — denetim kaydına yazılır). Uzatmada
  /// mevcut bitiş ileri tarihliyse süre onun üzerine eklenir.
  ///
  /// Dönen değer: yeni bitiş tarihi (iptalde null).
  Future<DateTime?> setPremiumOverride(
    String uid, {
    required String reason,
    int? days,
    bool revoke = false,
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

  @override
  Future<DateTime?> setPremiumOverride(
    String uid, {
    required String reason,
    int? days,
    bool revoke = false,
  }) async {
    final res = await _functions.httpsCallable('adminGrantPremium').call<Object?>({
      'uid': uid,
      'reason': reason,
      if (revoke) 'revoke': true else 'days': days,
    });
    final data = (res.data as Map?)?.cast<String, dynamic>();
    final iso = data?['expiresAt'] as String?;
    return iso == null ? null : DateTime.tryParse(iso);
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

  /// Manuel premium müdahale kaydı (sunucudaki `premiumOverrides` karşılığı) —
  /// testler gerekçenin yazıldığını doğrulayabilsin.
  final List<({String uid, int? days, String reason, bool revoke})> overrides =
      [];

  @override
  Future<DateTime?> setPremiumOverride(
    String uid, {
    required String reason,
    int? days,
    bool revoke = false,
  }) async {
    // Sunucu doğrulamalarının aynısı (mock ile CF davranışı ayrışmasın).
    if (reason.trim().length < 5) {
      throw ArgumentError('Gerekçe zorunlu (en az 5 karakter).');
    }
    final current = _items[uid];
    if (current == null) throw StateError('Usta profili yok.');

    overrides.add((uid: uid, days: days, reason: reason, revoke: revoke));

    if (revoke) {
      _items[uid] = current.copyWith(
        isPremium: false,
        premiumExpiresAt: DateTime.now(),
      );
      return null;
    }
    final d = days ?? 0;
    if (d < 1 || d > 3650) {
      throw ArgumentError('days 1..3650 aralığında olmalı.');
    }
    // UZATMA: aktif üyelik varsa üzerine ekle — aksi hâlde süre KISALIRDI.
    final now = DateTime.now();
    final currentEnd = current.premiumExpiresAt;
    final base =
        (currentEnd != null && currentEnd.isAfter(now)) ? currentEnd : now;
    final expiry = base.add(Duration(days: d));
    _items[uid] = current.copyWith(isPremium: true, premiumExpiresAt: expiry);
    return expiry;
  }
}

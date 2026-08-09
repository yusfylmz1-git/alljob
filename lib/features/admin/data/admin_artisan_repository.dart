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

  /// Yüklenen belgeleri onaylar/reddeder (usta bazında tek karar).
  /// Reddetmede [note] zorunludur — usta neyi düzelteceğini bilmeli.
  /// Onay yalnız "Belgeli usta" rozeti verir; mavi tike etki etmez.
  Future<void> reviewCertificates(
    String uid, {
    required bool approve,
    String? note,
  });

  /// Belgeleri incelemeyi bekleyen ustalar (`certificateStatus == pending`).
  Future<List<ArtisanProfile>> pendingCertificates({int limit = 50});

  /// TOPLU plan/müsaitlik güncellemesi (ücretsiz dönem bitişi — madde 7).
  ///
  /// Asıl mekanizma istemcideki premium KAPISIDIR
  /// ([ArtisanProfile.isAvailableAt]); bu metot onun yerine geçmez, elle
  /// müdahale gereken durumlar içindir (kampanya bitişi, toplu düzeltme).
  ///
  /// [mode]: `revokePremium` · `pauseAvailability` · `both`.
  /// [onlyWithoutActivePremium] true (varsayılan) iken parasını ödemiş
  /// aktif aboneler ATLANIR. [dryRun] true ise hiçbir şey yazılmaz, yalnız
  /// kaç ustanın etkileneceği döner — yönetici önce görsün.
  /// [reason] zorunludur (denetim kaydına yazılır).
  Future<BulkPlanResult> bulkPlanUpdate({
    required String mode,
    required String reason,
    bool onlyWithoutActivePremium = true,
    bool dryRun = false,
  });
}

/// [AdminArtisanRepository.bulkPlanUpdate] sonucu.
class BulkPlanResult {
  const BulkPlanResult({
    required this.etkilenen,
    required this.atlanan,
    required this.toplam,
    required this.dryRun,
  });

  /// Değişen (ya da dryRun'da değişecek olan) usta sayısı.
  final int etkilenen;

  /// Dokunulmayanlar: aktif aboneler + zaten o durumda olanlar.
  final int atlanan;
  final int toplam;
  final bool dryRun;
}

class FirebaseAdminArtisanRepository implements AdminArtisanRepository {
  FirebaseAdminArtisanRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

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
    final res = await _functions
        .httpsCallable('adminGrantPremium')
        .call<Object?>({
          'uid': uid,
          'reason': reason,
          if (revoke) 'revoke': true else 'days': days,
        });
    final data = (res.data as Map?)?.cast<String, dynamic>();
    final iso = data?['expiresAt'] as String?;
    return iso == null ? null : DateTime.tryParse(iso);
  }

  @override
  Future<void> reviewCertificates(
    String uid, {
    required bool approve,
    String? note,
  }) async {
    await _functions.httpsCallable('adminReviewCertificates').call<Object?>({
      'uid': uid,
      'approve': approve,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  @override
  Future<List<ArtisanProfile>> pendingCertificates({int limit = 50}) async {
    // Tek alan eşitliği → bileşik indeks gerekmez.
    final snap = await _db
        .collection('artisanProfiles')
        .where('certificateStatus', isEqualTo: 'pending')
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => ArtisanProfile.fromMap(d.id, d.data()))
        .toList();
  }

  @override
  Future<BulkPlanResult> bulkPlanUpdate({
    required String mode,
    required String reason,
    bool onlyWithoutActivePremium = true,
    bool dryRun = false,
  }) async {
    final res = await _functions
        .httpsCallable('adminBulkPlanUpdate')
        .call<Object?>({
          'mode': mode,
          'reason': reason,
          'onlyWithoutActivePremium': onlyWithoutActivePremium,
          'dryRun': dryRun,
        });
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    int say(String k) => (data[k] as num?)?.toInt() ?? 0;
    return BulkPlanResult(
      etkilenen: say('etkilenen'),
      atlanan: say('atlanan'),
      toplam: say('toplam'),
      dryRun: data['dryRun'] == true,
    );
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
    final base = (currentEnd != null && currentEnd.isAfter(now))
        ? currentEnd
        : now;
    final expiry = base.add(Duration(days: d));
    _items[uid] = current.copyWith(isPremium: true, premiumExpiresAt: expiry);
    return expiry;
  }

  /// Belge inceleme kararları (sunucu audit log'unun test karşılığı).
  final List<({String uid, bool approve, String? note})> certDecisions = [];

  @override
  Future<void> reviewCertificates(
    String uid, {
    required bool approve,
    String? note,
  }) async {
    final current = _items[uid];
    if (current == null) throw StateError('Usta profili yok.');
    if (current.certificates.isEmpty) {
      throw StateError('Bu ustanın yüklenmiş belgesi yok.');
    }
    // Sunucudaki kural: reddetmede gerekçe zorunlu.
    if (!approve && (note == null || note.trim().length < 5)) {
      throw ArgumentError('Red gerekçesi zorunlu (en az 5 karakter).');
    }
    certDecisions.add((uid: uid, approve: approve, note: note));
    _items[uid] = _withCertStatus(
      current,
      approve ? 'approved' : 'rejected',
      approve ? null : note!.trim(),
    );
  }

  @override
  Future<List<ArtisanProfile>> pendingCertificates({int limit = 50}) async {
    return _items.values
        .where((a) => a.certificateStatus == 'pending')
        .take(limit)
        .toList();
  }

  /// Toplu plan işlemleri kaydı (sunucu audit log'unun test karşılığı).
  final List<({String mode, String reason, bool dryRun})> bulkOps = [];

  @override
  Future<BulkPlanResult> bulkPlanUpdate({
    required String mode,
    required String reason,
    bool onlyWithoutActivePremium = true,
    bool dryRun = false,
  }) async {
    // Sunucu doğrulamalarının aynısı (mock ile CF davranışı ayrışmasın).
    const gecerli = ['revokePremium', 'pauseAvailability', 'both'];
    if (!gecerli.contains(mode)) {
      throw ArgumentError('Geçersiz mode: $mode');
    }
    if (reason.trim().length < 5) {
      throw ArgumentError('Gerekçe zorunlu (en az 5 karakter).');
    }

    bulkOps.add((mode: mode, reason: reason, dryRun: dryRun));

    final now = DateTime.now();
    var etkilenen = 0;
    var atlanan = 0;

    for (final entry in _items.entries.toList()) {
      final p = entry.value;
      final bitis = p.premiumExpiresAt;
      final aktifPremium = p.isPremium && bitis != null && bitis.isAfter(now);

      // Parasını ödemiş aktif aboneye dokunma (varsayılan).
      if (onlyWithoutActivePremium && aktifPremium) {
        atlanan++;
        continue;
      }

      final premiumDusecek =
          (mode == 'revokePremium' || mode == 'both') && p.isPremium;
      final duraklatilacak =
          (mode == 'pauseAvailability' || mode == 'both') && !p.manualPause;

      // Zaten hedef durumdaysa yazma — CF de boşuna yazma yapmıyor.
      if (!premiumDusecek && !duraklatilacak) {
        atlanan++;
        continue;
      }

      etkilenen++;
      if (dryRun) continue;

      _items[entry.key] = p.copyWith(
        isPremium: premiumDusecek ? false : p.isPremium,
        premiumExpiresAt: premiumDusecek ? now : p.premiumExpiresAt,
        manualPause: duraklatilacak ? true : p.manualPause,
      );
    }

    return BulkPlanResult(
      etkilenen: etkilenen,
      atlanan: atlanan,
      toplam: _items.length,
      dryRun: dryRun,
    );
  }

  /// `certificateStatus` salt okunur (CF yazar) → copyWith desteklemez;
  /// mock'ta sunucu etkisini taklit etmek için map üzerinden yeniden kurulur.
  static ArtisanProfile _withCertStatus(
    ArtisanProfile p,
    String status,
    String? note,
  ) {
    final map = Map<String, dynamic>.from(p.toMap())
      ..['certificateStatus'] = status
      ..['certificateNote'] = note
      // toMap salt-okunur alanları yazmaz; testte korunmaları gerekiyor.
      ..['isPremium'] = p.isPremium
      ..['premiumExpiresAt'] = p.premiumExpiresAt?.toIso8601String()
      ..['premiumProductId'] = p.premiumProductId;
    return ArtisanProfile.fromMap(p.uid, map);
  }
}

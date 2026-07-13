import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../data/models/job.dart';

/// Yöneticinin bir anlaşmazlığı (disputed iş) nasıl karara bağladığı.
///
/// İki güvenli karar (puan/sayaç muhasebesini bozmadan):
///  - [cancelJob]: anlaşmazlık haklı → iş İPTAL edilir (kimse puanlanmaz).
///  - [restoreJob]: anlaşmazlık yersiz/çözüldü → iş, şikayet öncesi durumuna
///    (`statusBeforeDispute`) döner ve kaldığı yerden devam eder.
enum DisputeDecision {
  cancelJob('cancel', 'İşi İptal Et'),
  restoreJob('restore', 'Devam Ettir');

  const DisputeDecision(this.apiValue, this.labelTR);
  final String apiValue;
  final String labelTR;
}

/// Yönetici anlaşmazlık (hakemlik) kuyruğu soyutlaması. `disputed` durumundaki
/// işleri YALNIZCA `admin:true` claim'i olan kullanıcı listeler; karar tüm
/// mutasyonlar gibi `adminResolveDispute` CF'inden geçer (istemci `jobs`'a
/// doğrudan yazmaz — Admin SDK kuralları aşar + denetim kaydı atomik yazılır).
abstract interface class AdminDisputeRepository {
  /// Açık anlaşmazlıklar — en yeni bildirilenler üstte.
  Stream<List<Job>> watchDisputes();

  /// Bir anlaşmazlığı karara bağlar; opsiyonel yönetici notu her iki tarafa
  /// bildirilir ve denetim kaydına yazılır.
  Future<void> resolveDispute(
    String jobId, {
    required DisputeDecision decision,
    String? note,
  });
}

/// Firestore `jobs` koleksiyonuyla çalışan [AdminDisputeRepository].
///
/// Sorgu YALNIZCA tek eşitlik filtresidir (`status == 'disputed'`) →
/// otomatik indeksli, bileşik indeks gerekmez. Sıralama (disputedAt desc)
/// bellek içinde yapılır (pencere [_pageLimit] ile sınırlı olduğundan ucuz).
/// `jobs` zaten herkese açık okunabildiğinden bu okuma için KURAL DEĞİŞİKLİĞİ
/// gerekmez; yalnızca yazan CF dağıtılır.
class FirebaseAdminDisputeRepository implements AdminDisputeRepository {
  FirebaseAdminDisputeRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static const int _pageLimit = 200;

  @override
  Stream<List<Job>> watchDisputes() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: JobStatus.disputed.apiValue)
        .limit(_pageLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Job.fromMap(d.id, d.data())).toList()
        ..sort((a, b) {
          final ad = a.disputedAt ?? a.createdAt;
          final bd = b.disputedAt ?? b.createdAt;
          return bd.compareTo(ad); // en yeni bildirilen üstte
        });
      return list;
    });
  }

  @override
  Future<void> resolveDispute(
    String jobId, {
    required DisputeDecision decision,
    String? note,
  }) async {
    await _functions.httpsCallable('adminResolveDispute').call<Object?>({
      'jobId': jobId,
      'decision': decision.apiValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}

/// Bellek-içi [AdminDisputeRepository] (testler ve Firebase'siz geliştirme).
/// CF etkisini taklit eder: [cancelJob] → cancelled, [restoreJob] →
/// `statusBeforeDispute`; her iki durumda anlaşmazlık alanları temizlenir.
class MockAdminDisputeRepository implements AdminDisputeRepository {
  MockAdminDisputeRepository([List<Job>? seed]) {
    if (seed != null) {
      for (final j in seed) {
        _items[j.jobId] = j;
      }
    }
  }

  final Map<String, Job> _items = {};
  final _changes = StreamController<void>.broadcast();

  List<Job> _query() {
    final list = _items.values
        .where((j) => j.status == JobStatus.disputed)
        .toList()
      ..sort((a, b) {
        final ad = a.disputedAt ?? a.createdAt;
        final bd = b.disputedAt ?? b.createdAt;
        return bd.compareTo(ad);
      });
    return list;
  }

  @override
  Stream<List<Job>> watchDisputes() async* {
    yield _query();
    await for (final _ in _changes.stream) {
      yield _query();
    }
  }

  @override
  Future<void> resolveDispute(
    String jobId, {
    required DisputeDecision decision,
    String? note,
  }) async {
    final j = _items[jobId];
    if (j == null || j.status != JobStatus.disputed) return;
    final restored = j.statusBeforeDispute ?? JobStatus.inProgress;
    _items[jobId] = j.copyWith(
      status: decision == DisputeDecision.cancelJob
          ? JobStatus.cancelled
          : restored,
      clearDispute: true,
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}

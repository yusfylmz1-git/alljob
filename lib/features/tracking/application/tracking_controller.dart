import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track_item.dart';
import '../../auth/application/auth_controller.dart';
import '../data/tracking_providers.dart';
import '../data/tracking_repository.dart';

/// Takip Merkezi eylemleri — ekranların ortak giriş noktası. Oturumdaki
/// kullanıcının uid'ini kapsüller (her ekran tekrar okumaz).
class TrackingController {
  TrackingController(this._ref);
  final Ref _ref;

  String? get _uid => _ref.read(currentUserProvider)?.uid;
  TrackingRepository get _repo => _ref.read(trackingRepositoryProvider);

  /// Oluşturur veya günceller. Oturum yoksa sessizce yok sayar (modül girişi
  /// zaten oturum ister).
  Future<void> save(TrackItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await _repo.upsert(uid, item);
  }

  /// Tamamlandı ↔ aktif arasında geçiş yapar.
  Future<void> toggleDone(TrackItem item) => save(
        item.copyWith(
          status: item.isDone ? TrackStatus.active : TrackStatus.done,
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> moveToTrash(String id) => _repo.moveToTrash(id);
  Future<void> restore(String id) => _repo.restore(id);
  Future<void> deletePermanently(String id) => _repo.deletePermanently(id);

  Future<void> emptyTrash() async {
    final uid = _uid;
    if (uid == null) return;
    await _repo.emptyTrash(uid);
  }
}

final trackingControllerProvider =
    Provider<TrackingController>((ref) => TrackingController(ref));

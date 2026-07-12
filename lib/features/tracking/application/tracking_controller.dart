import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track_item.dart';
import '../../auth/application/auth_controller.dart';
import '../data/attachment_store.dart';
import '../data/track_notification_service.dart';
import '../data/tracking_providers.dart';
import '../data/tracking_repository.dart';

/// Takip Merkezi eylemleri — ekranların ortak giriş noktası. Oturumdaki
/// kullanıcının uid'ini kapsüller (her ekran tekrar okumaz). Faz 2: her yazma
/// yerel hatırlatma bildirimini de senkronlar ([TrackNotificationService]).
class TrackingController {
  TrackingController(this._ref);
  final Ref _ref;

  String? get _uid => _ref.read(currentUserProvider)?.uid;
  TrackingRepository get _repo => _ref.read(trackingRepositoryProvider);
  TrackNotificationService get _notif =>
      _ref.read(trackNotificationServiceProvider);
  AttachmentStore get _attachments => _ref.read(attachmentStoreProvider);

  /// Oluşturur veya günceller. Oturum yoksa sessizce yok sayar (modül girişi
  /// zaten oturum ister). Kayıt sonrası hatırlatma bildirimi senkronlanır.
  Future<void> save(TrackItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await _repo.upsert(uid, item);
    await _notif.sync(item);
  }

  /// Tamamlama düğmesi. Tekrarsız kayıt: tamamlandı ↔ aktif arasında geçiş.
  /// TEKRARLI + hatırlatmalı kayıt tamamlanınca: aynı kayıt AKTİF kalır,
  /// [TrackItem.reminderAt] bir sonraki (gelecekteki) tarihe kayar — ürün
  /// kararı "aynı kayıt ilerlesin". Kaçırılan tekrarlar atlanır.
  Future<void> toggleDone(TrackItem item) {
    final now = DateTime.now();
    if (!item.isDone &&
        item.recurrence != TrackRecurrence.none &&
        item.reminderAt != null) {
      var next = item.recurrence.nextAfter(item.reminderAt!)!;
      // Geçmişte kalan tekrarları atlayıp ilk GELECEK tarihe kadar ilerle
      // (aşırı eski tarihlerde sonsuz döngüye karşı üst sınır).
      for (var i = 0; i < 5000 && !next.isAfter(now); i++) {
        next = item.recurrence.nextAfter(next)!;
      }
      return save(item.copyWith(
        status: TrackStatus.active,
        reminderAt: next,
        updatedAt: now,
      ));
    }
    return save(item.copyWith(
      status: item.isDone ? TrackStatus.active : TrackStatus.done,
      updatedAt: now,
    ));
  }

  Future<void> moveToTrash(String id) async {
    await _repo.moveToTrash(id);
    await _notif.cancel(id);
  }

  Future<void> restore(String id) async {
    await _repo.restore(id);
    // Geri alınan kaydın (gelecekteki) hatırlatması yeniden planlanır.
    final item = await _repo.getById(id);
    if (item != null) await _notif.sync(item);
  }

  Future<void> deletePermanently(String id) async {
    await _notif.cancel(id);
    // Ek dosyalarını da diskten temizle (yerel kopyalar).
    final item = await _repo.getById(id);
    if (item != null) await _attachments.deleteFiles(item.attachments);
    await _repo.deletePermanently(id);
  }

  Future<void> emptyTrash() async {
    final uid = _uid;
    if (uid == null) return;
    // Çöptekiler zaten çöpe atılırken iptal edildi; yine de garantiye al.
    // Ek dosyaları da temizlenir (kalıcı silme).
    final trashed = await _repo.watchTrashed(uid).first;
    for (final t in trashed) {
      await _notif.cancel(t.id);
      await _attachments.deleteFiles(t.attachments);
    }
    await _repo.emptyTrash(uid);
  }
}

final trackingControllerProvider =
    Provider<TrackingController>((ref) => TrackingController(ref));

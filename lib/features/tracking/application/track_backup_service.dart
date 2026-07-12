import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track_item.dart';
import '../../../features/storage/storage_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../data/attachment_store.dart';
import '../data/track_backup_repository.dart';
import '../data/track_notification_service.dart';
import '../data/tracking_providers.dart';
import '../data/tracking_repository.dart';

/// Bir yedekleme/geri yükleme işleminin sonucu (UI geri bildirimi için).
class BackupResult {
  const BackupResult.success(this.count) : error = null;
  const BackupResult.failure(this.error) : count = 0;

  final int count;
  final String? error;

  bool get ok => error == null;
}

/// Takip Merkezi bulut yedeği orkestrasyonu. Yerel-öncelikli mimari korunur:
/// bu servis CANLI SENKRON DEĞİL — kullanıcının elle tetiklediği tam yedek ve
/// geri yükleme yapar. Kayıt metadatası Firestore'a ([TrackBackupRepository]),
/// ek DOSYALARI (foto/dosya/ses) Storage'a yüklenir; ekin buluttaki adresi
/// yedek kaydında saklanır, geri yüklemede yerele indirilir.
class TrackBackupService {
  TrackBackupService(this._ref);
  final Ref _ref;

  String? get _uid => _ref.read(currentUserProvider)?.uid;
  TrackingRepository get _tracking => _ref.read(trackingRepositoryProvider);
  TrackBackupRepository get _backup => _ref.read(trackBackupRepositoryProvider);
  StorageRepository get _storage => _ref.read(storageRepositoryProvider);
  AttachmentStore get _attachments => _ref.read(attachmentStoreProvider);
  TrackNotificationService get _notif =>
      _ref.read(trackNotificationServiceProvider);

  Future<TrackBackupInfo?> currentInfo() async {
    final uid = _uid;
    if (uid == null) return null;
    return _backup.fetchInfo(uid);
  }

  String _contentTypeFor(TrackAttachmentType type) => switch (type) {
        TrackAttachmentType.photo => 'image/jpeg',
        TrackAttachmentType.audio => 'audio/mp4',
        TrackAttachmentType.file => 'application/octet-stream',
      };

  /// Aktif (çöpte olmayan) tüm kayıtları buluta yedekler. Ek dosyaları
  /// Storage'a yüklenir ve yedek kaydında bulut adresiyle değiştirilir.
  /// Yüklenemeyen (yerelde bulunamayan) ek atlanır — kayıt yine yedeklenir.
  Future<BackupResult> backupNow() async {
    final uid = _uid;
    if (uid == null) return const BackupResult.failure('Oturum bulunamadı.');
    try {
      final items = await _tracking.watchActive(uid).first;
      final toBackup = <TrackItem>[];
      for (final item in items) {
        final cloudAtts = <TrackAttachment>[];
        for (final a in item.attachments) {
          try {
            final bytes = await File(a.path).readAsBytes();
            final safeName = a.name ?? 'ek';
            final url = await _storage.uploadBytes(
              path: 'track/$uid/${item.id}/$safeName',
              bytes: bytes,
              contentType: _contentTypeFor(a.type),
            );
            cloudAtts.add(TrackAttachment(
              type: a.type,
              path: url,
              name: a.name,
              sizeBytes: a.sizeBytes ?? bytes.length,
              durationMs: a.durationMs,
            ));
          } catch (e) {
            // Yerelde bulunamayan/okunamayan ek atlanır; kayıt yine yedeklenir.
            debugPrint('Ek yedeklenemedi (atlandı): ${a.path} → $e');
          }
        }
        toBackup.add(item.copyWith(attachments: cloudAtts));
      }
      await _backup.backup(uid, toBackup, DateTime.now());
      return BackupResult.success(toBackup.length);
    } catch (e) {
      debugPrint('Yedekleme hatası: $e');
      return const BackupResult.failure(
          'Yedekleme başarısız oldu. İnternet bağlantını kontrol edip '
          'tekrar dene.');
    }
  }

  /// Bulut yedeğini yerele geri yükler (BİRLEŞTİRME: aynı kimlikli yerel kayıt
  /// üzerine yazılır, yerelde olup bulutta olmayan kayıtlar SİLİNMEZ). Bulut
  /// ekleri yerele indirilir; indirilemeyen ek atlanır.
  Future<BackupResult> restoreNow() async {
    final uid = _uid;
    if (uid == null) return const BackupResult.failure('Oturum bulunamadı.');
    try {
      final records = await _backup.restore(uid);
      for (final r in records) {
        final localAtts = <TrackAttachment>[];
        for (final a in r.attachments) {
          try {
            final bytes = await _storage.downloadBytes(a.path);
            if (bytes == null) continue;
            final saved = await _attachments.saveBytes(
              bytes: bytes,
              type: a.type,
              name: a.name,
              durationMs: a.durationMs,
            );
            localAtts.add(saved);
          } catch (e) {
            debugPrint('Ek indirilemedi (atlandı): ${a.path} → $e');
          }
        }
        final restored = r.copyWith(attachments: localAtts);
        await _tracking.upsert(uid, restored);
        // Geri yüklenen (gelecekteki) hatırlatmaları yeniden planla.
        await _notif.sync(restored);
      }
      return BackupResult.success(records.length);
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      return const BackupResult.failure(
          'Geri yükleme başarısız oldu. İnternet bağlantını kontrol edip '
          'tekrar dene.');
    }
  }
}

final trackBackupServiceProvider =
    Provider<TrackBackupService>((ref) => TrackBackupService(ref));

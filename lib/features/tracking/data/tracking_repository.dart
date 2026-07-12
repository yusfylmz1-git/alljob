import '../../../data/models/track_item.dart';

/// Takip Merkezi verisi soyutlaması. Yerel-öncelikli: üretimde
/// [SqfliteTrackingRepository] (cihazda sqflite), testlerde bellek-içi
/// [MockTrackingRepository]. Bulut yedeği (Faz 5) ayrı bir katman olur;
/// bu arayüz yalnız yerel kaydı yönetir.
///
/// Kayıtlar [ownerUid] ile ölçeklenir: aynı cihazda birden çok hesap açılırsa
/// biri diğerinin takiplerini göremez (Faz 5 bulut yedeği de uid bazlıdır).
abstract interface class TrackingRepository {
  /// Aktif (çöpe atılmamış) kayıtlar — güncellenme sırasına göre en yeni üstte.
  Stream<List<TrackItem>> watchActive(String ownerUid);

  /// Çöp kutusundaki kayıtlar — silinme sırasına göre en yeni üstte.
  Stream<List<TrackItem>> watchTrashed(String ownerUid);

  Future<TrackItem?> getById(String id);

  /// Oluşturur veya (varsa) tümüyle değiştirir.
  Future<void> upsert(String ownerUid, TrackItem item);

  /// Yumuşak silme: `deletedAt = now` → çöp kutusuna taşınır (kalıcı silmez).
  Future<void> moveToTrash(String id);

  /// Çöpten geri alır: `deletedAt` temizlenir.
  Future<void> restore(String id);

  /// Kalıcı olarak siler (geri alınamaz).
  Future<void> deletePermanently(String id);

  /// Çöp kutusunu tümüyle boşaltır (yalnız verilen kullanıcının).
  Future<void> emptyTrash(String ownerUid);
}

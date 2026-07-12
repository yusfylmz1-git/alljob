import '../../../data/models/track_item.dart';

/// Bulut yedeğinin özet bilgisi (son yedekleme zamanı + kayıt sayısı).
/// Yedekleme ekranı bunu göstererek kullanıcıya durum bildirir.
class TrackBackupInfo {
  const TrackBackupInfo({required this.updatedAt, required this.count});

  final DateTime updatedAt;
  final int count;
}

/// Takip Merkezi bulut YEDEĞİ soyutlaması. Yerel-öncelikli mimari korunur:
/// bu katman CANLI SENKRON DEĞİLDİR — yalnızca kullanıcının elle tetiklediği
/// tam yedek (kayıtların anlık görüntüsü) ve geri yükleme yapar.
///
/// Kayıtlar `users/{uid}/trackBackup/{id}` altında saklanır (yalnız sahibi
/// erişir — kişisel takip verisi kamuya açık değildir). Ek DOSYALARI ayrıca
/// Storage'a yüklenir; bu arayüz yalnız metadata (TrackItem) ile ilgilenir,
/// ek yükleme/indirme orkestrasyonu [TrackBackupService]'tedir.
abstract interface class TrackBackupRepository {
  /// Bulut yedeğinin özeti; hiç yedek yoksa null.
  Future<TrackBackupInfo?> fetchInfo(String uid);

  /// Verilen kayıtları bulutta AYNALAR: eksik olanları siler, mevcutları
  /// üzerine yazar, özet bilgisini [at] ile günceller. (Tam anlık görüntü.)
  Future<void> backup(String uid, List<TrackItem> items, DateTime at);

  /// Buluttaki tüm yedek kayıtları döndürür (özet dokümanı hariç).
  Future<List<TrackItem>> restore(String uid);
}

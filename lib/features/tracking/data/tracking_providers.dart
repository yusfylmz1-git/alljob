import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/track_item.dart';
import '../../auth/application/auth_controller.dart';
import 'firebase_track_backup_repository.dart';
import 'mock_track_backup_repository.dart';
import 'sqflite_tracking_repository.dart';
import 'track_backup_repository.dart';
import 'tracking_repository.dart';

/// Takip Merkezi deposu. Yerel-öncelikli: HER ZAMAN cihaz içi sqflite
/// (Firebase backend seçiminden bağımsız — takip verisi buluta değil cihaza
/// yazılır). Testlerde `mockBackendOverrides` ile bellek-içi mock'a çevrilir.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final repo = SqfliteTrackingRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Bulut yedeği deposu (Faz 5). Yerel takip verisinden farklı olarak BULUT
/// yedeği backend seçimine bağlıdır: Firebase varsa Firestore, yoksa (testler)
/// bellek-içi mock. Canlı senkron DEĞİL — yalnız elle yedek/geri yükle.
final trackBackupRepositoryProvider = Provider<TrackBackupRepository>((ref) {
  if (useFirebaseBackend) return FirebaseTrackBackupRepository();
  return MockTrackBackupRepository();
});

/// Oturumdaki kullanıcının aktif takipleri (çöpte olmayanlar). Oturum yoksa
/// boş (modül Profil'den açılır → normalde her zaman oturum vardır).
final activeTracksProvider = StreamProvider<List<TrackItem>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const <TrackItem>[]);
  return ref.watch(trackingRepositoryProvider).watchActive(uid);
});

/// Oturumdaki kullanıcının çöp kutusundaki takipleri.
final trashedTracksProvider = StreamProvider<List<TrackItem>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const <TrackItem>[]);
  return ref.watch(trackingRepositoryProvider).watchTrashed(uid);
});

/// Tek bir takibin canlı görünümü (detay ekranı) — aktif listeden türetilir,
/// böylece düzenleme/tamamlama anında yansır.
final trackByIdProvider = Provider.family<TrackItem?, String>((ref, id) {
  final list = ref.watch(activeTracksProvider).valueOrNull ?? const [];
  for (final t in list) {
    if (t.id == id) return t;
  }
  return null;
});

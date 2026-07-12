import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'storage_repository.dart';

/// Firebase Cloud Storage ile çalışan [StorageRepository]. Görseli yükler ve
/// kalıcı indirme URL'sini döndürür. Uzak URL olduğu için [localBytes] null döner
/// (görüntüleme `AppImage`'ın network yolu üzerinden yapılır).
class FirebaseStorageRepository implements StorageRepository {
  FirebaseStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// putData'nın KENDİ zaman aşımı yok: dalgalı ağda aktarım askıda kalınca
  /// Future asla dönmüyor ve UI'daki spinner sonsuza dek dönüyordu (sohbette
  /// "tekrar dene" akışı hiç tetiklenemiyordu). Görseller ~150–300 KB'a
  /// sıkıştırıldığından 60 sn cömert bir tavandır; aşılırsa aktarım iptal
  /// edilir ve çağıran katman hata akışını çalıştırır.
  static const Duration _uploadTimeout = Duration(seconds: 60);
  static const Duration _urlTimeout = Duration(seconds: 20);

  @override
  Future<String> uploadImage({
    required String pathHint,
    required Uint8List bytes,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('$pathHint/$ts.jpg');
    final task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    try {
      await task.timeout(_uploadTimeout);
    } on TimeoutException {
      // Askıda kalan aktarımı bırak (arkada tamamlansa bile handle
      // kullanılmayacak); iptalin kendisi hata verirse yoksay.
      unawaited(task.cancel().catchError((_) => false));
      rethrow;
    }
    return ref.getDownloadURL().timeout(_urlTimeout);
  }

  @override
  Uint8List? localBytes(String handle) => null;

  /// Bulut yedeğinden indirilebilecek en büyük ek (Storage `getData` üst sınırı).
  static const int _maxDownloadBytes = 30 * 1024 * 1024;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage.ref(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    try {
      await task.timeout(_uploadTimeout);
    } on TimeoutException {
      unawaited(task.cancel().catchError((_) => false));
      rethrow;
    }
    return ref.getDownloadURL().timeout(_urlTimeout);
  }

  @override
  Future<Uint8List?> downloadBytes(String handle) async {
    return _storage.refFromURL(handle).getData(_maxDownloadBytes).timeout(
          _uploadTimeout,
        );
  }
}

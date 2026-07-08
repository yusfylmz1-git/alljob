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

  @override
  Future<String> uploadImage({
    required String pathHint,
    required Uint8List bytes,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('$pathHint/$ts.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  @override
  Uint8List? localBytes(String handle) => null;
}

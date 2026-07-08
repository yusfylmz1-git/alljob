import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_config.dart';
import 'firebase_storage_repository.dart';

/// Görsel depolama soyutlaması (PRD: Firebase Cloud Storage).
/// Şu an `MockStorageRepository` ile bellek içi; Firebase'de
/// `FirebaseStorageRepository` yazılıp provider değişecek.
abstract interface class StorageRepository {
  /// Görseli yükler ve görüntülenebilir bir handle/URL döndürür.
  Future<String> uploadImage({
    required String pathHint,
    required Uint8List bytes,
  });

  /// Mock handle ise bellekteki baytları döndürür; uzak URL ise null.
  Uint8List? localBytes(String handle);
}

/// Bellek içi depolama. Yüklenen baytları `local://` handle ile saklar.
class MockStorageRepository implements StorageRepository {
  final Map<String, Uint8List> _store = {};
  int _counter = 0;

  @override
  Future<String> uploadImage({
    required String pathHint,
    required Uint8List bytes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final handle = 'local://$pathHint/${_counter++}';
    _store[handle] = bytes;
    return handle;
  }

  @override
  Uint8List? localBytes(String handle) => _store[handle];
}

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  // Storage, Blaze plan gerektirdiğinden ayrı bir bayrakla kontrol edilir.
  if (useFirebaseBackend && useFirebaseStorage) {
    return FirebaseStorageRepository();
  }
  return MockStorageRepository();
});

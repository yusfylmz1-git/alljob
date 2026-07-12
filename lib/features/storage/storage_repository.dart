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

  /// Ham baytları TAM yola yükler (Takip Merkezi bulut yedeği — foto/dosya/ses
  /// ekleri). [uploadImage]'dan farkı: yol birebir kullanılır (zaman damgası
  /// eklenmez) ve içerik tipi çağırana bırakılır (yalnız görsel değil).
  /// Döndürülen handle/URL sonradan [downloadBytes] ile geri okunur.
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  /// [uploadBytes]/[uploadImage] ile üretilmiş bir handle/URL'nin baytlarını
  /// indirir (bulut yedeğinden geri yükleme). Bulunamazsa null.
  Future<Uint8List?> downloadBytes(String handle);
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

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final handle = 'local://$path';
    _store[handle] = bytes;
    return handle;
  }

  @override
  Future<Uint8List?> downloadBytes(String handle) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _store[handle];
  }
}

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  // Storage, Blaze plan gerektirdiğinden ayrı bir bayrakla kontrol edilir.
  if (useFirebaseBackend && useFirebaseStorage) {
    return FirebaseStorageRepository();
  }
  return MockStorageRepository();
});

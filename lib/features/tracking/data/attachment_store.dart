import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/track_item.dart';

/// Takip Merkezi eklerini (foto/dosya/ses) YEREL olarak saklar. Seçilen/kaydedilen
/// dosya, uygulamanın kalıcı dizinine (`<appDocs>/track_attachments/`) KOPYALANIR
/// → kaynak (galeri önbelleği, geçici kayıt) silinse de ek durur. Buluta yükleme
/// YOK (o Faz 5). Kayıt silinince [deleteFiles] ile dosyalar da temizlenir.
class AttachmentStore {
  /// [baseDirOverride] yalnız testler içindir (path_provider olmadan geçici
  /// dizin sağlar); üretimde `getApplicationDocumentsDirectory` kullanılır.
  const AttachmentStore({Future<Directory> Function()? baseDirOverride})
      : _baseDirOverride = baseDirOverride;

  final Future<Directory> Function()? _baseDirOverride;

  static const _dirName = 'track_attachments';

  Future<Directory> _dir() async {
    final override = _baseDirOverride;
    final base = override != null
        ? await override()
        : await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _extForType(TrackAttachmentType type) => switch (type) {
        TrackAttachmentType.photo => '.jpg',
        TrackAttachmentType.audio => '.m4a',
        TrackAttachmentType.file => '.bin',
      };

  String _newName(String extension) {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rnd = Random().nextInt(1 << 32).toRadixString(36);
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return 'a_${ts}_$rnd$ext';
  }

  /// [sourcePath]'teki dosyayı uygulama dizinine kopyalar ve [TrackAttachment]
  /// döndürür. [move] true ise kaynak silinir (kendi ürettiğimiz geçici ses
  /// kaydı gibi). Görünen ad [displayName] verilmezse kaynağın adı kullanılır.
  Future<TrackAttachment> save({
    required String sourcePath,
    required TrackAttachmentType type,
    String? displayName,
    int? durationMs,
    bool move = false,
  }) async {
    final src = File(sourcePath);
    final ext = p.extension(sourcePath);
    final dir = await _dir();
    final destPath = p.join(dir.path, _newName(ext));
    final dest = move ? await src.rename(destPath) : await src.copy(destPath);
    // rename cihazlar arası (farklı hacim) başarısız olabilir → kopya + sil fallback.
    File finalFile = dest;
    if (move && !await File(destPath).exists()) {
      finalFile = await src.copy(destPath);
      try {
        await src.delete();
      } catch (_) {}
    }
    final size = await finalFile.length();
    return TrackAttachment(
      type: type,
      path: finalFile.path,
      name: displayName ?? p.basename(sourcePath),
      sizeBytes: size,
      durationMs: durationMs,
    );
  }

  /// Ham baytları (bulut yedeğinden indirilen ek) uygulama dizinine yazar ve
  /// yerel yolu taşıyan bir [TrackAttachment] döndürür. Dosya adı korunmaya
  /// çalışılır (uzantı için), yoksa türe göre varsayılan uzantı kullanılır.
  Future<TrackAttachment> saveBytes({
    required Uint8List bytes,
    required TrackAttachmentType type,
    String? name,
    int? durationMs,
  }) async {
    final ext = (name != null && p.extension(name).isNotEmpty)
        ? p.extension(name)
        : _extForType(type);
    final dir = await _dir();
    final destPath = p.join(dir.path, _newName(ext));
    final file = File(destPath);
    await file.writeAsBytes(bytes);
    return TrackAttachment(
      type: type,
      path: file.path,
      name: name,
      sizeBytes: bytes.length,
      durationMs: durationMs,
    );
  }

  /// Bir eke ait yerel dosyayı siler (yoksa sessizce geçer).
  Future<void> deleteFile(TrackAttachment att) async {
    try {
      final f = File(att.path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Ek silme hatası: $e');
    }
  }

  /// Bir kaydın tüm eklerinin dosyalarını siler (kayıt kalıcı silinirken).
  Future<void> deleteFiles(Iterable<TrackAttachment> atts) async {
    for (final a in atts) {
      await deleteFile(a);
    }
  }
}

final attachmentStoreProvider =
    Provider<AttachmentStore>((ref) => const AttachmentStore());

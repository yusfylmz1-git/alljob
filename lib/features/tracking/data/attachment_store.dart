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
  const AttachmentStore();

  static const _dirName = 'track_attachments';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

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

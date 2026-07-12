import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/track_item.dart';

String attachmentBytesLabel(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String attachmentDurationLabel(int? ms) {
  if (ms == null) return '';
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ---------------------------------------------------------------------------
// Düzenleme: eklenebilir/kaldırılabilir ek listesi
// ---------------------------------------------------------------------------

class AttachmentEditor extends StatelessWidget {
  const AttachmentEditor({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    required this.busy,
  });

  final List<TrackAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<TrackAttachment> onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final photos =
        attachments.where((a) => a.type == TrackAttachmentType.photo).toList();
    final others =
        attachments.where((a) => a.type != TrackAttachmentType.photo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in photos)
                _PhotoThumb(
                  attachment: a,
                  onRemove: () => onRemove(a),
                ),
            ],
          ),
        if (photos.isNotEmpty && others.isNotEmpty) const SizedBox(height: 10),
        for (final a in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FileRow(
              attachment: a,
              trailing: IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: context.palette.inkMuted),
                onPressed: () => onRemove(a),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: busy ? null : onAdd,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add, size: 18),
          label: Text(busy ? 'Ekleniyor…' : 'Ek ekle'),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.attachment, this.onRemove, this.onTap});
  final TrackAttachment attachment;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(attachment.path),
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 92,
                height: 92,
                color: context.palette.surfaceMuted,
                child: Icon(Icons.broken_image_outlined,
                    color: context.palette.inkFaint),
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close, size: 15, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.attachment, this.trailing});
  final TrackAttachment attachment;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isAudio = attachment.type == TrackAttachmentType.audio;
    final subtitle = isAudio
        ? 'Ses notu · ${attachmentDurationLabel(attachment.durationMs)}'
        : attachmentBytesLabel(attachment.sizeBytes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          Icon(isAudio ? Icons.mic : Icons.insert_drive_file_outlined,
              size: 22, color: palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name ?? (isAudio ? 'Ses notu' : 'Dosya'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: palette.inkMuted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detay: salt-okunur ek galerisi (foto tam ekran, ses oynatılır)
// ---------------------------------------------------------------------------

class AttachmentGallery extends StatelessWidget {
  const AttachmentGallery({super.key, required this.attachments});
  final List<TrackAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final photos =
        attachments.where((a) => a.type == TrackAttachmentType.photo).toList();
    final audios =
        attachments.where((a) => a.type == TrackAttachmentType.audio).toList();
    final files =
        attachments.where((a) => a.type == TrackAttachmentType.file).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in photos)
                _PhotoThumb(
                  attachment: a,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _FullScreenImage(path: a.path),
                    ),
                  ),
                ),
            ],
          ),
        if (photos.isNotEmpty && (audios.isNotEmpty || files.isNotEmpty))
          const SizedBox(height: 10),
        for (final a in audios)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AudioTile(attachment: a),
          ),
        for (final a in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FileRow(attachment: a),
          ),
      ],
    );
  }
}

class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.attachment});
  final TrackAttachment attachment;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.play(DeviceFileSource(widget.attachment.path));
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.attachment.name ?? 'Ses notu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  attachmentDurationLabel(widget.attachment.durationMs),
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(path), errorBuilder: (_, _, _) {
            return const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 48);
          }),
        ),
      ),
    );
  }
}

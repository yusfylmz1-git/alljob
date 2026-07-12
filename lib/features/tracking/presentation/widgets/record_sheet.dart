import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_palette.dart';

/// Ses kaydı sonucu: geçici dosya yolu + süre (ms). Çağıran katman dosyayı
/// [AttachmentStore] ile uygulama dizinine taşır.
class RecordResult {
  const RecordResult({required this.path, required this.durationMs});
  final String path;
  final int durationMs;
}

/// Ses notu kayıt sayfasını açar. Kayıt tamamlanırsa [RecordResult], iptal
/// edilirse null döner. İzin yoksa (mikrofon reddi) null döner.
Future<RecordResult?> showRecordSheet(BuildContext context) {
  return showModalBottomSheet<RecordResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _RecordSheet(),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet();

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final _recorder = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _starting = false;
  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _starting = false;
          _error = 'Mikrofon izni gerekli.';
        });
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path,
          'rec_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(const RecordConfig(), path: path);
      _elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
      setState(() {
        _recording = true;
        _starting = false;
      });
    } catch (_) {
      setState(() {
        _starting = false;
        _error = 'Kayıt başlatılamadı.';
      });
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final ms = _elapsed.inMilliseconds;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      if (path == null) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context, RecordResult(path: path, durationMs: ms));
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    try {
      if (_recording) {
        final path = await _recorder.stop();
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  String get _label {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ses Notu',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording
                    ? palette.danger.withValues(alpha: 0.12)
                    : palette.surfaceMuted,
              ),
              child: Icon(
                _recording ? Icons.mic : Icons.mic_none,
                size: 38,
                color: _recording ? palette.danger : palette.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(_label,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.danger)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _starting
                        ? null
                        : (_recording ? _stop : _start),
                    icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(_recording ? 'Bitir' : 'Kaydet'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _recording ? palette.danger : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

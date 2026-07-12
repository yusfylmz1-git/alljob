import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../application/track_backup_service.dart';
import '../data/track_backup_repository.dart';

/// Takip Merkezi bulut yedeği ekranı (Faz 5). Yerel-öncelikli mimari korunur:
/// kullanıcı takiplerini ELLE buluta yedekler ve gerektiğinde geri yükler.
/// CANLI SENKRON YOK — bu bilinçli bir üründür (yerel her zaman ana kaynak).
class TrackBackupScreen extends ConsumerStatefulWidget {
  const TrackBackupScreen({super.key});

  @override
  ConsumerState<TrackBackupScreen> createState() => _TrackBackupScreenState();
}

class _TrackBackupScreenState extends ConsumerState<TrackBackupScreen> {
  bool _loadingInfo = true;
  bool _busy = false;
  TrackBackupInfo? _info;

  @override
  void initState() {
    super.initState();
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    setState(() => _loadingInfo = true);
    final info = await ref.read(trackBackupServiceProvider).currentInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loadingInfo = false;
    });
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    final result = await ref.read(trackBackupServiceProvider).backupNow();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      context.showSuccess(
          '${result.count} takip buluta yedeklendi.');
      await _refreshInfo();
    } else {
      context.showError(result.error!);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedeği geri yükle'),
        content: const Text(
          'Buluttaki yedek bu cihaza geri yüklenecek. Aynı kimlikli kayıtlar '
          'yedekteki hâliyle güncellenir; yerelde olup yedekte olmayan '
          'kayıtların silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(trackBackupServiceProvider).restoreNow();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      context.showSuccess('${result.count} takip geri yüklendi.');
    } else {
      context.showError(result.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Bulut Yedeği',
        icon: Icons.cloud_sync_rounded,
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ListView(
          children: [
            _InfoCard(loading: _loadingInfo, info: _info),
            const SizedBox(height: 20),
            AppButton(
              label: 'Şimdi Yedekle',
              icon: Icons.cloud_upload_outlined,
              isLoading: _busy,
              onPressed: _busy ? null : _backup,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Yedeği Geri Yükle',
              icon: Icons.cloud_download_outlined,
              variant: AppButtonVariant.tonal,
              onPressed: _busy || _info == null ? null : _restore,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: palette.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Takiplerin öncelikle bu cihazda saklanır. Bulut yedeği '
                      'yalnızca güvenlik kopyasıdır — otomatik eşitleme yapılmaz. '
                      'Cihaz değiştirdiğinde ya da veri kaybına karşı elle '
                      'yedekle, sonra geri yükle.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.loading, required this.info});

  final bool loading;
  final TrackBackupInfo? info;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final Widget content;
    if (loading) {
      content = const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (info == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Henüz yedek yok',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('İlk yedeğini almak için "Şimdi Yedekle"ye dokun.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted)),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Son yedek',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: palette.inkMuted)),
          const SizedBox(height: 4),
          Text(_formatDate(info!.updatedAt),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${info!.count} takip yedekte',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: palette.inkMuted)),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_outlined,
              size: 30, color: palette.onPrimaryContainer),
          const SizedBox(width: 16),
          Expanded(child: content),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

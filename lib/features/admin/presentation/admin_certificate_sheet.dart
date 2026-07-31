import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/models/artisan_profile.dart';
import '../data/admin_providers.dart';

/// Ustalık/yeterlilik belgesi inceleme sayfası (usta bazında tek karar).
///
/// Uygulama ustaya "Belgeler yönetici onayından geçer" diyor; bu ekran o
/// sözün karşılığıdır. Onay YALNIZ "Belgeli usta" rozeti verir — mavi tik
/// (telefon/platform onayı) mantığına dokunmaz.
///
/// Reddetmede gerekçe zorunludur: usta neyi düzelteceğini bilmeli (gerekçe
/// ustaya bildirim olarak gider).
Future<void> showCertificateReviewSheet(
  BuildContext context,
  WidgetRef ref, {
  required ArtisanProfile profile,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CertificateReviewSheet(profile: profile),
  );
}

class _CertificateReviewSheet extends ConsumerStatefulWidget {
  const _CertificateReviewSheet({required this.profile});
  final ArtisanProfile profile;

  @override
  ConsumerState<_CertificateReviewSheet> createState() =>
      _CertificateReviewSheetState();
}

class _CertificateReviewSheetState
    extends ConsumerState<_CertificateReviewSheet> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve}) async {
    final note = _note.text.trim();
    if (!approve && note.length < 5) {
      context.showError('Red gerekçesi zorunlu (en az 5 karakter).');
      return;
    }
    // Kilidi ilk anda al — çift dokunuş ikinci karar göndermesin.
    setState(() => _busy = true);
    try {
      await ref
          .read(adminArtisanRepositoryProvider)
          .reviewCertificates(
            widget.profile.uid,
            approve: approve,
            note: approve ? null : note,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.invalidate(artisanDirectoryControllerProvider);
      context.showSuccess(
        approve ? 'Belgeler onaylandı.' : 'Belgeler reddedildi.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız. Tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final p = widget.profile;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Belge incelemesi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'UID: ${p.uid}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
              const SizedBox(height: 10),

              _StatusBanner(profile: p),
              const SizedBox(height: 14),

              Text(
                'Yüklenen belgeler (${p.certificates.length})',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.certificates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppImage(
                      handle: p.certificates[i],
                      width: 120,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Red gerekçesi (reddetmek için zorunlu)',
                  hintText: 'Örn: Belge okunaksız, net bir fotoğraf yükleyin.',
                  border: OutlineInputBorder(),
                ),
              ),
              Text(
                'Gerekçe ustaya bildirim olarak gönderilir.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Onayla'),
                      onPressed: _busy ? null : () => _decide(approve: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger,
                    ),
                    onPressed: _busy ? null : () => _decide(approve: false),
                    child: const Text('Reddet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.profile});
  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final (String text, Color color) = switch (profile.certificateStatus) {
      'approved' => (
        'Onaylı — usta "Belgeli usta" rozetini taşıyor.',
        palette.success,
      ),
      'rejected' => (
        'Reddedildi${profile.certificateNote != null ? ' · ${profile.certificateNote}' : ''}',
        palette.danger,
      ),
      'pending' => ('İnceleme bekliyor.', palette.warning),
      _ => ('Belge durumu yok.', palette.inkMuted),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../application/toolkit_models.dart';

/// Hesaplayıcı sonuçlarını gösteren ortak kart. Öne çıkan vurgu değeri +
/// derli toplu bir detay özeti; kopyalama/paylaşım başlıktaki iki küçük ikonla
/// yapılır (koca "Kopyala" düğmesi yerine).
///
/// Kopya → panoya; Paylaş → sistem paylaşım sayfası (WhatsApp/e-posta…). Kart
/// içine gömülü özel bir [eylemler] alanı verilirse (ör. Teklif'te "PDF")
/// alt satırda gösterilir.
class SonucKarti extends StatelessWidget {
  const SonucKarti({
    super.key,
    required this.baslik,
    required this.vurguDeger,
    required this.sonuc,
    this.kaynak,
    this.eylemler,
  });

  /// Kart başlığı (ör. "Sonuç").
  final String baslik;

  /// Öne çıkan tek satır (ör. "Tahmini boya ihtiyacı: 3,2 litre").
  final String vurguDeger;

  final HesapSonucu sonuc;

  /// Ölçünün kaynağı (AR / Manuel). Verilirse başlık satırında rozet gösterilir
  /// (PRD §6.6 kural 3). Elle girişli araçlarda null bırakılır.
  final OlcuKaynagi? kaynak;

  /// Karta özgü ek eylem düğmeleri (ör. Teklif'te "PDF olarak paylaş").
  /// Verilirse özetin altında bir satırda gösterilir.
  final List<Widget>? eylemler;

  Future<void> _kopyala(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: sonuc.ozet));
    if (context.mounted) context.showSuccess('Panoya kopyalandı.');
  }

  Future<void> _paylas() => SharePlus.instance.share(
        ShareParams(text: sonuc.ozet, subject: baslik),
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  baslik.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (kaynak != null) ...[
                _KaynakRozeti(kaynak: kaynak!),
                const SizedBox(width: 4),
              ],
              // Küçük kopya + paylaş ikonları (koca düğme yerine).
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Kopyala',
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: palette.primary,
                onPressed: () => _kopyala(context),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Paylaş',
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                color: palette.primary,
                onPressed: _paylas,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            vurguDeger,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const Divider(height: 24),
          Text(
            sonuc.ozet,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.ink),
          ),
          if (eylemler != null && eylemler!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: eylemler!),
          ],
        ],
      ),
    );
  }
}

/// Ölçü kaynağı rozeti (AR / Manuel).
class _KaynakRozeti extends StatelessWidget {
  const _KaynakRozeti({required this.kaynak});
  final OlcuKaynagi kaynak;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kaynak == OlcuKaynagi.ar
                ? Icons.camera_alt_outlined
                : Icons.edit_outlined,
            size: 13,
            color: palette.primary,
          ),
          const SizedBox(width: 4),
          Text(
            kaynak.etiket,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

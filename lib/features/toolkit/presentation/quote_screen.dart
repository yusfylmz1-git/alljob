import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../auth/application/auth_controller.dart';
import '../application/toolkit_calculators.dart' show trSayi;
import '../application/toolkit_cost.dart';
import '../application/toolkit_pdf.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Teklif Oluşturucu (PRD-007 Faz C §6.4). Kalemler (açıklama + miktar × birim
/// fiyat) + KDV (TR %20 seçeneği) + not → paylaşılabilir teklif. Sonuç hem
/// metin (kopyala/paylaş) hem **PDF** (paylaş/yazdır) olarak dışa aktarılır.
class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key});

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _KalemGirdi {
  final TextEditingController aciklama = TextEditingController();
  final TextEditingController miktar = TextEditingController(text: '1');
  final TextEditingController birimFiyat = TextEditingController();

  void dispose() {
    aciklama.dispose();
    miktar.dispose();
    birimFiyat.dispose();
  }
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  final List<_KalemGirdi> _kalemler = [_KalemGirdi()];
  final TextEditingController _not = TextEditingController();
  bool _kdvVar = true;
  TeklifSonucu? _sonuc;
  bool _pdfMesgul = false;

  @override
  void dispose() {
    for (final k in _kalemler) {
      k.dispose();
    }
    _not.dispose();
    super.dispose();
  }

  void _hesapla() {
    final kalemler = <TeklifKalemi>[];
    for (final g in _kalemler) {
      final aciklama = g.aciklama.text.trim();
      final miktar = Validators.parseTrAmount(g.miktar.text) ?? 0;
      final fiyat = Validators.parseTrAmount(g.birimFiyat.text) ?? 0;
      if (aciklama.isEmpty && miktar == 0 && fiyat == 0) continue;
      kalemler.add(TeklifKalemi(
        aciklama: aciklama.isEmpty ? 'Kalem' : aciklama,
        miktar: miktar,
        birimFiyat: fiyat,
      ));
    }
    if (kalemler.isEmpty) {
      setState(() => _sonuc = null);
      return;
    }
    setState(() {
      _sonuc = teklifHesapla(
        kalemler: kalemler,
        kdvOrani: _kdvVar ? 0.20 : 0.0,
        not: _not.text,
      );
    });
  }

  /// Teklifin PDF baytlarını üretir. Hazırlayan = oturum açık kullanıcının adı.
  Future<List<int>> _pdfBaytlari(TeklifSonucu sonuc) {
    final ad = ref.read(currentUserProvider)?.displayName.trim();
    return teklifPdfOlustur(
      sonuc,
      hazirlayan: (ad == null || ad.isEmpty) ? null : ad,
    );
  }

  Future<void> _pdfPaylas(TeklifSonucu sonuc) async {
    if (_pdfMesgul) return;
    setState(() => _pdfMesgul = true);
    try {
      final bytes = await _pdfBaytlari(sonuc);
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'teklif.pdf',
        subject: 'Fiyat Teklifi',
      );
    } catch (_) {
      if (mounted) context.showError('PDF oluşturulamadı.');
    } finally {
      if (mounted) setState(() => _pdfMesgul = false);
    }
  }

  Future<void> _pdfYazdir(TeklifSonucu sonuc) async {
    if (_pdfMesgul) return;
    setState(() => _pdfMesgul = true);
    try {
      await Printing.layoutPdf(
        name: 'Fiyat Teklifi',
        onLayout: (_) async => Uint8List.fromList(await _pdfBaytlari(sonuc)),
      );
    } catch (_) {
      if (mounted) context.showError('Yazdırma açılamadı.');
    } finally {
      if (mounted) setState(() => _pdfMesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Teklif Oluştur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          for (var i = 0; i < _kalemler.length; i++)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kalemler[i].aciklama,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: _kalemler.length > 1
                                  ? palette.danger
                                  : palette.inkMuted),
                          onPressed: _kalemler.length > 1
                              ? () => setState(
                                  () => _kalemler.removeAt(i).dispose())
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SayiAlani(
                            controller: _kalemler[i].miktar,
                            label: 'Miktar',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SayiAlani(
                            controller: _kalemler[i].birimFiyat,
                            label: 'Birim fiyat',
                            suffix: 'TL',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Kalem ekle'),
              onPressed: () => setState(() => _kalemler.add(_KalemGirdi())),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('KDV ekle (%20)'),
            value: _kdvVar,
            onChanged: (v) => setState(() => _kdvVar = v),
          ),
          TextFormField(
            controller: _not,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Not (isteğe bağlı)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Teklifi Oluştur'),
            onPressed: _hesapla,
          ),
          if (_sonuc != null) ...[
            const SizedBox(height: 20),
            SonucKarti(
              baslik: 'Genel toplam',
              vurguDeger: '${trSayi(_sonuc!.genelToplam)} TL',
              sonuc: _sonuc!,
              eylemler: [
                Expanded(
                  child: FilledButton.icon(
                    icon: _pdfMesgul
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF paylaş'),
                    onPressed:
                        _pdfMesgul ? null : () => _pdfPaylas(_sonuc!),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Yazdır',
                  icon: const Icon(Icons.print_outlined),
                  onPressed: _pdfMesgul ? null : () => _pdfYazdir(_sonuc!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

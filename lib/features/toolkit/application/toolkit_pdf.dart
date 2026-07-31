/// Usta Çantası — Teklif PDF üretimi (PRD-007 Faz C §6.4 uzantısı).
///
/// Teklifi paylaşılabilir/yazdırılabilir bir A4 belgeye dönüştürür. Türkçe
/// karakterler için uygulamanın Inter fontu PDF'e gömülür (varsayılan Helvetica
/// ş/ğ/İ/ı gliflerini basmaz). Saf üretim: UI'dan bağımsız, tek girdi
/// [TeklifSonucu].
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'toolkit_calculators.dart' show trSayi;
import 'toolkit_cost.dart';

/// Teklif için gömülü Inter font ailesi (regular + bold). Bir kez yüklenir.
class _PdfFontlari {
  _PdfFontlari(this.normal, this.bold);
  final pw.Font normal;
  final pw.Font bold;

  static _PdfFontlari? _cache;

  static Future<_PdfFontlari> yukle() async {
    if (_cache != null) return _cache!;
    final reg = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    return _cache = _PdfFontlari(pw.Font.ttf(reg), pw.Font.ttf(bold));
  }
}

/// [sonuc]'tan A4 teklif PDF'i üretir ve baytlarını döndürür.
///
/// [baslik] belge başlığı (varsayılan "Fiyat Teklifi"); [hazirlayan] varsa
/// üst köşede gösterilir (ör. ustanın adı — ileride profil ad soyad).
Future<List<int>> teklifPdfOlustur(
  TeklifSonucu sonuc, {
  String baslik = 'Fiyat Teklifi',
  String? hazirlayan,
}) async {
  final fontlar = await _PdfFontlari.yukle();
  final doc = pw.Document();

  final tarih = DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.now());
  final tema = pw.ThemeData.withFont(
    base: fontlar.normal,
    bold: fontlar.bold,
  );

  String tl(double v) => '${trSayi(v)} TL';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: tema,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Başlık şeridi.
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      baslik,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1E40AF),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(tarih,
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                if (hazirlayan != null && hazirlayan.trim().isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEFF4FF),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(hazirlayan.trim(),
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Kalemler tablosu.
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromInt(0xFF2563EB)),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              headers: ['Açıklama', 'Miktar', 'Birim Fiyat', 'Tutar'],
              data: [
                for (final k in sonuc.kalemler)
                  [
                    k.aciklama,
                    trSayi(k.miktar),
                    tl(k.birimFiyat),
                    tl(k.tutar),
                  ],
              ],
            ),
            pw.SizedBox(height: 14),

            // Toplamlar (sağa hizalı).
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 240,
                child: pw.Column(
                  children: [
                    _ozetSatiri('Ara toplam', tl(sonuc.araToplam)),
                    if (sonuc.kdvOrani > 0)
                      _ozetSatiri(
                        'KDV (%${trSayi(sonuc.kdvOrani * 100)})',
                        tl(sonuc.kdvTutari),
                      ),
                    pw.Divider(color: PdfColors.grey400),
                    _ozetSatiri('GENEL TOPLAM', tl(sonuc.genelToplam),
                        vurgu: true),
                  ],
                ),
              ),
            ),

            if (sonuc.not.trim().isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Not',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(sonuc.not.trim(),
                  style: const pw.TextStyle(fontSize: 10)),
            ],

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Bu teklif tahminidir; kesin fiyat yerinde görüldükten sonra '
              'netleşir. Ustasından ile oluşturulmuştur.',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _ozetSatiri(String etiket, String deger, {bool vurgu = false}) {
  final style = pw.TextStyle(
    fontSize: vurgu ? 13 : 10,
    fontWeight: vurgu ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: vurgu ? PdfColor.fromInt(0xFF1E40AF) : PdfColors.black,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(etiket, style: style),
        pw.Text(deger, style: style),
      ],
    ),
  );
}
